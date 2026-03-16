import 'dart:async';

import 'package:flutter/material.dart';

import '../event_bus/event_payload.dart';
import '../registry/widget_registry.dart';
import '../schema/sdui_node.dart';
import 'error_boundary.dart';
import 'sdui_render_context.dart';

/// Recursively renders an SduiNode tree into Flutter widgets.
class SduiRenderer {
  final WidgetRegistry registry;
  final SduiRenderContext renderContext;

  const SduiRenderer({required this.registry, required this.renderContext});

  Widget render(SduiNode node, [Map<String, dynamic> extraScope = const {}]) {
    // If this node has reactTo, wrap in a reactive widget that subscribes
    // to the EventBus channel and overrides props when matched.
    if (node.reactTo != null) {
      return ErrorBoundary(
        key: ValueKey(node.id),
        nodeId: node.id,
        child: _ReactiveWidget(
          node: node,
          renderer: this,
          extraScope: extraScope,
        ),
      );
    }

    // If this node has a dataSource, wrap in a data-fetching widget.
    if (node.dataSource != null) {
      return ErrorBoundary(
        key: ValueKey(node.id),
        nodeId: node.id,
        child: _DataSourceWidget(
          node: node,
          renderer: this,
          extraScope: extraScope,
        ),
      );
    }

    return _renderNode(node, extraScope);
  }

  Widget _renderNode(SduiNode node, Map<String, dynamic> extraScope) {
    final builder = registry.getBuilder(node.type);
    if (builder == null) return _unknownWidget(node);

    // Resolve templates in props (context + extra scope like item/data)
    final resolvedNode = node.copyWith(
      props: renderContext.templateResolver.resolveProps(node.props, extraScope),
    );

    // Recursively render children with the same extra scope
    final childWidgets =
        node.children.map((child) => render(child, extraScope)).toList();

    Widget widget = builder(resolvedNode, childWidgets, renderContext);

    // Wrap with gesture actions if any are defined
    widget = _wrapWithActions(widget, node, extraScope);

    return ErrorBoundary(
      key: ValueKey(node.id),
      nodeId: node.id,
      child: widget,
    );
  }

  /// Wraps a widget with GestureDetector if the node has actions defined.
  /// Resolves template bindings in action payloads using the current scope.
  Widget _wrapWithActions(
      Widget child, SduiNode node, Map<String, dynamic> extraScope) {
    if (node.actions.isEmpty) return child;

    final resolver = renderContext.templateResolver;
    final eventBus = renderContext.eventBus;

    void Function()? makeHandler(String gesture) {
      final action = node.actions[gesture];
      if (action == null) return null;
      return () {
        final resolvedChannel = resolver.resolveString(action.channel, extraScope);
        final resolvedPayload = resolver.resolveProps(action.payload, extraScope);
        eventBus.publish(
          resolvedChannel,
          EventPayload(
            type: gesture,
            sourceWidgetId: node.id,
            data: {...resolvedPayload, '_channel': resolvedChannel},
          ),
        );
      };
    }

    final onTap = makeHandler('onTap');
    final onDoubleTap = makeHandler('onDoubleTap');
    final onLongPress = makeHandler('onLongPress');

    if (onTap == null && onDoubleTap == null && onLongPress == null) {
      return child;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        child: child,
      ),
    );
  }

  Widget _unknownWidget(SduiNode node) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(25),
        border: Border.all(color: Colors.orange.withAlpha(76)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Unknown widget: "${node.type}"',
        style: TextStyle(color: Colors.orange.withAlpha(204), fontSize: 12),
      ),
    );
  }
}

/// StatefulWidget that fetches data from a service, then renders the node.
///
/// - List result → children are repeated as a template for each item
///   with `{{item.field}}` bindings.
/// - Single object result → `{{data.field}}` bindings resolve in props/children.
class _DataSourceWidget extends StatefulWidget {
  final SduiNode node;
  final SduiRenderer renderer;
  final Map<String, dynamic> extraScope;

  const _DataSourceWidget({
    required this.node,
    required this.renderer,
    required this.extraScope,
  });

  @override
  State<_DataSourceWidget> createState() => _DataSourceWidgetState();
}

class _DataSourceWidgetState extends State<_DataSourceWidget> {
  Future<dynamic>? _future;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    final caller = widget.renderer.renderContext.serviceCaller;
    if (caller == null) return;

    final ds = widget.node.dataSource!;

    // Resolve template bindings in args (e.g., "{{item.id}}" from parent scope)
    final resolver = widget.renderer.renderContext.templateResolver;
    final resolvedArgs = ds.args.map((arg) {
      if (arg is String) {
        return resolver.resolveString(arg, widget.extraScope);
      }
      return arg;
    }).toList();

    _future = caller(ds.service, ds.method, resolvedArgs);
  }

  @override
  Widget build(BuildContext context) {
    final caller = widget.renderer.renderContext.serviceCaller;
    if (caller == null) {
      return _buildPlaceholder('Not authenticated');
    }

    if (_future == null) {
      return _buildPlaceholder('Loading...');
    }

    return FutureBuilder<dynamic>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }
        if (snapshot.hasError) {
          return _buildError(snapshot.error.toString());
        }

        final data = snapshot.data;
        if (data is List) {
          return _buildWithListData(data);
        } else if (data is Map) {
          return _buildWithObjectData(Map<String, dynamic>.from(data));
        } else {
          return _buildError('Unexpected data type: ${data.runtimeType}');
        }
      },
    );
  }

  /// List result: render the node normally, but repeat children for each item.
  Widget _buildWithListData(List<dynamic> items) {
    final node = widget.node;
    final renderer = widget.renderer;

    debugPrint('[sdui] dataSource ${node.dataSource?.service}.${node.dataSource?.method} returned ${items.length} items');
    if (items.isNotEmpty && items.first is Map) {
      debugPrint('[sdui] first item keys: ${(items.first as Map).keys.toList()}');
      debugPrint('[sdui] first item: ${items.first}');
    }

    if (items.isEmpty) {
      return _renderNodeWithChildren(node, [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No data', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      ]);
    }

    // Build child widgets: for each item, render every child template
    final allChildren = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final itemMap =
          item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
      // Include index in scope so templates can produce unique IDs even if _id is null
      final itemScope = {...widget.extraScope, 'item': itemMap, '_index': i};

      for (final childNode in node.children) {
        // Append index suffix to all node IDs in the subtree to guarantee uniqueness
        final indexedNode = _suffixNodeIds(childNode, '__$i');
        allChildren.add(renderer.render(indexedNode, itemScope));
      }
    }

    // Render the node itself with the generated children
    return _renderNodeWithChildren(node, allChildren);
  }

  /// Single object result: render with {{data.field}} bindings.
  Widget _buildWithObjectData(Map<String, dynamic> data) {
    final node = widget.node;
    final renderer = widget.renderer;
    final dataScope = {...widget.extraScope, 'data': data};

    final childWidgets =
        node.children.map((child) => renderer.render(child, dataScope)).toList();

    return _renderNodeWithChildren(node, childWidgets, dataScope);
  }

  Widget _renderNodeWithChildren(SduiNode node, List<Widget> children,
      [Map<String, dynamic>? scope]) {
    final renderer = widget.renderer;
    final effectiveScope = scope ?? widget.extraScope;

    final builder = renderer.registry.getBuilder(node.type);
    if (builder == null) return renderer._unknownWidget(node);

    final resolvedNode = node.copyWith(
      props: renderer.renderContext.templateResolver
          .resolveProps(node.props, effectiveScope),
    );

    Widget result = builder(resolvedNode, children, renderer.renderContext);
    result = renderer._wrapWithActions(result, node, effectiveScope);
    return result;
  }

  Widget _buildLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(25),
        border: Border.all(color: Colors.red.withAlpha(76)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Data error: $message',
        style: TextStyle(color: Colors.red.withAlpha(204), fontSize: 12),
      ),
    );
  }

  Widget _buildPlaceholder(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(25),
        border: Border.all(color: Colors.grey.withAlpha(76)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.grey.withAlpha(178), fontSize: 12),
      ),
    );
  }
}

/// Reactive widget: subscribes to an EventBus channel and re-renders the node
/// with overridden props when the event payload matches the `reactTo.match` criteria.
///
/// Same pattern as _DataSourceWidget — a StatefulWidget wrapping a rendered node
/// that manages async state via EventBus subscription and setState.
class _ReactiveWidget extends StatefulWidget {
  final SduiNode node;
  final SduiRenderer renderer;
  final Map<String, dynamic> extraScope;

  const _ReactiveWidget({
    required this.node,
    required this.renderer,
    required this.extraScope,
  });

  @override
  State<_ReactiveWidget> createState() => _ReactiveWidgetState();
}

class _ReactiveWidgetState extends State<_ReactiveWidget> {
  StreamSubscription<EventPayload>? _sub;
  bool _matched = false;

  @override
  void initState() {
    super.initState();
    final reactTo = widget.node.reactTo!;
    final resolver = widget.renderer.renderContext.templateResolver;
    final channel = resolver.resolveString(reactTo.channel, widget.extraScope);
    _sub = widget.renderer.renderContext.eventBus
        .subscribe(channel)
        .listen(_onEvent);
  }

  void _onEvent(EventPayload event) {
    final reactTo = widget.node.reactTo!;
    final resolver = widget.renderer.renderContext.templateResolver;
    final resolvedMatch =
        resolver.resolveProps(reactTo.match, widget.extraScope);

    // Check if every key in match is equal to the corresponding value in event.data
    final matched = resolvedMatch.entries.every((entry) {
      if (entry.key.startsWith('_')) return true;
      return event.data[entry.key]?.toString() == entry.value?.toString();
    });

    if (matched != _matched) {
      setState(() => _matched = matched);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build the effective node: merge reactTo.props into node.props when matched
    final node = widget.node;
    final effectiveProps = _matched
        ? {...node.props, ...node.reactTo!.props}
        : node.props;

    // Create node without reactTo so the inner render doesn't double-wrap
    final effectiveNode = SduiNode(
      type: node.type,
      id: node.id,
      props: effectiveProps,
      children: node.children,
      annotations: node.annotations,
      dataSource: node.dataSource,
      actions: node.actions,
    );

    // Delegate to the normal render path (which handles dataSource, actions, etc.)
    return widget.renderer.render(effectiveNode, widget.extraScope);
  }
}

/// Recursively appends a suffix to all node IDs in the subtree.
/// This ensures uniqueness when a child template is repeated for list items.
SduiNode _suffixNodeIds(SduiNode node, String suffix) {
  return node.copyWith(
    id: '${node.id}$suffix',
    children: node.children.map((c) => _suffixNodeIds(c, suffix)).toList(),
  );
}
