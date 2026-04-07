import 'dart:async';

import 'package:flutter/widgets.dart';

import '../contracts/contract_bus.dart';
import '../contracts/event_contracts.dart';
import '../event_bus/event_bus.dart';
import '../event_bus/event_payload.dart';
import '../renderer/json_path_resolver.dart';
import '../renderer/template_resolver.dart';

/// Per-widget state manager. Sits outside the widget tree.
///
/// Owns all mutable state for a widget instance: selection, expansion,
/// filter, custom keys. The widget tree reads state via [StateManagerScope]
/// (InheritedNotifier) and rebuilds automatically when state changes.
///
/// EventBus is used only for cross-widget communication. Intra-widget
/// state flows through the StateManager, never through EventBus channels.
class StateManager extends ChangeNotifier {
  final String widgetId;
  final EventBus eventBus;
  final ContractBus? contractBus;
  final StateConfig config;

  final Map<String, dynamic> _state = {};
  final List<StreamSubscription> _subs = [];

  StateManager({
    required this.widgetId,
    required this.eventBus,
    this.contractBus,
    required this.config,
  }) {
    // Apply initial state before wiring listeners.
    _state.addAll(config.initialState);
    _wireExternalListeners();
    _wireContractSubscriptions();
    _wireToggleBindings();
    _wireSetBindings();
    _wireResetBindings();
  }

  // ---------------------------------------------------------------------------
  // State access
  // ---------------------------------------------------------------------------

  /// Get a single state value by key.
  dynamic get(String key) => _state[key];

  /// Full state snapshot — readable by chat/agent.
  Map<String, dynamic> get snapshot => Map.unmodifiable(_state);

  /// Check if an item is selected based on the configured selection.
  bool isSelected(Map<String, dynamic> item) {
    final sel = config.selection;
    if (sel == null) return false;
    final value = resolveJsonPath(item, sel.matchField);
    if (value == null) return false;
    final selected = _state['_selectedValues'] as Set<String>? ?? const {};
    return selected.contains(value.toString());
  }

  /// The match field for selection, if configured.
  String? get selectionMatchField => config.selection?.matchField;

  // ---------------------------------------------------------------------------
  // State mutation
  // ---------------------------------------------------------------------------

  /// Set a single key.
  void set(String key, dynamic value) {
    _state[key] = value;
    notifyListeners();
  }

  /// Merge multiple keys.
  void merge(Map<String, dynamic> values) {
    _state.addAll(values);
    notifyListeners();
  }

  /// Select a value. In single mode, replaces previous. In multi mode, toggles.
  void select(String value) {
    final sel = config.selection;
    if (sel == null) return;

    final current = _state['_selectedValues'] as Set<String>? ?? {};
    final updated = Set<String>.from(current);

    if (sel.multi) {
      if (!updated.remove(value)) {
        updated.add(value);
      }
    } else {
      updated
        ..clear()
        ..add(value);
    }

    _state['_selectedValues'] = updated;
    notifyListeners();
  }

  /// Toggle a boolean key.
  void toggle(String key) {
    _state[key] = !(_state[key] == true);
    notifyListeners();
  }

  /// Reset all state.
  void reset() {
    _state.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Action handler — called by Action widget
  // ---------------------------------------------------------------------------

  /// Handle a gesture action from the widget tree.
  ///
  /// Updates local state (e.g., selection) and publishes to EventBus
  /// if the channel is in the publish list.
  void onAction(String channel, Map<String, dynamic> payload) {
    // Update selection if this channel matches the selection config.
    final sel = config.selection;
    if (sel != null && channel == sel.channel) {
      final value = payload[sel.payloadField]?.toString();
      if (value != null) {
        select(value);
      }
    }

    // Publish to EventBus for cross-widget communication.
    if (config.publishChannels.contains(channel)) {
      eventBus.publish(
        channel,
        EventPayload(
          type: channel,
          sourceWidgetId: widgetId,
          data: {...payload, '_channel': channel},
        ),
      );
    }

    // Publish to ContractBus for typed inter-widget communication.
    final bus = contractBus;
    if (bus != null) {
      for (final prod in config.produces) {
        final contractPayload = <String, dynamic>{};
        for (final entry in prod.mapping.entries) {
          final contractField = entry.key;
          final sourceField = entry.value;
          contractPayload[contractField] =
              payload[sourceField] ?? payload[contractField];
        }
        bus.publish(
          contractName: prod.contract,
          payload: contractPayload,
          sourceWidgetId: widgetId,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // External event bridge
  // ---------------------------------------------------------------------------

  void _wireExternalListeners() {
    for (final channel in config.listenChannels) {
      _subs.add(eventBus.subscribe(channel).listen((event) {
        // External events can update state — e.g., "navigate to this item"
        merge(Map<String, dynamic>.from(event.data));
      }));
    }
  }

  void _wireContractSubscriptions() {
    final bus = contractBus;
    if (bus == null) return;
    for (final cons in config.consumes) {
      _subs.add(bus.subscribe(cons).listen((mapped) {
        merge(mapped);
      }));
    }
  }

  /// Subscribe to toggle binding channels — flip a boolean state key on event.
  void _wireToggleBindings() {
    for (final entry in config.toggleBindings.entries) {
      _subs.add(eventBus.subscribe(entry.key).listen((_) {
        toggle(entry.value);
      }));
    }
  }

  /// Subscribe to set binding channels — set a state key to the event's value.
  void _wireSetBindings() {
    for (final entry in config.setBindings.entries) {
      _subs.add(eventBus.subscribe(entry.key).listen((event) {
        set(entry.value, event.data['value']);
      }));
    }
  }

  /// Subscribe to reset binding channels — set a state key to false on event.
  void _wireResetBindings() {
    for (final entry in config.resetBindings.entries) {
      _subs.add(eventBus.subscribe(entry.key).listen((_) {
        set(entry.value, false);
      }));
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Configuration (from widget metadata)
// ---------------------------------------------------------------------------

/// State configuration declared in widget metadata.
class StateConfig {
  final SelectionConfig? selection;
  final Set<String> publishChannels;
  final Set<String> listenChannels;
  final List<ProducesDecl> produces;
  final List<ConsumesDecl> consumes;

  /// Default state values applied at construction time.
  final Map<String, dynamic> initialState;

  /// Channel → state key. When event arrives, toggle the boolean key.
  final Map<String, String> toggleBindings;

  /// Channel → state key. When event arrives, set key to event.data['value'].
  final Map<String, String> setBindings;

  /// Channel → state key. When event arrives, set key to false.
  final Map<String, String> resetBindings;

  const StateConfig({
    this.selection,
    this.publishChannels = const {},
    this.listenChannels = const {},
    this.produces = const [],
    this.consumes = const [],
    this.initialState = const {},
    this.toggleBindings = const {},
    this.setBindings = const {},
    this.resetBindings = const {},
  });

  factory StateConfig.fromJson(Map<String, dynamic> json) {
    SelectionConfig? selection;
    final selJson = json['selection'] as Map<String, dynamic>?;
    if (selJson != null) {
      selection = SelectionConfig(
        channel: selJson['channel'] as String,
        matchField: selJson['matchField'] as String,
        payloadField: selJson['payloadField'] as String?,
        multi: selJson['multi'] as bool? ?? false,
      );
    }

    final publish = json['publishTo'] as List?;
    final listen = json['listenTo'] as List?;

    return StateConfig(
      selection: selection,
      publishChannels: publish != null ? Set<String>.from(publish) : const {},
      listenChannels: listen != null ? Set<String>.from(listen) : const {},
      produces: (json['produces'] as List?)
              ?.map((e) => ProducesDecl.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      consumes: (json['consumes'] as List?)
              ?.map((e) => ConsumesDecl.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      initialState: (json['initialState'] as Map<String, dynamic>?) ?? const {},
      toggleBindings: (json['toggleBindings'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          const {},
      setBindings: (json['setBindings'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          const {},
      resetBindings: (json['resetBindings'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          const {},
    );
  }

  /// Return a new StateConfig with template expressions in channel names
  /// resolved against [scope] (e.g., `{{widgetId}}` → actual widget ID).
  StateConfig resolveChannels(
      TemplateResolver resolver, Map<String, dynamic> scope) {
    return StateConfig(
      selection: selection != null
          ? SelectionConfig(
              channel: resolver.resolveString(selection!.channel, scope),
              matchField: selection!.matchField,
              payloadField: selection!.payloadField,
              multi: selection!.multi,
            )
          : null,
      publishChannels:
          publishChannels.map((c) => resolver.resolveString(c, scope)).toSet(),
      listenChannels:
          listenChannels.map((c) => resolver.resolveString(c, scope)).toSet(),
      produces: produces,
      consumes: consumes,
      initialState: initialState,
      toggleBindings: toggleBindings.map(
          (k, v) => MapEntry(resolver.resolveString(k, scope), v)),
      setBindings: setBindings
          .map((k, v) => MapEntry(resolver.resolveString(k, scope), v)),
      resetBindings: resetBindings
          .map((k, v) => MapEntry(resolver.resolveString(k, scope), v)),
    );
  }

  static const empty = StateConfig();
}

/// Selection tracking configuration.
class SelectionConfig {
  final String channel;

  /// Field name on the data item (e.g., "id").
  final String matchField;

  /// Field name in the event payload (e.g., "nodeId").
  /// Defaults to [matchField] if not specified.
  final String payloadField;

  final bool multi;

  const SelectionConfig({
    required this.channel,
    required this.matchField,
    String? payloadField,
    this.multi = false,
  }) : payloadField = payloadField ?? matchField;
}

// ---------------------------------------------------------------------------
// InheritedWidget scope
// ---------------------------------------------------------------------------

/// Provides [StateManager] to the widget tree.
///
/// Uses [InheritedNotifier] so all descendants that call
/// `StateManagerScope.of(context)` rebuild when the StateManager notifies.
class StateManagerScope extends InheritedNotifier<StateManager> {
  const StateManagerScope({
    super.key,
    required StateManager manager,
    required super.child,
  }) : super(notifier: manager);

  static StateManager of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<StateManagerScope>();
    assert(scope != null, 'No StateManagerScope found in context');
    return scope!.notifier!;
  }

  static StateManager? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<StateManagerScope>()
        ?.notifier;
  }
}
