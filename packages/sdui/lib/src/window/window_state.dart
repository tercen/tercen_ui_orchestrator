import '../schema/sdui_node.dart';

/// Standard window sizes as fractions of the viewport.
class WindowSize {
  final double widthFraction;
  final double heightFraction;

  const WindowSize(this.widthFraction, this.heightFraction);

  static const small = WindowSize(0.30, 0.40);
  static const medium = WindowSize(0.40, 0.50);
  static const large = WindowSize(0.60, 0.70);
  static const column = WindowSize(0.30, 1.00);
  static const row = WindowSize(1.00, 0.40);
  static const full = WindowSize(1.00, 1.00);

  static WindowSize fromName(String name) => switch (name) {
        'small' => small,
        'medium' => medium,
        'large' => large,
        'column' => column,
        'row' => row,
        'full' => full,
        _ => medium,
      };
}

/// Standard alignment presets as fractions (0..1) of the viewport.
class WindowAlignment {
  final double xFraction;
  final double yFraction;

  const WindowAlignment(this.xFraction, this.yFraction);

  static const topLeft = WindowAlignment(0.0, 0.0);
  static const topRight = WindowAlignment(1.0, 0.0);
  static const bottomLeft = WindowAlignment(0.0, 1.0);
  static const bottomRight = WindowAlignment(1.0, 1.0);
  static const center = WindowAlignment(0.5, 0.5);
  static const left = WindowAlignment(0.0, 0.5);
  static const right = WindowAlignment(1.0, 0.5);
  static const top = WindowAlignment(0.5, 0.0);
  static const bottom = WindowAlignment(0.5, 1.0);

  static WindowAlignment fromName(String name) => switch (name) {
        'topLeft' => topLeft,
        'topRight' => topRight,
        'bottomLeft' => bottomLeft,
        'bottomRight' => bottomRight,
        'center' => center,
        'left' => left,
        'right' => right,
        'top' => top,
        'bottom' => bottom,
        _ => center,
      };
}

class WindowState {
  final String id;
  String? title;
  SduiNode content;
  WindowSize size;
  WindowAlignment alignment;
  double x;
  double y;
  double width;
  double height;
  int zIndex;
  bool minimized;

  WindowState({
    required this.id,
    this.title,
    required this.content,
    this.size = WindowSize.medium,
    this.alignment = WindowAlignment.center,
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
    this.zIndex = 0,
    this.minimized = false,
  });

  /// Compute actual pixel position from alignment and size within a viewport.
  void computePosition(double viewportW, double viewportH) {
    width = viewportW * size.widthFraction;
    height = viewportH * size.heightFraction;

    // Alignment fraction maps to the anchor point of the window.
    // 0.0 = window's left/top at viewport edge
    // 0.5 = window centered
    // 1.0 = window's right/bottom at viewport edge
    x = (viewportW - width) * alignment.xFraction;
    y = (viewportH - height) * alignment.yFraction;
  }

  /// Full serialization for layout save/restore — includes complete SduiNode
  /// content tree. Use this for persisting layouts, not for agent summaries.
  Map<String, dynamic> toFullJson() => {
        'id': id,
        if (title != null) 'title': title,
        'size': _sizeName(),
        'align': _alignName(),
        'x': x.round(),
        'y': y.round(),
        'width': width.round(),
        'height': height.round(),
        'zIndex': zIndex,
        if (minimized) 'minimized': true,
        'content': content.toJson(),
      };

  /// Restore a WindowState from a saved layout JSON.
  factory WindowState.fromFullJson(Map<String, dynamic> json) {
    return WindowState(
      id: json['id'] as String,
      title: json['title'] as String?,
      content: SduiNode.fromJson(
          Map<String, dynamic>.from(json['content'] as Map)),
      size: WindowSize.fromName(json['size'] as String? ?? 'medium'),
      alignment: WindowAlignment.fromName(json['align'] as String? ?? 'center'),
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
      zIndex: json['zIndex'] as int? ?? 0,
      minimized: json['minimized'] as bool? ?? false,
    );
  }

  /// Summary serialization for agent context — filtered props, no full content.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': content.type,
        if (title != null) 'title': title,
        'size': _sizeName(),
        'align': _alignName(),
        'x': x.round(),
        'y': y.round(),
        'width': width.round(),
        'height': height.round(),
        'zIndex': zIndex,
        if (minimized) 'minimized': true,
        if (content.props.isNotEmpty) 'props': _safeProps(content.props),
        if (content.children.isNotEmpty)
          'children': _summarizeChildren(content.children),
      };

  /// Summarise a content tree for the agent — include type, id, and key props
  /// (service/method/items/channel) but omit deep children to keep it compact.
  static List<Map<String, dynamic>> _summarizeChildren(List<SduiNode> nodes) {
    return nodes.map((c) {
      final m = <String, dynamic>{
        'type': c.type,
        'id': c.id,
      };
      final sp = _safeProps(c.props);
      if (sp.isNotEmpty) m['props'] = sp;
      if (c.children.isNotEmpty) {
        m['children'] = _summarizeChildren(c.children);
      }
      return m;
    }).toList();
  }

  /// Extract props that are useful for the agent to understand what a window
  /// is showing, without leaking large data blobs or auth tokens.
  static Map<String, dynamic> _safeProps(Map<String, dynamic> props) {
    const include = {
      'service', 'method', 'args', 'refreshOn',
      'items', 'channel', 'gesture', 'intent',
      'text', 'icon', 'label', 'title',
      'visible', 'fields',
    };
    final result = <String, dynamic>{};
    for (final key in props.keys) {
      if (include.contains(key)) {
        result[key] = props[key];
      }
    }
    return result;
  }

  String _sizeName() {
    if (size == WindowSize.small) return 'small';
    if (size == WindowSize.medium) return 'medium';
    if (size == WindowSize.large) return 'large';
    if (size == WindowSize.column) return 'column';
    if (size == WindowSize.row) return 'row';
    if (size == WindowSize.full) return 'full';
    return 'medium';
  }

  String _alignName() {
    if (alignment == WindowAlignment.topLeft) return 'topLeft';
    if (alignment == WindowAlignment.topRight) return 'topRight';
    if (alignment == WindowAlignment.bottomLeft) return 'bottomLeft';
    if (alignment == WindowAlignment.bottomRight) return 'bottomRight';
    if (alignment == WindowAlignment.center) return 'center';
    if (alignment == WindowAlignment.left) return 'left';
    if (alignment == WindowAlignment.right) return 'right';
    if (alignment == WindowAlignment.top) return 'top';
    if (alignment == WindowAlignment.bottom) return 'bottom';
    return 'center';
  }
}
