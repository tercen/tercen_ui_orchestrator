import 'package:sdui/sdui.dart';

import 'validation_result.dart';

/// Pattern that matches `{{expr}}` template bindings.
final _bindingPattern = RegExp(r'\{\{([^}]+)\}\}');

/// Known color token names from SduiColorTokens.resolve().
const _colorTokens = <String>{
  'primary', 'onPrimary', 'primaryContainer', 'onPrimaryContainer',
  'secondary', 'onSecondary', 'secondaryContainer', 'onSecondaryContainer',
  'tertiary', 'onTertiary', 'tertiaryContainer', 'onTertiaryContainer',
  'error', 'onError', 'errorContainer', 'onErrorContainer',
  'background', 'onBackground',
  'surface', 'onSurface', 'onSurfaceVariant', 'onSurfaceMuted', 'onSurfaceDisabled',
  'surfaceContainerLowest', 'surfaceContainerLow', 'surfaceContainer',
  'surfaceContainerHigh', 'surfaceContainerHighest',
  'surfaceVariant', 'border', 'divider', 'outline', 'outlineVariant',
  'inverseSurface', 'onInverseSurface', 'inversePrimary', 'scrim', 'shadow',
  'warning', 'onWarning', 'warningContainer', 'onWarningContainer',
  'success', 'onSuccess', 'successContainer', 'onSuccessContainer',
  'info', 'onInfo', 'infoContainer', 'onInfoContainer',
  'link', 'linkHover', 'panelBg', 'textTertiary', 'primaryBg',
  'textPrimary', 'textSecondary', 'textMuted', 'textDisabled',
  'surfaceElevated', 'panelBackground', 'borderSubtle',
  'primaryDarker', 'primaryLighter', 'primarySurface',
  'successLight', 'errorLight', 'warningLight', 'infoLight',
  'sectionHeaderBg', 'primaryHover', 'primaryActive',
};

/// Known text style token names from SduiTextStyleTokens.resolve().
const _textStyleTokens = <String>{
  'displayLarge', 'displayMedium', 'displaySmall',
  'headlineLarge', 'headlineMedium', 'headlineSmall',
  'titleLarge', 'titleMedium', 'titleSmall',
  'labelLarge', 'labelMedium', 'labelSmall',
  'bodyLarge', 'bodyMedium', 'bodySmall',
  'sectionHeader', 'micro',
  'h1', 'h2', 'h3', 'body', 'bodyLg', 'label',
};

/// Known spacing token names.
const _spacingTokens = <String>{'xs', 'sm', 'md', 'lg', 'xl', 'xxl'};

/// Known Tercen service names.
const _knownServices = <String>{
  'projectService', 'workflowService', 'userService', 'teamService',
  'fileService', 'taskService', 'tableSchemaService', 'operatorService',
  'eventService', 'documentService', 'projectDocumentService',
  'folderService', 'activityService', 'persistentService', 'queryService',
};

/// Props that accept color values.
const _colorProps = <String>{'color', 'borderColor', 'hoverColor', 'backgroundColor', 'iconColor'};

/// Behavior widgets that introduce scope variables.
const _scopeProviders = <String, Set<String>>{
  'DataSource': {'data', 'loading', 'ready', 'error', 'errorMessage'},
  'ForEach': {'item', '_index'},
  'StateHolder': {'state'},
  'ReactTo': {'matched'},
  'Sort': {'sorted'},
  'Filter': {'filtered'},
};

/// Validates SDUI widget templates for correctness.
///
/// Checks structural integrity, binding scopes, event wiring, service
/// references, theming compliance, ID patterns, and metadata consistency.
class TemplateValidator {
  final WidgetRegistry registry;

  /// Additional service names to accept (beyond the built-in set).
  final Set<String> extraServices;

  TemplateValidator({
    required this.registry,
    this.extraServices = const {},
  });

  /// Validate a single widget definition.
  List<ValidationResult> validate({
    required WidgetMetadata metadata,
    required SduiNode template,
  }) {
    final results = <ValidationResult>[];
    final allServices = {..._knownServices, ...extraServices};

    // Collect tree-wide data in a single pass.
    final seenIds = <String>{};
    final publishers = <String, List<Map<String, dynamic>>>{}; // channel → payloads
    final subscribers = <String, List<String>>{}; // channel → node paths

    _walk(
      node: template,
      path: '',
      scopeStack: <String>{},
      inForEach: false,
      results: results,
      seenIds: seenIds,
      publishers: publishers,
      subscribers: subscribers,
      metadata: metadata,
      allServices: allServices,
      selfType: metadata.type,
    );

    // Cross-tree checks after walk.
    _checkEventWiring(publishers, subscribers, results);
    _checkMetadata(metadata, template, publishers, results);

    return results;
  }

  /// Validate all widgets in a catalog JSON.
  Map<String, List<ValidationResult>> validateCatalog(
      Map<String, dynamic> catalogJson) {
    final results = <String, List<ValidationResult>>{};
    final widgets = catalogJson['widgets'] as List<dynamic>? ?? [];

    for (final entry in widgets) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final metaJson = map['metadata'] as Map<String, dynamic>?;
      final templateJson = map['template'] as Map<String, dynamic>?;
      if (metaJson == null || templateJson == null) continue;

      final meta = WidgetMetadata.fromJson(metaJson);
      final template = SduiNode.fromJson(templateJson);
      results[meta.type] = validate(metadata: meta, template: template);
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // Tree walk
  // ---------------------------------------------------------------------------

  void _walk({
    required SduiNode node,
    required String path,
    required Set<String> scopeStack,
    required bool inForEach,
    required List<ValidationResult> results,
    required Set<String> seenIds,
    required Map<String, List<Map<String, dynamic>>> publishers,
    required Map<String, List<String>> subscribers,
    required WidgetMetadata metadata,
    required Set<String> allServices,
    required String selfType,
  }) {
    final nodePath = path.isEmpty
        ? '${node.type}(${node.id})'
        : '$path > ${node.type}(${node.id})';

    // --- Rule 1: Structural ---
    _checkStructural(node, nodePath, seenIds, results, selfType);

    // --- Rule 2: Binding scope ---
    final newScope = Set<String>.from(scopeStack);
    final providerVars = _scopeProviders[node.type];
    if (providerVars != null) {
      newScope.addAll(providerVars);
    }
    // PromptRequired adds its field names to scope.
    if (node.type == 'PromptRequired') {
      final fields = node.props['fields'];
      if (fields is List) {
        for (final f in fields) {
          if (f is Map) {
            final name = f['name']?.toString() ?? '';
            if (name.isNotEmpty) newScope.add(name);
          }
        }
      }
    }
    _checkBindingScope(node, nodePath, newScope, results);

    // --- Rule 4: Service methods ---
    if (node.type == 'DataSource') {
      _checkService(node, nodePath, allServices, results);
    }

    // --- Rule 5: Theming ---
    _checkTheming(node, nodePath, results);

    // --- Rule 6: ID patterns ---
    _checkIdPatterns(node, nodePath, inForEach, results);

    // --- Collect publishers/subscribers ---
    _collectEvents(node, nodePath, publishers, subscribers);

    // Recurse into children.
    final childInForEach = inForEach || node.type == 'ForEach';
    for (final child in node.children) {
      _walk(
        node: child,
        path: nodePath,
        scopeStack: newScope,
        inForEach: childInForEach,
        results: results,
        seenIds: seenIds,
        publishers: publishers,
        subscribers: subscribers,
        metadata: metadata,
        allServices: allServices,
        selfType: selfType,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Rule 1: Structural
  // ---------------------------------------------------------------------------

  void _checkStructural(SduiNode node, String path, Set<String> seenIds,
      List<ValidationResult> results, String selfType) {
    if (node.type.isEmpty) {
      results.add(ValidationResult(
        severity: ValidationSeverity.error,
        message: 'Node has empty type',
        nodePath: path,
        ruleId: 'structural/empty-type',
      ));
    }
    if (node.id.isEmpty) {
      results.add(ValidationResult(
        severity: ValidationSeverity.error,
        message: 'Node has empty id',
        nodePath: path,
        ruleId: 'structural/empty-id',
      ));
    }

    // Check type exists (skip self — not yet registered).
    if (node.type.isNotEmpty &&
        node.type != selfType &&
        !registry.has(node.type)) {
      results.add(ValidationResult(
        severity: ValidationSeverity.error,
        message: 'Unknown widget type "${node.type}"',
        nodePath: path,
        ruleId: 'structural/unknown-type',
      ));
    }

    // Check ID uniqueness (only static IDs — those without {{...}}).
    if (node.id.isNotEmpty && !_bindingPattern.hasMatch(node.id)) {
      if (!seenIds.add(node.id)) {
        results.add(ValidationResult(
          severity: ValidationSeverity.error,
          message: 'Duplicate static ID "${node.id}"',
          nodePath: path,
          ruleId: 'structural/duplicate-id',
        ));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Rule 2: Binding scope
  // ---------------------------------------------------------------------------

  void _checkBindingScope(SduiNode node, String path, Set<String> scope,
      List<ValidationResult> results) {
    // Always-available roots.
    const globalRoots = {'props', 'widgetId', 'context'};

    _scanPropsForBindings(node.props, (expr) {
      final root = expr.split('.').first;
      if (globalRoots.contains(root)) return;
      if (scope.contains(root)) return;

      // Check which scope provider is needed.
      String? needed;
      for (final entry in _scopeProviders.entries) {
        if (entry.value.contains(root)) {
          needed = entry.key;
          break;
        }
      }

      results.add(ValidationResult(
        severity: ValidationSeverity.error,
        message: needed != null
            ? '"{{$expr}}" used outside $needed scope'
            : '"{{$expr}}" references unknown scope variable "$root"',
        nodePath: path,
        ruleId: 'binding-scope/${root.replaceAll('_', '')}-out-of-scope',
      ));
    });
  }

  // ---------------------------------------------------------------------------
  // Rule 3: Event wiring (collection phase)
  // ---------------------------------------------------------------------------

  void _collectEvents(
      SduiNode node,
      String path,
      Map<String, List<Map<String, dynamic>>> publishers,
      Map<String, List<String>> subscribers) {
    // Publishers: Action, ElevatedButton, TextButton, IconButton.
    if ({'Action', 'ElevatedButton', 'TextButton', 'IconButton'}
        .contains(node.type)) {
      final channel = _literalStringProp(node, 'channel');
      if (channel != null) {
        final payload = node.props['payload'];
        final payloadMap = payload is Map
            ? Map<String, dynamic>.from(payload)
            : <String, dynamic>{};
        publishers.putIfAbsent(channel, () => []).add(payloadMap);
      }
    }

    // Subscribers: ReactTo.
    if (node.type == 'ReactTo') {
      final channel = _literalStringProp(node, 'channel');
      if (channel != null) {
        subscribers.putIfAbsent(channel, () => []).add(path);
      }
    }

    // Subscribers: DataSource.refreshOn.
    if (node.type == 'DataSource') {
      final refreshOn = _literalStringProp(node, 'refreshOn');
      if (refreshOn != null) {
        subscribers.putIfAbsent(refreshOn, () => []).add(path);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Rule 3: Event wiring (cross-check phase)
  // ---------------------------------------------------------------------------

  void _checkEventWiring(
      Map<String, List<Map<String, dynamic>>> publishers,
      Map<String, List<String>> subscribers,
      List<ValidationResult> results) {
    // Check subscribers have publishers (skip system/navigator channels).
    for (final entry in subscribers.entries) {
      final channel = entry.key;
      if (_isExternalChannel(channel)) continue;
      if (!publishers.containsKey(channel)) {
        for (final path in entry.value) {
          results.add(ValidationResult(
            severity: ValidationSeverity.warning,
            message: 'Subscribes to "$channel" but no publisher in this template',
            nodePath: path,
            ruleId: 'event-wiring/no-publisher',
          ));
        }
      }
    }
  }

  bool _isExternalChannel(String channel) =>
      channel.startsWith('system.') ||
      channel.startsWith('navigator.') ||
      channel.startsWith('header.') ||
      channel.startsWith('window.') ||
      channel.startsWith('chat.') ||
      channel.startsWith('workflow.');

  // ---------------------------------------------------------------------------
  // Rule 4: Service methods
  // ---------------------------------------------------------------------------

  void _checkService(SduiNode node, String path, Set<String> allServices,
      List<ValidationResult> results) {
    final service = _literalStringProp(node, 'service');
    final method = _literalStringProp(node, 'method');

    if (service == null && !_hasBindingProp(node, 'service')) {
      results.add(ValidationResult(
        severity: ValidationSeverity.error,
        message: 'DataSource missing "service" prop',
        nodePath: path,
        ruleId: 'service/missing-service',
      ));
    } else if (service != null && !allServices.contains(service)) {
      results.add(ValidationResult(
        severity: ValidationSeverity.warning,
        message: 'Unknown service "$service"',
        nodePath: path,
        ruleId: 'service/unknown-service',
      ));
    }

    if (method == null && !_hasBindingProp(node, 'method')) {
      results.add(ValidationResult(
        severity: ValidationSeverity.error,
        message: 'DataSource missing "method" prop',
        nodePath: path,
        ruleId: 'service/missing-method',
      ));
    }

    // Check args exist.
    if (!node.props.containsKey('args')) {
      results.add(ValidationResult(
        severity: ValidationSeverity.info,
        message: 'DataSource has no "args" — will call $method with empty args',
        nodePath: path,
        ruleId: 'service/no-args',
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Rule 5: Theming
  // ---------------------------------------------------------------------------

  void _checkTheming(SduiNode node, String path,
      List<ValidationResult> results) {
    // Check color props.
    for (final prop in _colorProps) {
      final value = node.props[prop];
      if (value is! String || _bindingPattern.hasMatch(value)) continue;

      if (value.startsWith('#')) {
        results.add(ValidationResult(
          severity: ValidationSeverity.warning,
          message: 'Raw hex color "$value" in "$prop" — use a semantic token',
          nodePath: path,
          ruleId: 'theming/raw-hex-color',
        ));
      } else if (!_colorTokens.contains(value) &&
          !_isNamedMaterialColor(value)) {
        results.add(ValidationResult(
          severity: ValidationSeverity.warning,
          message: 'Unknown color token "$value" in "$prop"',
          nodePath: path,
          ruleId: 'theming/unknown-color-token',
        ));
      }
    }

    // Check text styling.
    if (node.type == 'Text' || node.type == 'SelectableText') {
      final fontSize = node.props['fontSize'];
      if (fontSize is num) {
        results.add(ValidationResult(
          severity: ValidationSeverity.warning,
          message: 'Raw fontSize=$fontSize — use "textStyle" with a token name',
          nodePath: path,
          ruleId: 'theming/raw-font-size',
        ));
      }
      final textStyle = node.props['textStyle'];
      if (textStyle is String &&
          !_bindingPattern.hasMatch(textStyle) &&
          !_textStyleTokens.contains(textStyle)) {
        results.add(ValidationResult(
          severity: ValidationSeverity.warning,
          message: 'Unknown textStyle token "$textStyle"',
          nodePath: path,
          ruleId: 'theming/unknown-text-style',
        ));
      }
    }

    // Check spacing tokens.
    final padding = node.props['padding'];
    if (padding is num) {
      results.add(ValidationResult(
        severity: ValidationSeverity.info,
        message: 'Numeric padding=$padding — consider using a spacing token (${_spacingTokens.join(", ")})',
        nodePath: path,
        ruleId: 'theming/raw-spacing',
      ));
    }
  }

  bool _isNamedMaterialColor(String value) => const {
        'red', 'pink', 'purple', 'deepPurple', 'indigo', 'blue', 'lightBlue',
        'cyan', 'teal', 'green', 'lightGreen', 'lime', 'yellow', 'amber',
        'orange', 'deepOrange', 'brown', 'grey', 'gray', 'blueGrey',
        'white', 'black', 'transparent',
      }.contains(value);

  // ---------------------------------------------------------------------------
  // Rule 6: ID patterns
  // ---------------------------------------------------------------------------

  void _checkIdPatterns(SduiNode node, String path, bool inForEach,
      List<ValidationResult> results) {
    final id = node.id;
    if (id.isEmpty) return;

    // Check that IDs use {{widgetId}} prefix (unless inside ForEach where
    // {{item.X}} is expected).
    if (!id.contains('{{widgetId}}') && !id.contains('{{item.') && !id.contains('{{_index}}')) {
      results.add(ValidationResult(
        severity: ValidationSeverity.warning,
        message: 'ID "$id" has no {{widgetId}} prefix — will collide across instances',
        nodePath: path,
        ruleId: 'id-pattern/no-widget-id-prefix',
      ));
    }

    // Inside ForEach, IDs should differentiate per iteration.
    if (inForEach &&
        !id.contains('{{item.') &&
        !id.contains('{{_index}}')) {
      results.add(ValidationResult(
        severity: ValidationSeverity.info,
        message:
            'ID "$id" inside ForEach has no {{item.X}} — relies on auto-suffix',
        nodePath: path,
        ruleId: 'id-pattern/no-item-id-in-foreach',
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Rule 7: Metadata validation
  // ---------------------------------------------------------------------------

  void _checkMetadata(
      WidgetMetadata metadata,
      SduiNode template,
      Map<String, List<Map<String, dynamic>>> publishers,
      List<ValidationResult> results) {
    // Collect all {{props.X}} bindings used in the template.
    final usedProps = <String>{};
    _collectPropsBindings(template, usedProps);

    // Check declared but unused props.
    for (final entry in metadata.props.entries) {
      if (!usedProps.contains(entry.key)) {
        results.add(ValidationResult(
          severity: ValidationSeverity.warning,
          message: 'Prop "${entry.key}" declared in metadata but not used in template',
          nodePath: '(metadata)',
          ruleId: 'metadata/unused-prop',
        ));
      }
    }

    // Check used but undeclared props.
    for (final prop in usedProps) {
      if (!metadata.props.containsKey(prop)) {
        results.add(ValidationResult(
          severity: ValidationSeverity.warning,
          message: 'Template uses {{props.$prop}} but it is not declared in metadata',
          nodePath: '(metadata)',
          ruleId: 'metadata/undeclared-prop',
        ));
      }
    }

    // Check emittedEvents vs actual publishers.
    final publishedChannels = publishers.keys.toSet();
    for (final declared in metadata.emittedEvents) {
      if (!publishedChannels.contains(declared)) {
        results.add(ValidationResult(
          severity: ValidationSeverity.warning,
          message: 'emittedEvents declares "$declared" but no Action publishes to it',
          nodePath: '(metadata)',
          ruleId: 'metadata/unmatched-emitted-event',
        ));
      }
    }

    // Check description quality.
    if (metadata.description.length < 10) {
      results.add(ValidationResult(
        severity: ValidationSeverity.info,
        message: 'Widget description is very short — AIs use this to decide when to use the widget',
        nodePath: '(metadata)',
        ruleId: 'metadata/short-description',
      ));
    }
  }

  void _collectPropsBindings(SduiNode node, Set<String> usedProps) {
    _scanPropsForBindings(node.props, (expr) {
      if (expr.startsWith('props.')) {
        final propName = expr.substring(6).split('.').first;
        usedProps.add(propName);
      }
    });
    for (final child in node.children) {
      _collectPropsBindings(child, usedProps);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Scan all string values in a props map for {{...}} bindings.
  void _scanPropsForBindings(
      Map<String, dynamic> props, void Function(String expr) onBinding) {
    for (final value in props.values) {
      _scanValue(value, onBinding);
    }
  }

  void _scanValue(dynamic value, void Function(String expr) onBinding) {
    if (value is String) {
      for (final match in _bindingPattern.allMatches(value)) {
        onBinding(match.group(1)!);
      }
    } else if (value is Map) {
      for (final v in value.values) {
        _scanValue(v, onBinding);
      }
    } else if (value is List) {
      for (final v in value) {
        _scanValue(v, onBinding);
      }
    }
  }

  /// Get a prop value as a literal string (null if missing or a binding).
  String? _literalStringProp(SduiNode node, String prop) {
    final value = node.props[prop];
    if (value is! String) return null;
    if (_bindingPattern.hasMatch(value)) return null;
    return value;
  }

  /// Check if a prop is a binding expression.
  bool _hasBindingProp(SduiNode node, String prop) {
    final value = node.props[prop];
    return value is String && _bindingPattern.hasMatch(value);
  }
}
