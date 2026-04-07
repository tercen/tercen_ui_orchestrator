import '../contracts/event_contracts.dart';
import '../schema/prop_converter.dart';
import '../state/state_manager.dart';

int? _toInt(dynamic v) => PropConverter.to<int>(v);

class PropSpec {
  final String type;
  final bool required;
  final dynamic defaultValue;
  final List<String>? values;
  final String? description;

  const PropSpec({
    required this.type,
    this.required = false,
    this.defaultValue,
    this.values,
    this.description,
  });

  factory PropSpec.fromJson(Map<String, dynamic> json) {
    return PropSpec(
      type: json['type'] as String,
      required: json['required'] as bool? ?? false,
      defaultValue: json['default'],
      values: (json['values'] as List<dynamic>?)?.cast<String>(),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'required': required,
        if (defaultValue != null) 'default': defaultValue,
        if (values != null) 'values': values,
        if (description != null) 'description': description,
      };
}

/// Declares that a widget handles a specific intent.
/// When an event with matching intent name arrives on `system.intent`,
/// the IntentRouter creates a window with this widget type.
class IntentSpec {
  final String intent;
  final Map<String, String> propsMap; // intent param → widget prop
  final String? windowTitle; // supports {{paramName}} interpolation
  final String windowSize;
  final String windowAlign;

  const IntentSpec({
    required this.intent,
    this.propsMap = const {},
    this.windowTitle,
    this.windowSize = 'medium',
    this.windowAlign = 'center',
  });

  factory IntentSpec.fromJson(Map<String, dynamic> json) {
    return IntentSpec(
      intent: json['intent'] as String,
      propsMap: (json['propsMap'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          const {},
      windowTitle: json['windowTitle'] as String?,
      windowSize: json['windowSize'] as String? ?? 'medium',
      windowAlign: json['windowAlign'] as String? ?? 'center',
    );
  }

  Map<String, dynamic> toJson() => {
        'intent': intent,
        if (propsMap.isNotEmpty) 'propsMap': propsMap,
        if (windowTitle != null) 'windowTitle': windowTitle,
        'windowSize': windowSize,
        'windowAlign': windowAlign,
      };
}

class WidgetMetadata {
  final String type;
  final int tier; // 1 = Flutter primitive, 2 = Tercen domain
  final String description;
  final Map<String, PropSpec> props;
  final List<String> gestures;
  final List<String> emittedEvents;
  final List<String> acceptedActions;
  final List<IntentSpec> handlesIntent;

  /// Hex color for the 8px tab color square in the pane tab strip.
  /// Example: '#1E40AF'. If null, a default neutral color is used.
  final String? typeColor;

  /// State configuration — selection tracking, EventBus bridging.
  /// If non-null, the renderer creates a StateManager for this widget.
  final StateConfig? stateConfig;

  /// Contract declarations — typed inter-widget communication.
  final List<ProducesDecl> produces;
  final List<ConsumesDecl> consumes;

  /// Semantic metadata — structured fields for agent discovery.
  /// [domain]: entity this widget works with (project, workflow, file, team, task, system)
  /// [capabilities]: what it can do (browse, search, select, create, delete, navigate, monitor, chat)
  /// [selectionMode]: single, multiple, or none
  /// [dataSource]: service.method it calls for data (e.g. "projectService.findByTeamCreatedDate")
  final String? domain;
  final List<String> capabilities;
  final String selectionMode; // 'single', 'multiple', 'none'
  final String? dataSource;

  const WidgetMetadata({
    required this.type,
    this.tier = 1,
    this.description = '',
    this.props = const {},
    this.gestures = const [],
    this.emittedEvents = const [],
    this.acceptedActions = const [],
    this.handlesIntent = const [],
    this.typeColor,
    this.stateConfig,
    this.produces = const [],
    this.consumes = const [],
    this.domain,
    this.capabilities = const [],
    this.selectionMode = 'none',
    this.dataSource,
  });

  factory WidgetMetadata.fromJson(Map<String, dynamic> json) {
    return WidgetMetadata(
      type: json['type'] as String,
      tier: _toInt(json['tier']) ?? 1,
      description: json['description'] as String? ?? '',
      typeColor: json['typeColor'] as String?,
      props: (json['props'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, PropSpec.fromJson(v as Map<String, dynamic>))) ??
          const {},
      gestures: (json['gestures'] as List<dynamic>?)?.cast<String>() ?? const [],
      emittedEvents:
          (json['emittedEvents'] as List<dynamic>?)?.cast<String>() ?? const [],
      acceptedActions:
          (json['acceptedActions'] as List<dynamic>?)?.cast<String>() ?? const [],
      handlesIntent: _parseIntentSpecs(json['handlesIntent']),
      stateConfig: json['state'] != null
          ? StateConfig.fromJson(json['state'] as Map<String, dynamic>)
          : null,
      produces: (json['produces'] as List?)
              ?.map((e) => ProducesDecl.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      consumes: (json['consumes'] as List?)
              ?.map((e) => ConsumesDecl.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      domain: json['domain'] as String?,
      capabilities:
          (json['capabilities'] as List<dynamic>?)?.cast<String>() ?? const [],
      selectionMode: json['selectionMode'] as String? ?? 'none',
      dataSource: json['dataSource'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'tier': tier,
        'description': description,
        if (typeColor != null) 'typeColor': typeColor,
        'props': props.map((k, v) => MapEntry(k, v.toJson())),
        if (gestures.isNotEmpty) 'gestures': gestures,
        if (emittedEvents.isNotEmpty) 'emittedEvents': emittedEvents,
        if (acceptedActions.isNotEmpty) 'acceptedActions': acceptedActions,
        if (handlesIntent.isNotEmpty)
          'handlesIntent': handlesIntent.map((i) => i.toJson()).toList(),
        if (stateConfig != null) 'state': {
          if (stateConfig!.selection != null) 'selection': {
            'channel': stateConfig!.selection!.channel,
            'matchField': stateConfig!.selection!.matchField,
            if (stateConfig!.selection!.payloadField != stateConfig!.selection!.matchField)
              'payloadField': stateConfig!.selection!.payloadField,
            if (stateConfig!.selection!.multi) 'multi': true,
          },
          if (stateConfig!.publishChannels.isNotEmpty)
            'publishTo': stateConfig!.publishChannels.toList(),
          if (stateConfig!.listenChannels.isNotEmpty)
            'listenTo': stateConfig!.listenChannels.toList(),
        },
        if (produces.isNotEmpty)
          'produces': produces.map((p) => p.toJson()).toList(),
        if (consumes.isNotEmpty)
          'consumes': consumes.map((c) => c.toJson()).toList(),
        if (domain != null) 'domain': domain,
        if (capabilities.isNotEmpty) 'capabilities': capabilities,
        if (selectionMode != 'none') 'selectionMode': selectionMode,
        if (dataSource != null) 'dataSource': dataSource,
      };
}

List<IntentSpec> _parseIntentSpecs(dynamic raw) {
  if (raw == null) return const [];
  if (raw is Map) {
    return [IntentSpec.fromJson(Map<String, dynamic>.from(raw))];
  }
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((m) => IntentSpec.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
  return const [];
}
