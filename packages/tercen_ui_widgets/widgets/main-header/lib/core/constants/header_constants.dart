/// Constants specific to the header skeleton.
/// These tokens are exclusive to the header and must NOT be used in other skeletons.
class HeaderConstants {
  HeaderConstants._();

  /// Fixed height of the header chrome bar (36px).
  /// Visually subordinate to the 48px window toolbar.
  static const double headerChromeHeight = 36.0;

  /// Avatar circle diameter. Fits in 36px with 4px padding top/bottom.
  static const double avatarSize = 28.0;

  /// Maximum height for the brand mark slot content.
  static const double brandMarkMaxHeight = 28.0;

  /// Width of the user dropdown menu.
  static const double dropdownWidth = 220.0;
}
