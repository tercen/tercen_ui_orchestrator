import 'dart:convert';

import 'package:sdui/sdui.dart';

/// Known scope variables provided by behavior widgets.
const _scopeProviders = <String, Map<String, String>>{
  'DataSource': {
    'data': 'any — the fetched result (list or object)',
    'loading': 'boolean — true while fetching',
    'ready': 'boolean — true when data loaded',
    'error': 'boolean — true if fetch failed',
    'errorMessage': 'string — error message',
  },
  'ForEach': {
    'item': 'object — current iteration item',
    '_index': 'integer — current iteration index',
  },
  'StateHolder': {
    'state': 'object — mutable local state',
  },
  'ReactTo': {
    'matched': 'boolean — true if latest event matched',
  },
  'Sort': {
    'sorted': 'array — the sorted list',
  },
  'Filter': {
    'filtered': 'array — the filtered list',
  },
};

/// Generates a JSON Schema describing all SDUI components.
///
/// Walks the [WidgetRegistry] after [registerBuiltinWidgets] and catalog loading,
/// emitting a schema with every widget type, its props, children rules,
/// scope provisions, and event contracts.
///
/// If [tokensJson] is provided, token definitions are extracted from it
/// (single source of truth). Otherwise falls back to hardcoded defaults.
class SduiSchemaGenerator {
  final WidgetRegistry registry;
  final Map<String, dynamic>? tokensJson;

  SduiSchemaGenerator(this.registry, {this.tokensJson});

  /// Generate the full SDUI component schema.
  Map<String, dynamic> generate() {
    final components = <String, dynamic>{};

    for (final meta in registry.catalog) {
      components[meta.type] = _componentSchema(meta);
    }

    return {
      '\$schema': 'https://json-schema.org/draft/2020-12/schema',
      'title': 'SDUI Component Schema',
      'description': 'Auto-generated from WidgetRegistry. '
          'Describes all available SDUI primitives, behavior widgets, '
          'and catalog templates with their props, scope provisions, '
          'and event contracts.',
      'version': '1.0.0',
      'components': components,
      'tokens': _tokenDefinitions(),
      'bindings': _bindingDefinitions(),
    };
  }

  /// Write the schema as JSON.
  String toJson() {
    return const JsonEncoder.withIndent('  ').convert(generate());
  }

  Map<String, dynamic> _componentSchema(WidgetMetadata meta) {
    final schema = <String, dynamic>{
      'description': meta.description,
      'tier': meta.tier,
    };

    // Props.
    if (meta.props.isNotEmpty) {
      final props = <String, dynamic>{};
      final required = <String>[];
      for (final entry in meta.props.entries) {
        props[entry.key] = _propSpecSchema(entry.value);
        if (entry.value.required) required.add(entry.key);
      }
      schema['props'] = props;
      if (required.isNotEmpty) schema['requiredProps'] = required;
    }

    // Children.
    // Behavior widgets and layout widgets accept children; leaf widgets don't.
    final isLeaf = const {
      'Text', 'SelectableText', 'Icon', 'LoadingIndicator', 'Divider',
      'Chip', 'Image', 'ProgressBar', 'Spacer', 'SizedBox', 'Placeholder',
      'Identicon', 'Markdown',
    }.contains(meta.type);
    schema['children'] = !isLeaf;

    // Scope provisions (behavior widgets).
    final provisions = _scopeProviders[meta.type];
    if (provisions != null) {
      schema['provides'] = provisions;
    }

    // PromptRequired provides its field names.
    if (meta.type == 'PromptRequired') {
      schema['provides'] = {
        '<fieldName>': 'string — each field defined in props.fields becomes a scope variable',
      };
    }

    // Emitted events.
    if (meta.emittedEvents.isNotEmpty) {
      schema['emits'] = meta.emittedEvents;
    }

    // Accepted actions.
    if (meta.acceptedActions.isNotEmpty) {
      schema['acceptedActions'] = meta.acceptedActions;
    }

    // Handled intents.
    if (meta.handlesIntent.isNotEmpty) {
      schema['handlesIntent'] = meta.handlesIntent
          .map((i) => i.toJson())
          .toList();
    }

    // Semantic metadata (for agent discovery).
    if (meta.domain != null) schema['domain'] = meta.domain;
    if (meta.capabilities.isNotEmpty) schema['capabilities'] = meta.capabilities;
    if (meta.selectionMode != 'none') schema['selectionMode'] = meta.selectionMode;
    if (meta.dataSource != null) schema['dataSource'] = meta.dataSource;

    return schema;
  }

  Map<String, dynamic> _propSpecSchema(PropSpec spec) {
    final schema = <String, dynamic>{
      'type': spec.type,
    };
    if (spec.description != null && spec.description!.isNotEmpty) {
      schema['description'] = spec.description;
    }
    if (spec.defaultValue != null) {
      schema['default'] = spec.defaultValue;
    }
    if (spec.values != null && spec.values!.isNotEmpty) {
      schema['enum'] = spec.values;
    }
    return schema;
  }

  Map<String, dynamic> _tokenDefinitions() {
    if (tokensJson != null) {
      return _tokenDefinitionsFromJson(tokensJson!);
    }
    // Fallback if no tokens.json provided.
    return _tokenDefinitionsFallback();
  }

  Map<String, dynamic> _tokenDefinitionsFromJson(Map<String, dynamic> tokens) {
    // Colors: from themes.light.colors keys.
    final themes = tokens['themes'] as Map<String, dynamic>? ?? {};
    final lightTheme = themes['light'] as Map<String, dynamic>? ?? {};
    final colors = lightTheme['colors'] as Map<String, dynamic>? ?? {};

    // Text styles: from top-level textStyles keys.
    final textStyles = tokens['textStyles'] as Map<String, dynamic>? ?? {};

    // Spacing: from top-level spacing.
    final spacing = tokens['spacing'] as Map<String, dynamic>? ?? {};

    // Radius: from top-level radius.
    final radius = tokens['radius'] as Map<String, dynamic>? ?? {};

    return {
      'color': {
        'description': 'Semantic color token names — extracted from tokens.json themes.light.colors',
        'values': colors.keys.toList()..sort(),
      },
      'textStyle': {
        'description': 'Text style token names — extracted from tokens.json textStyles',
        'values': textStyles.keys.toList()..sort(),
      },
      'spacing': {
        'description': 'Spacing token names — extracted from tokens.json spacing',
        'values': spacing.keys.toList(),
        'mapping': spacing,
      },
      'radius': {
        'description': 'Border radius token names — extracted from tokens.json radius',
        'values': radius.keys.toList(),
        'mapping': radius,
      },
      'roles': {
        'description': 'Semantic text roles used by archetypes. '
            'Widget authors pick roles, not raw token names.',
        'values': {
          'prominent': {'textStyle': 'titleMedium', 'color': 'onSurface'},
          'primary': {'textStyle': 'bodySmall', 'color': 'onSurface'},
          'secondary': {'textStyle': 'labelSmall', 'color': 'onSurfaceMuted'},
          'muted': {'textStyle': 'labelSmall', 'color': 'onSurfaceDisabled'},
          'action': {'textStyle': 'labelMedium', 'color': 'primary'},
          'section': {'textStyle': 'labelMedium', 'color': 'onSurface'},
        },
      },
    };
  }

  Map<String, dynamic> _tokenDefinitionsFallback() {
    return {
      'color': {
        'description': 'Semantic color token names (fallback — no tokens.json)',
        'values': [
          'primary', 'onPrimary', 'primaryContainer', 'onPrimaryContainer',
          'secondary', 'onSecondary', 'secondaryContainer', 'onSecondaryContainer',
          'tertiary', 'onTertiary', 'tertiaryContainer', 'onTertiaryContainer',
          'error', 'onError', 'errorContainer', 'onErrorContainer',
          'surface', 'onSurface', 'onSurfaceVariant', 'onSurfaceMuted',
          'surfaceContainerHigh', 'surfaceContainerLow', 'surfaceContainer',
          'outline', 'outlineVariant',
          'warning', 'success', 'info', 'link',
        ],
      },
      'textStyle': {
        'description': 'Text style token names (fallback)',
        'values': [
          'displayLarge', 'displayMedium', 'displaySmall',
          'headlineLarge', 'headlineMedium', 'headlineSmall',
          'titleLarge', 'titleMedium', 'titleSmall',
          'labelLarge', 'labelMedium', 'labelSmall',
          'bodyLarge', 'bodyMedium', 'bodySmall',
        ],
      },
      'spacing': {
        'description': 'Spacing token names (fallback)',
        'values': ['xs', 'sm', 'md', 'lg', 'xl', 'xxl'],
        'mapping': {'xs': 4, 'sm': 8, 'md': 16, 'lg': 24, 'xl': 32, 'xxl': 48},
      },
    };
  }

  Map<String, dynamic> _bindingDefinitions() {
    return {
      'description': 'Template binding expressions available in SDUI templates',
      'globalBindings': {
        'props.X': 'Caller-provided prop value',
        'widgetId': 'The ID of the node that invoked this template',
        'context.username': 'Current user username',
        'context.userId': 'Current user ID',
      },
      'scopeBindings': {
        'data': 'Inside DataSource — fetched result',
        'loading': 'Inside DataSource — fetch in progress',
        'ready': 'Inside DataSource — fetch succeeded',
        'error': 'Inside DataSource — fetch failed',
        'errorMessage': 'Inside DataSource — error message',
        'item': 'Inside ForEach — current iteration item',
        '_index': 'Inside ForEach — current iteration index',
        'state': 'Inside StateHolder — mutable state object',
        'matched': 'Inside ReactTo — whether latest event matched',
        'isSelected': 'Inside ForEach with Interaction ancestor — whether item is selected',
        'sorted': 'Inside Sort — sorted list',
        'filtered': 'Inside Filter — filtered list',
      },
    };
  }
}
