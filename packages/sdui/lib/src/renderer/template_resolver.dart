import 'json_path_resolver.dart';

/// Wrapper that distinguishes "resolved to null" from "not resolved".
class _Resolved {
  final dynamic value;
  const _Resolved(this.value);
}

/// Matches {{scope.path}}, {{scope:$jsonPath}}, or {{key}} where:
///   - Simple:   {{item.name}}
///   - Nested:   {{item.acl.owner}}
///   - JSONPath:  {{item:$.acl.owner}}
///   - JSONPath:  {{item:$.steps[0].name}}
///   - JSONPath:  {{item:$.steps[?@.id=='abc'].name}}
///   - Bare key:  {{widgetId}} — looks up directly in extraScope
///
/// Three forms:
///   {{scope.dotPath}}       — backward-compatible simple dot navigation
///   {{scope:$jsonPath}}     — full JSONPath (triggered by ':$')
///   {{key}}                 — bare key lookup in scope (for simple string values)
final _templatePattern = RegExp(
  r'\{\{(\w+)'           // scope name (e.g., item, data, context, widgetId)
  r'(?:'
    r':(\$[^\}]+)'       // JSONPath form:  :$.acl.owner
    r'|'
    r'\.([.\w]+)'        // dot-path form:  .acl.owner
  r')?'                   // path is optional — bare {{key}} is valid
  r'\}\}',
);

class TemplateResolver {
  final Map<String, dynamic> _values = {};

  void set(String key, dynamic value) => _values[key] = value;

  dynamic get(String key) => _values[key];

  /// Resolves {{scope.field}} and {{scope:$path}} templates in a props map.
  ///
  /// Scopes: `context` (global values), `item` (list iteration), `data` (single object).
  Map<String, dynamic> resolveProps(Map<String, dynamic> props,
      [Map<String, dynamic> extraScope = const {}]) {
    return props
        .map((key, value) => MapEntry(key, _resolveValue(value, extraScope)));
  }

  /// Resolves templates in a single value, preserving the original type.
  ///
  /// Use this instead of [resolveString] when the resolved value may be
  /// a non-string type (int, bool, List, Map) — e.g., dataSource args.
  dynamic resolveValue(dynamic value,
          [Map<String, dynamic> extraScope = const {}]) =>
      _resolveValue(value, extraScope);

  dynamic _resolveValue(dynamic value, Map<String, dynamic> extraScope) {
    if (value is String) {
      // If the entire string is a single {{...}} expression, return the raw
      // value (preserving its original type — int, double, bool, List, null, etc.)
      // instead of converting to string.
      final raw = _resolveRaw(value, extraScope);
      if (raw != null) {
        // Auto-format Tercen date objects when used as a prop value
        if (raw.value is Map && raw.value['kind'] == 'Date') {
          return _valueToString(raw.value);
        }
        return raw.value;
      }
      return _resolveString(value, extraScope);
    }
    if (value is Map<String, dynamic>) return resolveProps(value, extraScope);
    if (value is List) {
      return value.map((v) => _resolveValue(v, extraScope)).toList();
    }
    return value;
  }

  /// If [input] is exactly one `{{...}}` with no surrounding text, return the
  /// raw resolved value wrapped in [_Resolved] (preserving type, including null).
  /// Returns `null` (unwrapped) only if the template could NOT be resolved
  /// (key not in scope, no match, or not a full-string template).
  _Resolved? _resolveRaw(String input, Map<String, dynamic> extraScope) {
    final match = _templatePattern.firstMatch(input);
    if (match == null) return null;
    // Must span the entire string — no surrounding text.
    if (match.start != 0 || match.end != input.length) return null;

    final scope = match.group(1)!;
    final jsonPath = match.group(2);
    final dotPath = match.group(3);

    // Bare key
    if (jsonPath == null && dotPath == null) {
      if (extraScope.containsKey(scope)) return _Resolved(extraScope[scope]);
      if (_values.containsKey(scope)) return _Resolved(_values[scope]);
      return null;
    }

    // Scoped lookup
    dynamic root;
    if (extraScope.containsKey(scope)) {
      root = extraScope[scope];
    } else if (scope == 'context') {
      root = _values;
    } else {
      return null;
    }

    final path = jsonPath ?? dotPath ?? '';
    return _Resolved(resolveJsonPath(root, path));
  }

  /// Resolves templates in a single string value.
  String resolveString(String input,
          [Map<String, dynamic> extraScope = const {}]) =>
      _resolveString(input, extraScope);

  String _resolveString(String input, Map<String, dynamic> extraScope) {
    return input.replaceAllMapped(_templatePattern, (match) {
      final scope = match.group(1)!;
      final jsonPath = match.group(2);  // e.g., $.acl.owner
      final dotPath = match.group(3);   // e.g., acl.owner

      // Bare key: {{widgetId}} — no path, just look up the value directly
      if (jsonPath == null && dotPath == null) {
        if (extraScope.containsKey(scope)) {
          final value = extraScope[scope];
          return value?.toString() ?? '';
        } else if (_values.containsKey(scope)) {
          return _values[scope]?.toString() ?? '';
        }
        return match.group(0)!; // unresolved — leave as-is
      }

      // Look up the root object for this scope
      dynamic root;
      if (extraScope.containsKey(scope)) {
        root = extraScope[scope];
      } else if (scope == 'context') {
        root = _values;
      } else {
        return match.group(0)!; // unresolved — leave as-is
      }

      // Resolve the path
      final path = jsonPath ?? dotPath ?? '';
      final value = resolveJsonPath(root, path);

      // Return the resolved value, or empty string if null
      return _valueToString(value);
    });
  }

  /// Converts a resolved value to a display string, handling special types
  /// like Tercen date objects ({kind: "Date", value: "2026-03-25T..."}).
  static String _valueToString(dynamic value) {
    if (value == null) return '';
    if (value is Map) {
      // Tercen date object → format as short date
      if (value['kind'] == 'Date' && value['value'] is String) {
        return _formatDate(value['value'] as String);
      }
      return value.toString();
    }
    return value.toString();
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Formats an ISO 8601 date string as "Mar 25, 2026".
  static String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
