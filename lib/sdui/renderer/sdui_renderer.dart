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

  Widget render(SduiNode node) {
    final builder = registry.getBuilder(node.type);
    if (builder == null) {
      return _unknownWidget(node);
    }

    // Resolve templates in props
    final resolvedNode = node.copyWith(
      props: renderContext.templateResolver.resolveProps(node.props),
    );

    // Recursively render children
    final childWidgets = node.children.map(render).toList();

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
