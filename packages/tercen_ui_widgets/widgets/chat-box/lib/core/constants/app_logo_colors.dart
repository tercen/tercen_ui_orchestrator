import 'dart:ui';

/// The 16 colours from the Tercen App logo (App.svg), arranged in
/// row-major order of the 4×4 grid.
///
/// Used for decorative colour-coded markers (e.g. assistant message
/// bullet squares) that rotate through the full palette.
class AppLogoColors {
  AppLogoColors._();

  static const List<Color> palette = [
    // Row 0
    Color(0xFFFF0000), // red
    Color(0xFFFF8200), // orange
    Color(0xFF99FF00), // lime
    Color(0xFFFFBF00), // amber
    // Row 1
    Color(0xFF9333EA), // purple
    Color(0xFF0099FF), // sky blue
    Color(0xFF6D0000), // maroon
    Color(0xFF66FF7F), // mint
    // Row 2
    Color(0xFFE040FB), // magenta
    Color(0xFF00FFFF), // cyan
    Color(0xFF0000FF), // blue
    Color(0xFF0D9488), // teal
    // Row 3
    Color(0xFFFF4F00), // vermilion
    Color(0xFFEC4899), // pink
    Color(0xFFFFF8DC), // cornsilk
    Color(0xFFFFDD00), // yellow
  ];

  /// Returns a colour from the palette, cycling for any index.
  static Color atIndex(int index) => palette[index % palette.length];
}
