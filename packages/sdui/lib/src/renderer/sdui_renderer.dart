import 'package:flutter/material.dart';

import '../error_reporter.dart';
import '../registry/widget_registry.dart';
import '../schema/sdui_node.dart';
import '../state/state_manager.dart';
import 'sdui_render_context.dart';

/// Recursively renders an SduiNode tree into Flutter widgets.
///
/// The renderer is intentionally simple: resolve props, look up builder,
/// render children. All behavior (data fetching, reactivity, gestures,
/// iteration) lives in composable scope/widget builders registered in
/// the WidgetRegistry.
class SduiRenderer {
  final WidgetRegistry registry;
  final SduiRenderContext renderContext;

  const SduiRenderer({required this.registry, required this.renderContext});

  /// Tracks whether we've already logged a full render trace for a given window.
  /// After the first render, subsequent renders only log at template level.
  static final Set<String> _tracedIds = {};

  Widget render(SduiNode node, [Map<String, dynamic> extraScope = const {}]) {
    final traceKey = node.id;
    final isFirstRender = !_tracedIds.contains(traceKey);

    // 1. Scope builder — controls how children are rendered (DataSource, ForEach, etc.)
    final scopeBuilder = registry.getScopeBuilder(node.type);
    if (scopeBuilder != null) {
      if (isFirstRender) {
        _tracedIds.add(traceKey);
      }
      return _buildScoped(node, scopeBuilder, extraScope);
    }

    // 2. Standard builder — children are pre-rendered
    final builder = registry.getBuilder(node.type);
    if (builder != null) {
      if (isFirstRender) {
        _tracedIds.add(traceKey);
      }
      return _buildStandard(node, builder, extraScope);
    }

    // 3. Template — expand and render the template tree
    final template = registry.getTemplate(node.type);
    if (template != null) {
      if (isFirstRender) {
        _tracedIds.add(traceKey);
        debugPrint('[SduiRenderer] >>> expanding template "${node.type}" (id: ${node.id}) '
            'template root type="${template.type}" children=${template.children.length} '
            'scope keys=${extraScope.keys.toList()}');
      }
      return _renderTemplate(node, template, extraScope);
    }

    // 4. Unknown widget type
    debugPrint('[SduiRenderer] UNKNOWN type="${node.type}" (id: ${node.id})');
    return _unknownWidget(node);
  }

  Widget _buildScoped(
      SduiNode node, SduiScopeBuilder builder, Map<String, dynamic> extraScope) {
    Map<String, dynamic> resolvedProps;
    try {
      resolvedProps =
          renderContext.templateResolver.resolveProps(node.props, extraScope);
    } catch (e, st) {
      return _reportAndBuildError(e, st, 'template resolution', node);
    }

    // Resolve the node ID (template bindings like {{widgetId}}-input)
    final resolvedId = renderContext.templateResolver
        .resolveValue(node.id, extraScope) as String? ?? node.id;

    final resolvedNode = node.copyWith(
      id: resolvedId,
      props: {
        ...resolvedProps,
        // Preserve the raw (unresolved) args so DataSource can re-resolve
        // them against event scope on refreshOn events.
        if (node.props.containsKey('args'))
          '_rawArgs': node.props['args'],
        // Preserve the parent scope so DataSource can merge it with event
        // scope when re-resolving args (e.g. {{props.scopeId}} + {{startDate}}).
        '_parentScope': extraScope,
        // Preserve the raw children config — its args contain {{parent.xxx}}
        // bindings that must be resolved at fetch time, not render time.
        if (node.props.containsKey('children'))
          'children': node.props['children'],
      },
    );

    // The childRenderer closure captures the current scope and lets the
    // scope builder render children with additional scope entries.
    Widget childRenderer(SduiNode childNode, Map<String, dynamic> scopeAdditions) {
      return render(childNode, {...extraScope, ...scopeAdditions});
    }

    try {
      return KeyedSubtree(
        key: ValueKey(resolvedId),
        child: builder(resolvedNode, renderContext, childRenderer),
      );
    } catch (e, st) {
      return _reportAndBuildError(e, st, 'build', node,
          resolvedProps: resolvedProps);
    }
  }

  Widget _buildStandard(
      SduiNode node, SduiWidgetBuilder builder, Map<String, dynamic> extraScope) {
    Map<String, dynamic> resolvedProps;
    try {
      resolvedProps =
          renderContext.templateResolver.resolveProps(node.props, extraScope);
    } catch (e, st) {
      return _reportAndBuildError(e, st, 'template resolution', node);
    }

    // Resolve the node ID (template bindings like {{widgetId}}-input)
    final resolvedId = renderContext.templateResolver
        .resolveValue(node.id, extraScope) as String? ?? node.id;

    final resolvedNode = node.copyWith(id: resolvedId, props: resolvedProps);
    final childWidgets =
        node.children.map((child) => render(child, extraScope)).toList();

    try {
      return KeyedSubtree(
        key: ValueKey(resolvedId),
        child: builder(resolvedNode, childWidgets, renderContext),
      );
    } catch (e, st) {
      return _reportAndBuildError(e, st, 'build', node,
          resolvedProps: resolvedProps);
    }
  }

  /// Expands a template widget into a [_ComponentHost] — a self-contained
  /// rebuild boundary.
  ///
  /// Every template widget is a component. The ComponentHost is a StatefulWidget
  /// that renders the template in its own build(). When the StateManager notifies,
  /// only this component rebuilds — siblings and parents are untouched.
  Widget _renderTemplate(
      SduiNode node, SduiNode template, Map<String, dynamic> extraScope) {
    final meta = registry.getMetadata(node.type);
    final propsWithDefaults = <String, dynamic>{};
    if (meta != null) {
      for (final entry in meta.props.entries) {
        if (entry.value.defaultValue != null) {
          propsWithDefaults[entry.key] = entry.value.defaultValue;
        }
      }
    }
    propsWithDefaults.addAll(node.props);

    final templateScope = {
      ...extraScope,
      'props': propsWithDefaults,
      'widgetId': node.id,
    };

    // Merge produces/consumes from metadata into the state config.
    // If a widget has contract declarations but no state block, we still
    // need a StateConfig so the renderer creates a StateManager for it.
    var stateConfig = meta?.stateConfig;
    final produces = meta?.produces ?? const [];
    final consumes = meta?.consumes ?? const [];
    if (produces.isNotEmpty || consumes.isNotEmpty) {
      stateConfig = StateConfig(
        selection: stateConfig?.selection,
        publishChannels: stateConfig?.publishChannels ?? const {},
        listenChannels: stateConfig?.listenChannels ?? const {},
        produces: produces,
        consumes: consumes,
      );
    }

    return _ComponentHost(
      key: ValueKey('comp-${node.id}'),
      widgetId: node.id,
      template: template,
      templateScope: templateScope,
      stateConfig: stateConfig,
      renderer: this,
    );
  }


  Widget _reportAndBuildError(
    Object error,
    StackTrace stackTrace,
    String phase,
    SduiNode node, {
    Map<String, dynamic>? resolvedProps,
  }) {
    final propInfo = resolvedProps != null
        ? resolvedProps.map((k, v) => MapEntry(k, '${v.runtimeType}=$v'))
        : node.props.map((k, v) => MapEntry(k, '${v.runtimeType}=$v'));

    ErrorReporter.instance.report(
      error,
      stackTrace: stackTrace,
      source: 'sdui.renderer',
      context: '$phase "${node.type}" (id: ${node.id}), props: $propInfo',
    );

    final theme = renderContext.theme;
    return Container(
      key: ValueKey('error-${node.id}'),
      padding: EdgeInsets.all(theme.spacing.sm),
      decoration: BoxDecoration(
        color: theme.colors.error.withAlpha(theme.opacity.subtle),
        border: Border.all(color: theme.colors.error.withAlpha(theme.opacity.light)),
        borderRadius: BorderRadius.circular(theme.radius.sm),
      ),
      child: Text(
        '${node.type}(${node.id}): $error',
        style: TextStyle(color: theme.colors.error.withAlpha(theme.opacity.strong), fontSize: theme.textStyles.bodySmall.fontSize),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _unknownWidget(SduiNode node) {
    ErrorReporter.instance.report(
      'Unknown widget type: "${node.type}"',
      source: 'sdui.renderer',
      context: 'id: ${node.id}',
      severity: ErrorSeverity.warning,
    );
    final theme = renderContext.theme;
    return Container(
      padding: EdgeInsets.all(theme.spacing.sm + theme.spacing.xs),
      decoration: BoxDecoration(
        color: theme.colors.warning.withAlpha(theme.opacity.subtle),
        border: Border.all(color: theme.colors.warning.withAlpha(theme.opacity.light)),
        borderRadius: BorderRadius.circular(theme.radius.sm),
      ),
      child: Text(
        'Unknown widget: "${node.type}"',
        style: TextStyle(color: theme.colors.warning.withAlpha(theme.opacity.strong), fontSize: theme.textStyles.bodySmall.fontSize),
      ),
    );
  }
}

/// The component boundary. Every template widget gets one.
///
/// A StatefulWidget that:
/// - Owns the StateManager (if state config exists)
/// - Renders the SDUI template in its own build()
/// - Rebuilds only when StateManager notifies (via listener + setState)
/// - Isolates its subtree from parent rebuilds
///
/// This is the fundamental rebuild unit. Parent components don't cause
/// child components to rebuild. Siblings are independent.
class _ComponentHost extends StatefulWidget {
  final String widgetId;
  final SduiNode template;
  final Map<String, dynamic> templateScope;
  final StateConfig? stateConfig;
  final SduiRenderer renderer;

  const _ComponentHost({
    super.key,
    required this.widgetId,
    required this.template,
    required this.templateScope,
    required this.stateConfig,
    required this.renderer,
  });

  @override
  State<_ComponentHost> createState() => _ComponentHostState();
}

class _ComponentHostState extends State<_ComponentHost> {
  StateManager? _manager;

  @override
  void initState() {
    super.initState();
    final config = widget.stateConfig;
    if (config != null) {
      // Resolve template expressions in channel names (e.g., {{widgetId}}).
      final resolvedConfig = config.resolveChannels(
        widget.renderer.renderContext.templateResolver,
        widget.templateScope,
      );
      _manager = StateManager(
        widgetId: widget.widgetId,
        eventBus: widget.renderer.renderContext.eventBus,
        contractBus: widget.renderer.renderContext.contractBus,
        config: resolvedConfig,
      );
      _manager!.addListener(_onStateChange);
    }
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _manager?.removeListener(_onStateChange);
    _manager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set StateManager — persists for the lifetime of this component.
    // DataSource and ForEach read it when Flutter calls their build().
    widget.renderer.renderContext.stateManager = _manager;

    // Merge state snapshot into scope so {{state.key}} resolves in children.
    final scope = {
      ...widget.templateScope,
      if (_manager != null) 'state': _manager!.snapshot,
    };

    final rendered = widget.renderer.render(
      widget.template,
      scope,
    );

    if (_manager != null) {
      return StateManagerScope(
        manager: _manager!,
        child: rendered,
      );
    }

    return rendered;
  }
}
