import 'dart:ui';

/// Identity properties that the window exposes to the Frame.
class WindowIdentity {
  final String typeId;
  final Color typeColor;
  String label;

  WindowIdentity({
    required this.typeId,
    required this.typeColor,
    required this.label,
  });
}
