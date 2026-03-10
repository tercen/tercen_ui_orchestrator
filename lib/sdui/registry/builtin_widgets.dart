import 'package:flutter/material.dart';

import '../renderer/sdui_render_context.dart';
import '../schema/sdui_node.dart';
import 'widget_metadata.dart';
import 'widget_registry.dart';

/// Register Flutter primitive widgets (Tier 1) into the registry.
void registerBuiltinWidgets(WidgetRegistry registry) {
  // Layout primitives
  registry.register('Row', _buildRow,
      metadata: const WidgetMetadata(
        type: 'Row',
        description: 'Horizontal layout',
        props: {
          'mainAxisAlignment': PropSpec(type: 'string', defaultValue: 'start'),
          'crossAxisAlignment': PropSpec(type: 'string', defaultValue: 'center'),
        },
      ));

  registry.register('Column', _buildColumn,
      metadata: const WidgetMetadata(
        type: 'Column',
        description: 'Vertical layout',
        props: {
          'mainAxisAlignment': PropSpec(type: 'string', defaultValue: 'start'),
          'crossAxisAlignment': PropSpec(type: 'string', defaultValue: 'center'),
        },
      ));

  registry.register('Container', _buildContainer,
      metadata: const WidgetMetadata(
        type: 'Container',
        description: 'Box with optional padding, color, and constraints',
        props: {
          'color': PropSpec(type: 'string'),
          'padding': PropSpec(type: 'number'),
          'width': PropSpec(type: 'number'),
          'height': PropSpec(type: 'number'),
        },
      ));

  registry.register('Text', _buildText,
      metadata: const WidgetMetadata(
        type: 'Text',
        description: 'Text display',
        props: {
          'text': PropSpec(type: 'string', required: true),
          'fontSize': PropSpec(type: 'number', defaultValue: 14),
          'color': PropSpec(type: 'string'),
          'fontWeight': PropSpec(type: 'string'),
        },
      ));

  registry.register('Expanded', _buildExpanded,
      metadata: const WidgetMetadata(
        type: 'Expanded',
        description: 'Expand child to fill available space',
        props: {'flex': PropSpec(type: 'int', defaultValue: 1)},
      ));

  registry.register('SizedBox', _buildSizedBox,
      metadata: const WidgetMetadata(
        type: 'SizedBox',
        description: 'Fixed-size box or spacer',
        props: {
          'width': PropSpec(type: 'number'),
          'height': PropSpec(type: 'number'),
        },
      ));

  registry.register('Center', _buildCenter,
      metadata: const WidgetMetadata(
        type: 'Center',
        description: 'Center child within parent',
      ));

  registry.register('ListView', _buildListView,
      metadata: const WidgetMetadata(
        type: 'ListView',
        description: 'Scrollable list of children',
        props: {
          'padding': PropSpec(type: 'number'),
        },
      ));

  registry.register('Grid', _buildGrid,
      metadata: const WidgetMetadata(
        type: 'Grid',
        description: 'Grid layout with configurable columns',
        props: {
          'columns': PropSpec(type: 'int', required: true, defaultValue: 2),
          'spacing': PropSpec(type: 'number', defaultValue: 8),
        },
      ));

  registry.register('Card', _buildCard,
      metadata: const WidgetMetadata(
        type: 'Card',
        description: 'Material card with elevation',
        props: {
          'elevation': PropSpec(type: 'number', defaultValue: 1),
          'color': PropSpec(type: 'string'),
        },
      ));

  registry.register('Padding', _buildPadding,
      metadata: const WidgetMetadata(
        type: 'Padding',
        description: 'Add padding around child',
        props: {
          'padding': PropSpec(type: 'number', required: true, defaultValue: 8),
        },
      ));

  // Test / placeholder widget
  registry.register('Placeholder', _buildPlaceholder,
      metadata: const WidgetMetadata(
        type: 'Placeholder',
        description: 'Placeholder widget for testing',
        props: {
          'label': PropSpec(type: 'string', defaultValue: 'Placeholder'),
          'color': PropSpec(type: 'string'),
        },
      ));
}

// -- Builder implementations --

Widget _buildRow(SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return Row(
    mainAxisAlignment: _parseMainAxis(node.props['mainAxisAlignment']),
    crossAxisAlignment: _parseCrossAxis(node.props['crossAxisAlignment']),
    children: children,
  );
}

Widget _buildColumn(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return Column(
    mainAxisAlignment: _parseMainAxis(node.props['mainAxisAlignment']),
    crossAxisAlignment: _parseCrossAxis(node.props['crossAxisAlignment']),
    children: children,
  );
}

Widget _buildContainer(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return Container(
    color: _parseColor(node.props['color']),
    padding: _edgeInsets(node.props['padding']),
    width: (node.props['width'] as num?)?.toDouble(),
    height: (node.props['height'] as num?)?.toDouble(),
    child: children.isEmpty ? null : children.first,
  );
}

Widget _buildText(SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return Text(
    node.props['text'] as String? ?? '',
    style: TextStyle(
      fontSize: (node.props['fontSize'] as num?)?.toDouble() ?? 14,
      color: _parseColor(node.props['color']) ?? Colors.white70,
      fontWeight: _parseFontWeight(node.props['fontWeight']),
    ),
  );
}

Widget _buildExpanded(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return Expanded(
    flex: node.props['flex'] as int? ?? 1,
    child: children.isEmpty ? const SizedBox.shrink() : children.first,
  );
}

Widget _buildSizedBox(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return SizedBox(
    width: (node.props['width'] as num?)?.toDouble(),
    height: (node.props['height'] as num?)?.toDouble(),
    child: children.isEmpty ? null : children.first,
  );
}

Widget _buildCenter(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return Center(child: children.isEmpty ? null : children.first);
}

Widget _buildListView(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return ListView(
    padding: _edgeInsets(node.props['padding']),
    children: children,
  );
}

Widget _buildGrid(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final columns = node.props['columns'] as int? ?? 2;
  final spacing = (node.props['spacing'] as num?)?.toDouble() ?? 8;
  return GridView.count(
    crossAxisCount: columns,
    mainAxisSpacing: spacing,
    crossAxisSpacing: spacing,
    shrinkWrap: true,
    children: children,
  );
}

Widget _buildCard(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return Card(
    elevation: (node.props['elevation'] as num?)?.toDouble() ?? 1,
    color: _parseColor(node.props['color']),
    child: children.isEmpty ? null : children.first,
  );
}

Widget _buildPadding(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return Padding(
    padding: _edgeInsets(node.props['padding']) ?? EdgeInsets.zero,
    child: children.isEmpty ? null : children.first,
  );
}

Widget _buildPlaceholder(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final label = node.props['label'] as String? ?? 'Placeholder';
  final color = _parseColor(node.props['color']) ?? Colors.blue;
  return Container(
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      border: Border.all(color: color.withAlpha(76)),
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.all(16),
    child: Center(
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 16),
      ),
    ),
  );
}

// -- Helpers --

MainAxisAlignment _parseMainAxis(dynamic value) => switch (value) {
      'start' => MainAxisAlignment.start,
      'end' => MainAxisAlignment.end,
      'center' => MainAxisAlignment.center,
      'spaceBetween' => MainAxisAlignment.spaceBetween,
      'spaceAround' => MainAxisAlignment.spaceAround,
      'spaceEvenly' => MainAxisAlignment.spaceEvenly,
      _ => MainAxisAlignment.start,
    };

CrossAxisAlignment _parseCrossAxis(dynamic value) => switch (value) {
      'start' => CrossAxisAlignment.start,
      'end' => CrossAxisAlignment.end,
      'center' => CrossAxisAlignment.center,
      'stretch' => CrossAxisAlignment.stretch,
      _ => CrossAxisAlignment.center,
    };

Color? _parseColor(dynamic value) {
  if (value == null) return null;
  if (value is String && value.startsWith('#') && value.length == 7) {
    return Color(int.parse('FF${value.substring(1)}', radix: 16));
  }
  // Named color shortcuts
  return switch (value) {
    'red' => Colors.red,
    'blue' => Colors.blue,
    'green' => Colors.green,
    'orange' => Colors.orange,
    'purple' => Colors.purple,
    'white' => Colors.white,
    'black' => Colors.black,
    'grey' || 'gray' => Colors.grey,
    _ => null,
  };
}

FontWeight? _parseFontWeight(dynamic value) => switch (value) {
      'bold' => FontWeight.bold,
      'w100' => FontWeight.w100,
      'w200' => FontWeight.w200,
      'w300' => FontWeight.w300,
      'w400' => FontWeight.w400,
      'w500' => FontWeight.w500,
      'w600' => FontWeight.w600,
      'w700' => FontWeight.w700,
      'w800' => FontWeight.w800,
      'w900' => FontWeight.w900,
      _ => null,
    };

EdgeInsets? _edgeInsets(dynamic value) {
  if (value == null) return null;
  if (value is num) return EdgeInsets.all(value.toDouble());
  return null;
}
