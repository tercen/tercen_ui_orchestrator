/// Resolves a JSONPath expression against a plain Dart Map/List structure.
///
/// Supports:
///   $.name              → map['name']
///   $.acl.owner         → map['acl']['owner']
///   $.steps[0].name     → map['steps'][0]['name']
///   $.steps[?@.id=='x'] → first element in steps where id == 'x'
///
/// Also accepts simple dot paths (without $. prefix) for backward compat:
///   acl.owner           → map['acl']['owner']
dynamic resolveJsonPath(dynamic root, String path) {
  if (path.isEmpty) return root;

  // If it starts with $, parse as JSONPath; otherwise simple dot path
  if (path.startsWith(r'$')) {
    return _navigateJsonPath(root, path.substring(1));
  }
  return _navigateDotPath(root, path);
}

/// Simple dot-path: "acl.owner" → root['acl']['owner']
dynamic _navigateDotPath(dynamic root, String path) {
  dynamic current = root;
  for (final segment in path.split('.')) {
    if (current is Map) {
      current = current[segment];
    } else {
      return null;
    }
  }
  return current;
}

/// Full JSONPath navigation on plain Maps/Lists.
///
/// Tokenizes the path after the '$' into segments:
///   .property     → PropertySegment
///   [0]           → IndexSegment
///   [?@.p=='v']   → FilterSegment
dynamic _navigateJsonPath(dynamic root, String path) {
  if (path.isEmpty) return root;

  final segments = _tokenize(path);
  dynamic current = root;

  for (final seg in segments) {
    if (current == null) return null;
    current = seg.navigate(current);
  }
  return current;
}

List<_Segment> _tokenize(String path) {
  final segments = <_Segment>[];

  // Match: .property, [0], or [?@.prop=='value'] / [?@.prop=="value"]
  final regex = RegExp(
    r'\.([a-zA-Z_][a-zA-Z0-9_]*)'
    r'|\[(\d+)\]'
    r"""\[\?@\.([a-zA-Z_][a-zA-Z0-9_]*)==['"]([^'"]+)['"]\]""",
  );

  for (final match in regex.allMatches(path)) {
    if (match.group(1) != null) {
      segments.add(_PropertySegment(match.group(1)!));
    } else if (match.group(2) != null) {
      segments.add(_IndexSegment(int.parse(match.group(2)!)));
    } else if (match.group(3) != null && match.group(4) != null) {
      segments.add(_FilterSegment(match.group(3)!, match.group(4)!));
    }
  }

  return segments;
}

// -- Segment types (work on plain Maps/Lists) --

abstract class _Segment {
  dynamic navigate(dynamic target);
}

class _PropertySegment extends _Segment {
  final String property;
  _PropertySegment(this.property);

  @override
  dynamic navigate(dynamic target) {
    if (target is Map) return target[property];
    return null;
  }
}

class _IndexSegment extends _Segment {
  final int index;
  _IndexSegment(this.index);

  @override
  dynamic navigate(dynamic target) {
    if (target is List && index >= 0 && index < target.length) {
      return target[index];
    }
    return null;
  }
}

class _FilterSegment extends _Segment {
  final String property;
  final String value;
  _FilterSegment(this.property, this.value);

  @override
  dynamic navigate(dynamic target) {
    if (target is! List) return null;
    for (final item in target) {
      if (item is Map && item[property]?.toString() == value) {
        return item;
      }
    }
    return null;
  }
}
