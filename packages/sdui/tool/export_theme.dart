/// Exports SduiTheme light + dark values to JSON for the style guide generator.
///
/// Usage: flutter run -d linux tool/export_theme.dart > theme-export.json
/// Or:    dart run tool/export_theme.dart  (if no Flutter widgets are used)
///
/// This must be run from the sdui package root.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sdui/sdui.dart';

String _hex(Color c) {
  final r = c.red.toRadixString(16).padLeft(2, '0');
  final g = c.green.toRadixString(16).padLeft(2, '0');
  final b = c.blue.toRadixString(16).padLeft(2, '0');
  return '#${r}${g}${b}'.toUpperCase();
}

Map<String, String> _exportColors(SduiColorTokens c) {
  // Use resolve() to get all named tokens
  final names = <String>[
    'primary', 'onPrimary', 'primaryContainer', 'onPrimaryContainer',
    'secondary', 'onSecondary', 'secondaryContainer', 'onSecondaryContainer',
    'tertiary', 'onTertiary', 'tertiaryContainer', 'onTertiaryContainer',
    'error', 'onError', 'errorContainer', 'onErrorContainer',
    'background', 'onBackground',
    'surface', 'onSurface', 'onSurfaceVariant', 'onSurfaceMuted', 'onSurfaceDisabled',
    'surfaceContainerLowest', 'surfaceContainerLow', 'surfaceContainer',
    'surfaceContainerHigh', 'surfaceContainerHighest',
    'outline', 'outlineVariant',
    'inverseSurface', 'onInverseSurface', 'inversePrimary',
    'scrim', 'shadow',
    'warning', 'onWarning', 'warningContainer', 'onWarningContainer',
    'success', 'onSuccess', 'successContainer', 'onSuccessContainer',
    'info', 'onInfo', 'infoContainer', 'onInfoContainer',
    'link', 'linkHover',
    'textTertiary', 'primaryFixed',
  ];

  final map = <String, String>{};
  for (final name in names) {
    final color = c.resolve(name);
    if (color != null) {
      map[name] = _hex(color);
    }
  }
  return map;
}

Map<String, dynamic> _exportTextStyle(SduiTextStyleDef def) => {
  'fontSize': def.fontSize,
  'fontWeight': def.fontWeight,
  'lineHeight': def.lineHeight,
  if (def.letterSpacing != null) 'letterSpacing': def.letterSpacing,
};

Map<String, dynamic> _exportTextStyles(SduiTextStyleTokens ts) {
  final names = <String>[
    'headlineLarge', 'headlineMedium', 'headlineSmall',
    'bodyLarge', 'bodyMedium', 'bodySmall',
    'labelLarge', 'labelSmall', 'sectionHeader', 'micro',
  ];
  final map = <String, dynamic>{};
  for (final name in names) {
    final def = ts.resolve(name);
    if (def != null) map[name] = _exportTextStyle(def);
  }
  return map;
}

void main() {
  const light = SduiTheme.light();
  const dark = SduiTheme.dark();

  final export = {
    'generatedAt': DateTime.now().toIso8601String(),
    'generator': 'sdui/tool/export_theme.dart',

    'fontFamily': light.fontFamily,

    'spacing': {
      'xs': light.spacing.xs,
      'sm': light.spacing.sm,
      'md': light.spacing.md,
      'lg': light.spacing.lg,
      'xl': light.spacing.xl,
      'xxl': light.spacing.xxl,
    },

    'radius': {
      'sm': light.radius.sm,
      'md': light.radius.md,
      'lg': light.radius.lg,
      'xl': light.radius.xl,
      'full': light.radius.full,
    },

    'elevation': {
      'none': light.elevation.none,
      'low': light.elevation.low,
      'medium': light.elevation.medium,
      'high': light.elevation.high,
    },

    'lineWeight': {
      'subtle': light.lineWeight.subtle,
      'standard': light.lineWeight.standard,
      'emphasis': light.lineWeight.emphasis,
      'vizGrid': light.lineWeight.vizGrid,
      'vizAxis': light.lineWeight.vizAxis,
      'vizData': light.lineWeight.vizData,
      'vizHighlight': light.lineWeight.vizHighlight,
    },

    'controlHeight': {
      'sm': light.controlHeight.sm,
      'md': light.controlHeight.md,
      'lg': light.controlHeight.lg,
    },

    'button': {
      'paddingH': light.button.paddingH,
      'paddingV': light.button.paddingV,
      'borderRadius': light.button.borderRadius,
      'outlinedBorderWidth': light.button.outlinedBorderWidth,
    },

    'iconSize': {
      'sm': light.iconSize.sm,
      'md': light.iconSize.md,
      'lg': light.iconSize.lg,
    },

    'window': {
      'toolbarHeight': light.window.toolbarHeight,
      'toolbarButtonSize': light.window.toolbarButtonSize,
      'toolbarButtonIconSize': light.window.toolbarButtonIconSize,
      'headerChromeHeight': light.window.headerChromeHeight,
      'avatarSize': light.window.avatarSize,
      'focusRingWidth': light.window.focusRingWidth,
      'focusRingOffset': light.window.focusRingOffset,
    },

    'dataTable': {
      'headerPaddingV': light.dataTable.headerPaddingV,
      'headerPaddingH': light.dataTable.headerPaddingH,
      'cellPaddingV': light.dataTable.cellPaddingV,
      'cellPaddingH': light.dataTable.cellPaddingH,
      'rowSeparatorWidth': light.dataTable.rowSeparatorWidth,
    },

    'textStyles': _exportTextStyles(light.textStyles),

    'themes': {
      'light': { 'colors': _exportColors(light.colors) },
      'dark': { 'colors': _exportColors(dark.colors) },
    },

    'primitives': _exportPrimitives(),
  };

  print(const JsonEncoder.withIndent('  ').convert(export));
}

List<Map<String, dynamic>> _exportPrimitives() {
  final registry = WidgetRegistry();
  registerBuiltinWidgets(registry);

  // Categorise primitives by their role
  const categories = <String, List<String>>{
    'Layout': ['Row', 'Column', 'Container', 'Expanded', 'SizedBox', 'Center',
               'Spacer', 'Padding', 'Wrap', 'Grid'],
    'Content': ['Text', 'SelectableText', 'Markdown', 'Icon', 'Image',
                'Tooltip', 'Divider'],
    'Interactive': ['PrimaryButton', 'SecondaryButton', 'GhostButton',
                    'SubtleButton', 'DangerButton', 'IconButton',
                    'ToggleButton', 'PopupMenu', 'TextField',
                    'DropdownButton', 'Switch', 'Checkbox', 'Radio',
                    'RadioGroup', 'Slider', 'TabBar'],
    'Feedback': ['LoadingIndicator', 'ProgressBar', 'Chip', 'CircleAvatar',
                 'Badge', 'Alert'],
    'Data Display': ['Card', 'DashboardCard', 'DataGrid',
                     'ImageViewer', 'TabbedImageViewer', 'DirectedGraph',
                     'FormDialog'],
    'Domain': ['WindowShell', 'Identicon', 'Placeholder', 'ListView'],
    'Behaviour': ['DataSource', 'ForEach', 'Action', 'ReactTo', 'Conditional',
                  'StateHolder', 'Sort', 'Filter', 'PromptRequired'],
  };

  // Build a type→category lookup
  final typeCategory = <String, String>{};
  for (final entry in categories.entries) {
    for (final type in entry.value) {
      typeCategory[type] = entry.key;
    }
  }

  // Scope variable documentation (not in metadata, must be manual)
  const scopeVars = <String, List<String>>{
    'DataSource': ['{{loading}}', '{{data}}', '{{error}}', '{{errorMessage}}'],
    'ForEach': ['{{item}}', '{{_index}}'],
    'StateHolder': ['{{state}}'],
    'ReactTo': ['{{matched}}'],
    'Sort': ['{{sorted}}'],
    'Filter': ['{{filtered}}'],
  };

  final result = <Map<String, dynamic>>[];
  for (final meta in registry.catalog) {
    final entry = meta.toJson();
    entry['category'] = typeCategory[meta.type] ?? 'Other';
    if (scopeVars.containsKey(meta.type)) {
      entry['scopeVariables'] = scopeVars[meta.type];
    }
    result.add(entry);
  }

  // Sort by category then type
  final catOrder = categories.keys.toList();
  result.sort((a, b) {
    final ca = catOrder.indexOf(a['category'] as String);
    final cb = catOrder.indexOf(b['category'] as String);
    if (ca != cb) return ca.compareTo(cb);
    return (a['type'] as String).compareTo(b['type'] as String);
  });

  return result;
}
