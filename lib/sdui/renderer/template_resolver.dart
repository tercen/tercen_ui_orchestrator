final _templatePattern = RegExp(r'\{\{context\.(\w+)\}\}');

class TemplateResolver {
  final Map<String, dynamic> _values = {};

  void set(String key, dynamic value) => _values[key] = value;

  dynamic get(String key) => _values[key];

  /// Resolves {{context.x}} templates in a props map.
  Map<String, dynamic> resolveProps(Map<String, dynamic> props) {
    return props.map((key, value) => MapEntry(key, _resolveValue(value)));
  }

  dynamic _resolveValue(dynamic value) {
    if (value is String) return _resolveString(value);
    if (value is Map<String, dynamic>) return resolveProps(value);
    if (value is List) return value.map(_resolveValue).toList();
    return value;
  }

  String _resolveString(String input) {
    return input.replaceAllMapped(_templatePattern, (match) {
      final key = match.group(1)!;
      return _values[key]?.toString() ?? match.group(0)!;
    });
  }
}
