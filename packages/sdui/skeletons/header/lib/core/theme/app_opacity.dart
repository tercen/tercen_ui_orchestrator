/// Opacity tokens — alpha values for consistent transparency.
/// Source: tercen-style design-tokens.md
///
/// All withAlpha() calls must use these constants — no hardcoded numbers.
class AppOpacity {
  AppOpacity._();

  // Opacity levels (int alpha, 0–255)
  static const int subtle = 25;    // ~10% — status/error background tint
  static const int light = 76;     // ~30% — status/error borders
  static const int disabled = 97;  // ~38% — disabled icon overlay
  static const int medium = 127;   // ~50% — shadows, scrim
  static const int strong = 204;   // ~80% — error text on tinted background
}
