/// Semantic role → token combination.
/// Maps human-readable intent ("prominent", "secondary") to theme token names.
class TextRole {
  final String textStyle;
  final String color;
  const TextRole(this.textStyle, this.color);
}

/// Skeleton-level theme decisions.
///
/// This is the bridge between user intent and design tokens:
/// - User/AI says "prominent title" → SkeletonTheme.prominent
/// - SkeletonTheme.prominent → titleMedium + onSurface
/// - tokens.json titleMedium → {fontSize: 16, fontWeight: 500}
///
/// Archetypes reference these constants instead of raw token names.
/// One place to change if the design system evolves.
class SkeletonTheme {
  // ---------------------------------------------------------------------------
  // Semantic text roles
  // ---------------------------------------------------------------------------

  /// Widget titles, emphasized content.
  static const prominent = TextRole('titleMedium', 'onSurface');

  /// Main item text — default for primaryField.
  static const primary = TextRole('bodySmall', 'onSurface');

  /// Supporting text — default for secondaryField.
  static const secondary = TextRole('labelSmall', 'onSurfaceMuted');

  /// Timestamps, metadata — default for tertiaryField.
  static const muted = TextRole('labelSmall', 'onSurfaceDisabled');

  /// Clickable labels, links, action text.
  static const action = TextRole('labelMedium', 'primary');

  /// Section headers, toolbar titles.
  static const section = TextRole('labelMedium', 'onSurface');

  // ---------------------------------------------------------------------------
  // Layout roles → spacing token names
  // ---------------------------------------------------------------------------

  static const toolbarBg = 'surfaceContainerHigh';
  static const toolbarPadding = 'sm';
  static const listItemPadding = 'sm';
  static const listPadding = 'xs';
  static const sectionGap = 'md';
  static const formFieldGap = 'sm';
  static const formPadding = 'md';

  // ---------------------------------------------------------------------------
  // Color roles → color token names
  // ---------------------------------------------------------------------------

  static const itemIconColor = 'onSurfaceVariant';
  static const errorColor = 'error';
  static const dividerColor = 'outlineVariant';

  // ---------------------------------------------------------------------------
  // Fixed sizes (not tokens — pixel values)
  // ---------------------------------------------------------------------------

  static const itemIconSize = 16;
  static const errorIconSize = 32;
  static const iconTextGap = 8.0;
  static const fieldLabelWidth = 120.0;
  static const submitGapHeight = 16.0;
  static const smallGapHeight = 4.0;

  // ---------------------------------------------------------------------------
  // Role resolution
  // ---------------------------------------------------------------------------

  /// Resolve a role name string to a TextRole.
  static TextRole? resolveRole(String? role) => switch (role) {
        'prominent' => prominent,
        'primary' => primary,
        'secondary' => secondary,
        'muted' => muted,
        'action' => action,
        'section' => section,
        _ => null,
      };

  /// Role for a field by position (implicit assignment).
  static TextRole roleForPosition(int index) => switch (index) {
        0 => primary,
        1 => secondary,
        _ => muted,
      };
}
