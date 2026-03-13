import 'json_path_resolver.dart';

/// Matches {{scope.path}} where path can be:
///   - Simple:   {{item.name}}
///   - Nested:   {{item.acl.owner}}
///   - JSONPath:  {{item:$.acl.owner}}
///   - JSONPath:  {{item:$.steps[0].name}}
///   - JSONPath:  {{item:$.steps[?@.id=='abc'].name}}
///
/// Two forms:
///   {{scope.dotPath}}       — backward-compatible simple dot navigation
///   {{scope:$jsonPath}}     — full JSONPath (triggered by ':$')
final _templatePattern = RegExp(
  r'\{\{(\w+)'           // scope name (e.g., item, data, context)
  r'(?:'
    r':(\$[^\}]+)'       // JSONPath form:  :$.acl.owner
    r'|'
    r'\.([.\w]+)'        // dot-path form:  .acl.owner
  r')'
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

  dynamic _resolveValue(dynamic value, Map<String, dynamic> extraScope) {
    if (value is String) return _resolveString(value, extraScope);
    if (value is Map<String, dynamic>) return resolveProps(value, extraScope);
    if (value is List) {
      return value.map((v) => _resolveValue(v, extraScope)).toList();
    }
    return value;
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
      return value?.toString() ?? '';
    });
  }
}
