import 'package:flutter/material.dart';

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

    final widget = builder(resolvedNode, childWidgets, renderContext);

    return ErrorBoundary(
      key: ValueKey(node.id),
      nodeId: node.id,
      child: widget,
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

    return builder(resolvedNode, children, renderer.renderContext);
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

/// Recursively appends a suffix to all node IDs in the subtree.
/// This ensures uniqueness when a child template is repeated for list items.
SduiNode _suffixNodeIds(SduiNode node, String suffix) {
  return node.copyWith(
    id: '${node.id}$suffix',
    children: node.children.map((c) => _suffixNodeIds(c, suffix)).toList(),
  );
}
