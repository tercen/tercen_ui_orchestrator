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
  final String? title;
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': content.type,
        if (title != null) 'title': title,
        'size': _sizeName(),
        'align': _alignName(),
        if (content.children.isNotEmpty)
          'children': content.children.map((c) => c.type).toList(),
      };

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
