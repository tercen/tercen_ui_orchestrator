import 'package:flutter/widgets.dart';

import '../renderer/sdui_render_context.dart';
import '../schema/sdui_node.dart';
import 'widget_metadata.dart';

typedef SduiWidgetBuilder = Widget Function(
  SduiNode node,
  List<Widget> children,
  SduiRenderContext context,
);

class _RegistryEntry {
  final SduiWidgetBuilder builder;
  final WidgetMetadata metadata;

  const _RegistryEntry({required this.builder, required this.metadata});
}

class WidgetRegistry {
  final Map<String, _RegistryEntry> _entries = {};

  void register(
    String type,
    SduiWidgetBuilder builder, {
    WidgetMetadata? metadata,
  }) {
    _entries[type] = _RegistryEntry(
      builder: builder,
      metadata: metadata ?? WidgetMetadata(type: type),
    );
  }

  SduiWidgetBuilder? getBuilder(String type) => _entries[type]?.builder;

  WidgetMetadata? getMetadata(String type) => _entries[type]?.metadata;

  bool has(String type) => _entries.containsKey(type);

  /// All registered widget metadata — exposed to AI for catalog queries.
  List<WidgetMetadata> get catalog =>
      _entries.values.map((e) => e.metadata).toList();

  List<String> get types => _entries.keys.toList();
}
