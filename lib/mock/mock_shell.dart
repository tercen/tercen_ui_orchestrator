import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sdui/sdui.dart';
import 'package:tercen_ui_orchestrator/sdui/contracts/contract_registry.dart';

import 'event_inspector.dart';
import 'item_inspector.dart';
import 'mock_service_caller.dart';

/// Scope builder types that require a real backend and won't work in mock mode.
const _unsupportedScopeTypes = {'ChatStream', 'TaskStream'};

/// The mock orchestrator shell. Renders a single catalog widget inside the
/// real WindowManager (floating window with title bar) and provides an event
/// inspector/injector panel on the right.
class MockShell extends StatefulWidget {
  /// Widget type to render initially (from dart-define).
  final String? initialWidget;

  /// Catalog JSON to load. If null, only built-in primitives are available.
  final Map<String, dynamic>? catalog;

  /// SDUI theme — same tokens.json as production.
  final SduiTheme? sduiTheme;

  const MockShell({super.key, this.initialWidget, this.catalog, this.sduiTheme});

  @override
  State<MockShell> createState() => _MockShellState();
}

class _MockShellState extends State<MockShell> {
  late final SduiContext _sduiContext;
  late final MockServiceCaller _mockCaller;
  String? _selectedWidget;
  List<String> _availableWidgets = [];
  List<String> _knownChannels = [];
  int _openCounter = 0;

  /// Widgets that use scope builders needing real backends.
  final _incompatibleWidgets = <String, String>{};

  @override
  void initState() {
    super.initState();

    _mockCaller = MockServiceCaller();
    final theme = widget.sduiTheme ?? const SduiTheme.light();
    _sduiContext = SduiContext.create(
      theme: theme,
      contractRegistry: createDefaultRegistry(),
    );

    // Wire the mock service caller.
    _sduiContext.renderContext.serviceCaller = _mockCaller.call;

    // Set mock user context.
    _sduiContext.renderContext.setUserContext({
      'username': 'mock-user',
      'userId': 'mock-user-id',
      'token': '',
      'isDark': false,
    });

    // Load catalog if provided.
    if (widget.catalog != null) {
      _sduiContext.registry.loadCatalog(widget.catalog!);
    }

    // Collect available Tier 2 (template) widgets and check mock compatibility.
    for (final meta in _sduiContext.registry.catalog) {
      if (meta.tier != 2) continue;
      _availableWidgets.add(meta.type);

      final template = _sduiContext.registry.getTemplate(meta.type);
      if (template != null) {
        final unsupported = _findUnsupportedScopes(template);
        if (unsupported.isNotEmpty) {
          _incompatibleWidgets[meta.type] = unsupported.join(', ');
        }
      }
    }
    _availableWidgets.sort();

    _selectedWidget = widget.initialWidget;
    if (_selectedWidget != null && !_sduiContext.registry.has(_selectedWidget!)) {
      debugPrint('[MockShell] Widget "$_selectedWidget" not found in registry');
      _selectedWidget = null;
    }
    _selectedWidget ??=
        _availableWidgets.isNotEmpty ? _availableWidgets.first : null;

    if (_selectedWidget != null) {
      _updateKnownChannels(_selectedWidget!);
      _openWidget(_selectedWidget!);
    }
  }

  /// Walk template tree and return any unsupported scope types found.
  Set<String> _findUnsupportedScopes(SduiNode node) {
    final found = <String>{};
    if (_unsupportedScopeTypes.contains(node.type)) {
      found.add(node.type);
    }
    for (final child in node.children) {
      found.addAll(_findUnsupportedScopes(child));
    }
    return found;
  }

  void _openWidget(String type) {
    // Use a counter so each open creates a genuinely new widget tree,
    // forcing initState → _fetchData with the current scenario.
    _openCounter++;
    _sduiContext.windowManager.clearAll();

    // Pre-seed PromptRequired fields with their defaults so the config
    // popup is bypassed automatically.
    _seedPromptDefaults(type);

    _sduiContext.eventBus.publish(
      'system.layout.op',
      EventPayload(type: 'layout.op', data: {
        'op': 'addWindow',
        'id': 'mock-$type-$_openCounter',
        'size': 'medium',
        'align': 'center',
        'title': type,
        'content': {
          'type': type,
          'id': 'mock-$type-$_openCounter-root',
          'props': <String, dynamic>{},
          'children': <Map<String, dynamic>>[],
        },
      }),
    );
  }

  /// Walk the template for PromptRequired nodes and set their field defaults
  /// into the template resolver so the popup is skipped.
  void _seedPromptDefaults(String type) {
    final template = _sduiContext.registry.getTemplate(type);
    if (template == null) return;
    _seedFromNode(template);
  }

  void _seedFromNode(SduiNode node) {
    if (node.type == 'PromptRequired') {
      final fields = node.props['fields'];
      if (fields is List) {
        for (final field in fields) {
          if (field is! Map) continue;
          final name = field['name']?.toString() ?? '';
          final defaultVal = field['default']?.toString() ?? '';
          if (name.isNotEmpty && defaultVal.isNotEmpty) {
            _sduiContext.renderContext.templateResolver.set(name, defaultVal);
          }
        }
      }
    }
    for (final child in node.children) {
      _seedFromNode(child);
    }
  }

  void _updateKnownChannels(String type) {
    final channels = <String>{};
    final meta = _sduiContext.registry.getMetadata(type);
    if (meta != null) {
      channels.addAll(meta.emittedEvents);
    }

    final template = _sduiContext.registry.getTemplate(type);
    if (template != null) {
      _collectChannelsFromNode(template, channels);
    }

    setState(() => _knownChannels = channels.toList()..sort());
  }

  void _collectChannelsFromNode(SduiNode node, Set<String> channels) {
    final props = node.props;
    final refreshOn = props['refreshOn'];
    if (refreshOn is String && refreshOn.isNotEmpty) {
      channels.add(refreshOn);
    }
    final channel = props['channel'];
    if (channel is String && channel.isNotEmpty) {
      channels.add(channel);
    }
    for (final child in node.children) {
      _collectChannelsFromNode(child, channels);
    }
  }

  void _onWidgetSelected(String? type) {
    if (type == null || type == _selectedWidget) return;
    setState(() {
      _selectedWidget = type;
      _updateKnownChannels(type);
      _openWidget(type);
    });
  }

  void _onScenarioChanged(MockScenario scenario) {
    setState(() {
      _mockCaller.scenario = scenario;
      if (_selectedWidget != null) {
        _openWidget(_selectedWidget!);
      }
    });
  }

  @override
  void dispose() {
    _sduiContext.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SduiScope(
      sduiContext: _sduiContext,
      child: Scaffold(
        body: Column(
          children: [
            _buildToolbar(cs, tt),
            // Compatibility warning
            if (_selectedWidget != null &&
                _incompatibleWidgets.containsKey(_selectedWidget))
              _buildWarningBar(cs, tt),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildWidgetArea(cs, tt),
                  ),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 340,
                    child: _buildRightPanel(cs, tt),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBar(ColorScheme cs, TextTheme tt) {
    final reason = _incompatibleWidgets[_selectedWidget] ?? '';
    return Container(
      width: double.infinity,
      color: cs.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.warning_amber, size: 16, color: cs.onErrorContainer),
          const SizedBox(width: 8),
          Text(
            'Needs real backend: $reason — widget may not render correctly in mock mode',
            style: tt.labelSmall?.copyWith(color: cs.onErrorContainer),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(ColorScheme cs, TextTheme tt) {
    return Material(
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Icon(Icons.widgets_outlined, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text('SDUI Mock',
                  style: tt.titleSmall?.copyWith(color: cs.onSurface)),
              const SizedBox(width: 16),

              // Widget selector — shows compatibility icon per widget
              DropdownButton<String>(
                value: _selectedWidget,
                items: _availableWidgets.map((w) {
                  final incompatible = _incompatibleWidgets.containsKey(w);
                  return DropdownMenuItem(
                    value: w,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (incompatible)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(Icons.warning_amber,
                                size: 14, color: cs.error),
                          ),
                        Text(w),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _onWidgetSelected,
                underline: const SizedBox.shrink(),
                isDense: true,
                style: tt.labelMedium?.copyWith(color: cs.onSurface),
              ),
              const SizedBox(width: 24),

              // Scenario selector
              Text('Scenario:',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(width: 8),
              ...MockScenario.values.map((s) {
                final selected = s == _mockCaller.scenario;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ChoiceChip(
                    label: Text(s.label, style: tt.labelSmall),
                    selected: selected,
                    onSelected: (_) => _onScenarioChanged(s),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }),

              const SizedBox(width: 24),

              // Known channels indicator
              if (_knownChannels.isNotEmpty)
                Tooltip(
                  message: 'Channels: ${_knownChannels.join(', ')}',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cable, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${_knownChannels.length} channels',
                          style: tt.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetArea(ColorScheme cs, TextTheme tt) {
    if (_selectedWidget == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 8),
            Text('No catalog widgets found',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    // Render via the real WindowManager — same floating windows as production.
    return Container(
      color: cs.surface,
      child: ListenableBuilder(
        listenable: _sduiContext.windowManager,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              if (_sduiContext.windowManager.windows.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              return _sduiContext.windowManager.buildStack(
                constraints.maxWidth,
                constraints.maxHeight,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRightPanel(ColorScheme cs, TextTheme tt) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            indicatorColor: cs.primary,
            tabs: const [
              Tab(text: 'Events'),
              Tab(text: 'Calls'),
              Tab(text: 'Item'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                EventInspector(
                  eventBus: _sduiContext.eventBus,
                  knownChannels: _knownChannels,
                ),
                _buildServiceCallLog(cs, tt),
                ItemInspector(eventBus: _sduiContext.eventBus),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCallLog(ColorScheme cs, TextTheme tt) {
    return ListenableBuilder(
      listenable: _mockCaller,
      builder: (context, _) {
        final calls = _mockCaller.callLog;
        if (calls.isEmpty) {
          return Center(
            child: Text('No service calls yet',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(4),
          itemCount: calls.length,
          itemBuilder: (context, index) {
            final c = calls[index];
            final time =
                '${c.timestamp.hour.toString().padLeft(2, '0')}:'
                '${c.timestamp.minute.toString().padLeft(2, '0')}:'
                '${c.timestamp.second.toString().padLeft(2, '0')}';
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 2),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storage, size: 12, color: cs.secondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${c.service}.${c.method}',
                            style: tt.labelSmall?.copyWith(
                              color: cs.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(time,
                            style: tt.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                    if (c.args.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _argsPreview(c.args),
                          style: tt.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            color: cs.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _argsPreview(List<dynamic> args) {
    try {
      return const JsonEncoder.withIndent(null).convert(args);
    } catch (_) {
      return args.toString();
    }
  }
}
