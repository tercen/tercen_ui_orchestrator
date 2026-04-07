import 'package:flutter/widgets.dart';

import '../renderer/sdui_render_context.dart';
import '../schema/sdui_node.dart';
import 'widget_metadata.dart';

/// Builder for simple widgets whose children are pre-rendered.
typedef SduiWidgetBuilder = Widget Function(
  SduiNode node,
  List<Widget> children,
  SduiRenderContext context,
);

/// Renders a single child node with additional scope entries.
typedef SduiChildRenderer = Widget Function(
  SduiNode childNode,
  Map<String, dynamic> scopeAdditions,
);

/// Builder for widgets that control child rendering (DataSource, ForEach, ReactTo, etc.).
/// Receives the raw node and a [childRenderer] callback to render children with custom scope.
typedef SduiScopeBuilder = Widget Function(
  SduiNode node,
  SduiRenderContext context,
  SduiChildRenderer childRenderer,
);

class _RegistryEntry {
  final SduiWidgetBuilder builder;
  final WidgetMetadata metadata;

  const _RegistryEntry({required this.builder, required this.metadata});
}

class _ScopeRegistryEntry {
  final SduiScopeBuilder builder;
  final WidgetMetadata metadata;

  const _ScopeRegistryEntry({required this.builder, required this.metadata});
}

/// A template-based widget: an SduiNode tree that gets expanded at render time.
class _TemplateEntry {
  final SduiNode template;
  final WidgetMetadata metadata;

  const _TemplateEntry({required this.template, required this.metadata});
}

class WidgetRegistry extends ChangeNotifier {
  final Map<String, _RegistryEntry> _entries = {};
  final Map<String, _ScopeRegistryEntry> _scopeEntries = {};
  final Map<String, _TemplateEntry> _templates = {};

  /// Register a compiled widget builder.
  void register(
    String type,
    SduiWidgetBuilder builder, {
    WidgetMetadata? metadata,
  }) {
    _entries[type] = _RegistryEntry(
      builder: builder,
      metadata: metadata ?? WidgetMetadata(type: type),
    );
    notifyListeners();
  }

  /// Register a scope-modifying widget builder (DataSource, ForEach, ReactTo, etc.).
  void registerScope(
    String type,
    SduiScopeBuilder builder, {
    WidgetMetadata? metadata,
  }) {
    _scopeEntries[type] = _ScopeRegistryEntry(
      builder: builder,
      metadata: metadata ?? WidgetMetadata(type: type),
    );
    notifyListeners();
  }

  /// Register a template widget — an SduiNode tree that gets expanded at render time.
  void registerTemplate(
    String type,
    SduiNode template, {
    required WidgetMetadata metadata,
  }) {
    _templates[type] = _TemplateEntry(template: template, metadata: metadata);
    notifyListeners();
  }

  /// Load templates from a catalog JSON (as produced by a widget library export).
  void loadCatalog(Map<String, dynamic> catalog) {
    final widgets = catalog['widgets'] as List<dynamic>? ?? [];
    debugPrint('[WidgetRegistry] loadCatalog: ${widgets.length} widget(s) in catalog');
    for (final entry in widgets) {
      if (entry is! Map<String, dynamic>) {
        debugPrint('[WidgetRegistry]   skipping non-map entry: ${entry.runtimeType}');
        continue;
      }
      final metaJson = entry['metadata'] as Map<String, dynamic>?;
      final templateJson = entry['template'] as Map<String, dynamic>?;
      if (metaJson == null || templateJson == null) {
        debugPrint('[WidgetRegistry]   skipping entry: metadata=${metaJson != null}, template=${templateJson != null}');
        continue;
      }

      final meta = WidgetMetadata.fromJson(metaJson);
      final template = SduiNode.fromJson(templateJson);
      _templates[meta.type] = _TemplateEntry(template: template, metadata: meta);
      debugPrint('[WidgetRegistry]   registered template "${meta.type}" '
          'tier=${meta.tier} root=${template.type} children=${template.children.length} '
          'requiredProps=${meta.props.entries.where((e) => e.value.required).map((e) => e.key).toList()}');
    }
    debugPrint('[WidgetRegistry] registry totals: '
        'builders=${_entries.length} scopeBuilders=${_scopeEntries.length} templates=${_templates.length}');
    debugPrint('[WidgetRegistry] all registered types: ${types}');
    notifyListeners();
  }

  SduiWidgetBuilder? getBuilder(String type) => _entries[type]?.builder;

  SduiScopeBuilder? getScopeBuilder(String type) =>
      _scopeEntries[type]?.builder;

  /// Get a registered template for a type, or null if not found.
  SduiNode? getTemplate(String type) => _templates[type]?.template;

  WidgetMetadata? getMetadata(String type) =>
      _entries[type]?.metadata ??
      _scopeEntries[type]?.metadata ??
      _templates[type]?.metadata;

  bool has(String type) =>
      _entries.containsKey(type) ||
      _scopeEntries.containsKey(type) ||
      _templates.containsKey(type);

  /// All registered widget metadata — exposed to AI for catalog queries.
  List<WidgetMetadata> get catalog => [
        ..._entries.values.map((e) => e.metadata),
        ..._scopeEntries.values.map((e) => e.metadata),
        ..._templates.values.map((e) => e.metadata),
      ];

  List<String> get types =>
      [..._entries.keys, ..._scopeEntries.keys, ..._templates.keys];
}
