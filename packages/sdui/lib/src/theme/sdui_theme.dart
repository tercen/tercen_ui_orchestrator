import 'package:flutter/material.dart';

/// Parses a hex color string (#RRGGBB or #AARRGGBB) into a Color.
Color _parseHex(String hex) {
  final h = hex.startsWith('#') ? hex.substring(1) : hex;
  if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
  if (h.length == 8) return Color(int.parse(h, radix: 16));
  return const Color(0xFFFF00FF); // fallback — visually obvious mistake
}

Color _colorFromJson(Map<String, dynamic> json, String key, Color fallback) {
  final v = json[key];
  if (v is String) return _parseHex(v);
  return fallback;
}

double _doubleFromJson(Map<String, dynamic> json, String key, double fallback) {
  final v = json[key];
  if (v is num) return v.toDouble();
  return fallback;
}

int _intFromJson(Map<String, dynamic> json, String key, int fallback) {
  final v = json[key];
  if (v is num) return v.toInt();
  return fallback;
}

/// Color tokens for SDUI theming — covers full Material 3 ColorScheme + status colors.
class SduiColorTokens {
  // Primary
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  // Secondary
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;

  // Tertiary
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;

  // Error
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;

  // Background / Surface
  final Color background;
  final Color onBackground;
  final Color surface;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color onSurfaceMuted;
  final Color onSurfaceDisabled;

  // Surface containers (M3)
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;

  // Outline
  final Color outline;
  final Color outlineVariant;

  // Inverse
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color inversePrimary;

  // Scrim / shadow
  final Color scrim;
  final Color shadow;

  // Status — warning
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  // Status — success
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  // Status — info
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  // Extra
  final Color link;
  final Color linkHover;
  final Color panelBg;
  final Color textTertiary;
  final Color primaryBg;

  // Legacy aliases (kept for backward compat in widgets)
  Color get surfaceVariant => surfaceContainerHighest;
  Color get border => outline;
  Color get divider => outlineVariant;

  // Skeleton aliases
  Color get textPrimary => onSurface;
  Color get textSecondary => onSurfaceVariant;
  Color get textMuted => onSurfaceMuted;
  Color get textDisabled => onSurfaceDisabled;
  Color get surfaceElevated => surfaceContainerHigh;
  Color get panelBackground => panelBg;
  Color get borderSubtle => outlineVariant;
  Color get primaryDarker => onPrimaryContainer;
  Color get primaryLighter => secondary;
  Color get primarySurface => primaryContainer;
  Color get successLight => successContainer;
  Color get errorLight => errorContainer;
  Color get warningLight => warningContainer;
  Color get infoLight => infoContainer;

  // Backward compat — sectionHeaderBg now maps to surfaceContainerHigh
  Color get sectionHeaderBg => surfaceContainerHigh;

  const SduiColorTokens({
    required this.primary,
    required this.onPrimary,
    this.primaryContainer = const Color(0xFFDBEAFE),
    this.onPrimaryContainer = const Color(0xFF1E3A8A),
    required this.secondary,
    required this.onSecondary,
    this.secondaryContainer = const Color(0xFFDBEAFE),
    this.onSecondaryContainer = const Color(0xFF1E40AF),
    this.tertiary = const Color(0xFF6D28D9),
    this.onTertiary = const Color(0xFFFFFFFF),
    this.tertiaryContainer = const Color(0xFFEDE9FE),
    this.onTertiaryContainer = const Color(0xFF6D28D9),
    required this.error,
    required this.onError,
    required this.errorContainer,
    this.onErrorContainer = const Color(0xFFB91C1C),
    required this.background,
    this.onBackground = const Color(0xFF111827),
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onSurfaceMuted,
    this.onSurfaceDisabled = const Color(0xFF9CA3AF),
    this.surfaceContainerLowest = const Color(0xFFFFFFFF),
    this.surfaceContainerLow = const Color(0xFFF9FAFB),
    this.surfaceContainer = const Color(0xFFF3F4F6),
    this.surfaceContainerHigh = const Color(0xFFE5E7EB),
    this.surfaceContainerHighest = const Color(0xFFD1D5DB),
    this.outline = const Color(0xFFD1D5DB),
    this.outlineVariant = const Color(0xFFE5E7EB),
    this.inverseSurface = const Color(0xFF111827),
    this.onInverseSurface = const Color(0xFFF9FAFB),
    this.inversePrimary = const Color(0xFF93C5FD),
    this.scrim = const Color(0xFF000000),
    this.shadow = const Color(0xFF000000),
    required this.warning,
    this.onWarning = const Color(0xFFFFFFFF),
    required this.warningContainer,
    this.onWarningContainer = const Color(0xFFB45309),
    required this.success,
    this.onSuccess = const Color(0xFFFFFFFF),
    this.successContainer = const Color(0xFFD1FAE5),
    this.onSuccessContainer = const Color(0xFF047857),
    required this.info,
    this.onInfo = const Color(0xFFFFFFFF),
    this.infoContainer = const Color(0xFFCFFAFE),
    this.onInfoContainer = const Color(0xFF0E7490),
    this.link = const Color(0xFF1E40AF),
    this.linkHover = const Color(0xFF1E3A8A),
    this.panelBg = const Color(0xFFF9FAFB),
    this.textTertiary = const Color(0xFF4B5563),
    this.primaryBg = const Color(0xFFEFF6FF),
  });

  factory SduiColorTokens.fromJson(Map<String, dynamic> json, SduiColorTokens defaults) {
    return SduiColorTokens(
      primary: _colorFromJson(json, 'primary', defaults.primary),
      onPrimary: _colorFromJson(json, 'onPrimary', defaults.onPrimary),
      primaryContainer: _colorFromJson(json, 'primaryContainer', defaults.primaryContainer),
      onPrimaryContainer: _colorFromJson(json, 'onPrimaryContainer', defaults.onPrimaryContainer),
      secondary: _colorFromJson(json, 'secondary', defaults.secondary),
      onSecondary: _colorFromJson(json, 'onSecondary', defaults.onSecondary),
      secondaryContainer: _colorFromJson(json, 'secondaryContainer', defaults.secondaryContainer),
      onSecondaryContainer: _colorFromJson(json, 'onSecondaryContainer', defaults.onSecondaryContainer),
      tertiary: _colorFromJson(json, 'tertiary', defaults.tertiary),
      onTertiary: _colorFromJson(json, 'onTertiary', defaults.onTertiary),
      tertiaryContainer: _colorFromJson(json, 'tertiaryContainer', defaults.tertiaryContainer),
      onTertiaryContainer: _colorFromJson(json, 'onTertiaryContainer', defaults.onTertiaryContainer),
      error: _colorFromJson(json, 'error', defaults.error),
      onError: _colorFromJson(json, 'onError', defaults.onError),
      errorContainer: _colorFromJson(json, 'errorContainer', defaults.errorContainer),
      onErrorContainer: _colorFromJson(json, 'onErrorContainer', defaults.onErrorContainer),
      background: _colorFromJson(json, 'background', defaults.background),
      onBackground: _colorFromJson(json, 'onBackground', defaults.onBackground),
      surface: _colorFromJson(json, 'surface', defaults.surface),
      onSurface: _colorFromJson(json, 'onSurface', defaults.onSurface),
      onSurfaceVariant: _colorFromJson(json, 'onSurfaceVariant', defaults.onSurfaceVariant),
      onSurfaceMuted: _colorFromJson(json, 'onSurfaceMuted', defaults.onSurfaceMuted),
      onSurfaceDisabled: _colorFromJson(json, 'onSurfaceDisabled', defaults.onSurfaceDisabled),
      surfaceContainerLowest: _colorFromJson(json, 'surfaceContainerLowest', defaults.surfaceContainerLowest),
      surfaceContainerLow: _colorFromJson(json, 'surfaceContainerLow', defaults.surfaceContainerLow),
      surfaceContainer: _colorFromJson(json, 'surfaceContainer', defaults.surfaceContainer),
      surfaceContainerHigh: _colorFromJson(json, 'surfaceContainerHigh', defaults.surfaceContainerHigh),
      surfaceContainerHighest: _colorFromJson(json, 'surfaceContainerHighest', defaults.surfaceContainerHighest),
      outline: _colorFromJson(json, 'outline', defaults.outline),
      outlineVariant: _colorFromJson(json, 'outlineVariant', defaults.outlineVariant),
      inverseSurface: _colorFromJson(json, 'inverseSurface', defaults.inverseSurface),
      onInverseSurface: _colorFromJson(json, 'onInverseSurface', defaults.onInverseSurface),
      inversePrimary: _colorFromJson(json, 'inversePrimary', defaults.inversePrimary),
      scrim: _colorFromJson(json, 'scrim', defaults.scrim),
      shadow: _colorFromJson(json, 'shadow', defaults.shadow),
      warning: _colorFromJson(json, 'warning', defaults.warning),
      onWarning: _colorFromJson(json, 'onWarning', defaults.onWarning),
      warningContainer: _colorFromJson(json, 'warningContainer', defaults.warningContainer),
      onWarningContainer: _colorFromJson(json, 'onWarningContainer', defaults.onWarningContainer),
      success: _colorFromJson(json, 'success', defaults.success),
      onSuccess: _colorFromJson(json, 'onSuccess', defaults.onSuccess),
      successContainer: _colorFromJson(json, 'successContainer', defaults.successContainer),
      onSuccessContainer: _colorFromJson(json, 'onSuccessContainer', defaults.onSuccessContainer),
      info: _colorFromJson(json, 'info', defaults.info),
      onInfo: _colorFromJson(json, 'onInfo', defaults.onInfo),
      infoContainer: _colorFromJson(json, 'infoContainer', defaults.infoContainer),
      onInfoContainer: _colorFromJson(json, 'onInfoContainer', defaults.onInfoContainer),
      link: _colorFromJson(json, 'link', defaults.link),
      linkHover: _colorFromJson(json, 'linkHover', defaults.linkHover),
      panelBg: _colorFromJson(json, 'panelBg', defaults.panelBg),
      textTertiary: _colorFromJson(json, 'textTertiary', defaults.textTertiary),
      primaryBg: _colorFromJson(json, 'primaryBg', defaults.primaryBg),
    );
  }

  /// Resolve a semantic token name to a Color.
  Color? resolve(String name) => switch (name) {
    'primary' => primary,
    'onPrimary' => onPrimary,
    'primaryContainer' => primaryContainer,
    'onPrimaryContainer' => onPrimaryContainer,
    'secondary' => secondary,
    'onSecondary' => onSecondary,
    'secondaryContainer' => secondaryContainer,
    'onSecondaryContainer' => onSecondaryContainer,
    'tertiary' => tertiary,
    'onTertiary' => onTertiary,
    'tertiaryContainer' => tertiaryContainer,
    'onTertiaryContainer' => onTertiaryContainer,
    'error' => error,
    'onError' => onError,
    'errorContainer' => errorContainer,
    'onErrorContainer' => onErrorContainer,
    'background' => background,
    'onBackground' => onBackground,
    'surface' => surface,
    'onSurface' => onSurface,
    'onSurfaceVariant' => onSurfaceVariant,
    'onSurfaceMuted' => onSurfaceMuted,
    'onSurfaceDisabled' => onSurfaceDisabled,
    'surfaceContainerLowest' => surfaceContainerLowest,
    'surfaceContainerLow' => surfaceContainerLow,
    'surfaceContainer' => surfaceContainer,
    'surfaceContainerHigh' => surfaceContainerHigh,
    'surfaceContainerHighest' => surfaceContainerHighest,
    // Legacy aliases
    'surfaceVariant' => surfaceVariant,
    'border' => border,
    'divider' => divider,
    'outline' => outline,
    'outlineVariant' => outlineVariant,
    'inverseSurface' => inverseSurface,
    'onInverseSurface' => onInverseSurface,
    'inversePrimary' => inversePrimary,
    'scrim' => scrim,
    'shadow' => shadow,
    'warning' => warning,
    'onWarning' => onWarning,
    'warningContainer' => warningContainer,
    'onWarningContainer' => onWarningContainer,
    'success' => success,
    'onSuccess' => onSuccess,
    'successContainer' => successContainer,
    'onSuccessContainer' => onSuccessContainer,
    'info' => info,
    'onInfo' => onInfo,
    'infoContainer' => infoContainer,
    'onInfoContainer' => onInfoContainer,
    'link' => link,
    'linkHover' => linkHover,
    'textTertiary' => textTertiary,
    'primaryFixed' => primaryBg,
    _ => null,
  };
}

/// Spacing tokens.
class SduiSpacingTokens {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  const SduiSpacingTokens({
    this.xs = 4,
    this.sm = 8,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
    this.xxl = 48,
  });

  factory SduiSpacingTokens.fromJson(Map<String, dynamic> json) {
    const d = SduiSpacingTokens();
    return SduiSpacingTokens(
      xs: _doubleFromJson(json, 'xs', d.xs),
      sm: _doubleFromJson(json, 'sm', d.sm),
      md: _doubleFromJson(json, 'md', d.md),
      lg: _doubleFromJson(json, 'lg', d.lg),
      xl: _doubleFromJson(json, 'xl', d.xl),
      xxl: _doubleFromJson(json, 'xxl', d.xxl),
    );
  }

  /// Resolve a spacing token name to a value.
  double? resolve(String name) => switch (name) {
    'xs' => xs,
    'sm' => sm,
    'md' => md,
    'lg' => lg,
    'xl' => xl,
    'xxl' => xxl,
    _ => null,
  };
}

/// M3 text style definition.
class SduiTextStyleDef {
  final double fontSize;
  final int fontWeight;
  final double lineHeight;
  final double? letterSpacing;

  const SduiTextStyleDef({
    required this.fontSize,
    required this.fontWeight,
    required this.lineHeight,
    this.letterSpacing,
  });

  factory SduiTextStyleDef.fromJson(Map<String, dynamic> json, SduiTextStyleDef defaults) {
    return SduiTextStyleDef(
      fontSize: _doubleFromJson(json, 'fontSize', defaults.fontSize),
      fontWeight: _intFromJson(json, 'fontWeight', defaults.fontWeight),
      lineHeight: _doubleFromJson(json, 'lineHeight', defaults.lineHeight),
      letterSpacing: json['letterSpacing'] is num
          ? (json['letterSpacing'] as num).toDouble()
          : defaults.letterSpacing,
    );
  }

  TextStyle toTextStyle({Color? color, String? fontFamily}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: _weight(fontWeight),
      height: lineHeight,
      letterSpacing: letterSpacing,
      color: color,
      fontFamily: fontFamily,
    );
  }

  static FontWeight _weight(int w) => switch (w) {
    100 => FontWeight.w100,
    200 => FontWeight.w200,
    300 => FontWeight.w300,
    400 => FontWeight.w400,
    500 => FontWeight.w500,
    600 => FontWeight.w600,
    700 => FontWeight.w700,
    800 => FontWeight.w800,
    900 => FontWeight.w900,
    _ => FontWeight.w400,
  };
}

/// Typography tokens — skeleton text styles + M3 TextTheme mapping.
class SduiTextStyleTokens {
  final SduiTextStyleDef headlineLarge;
  final SduiTextStyleDef headlineMedium;
  final SduiTextStyleDef headlineSmall;
  final SduiTextStyleDef bodyLarge;
  final SduiTextStyleDef bodyMedium;
  final SduiTextStyleDef bodySmall;
  final SduiTextStyleDef labelLarge;
  final SduiTextStyleDef labelSmall;
  final SduiTextStyleDef sectionHeader;
  final SduiTextStyleDef micro;

  // Aliases
  SduiTextStyleDef get h1 => headlineLarge;
  SduiTextStyleDef get h2 => headlineMedium;
  SduiTextStyleDef get h3 => headlineSmall;
  SduiTextStyleDef get body => bodyMedium;
  SduiTextStyleDef get bodyLg => bodyLarge;
  SduiTextStyleDef get label => labelLarge;

  const SduiTextStyleTokens({
    this.headlineLarge = const SduiTextStyleDef(fontSize: 24, fontWeight: 600, lineHeight: 1.25),
    this.headlineMedium = const SduiTextStyleDef(fontSize: 20, fontWeight: 600, lineHeight: 1.25),
    this.headlineSmall = const SduiTextStyleDef(fontSize: 16, fontWeight: 600, lineHeight: 1.25),
    this.bodyLarge = const SduiTextStyleDef(fontSize: 16, fontWeight: 400, lineHeight: 1.5),
    this.bodyMedium = const SduiTextStyleDef(fontSize: 14, fontWeight: 400, lineHeight: 1.5),
    this.bodySmall = const SduiTextStyleDef(fontSize: 12, fontWeight: 400, lineHeight: 1.5),
    this.labelLarge = const SduiTextStyleDef(fontSize: 14, fontWeight: 500, lineHeight: 1.5),
    this.labelSmall = const SduiTextStyleDef(fontSize: 12, fontWeight: 500, lineHeight: 1.5),
    this.sectionHeader = const SduiTextStyleDef(fontSize: 12, fontWeight: 600, lineHeight: 1.25, letterSpacing: 0.5),
    this.micro = const SduiTextStyleDef(fontSize: 8, fontWeight: 400, lineHeight: 1.5),
  });

  factory SduiTextStyleTokens.fromJson(Map<String, dynamic> json) {
    const d = SduiTextStyleTokens();
    SduiTextStyleDef _parse(String key, SduiTextStyleDef fallback) {
      final v = json[key];
      if (v is Map<String, dynamic>) return SduiTextStyleDef.fromJson(v, fallback);
      return fallback;
    }
    return SduiTextStyleTokens(
      headlineLarge: _parse('headlineLarge', d.headlineLarge),
      headlineMedium: _parse('headlineMedium', d.headlineMedium),
      headlineSmall: _parse('headlineSmall', d.headlineSmall),
      bodyLarge: _parse('bodyLarge', d.bodyLarge),
      bodyMedium: _parse('bodyMedium', d.bodyMedium),
      bodySmall: _parse('bodySmall', d.bodySmall),
      labelLarge: _parse('labelLarge', d.labelLarge),
      labelSmall: _parse('labelSmall', d.labelSmall),
      sectionHeader: _parse('sectionHeader', d.sectionHeader),
      micro: _parse('micro', d.micro),
    );
  }

  /// Resolve a text style name.
  SduiTextStyleDef? resolve(String name) => switch (name) {
    'headlineLarge' => headlineLarge,
    'headlineMedium' => headlineMedium,
    'headlineSmall' => headlineSmall,
    'bodyLarge' => bodyLarge,
    'bodyMedium' => bodyMedium,
    'bodySmall' => bodySmall,
    'labelLarge' => labelLarge,
    'labelSmall' => labelSmall,
    'sectionHeader' => sectionHeader,
    'micro' => micro,
    // Aliases
    'h1' => h1,
    'h2' => h2,
    'h3' => h3,
    'body' => body,
    'bodyLg' => bodyLg,
    'label' => label,
    _ => null,
  };

  TextTheme toTextTheme({String? fontFamily}) {
    return TextTheme(
      displayLarge: headlineLarge.toTextStyle(fontFamily: fontFamily),
      displayMedium: headlineMedium.toTextStyle(fontFamily: fontFamily),
      displaySmall: headlineLarge.toTextStyle(fontFamily: fontFamily),
      headlineLarge: headlineLarge.toTextStyle(fontFamily: fontFamily),
      headlineMedium: headlineMedium.toTextStyle(fontFamily: fontFamily),
      headlineSmall: headlineSmall.toTextStyle(fontFamily: fontFamily),
      titleLarge: headlineSmall.toTextStyle(fontFamily: fontFamily),
      titleMedium: headlineSmall.toTextStyle(fontFamily: fontFamily),
      titleSmall: labelLarge.toTextStyle(fontFamily: fontFamily),
      bodyLarge: bodyLarge.toTextStyle(fontFamily: fontFamily),
      bodyMedium: bodyMedium.toTextStyle(fontFamily: fontFamily),
      bodySmall: bodySmall.toTextStyle(fontFamily: fontFamily),
      labelLarge: labelLarge.toTextStyle(fontFamily: fontFamily),
      labelMedium: labelSmall.toTextStyle(fontFamily: fontFamily),
      labelSmall: labelSmall.toTextStyle(fontFamily: fontFamily),
    );
  }
}

/// Line weight tokens.
class SduiLineWeightTokens {
  final double subtle;
  final double standard;
  final double emphasis;
  final double vizGrid;
  final double vizAxis;
  final double vizData;
  final double vizHighlight;

  const SduiLineWeightTokens({
    this.subtle = 1.0,
    this.standard = 1.5,
    this.emphasis = 2.0,
    this.vizGrid = 1.0,
    this.vizAxis = 2.0,
    this.vizData = 2.0,
    this.vizHighlight = 3.0,
  });

  factory SduiLineWeightTokens.fromJson(Map<String, dynamic> json) {
    const d = SduiLineWeightTokens();
    return SduiLineWeightTokens(
      subtle: _doubleFromJson(json, 'subtle', d.subtle),
      standard: _doubleFromJson(json, 'standard', d.standard),
      emphasis: _doubleFromJson(json, 'emphasis', d.emphasis),
      vizGrid: _doubleFromJson(json, 'vizGrid', d.vizGrid),
      vizAxis: _doubleFromJson(json, 'vizAxis', d.vizAxis),
      vizData: _doubleFromJson(json, 'vizData', d.vizData),
      vizHighlight: _doubleFromJson(json, 'vizHighlight', d.vizHighlight),
    );
  }
}

/// Panel dimension tokens.
class SduiPanelTokens {
  final double width;
  final double minWidth;
  final double maxWidth;
  final double collapsedWidth;
  final double headerHeight;
  final double topBarHeight;

  const SduiPanelTokens({
    this.width = 280,
    this.minWidth = 280,
    this.maxWidth = 400,
    this.collapsedWidth = 48,
    this.headerHeight = 48,
    this.topBarHeight = 48,
  });

  factory SduiPanelTokens.fromJson(Map<String, dynamic> json) {
    const d = SduiPanelTokens();
    return SduiPanelTokens(
      width: _doubleFromJson(json, 'width', d.width),
      minWidth: _doubleFromJson(json, 'minWidth', d.minWidth),
      maxWidth: _doubleFromJson(json, 'maxWidth', d.maxWidth),
      collapsedWidth: _doubleFromJson(json, 'collapsedWidth', d.collapsedWidth),
      headerHeight: _doubleFromJson(json, 'headerHeight', d.headerHeight),
      topBarHeight: _doubleFromJson(json, 'topBarHeight', d.topBarHeight),
    );
  }
}

/// Button styling tokens — mirrors skeleton ElevatedButton/TextButton/OutlinedButton theme.
class SduiButtonTokens {
  final double paddingH;
  final double paddingV;
  final double borderRadius;
  final double outlinedBorderWidth;

  const SduiButtonTokens({
    this.paddingH = 16,
    this.paddingV = 8,
    this.borderRadius = 8,
    this.outlinedBorderWidth = 1.5,
  });

  factory SduiButtonTokens.fromJson(Map<String, dynamic> json) {
    const d = SduiButtonTokens();
    return SduiButtonTokens(
      paddingH: _doubleFromJson(json, 'paddingH', d.paddingH),
      paddingV: _doubleFromJson(json, 'paddingV', d.paddingV),
      borderRadius: _doubleFromJson(json, 'borderRadius', d.borderRadius),
      outlinedBorderWidth: _doubleFromJson(json, 'outlinedBorderWidth', d.outlinedBorderWidth),
    );
  }
}

/// Icon size tokens — consistent icon sizing across widgets.
class SduiIconSizeTokens {
  final double sm;
  final double md;
  final double lg;

  const SduiIconSizeTokens({
    this.sm = 16,
    this.md = 24,
    this.lg = 32,
  });

  factory SduiIconSizeTokens.fromJson(Map<String, dynamic> json) {
    const d = SduiIconSizeTokens();
    return SduiIconSizeTokens(
      sm: _doubleFromJson(json, 'sm', d.sm),
      md: _doubleFromJson(json, 'md', d.md),
      lg: _doubleFromJson(json, 'lg', d.lg),
    );
  }
}

/// Control height tokens.
class SduiControlHeightTokens {
  final double sm;
  final double md;
  final double lg;

  const SduiControlHeightTokens({
    this.sm = 28,
    this.md = 36,
    this.lg = 44,
  });

  factory SduiControlHeightTokens.fromJson(Map<String, dynamic> json) {
    const d = SduiControlHeightTokens();
    return SduiControlHeightTokens(
      sm: _doubleFromJson(json, 'sm', d.sm),
      md: _doubleFromJson(json, 'md', d.md),
      lg: _doubleFromJson(json, 'lg', d.lg),
    );
  }
}

/// Elevation tokens — Material elevation values (not CSS shadows).
class SduiElevationTokens {
  final double none;
  final double low;
  final double medium;
  final double high;

  const SduiElevationTokens({
    this.none = 0,
    this.low = 1,
    this.medium = 4,
    this.high = 8,
  });

  factory SduiElevationTokens.fromJson(Map<String, dynamic> json) {
    const d = SduiElevationTokens();
    return SduiElevationTokens(
      none: _doubleFromJson(json, 'none', d.none),
      low: _doubleFromJson(json, 'low', d.low),
      medium: _doubleFromJson(json, 'medium', d.medium),
      high: _doubleFromJson(json, 'high', d.high),
    );
  }
}

/// Legacy typography tokens — kept for backward compat.
/// Prefer [SduiTextStyleTokens] for new code.
class SduiTypographyTokens {
  final double bodySize;
  final double captionSize;
  final double titleSize;
  final double headingSize;

  const SduiTypographyTokens({
    this.bodySize = 14,
    this.captionSize = 12,
    this.titleSize = 16,
    this.headingSize = 20,
  });
}

/// Border radius tokens.
class SduiRadiusTokens {
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double full;

  const SduiRadiusTokens({
    this.sm = 4,
    this.md = 8,
    this.lg = 12,
    this.xl = 16,
    this.full = 9999,
  });

  factory SduiRadiusTokens.fromJson(Map<String, dynamic> json) {
    const d = SduiRadiusTokens();
    return SduiRadiusTokens(
      sm: _doubleFromJson(json, 'sm', d.sm),
      md: _doubleFromJson(json, 'md', d.md),
      lg: _doubleFromJson(json, 'lg', d.lg),
      xl: _doubleFromJson(json, 'xl', d.xl),
      full: _doubleFromJson(json, 'full', d.full),
    );
  }

  /// Resolve a radius token name.
  double? resolve(String name) => switch (name) {
    'sm' || 'small' => sm,
    'md' || 'medium' => md,
    'lg' || 'large' => lg,
    'xl' => xl,
    'full' => full,
    _ => null,
  };
}

/// Opacity tokens — alpha values for consistent transparency.
class SduiOpacityTokens {
  final int subtle;    // ~10% — status/error background tint
  final int light;     // ~30% — status/error borders
  final int disabled;  // ~38% — disabled icon overlay
  final int medium;    // ~50% — shadows, scrim
  final int strong;    // ~80% — error text on tinted background

  const SduiOpacityTokens({
    this.subtle = 25,
    this.light = 76,
    this.disabled = 97,
    this.medium = 127,
    this.strong = 204,
  });

  factory SduiOpacityTokens.fromJson(Map<String, dynamic> json) {
    const d = SduiOpacityTokens();
    return SduiOpacityTokens(
      subtle: _intFromJson(json, 'subtle', d.subtle),
      light: _intFromJson(json, 'light', d.light),
      disabled: _intFromJson(json, 'disabled', d.disabled),
      medium: _intFromJson(json, 'medium', d.medium),
      strong: _intFromJson(json, 'strong', d.strong),
    );
  }
}

/// Animation duration tokens.
class SduiAnimationTokens {
  final Duration fast;    // Button hover, focus transitions
  final Duration medium;  // Panel expand/collapse
  final Duration slow;    // Skeleton pulse half-cycle
  final Curve curve;      // Standard easing

  const SduiAnimationTokens({
    this.fast = const Duration(milliseconds: 150),
    this.medium = const Duration(milliseconds: 300),
    this.slow = const Duration(milliseconds: 600),
    this.curve = Curves.ease,
  });

  factory SduiAnimationTokens.fromJson(Map<String, dynamic> json) {
    const d = SduiAnimationTokens();
    return SduiAnimationTokens(
      fast: Duration(milliseconds: _intFromJson(json, 'fastMs', d.fast.inMilliseconds)),
      medium: Duration(milliseconds: _intFromJson(json, 'mediumMs', d.medium.inMilliseconds)),
      slow: Duration(milliseconds: _intFromJson(json, 'slowMs', d.slow.inMilliseconds)),
      // curve is not serializable — always use default
    );
  }
}

/// Window/header dimension tokens — mirrors skeleton WindowConstants + HeaderConstants.
class SduiWindowTokens {
  // Toolbar
  final double toolbarHeight;
  final double toolbarButtonSize;
  final double toolbarButtonIconSize;
  final double toolbarButtonRadius;
  final double toolbarButtonBorderWidth;
  final double toolbarGap;
  // Tabs (frame-level)
  final double tabHeight;
  final double tabStripHeight;
  final double tabMaxWidth;
  final double tabCornerRadius;
  final double tabBorderWidth;
  final double tabButtonSize;
  final double tabButtonIconSize;
  final double tabIconSize;
  final double tabIconRadius;
  final double tabFontSize;
  // Body state
  final double bodyStateIconSize;
  final double bodyStateMaxWidth;
  final double spinnerSize;
  final double spinnerStrokeWidth;
  final double minWidgetWidth;
  // Header
  final double headerChromeHeight;
  final double avatarSize;
  final double brandMarkMaxHeight;
  final double dropdownWidth;
  // Focus ring
  final double focusRingWidth;
  final double focusRingOffset;

  const SduiWindowTokens({
    this.toolbarHeight = 48,
    this.toolbarButtonSize = 32,
    this.toolbarButtonIconSize = 16,
    this.toolbarButtonRadius = 8,
    this.toolbarButtonBorderWidth = 1,
    this.toolbarGap = 8,
    this.tabHeight = 28,
    this.tabStripHeight = 32,
    this.tabMaxWidth = 220,
    this.tabCornerRadius = 6,
    this.tabBorderWidth = 2,
    this.tabButtonSize = 20,
    this.tabButtonIconSize = 11,
    this.tabIconSize = 8,
    this.tabIconRadius = 2,
    this.tabFontSize = 11,
    this.bodyStateIconSize = 32,
    this.bodyStateMaxWidth = 280,
    this.spinnerSize = 28,
    this.spinnerStrokeWidth = 3,
    this.minWidgetWidth = 208,
    this.headerChromeHeight = 36,
    this.avatarSize = 28,
    this.brandMarkMaxHeight = 28,
    this.dropdownWidth = 220,
    this.focusRingWidth = 2,
    this.focusRingOffset = 2,
  });

  factory SduiWindowTokens.fromJson(Map<String, dynamic> json) {
    const d = SduiWindowTokens();
    return SduiWindowTokens(
      toolbarHeight: _doubleFromJson(json, 'toolbarHeight', d.toolbarHeight),
      toolbarButtonSize: _doubleFromJson(json, 'toolbarButtonSize', d.toolbarButtonSize),
      toolbarButtonIconSize: _doubleFromJson(json, 'toolbarButtonIconSize', d.toolbarButtonIconSize),
      toolbarButtonRadius: _doubleFromJson(json, 'toolbarButtonRadius', d.toolbarButtonRadius),
      toolbarButtonBorderWidth: _doubleFromJson(json, 'toolbarButtonBorderWidth', d.toolbarButtonBorderWidth),
      toolbarGap: _doubleFromJson(json, 'toolbarGap', d.toolbarGap),
      tabHeight: _doubleFromJson(json, 'tabHeight', d.tabHeight),
      tabStripHeight: _doubleFromJson(json, 'tabStripHeight', d.tabStripHeight),
      tabMaxWidth: _doubleFromJson(json, 'tabMaxWidth', d.tabMaxWidth),
      tabCornerRadius: _doubleFromJson(json, 'tabCornerRadius', d.tabCornerRadius),
      tabBorderWidth: _doubleFromJson(json, 'tabBorderWidth', d.tabBorderWidth),
      tabButtonSize: _doubleFromJson(json, 'tabButtonSize', d.tabButtonSize),
      tabButtonIconSize: _doubleFromJson(json, 'tabButtonIconSize', d.tabButtonIconSize),
      tabIconSize: _doubleFromJson(json, 'tabIconSize', d.tabIconSize),
      tabIconRadius: _doubleFromJson(json, 'tabIconRadius', d.tabIconRadius),
      tabFontSize: _doubleFromJson(json, 'tabFontSize', d.tabFontSize),
      bodyStateIconSize: _doubleFromJson(json, 'bodyStateIconSize', d.bodyStateIconSize),
      bodyStateMaxWidth: _doubleFromJson(json, 'bodyStateMaxWidth', d.bodyStateMaxWidth),
      spinnerSize: _doubleFromJson(json, 'spinnerSize', d.spinnerSize),
      spinnerStrokeWidth: _doubleFromJson(json, 'spinnerStrokeWidth', d.spinnerStrokeWidth),
      minWidgetWidth: _doubleFromJson(json, 'minWidgetWidth', d.minWidgetWidth),
      headerChromeHeight: _doubleFromJson(json, 'headerChromeHeight', d.headerChromeHeight),
      avatarSize: _doubleFromJson(json, 'avatarSize', d.avatarSize),
      brandMarkMaxHeight: _doubleFromJson(json, 'brandMarkMaxHeight', d.brandMarkMaxHeight),
      dropdownWidth: _doubleFromJson(json, 'dropdownWidth', d.dropdownWidth),
      focusRingWidth: _doubleFromJson(json, 'focusRingWidth', d.focusRingWidth),
      focusRingOffset: _doubleFromJson(json, 'focusRingOffset', d.focusRingOffset),
    );
  }
}

/// Data table styling tokens (base-8 grid, 4px half-increments).
class SduiDataTableTokens {
  final double headerPaddingV;
  final double headerPaddingH;
  final double cellPaddingV;
  final double cellPaddingH;
  final double columnMinWidth;
  final double tableMinWidth;
  final double rowSeparatorWidth;  // lineSubtle (1.0)

  const SduiDataTableTokens({
    this.headerPaddingV = 8,
    this.headerPaddingH = 8,
    this.cellPaddingV = 4,
    this.cellPaddingH = 8,
    this.columnMinWidth = 140,
    this.tableMinWidth = 400,
    this.rowSeparatorWidth = 1.0,
  });

  factory SduiDataTableTokens.fromJson(Map<String, dynamic> json) {
    const d = SduiDataTableTokens();
    return SduiDataTableTokens(
      headerPaddingV: _doubleFromJson(json, 'headerPaddingV', d.headerPaddingV),
      headerPaddingH: _doubleFromJson(json, 'headerPaddingH', d.headerPaddingH),
      cellPaddingV: _doubleFromJson(json, 'cellPaddingV', d.cellPaddingV),
      cellPaddingH: _doubleFromJson(json, 'cellPaddingH', d.cellPaddingH),
      columnMinWidth: _doubleFromJson(json, 'columnMinWidth', d.columnMinWidth),
      tableMinWidth: _doubleFromJson(json, 'tableMinWidth', d.tableMinWidth),
      rowSeparatorWidth: _doubleFromJson(json, 'rowSeparatorWidth', d.rowSeparatorWidth),
    );
  }
}

/// Internal (content-level) tab tokens — visually subordinate to frame-level window tabs.
class SduiInternalTabTokens {
  final double height;
  final double paddingH;
  final double paddingV;
  final double iconSize;
  final double fontSize;
  final int fontWeightActive;   // w600
  final int fontWeightInactive; // w400
  final double activeBorderWidth; // lineEmphasis (2.0)
  final double cornerRadius;     // radiusSm (4)

  const SduiInternalTabTokens({
    this.height = 32,
    this.paddingH = 12,
    this.paddingV = 8,
    this.iconSize = 12,
    this.fontSize = 12,
    this.fontWeightActive = 600,
    this.fontWeightInactive = 400,
    this.activeBorderWidth = 2.0,
    this.cornerRadius = 4,
  });

  factory SduiInternalTabTokens.fromJson(Map<String, dynamic> json) {
    const d = SduiInternalTabTokens();
    return SduiInternalTabTokens(
      height: _doubleFromJson(json, 'height', d.height),
      paddingH: _doubleFromJson(json, 'paddingH', d.paddingH),
      paddingV: _doubleFromJson(json, 'paddingV', d.paddingV),
      iconSize: _doubleFromJson(json, 'iconSize', d.iconSize),
      fontSize: _doubleFromJson(json, 'fontSize', d.fontSize),
      fontWeightActive: _intFromJson(json, 'fontWeightActive', d.fontWeightActive),
      fontWeightInactive: _intFromJson(json, 'fontWeightInactive', d.fontWeightInactive),
      activeBorderWidth: _doubleFromJson(json, 'activeBorderWidth', d.activeBorderWidth),
      cornerRadius: _doubleFromJson(json, 'cornerRadius', d.cornerRadius),
    );
  }
}

/// Top-level SDUI theme with all token groups.
class SduiTheme {
  final SduiColorTokens colors;
  final SduiSpacingTokens spacing;
  final SduiTextStyleTokens textStyles;
  final SduiElevationTokens elevation;
  final SduiRadiusTokens radius;
  final SduiLineWeightTokens lineWeight;
  final SduiPanelTokens panel;
  final SduiControlHeightTokens controlHeight;
  final String fontFamily;
  final SduiWindowTokens window;
  final SduiOpacityTokens opacity;
  final SduiAnimationTokens animation;
  final SduiDataTableTokens dataTable;
  final SduiInternalTabTokens internalTab;
  final SduiButtonTokens button;
  final SduiIconSizeTokens iconSize;

  /// Legacy typography accessor — derives from textStyles for backward compat.
  SduiTypographyTokens get typography => SduiTypographyTokens(
    bodySize: textStyles.bodyMedium.fontSize,
    captionSize: textStyles.bodySmall.fontSize,
    titleSize: textStyles.headlineSmall.fontSize,
    headingSize: textStyles.headlineMedium.fontSize,
  );

  const SduiTheme({
    required this.colors,
    this.spacing = const SduiSpacingTokens(),
    this.textStyles = const SduiTextStyleTokens(),
    this.elevation = const SduiElevationTokens(),
    this.radius = const SduiRadiusTokens(),
    this.lineWeight = const SduiLineWeightTokens(),
    this.panel = const SduiPanelTokens(),
    this.controlHeight = const SduiControlHeightTokens(),
    this.fontFamily = 'Fira Sans',
    this.window = const SduiWindowTokens(),
    this.opacity = const SduiOpacityTokens(),
    this.animation = const SduiAnimationTokens(),
    this.dataTable = const SduiDataTableTokens(),
    this.internalTab = const SduiInternalTabTokens(),
    this.button = const SduiButtonTokens(),
    this.iconSize = const SduiIconSizeTokens(),
  });

  /// Create a theme from tokens.json.
  /// [json] is the full tokens.json content.
  /// [themeName] selects which color theme to use ('light' or 'dark').
  factory SduiTheme.fromJson(Map<String, dynamic> json, {String themeName = 'light'}) {
    // Pick the right defaults to fall back on
    final defaults = themeName == 'dark'
        ? const SduiTheme.dark()
        : const SduiTheme.light();

    // Colors live under themes.<name>.colors
    final themes = json['themes'] as Map<String, dynamic>? ?? {};
    final themeData = themes[themeName] as Map<String, dynamic>? ?? {};
    final colorsJson = themeData['colors'] as Map<String, dynamic>? ?? {};

    final colors = SduiColorTokens.fromJson(colorsJson, defaults.colors);

    // Top-level token groups
    final spacingJson = json['spacing'] as Map<String, dynamic>? ?? {};
    final textStylesJson = json['textStyles'] as Map<String, dynamic>? ?? {};
    final radiusJson = json['radius'] as Map<String, dynamic>? ?? {};
    final lineWeightJson = json['lineWeight'] as Map<String, dynamic>? ?? {};
    final panelJson = json['panel'] as Map<String, dynamic>? ?? {};
    final controlHeightJson = json['controlHeight'] as Map<String, dynamic>? ?? {};
    final elevationJson = json['elevation'] as Map<String, dynamic>? ?? {};
    final buttonJson = json['button'] as Map<String, dynamic>? ?? {};
    final iconSizeJson = json['iconSize'] as Map<String, dynamic>? ?? {};
    final windowJson = json['window'] as Map<String, dynamic>? ?? {};
    final opacityJson = json['opacity'] as Map<String, dynamic>? ?? {};
    final animationJson = json['animation'] as Map<String, dynamic>? ?? {};
    final dataTableJson = json['dataTable'] as Map<String, dynamic>? ?? {};
    final internalTabJson = json['internalTab'] as Map<String, dynamic>? ?? {};

    return SduiTheme(
      colors: colors,
      spacing: SduiSpacingTokens.fromJson(spacingJson),
      textStyles: SduiTextStyleTokens.fromJson(textStylesJson),
      elevation: SduiElevationTokens.fromJson(elevationJson),
      radius: SduiRadiusTokens.fromJson(radiusJson),
      lineWeight: SduiLineWeightTokens.fromJson(lineWeightJson),
      panel: SduiPanelTokens.fromJson(panelJson),
      controlHeight: SduiControlHeightTokens.fromJson(controlHeightJson),
      fontFamily: json['fontFamily'] as String? ?? defaults.fontFamily,
      window: SduiWindowTokens.fromJson(windowJson),
      opacity: SduiOpacityTokens.fromJson(opacityJson),
      animation: SduiAnimationTokens.fromJson(animationJson),
      dataTable: SduiDataTableTokens.fromJson(dataTableJson),
      internalTab: SduiInternalTabTokens.fromJson(internalTabJson),
      button: SduiButtonTokens.fromJson(buttonJson),
      iconSize: SduiIconSizeTokens.fromJson(iconSizeJson),
    );
  }

  /// Light theme — default.
  const SduiTheme.light()
      : colors = const SduiColorTokens(
          primary: Color(0xFF1E40AF),
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFDBEAFE),
          onPrimaryContainer: Color(0xFF1E3A8A),
          secondary: Color(0xFF2563EB),
          onSecondary: Color(0xFFFFFFFF),
          secondaryContainer: Color(0xFFDBEAFE),
          onSecondaryContainer: Color(0xFF1E40AF),
          tertiary: Color(0xFF6D28D9),
          onTertiary: Color(0xFFFFFFFF),
          tertiaryContainer: Color(0xFFEDE9FE),
          onTertiaryContainer: Color(0xFF6D28D9),
          error: Color(0xFFB91C1C),
          onError: Color(0xFFFFFFFF),
          errorContainer: Color(0xFFFEE2E2),
          onErrorContainer: Color(0xFFB91C1C),
          background: Color(0xFFF3F4F6),
          onBackground: Color(0xFF111827),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF111827),
          onSurfaceVariant: Color(0xFF374151),
          onSurfaceMuted: Color(0xFF6B7280),
          onSurfaceDisabled: Color(0xFF9CA3AF),
          surfaceContainerLowest: Color(0xFFFFFFFF),
          surfaceContainerLow: Color(0xFFF9FAFB),
          surfaceContainer: Color(0xFFF3F4F6),
          surfaceContainerHigh: Color(0xFFE5E7EB),
          surfaceContainerHighest: Color(0xFFD1D5DB),
          outline: Color(0xFFD1D5DB),
          outlineVariant: Color(0xFFE5E7EB),
          inverseSurface: Color(0xFF111827),
          onInverseSurface: Color(0xFFF9FAFB),
          inversePrimary: Color(0xFF93C5FD),
          scrim: Color(0xFF000000),
          shadow: Color(0xFF000000),
          warning: Color(0xFFB45309),
          onWarning: Color(0xFFFFFFFF),
          warningContainer: Color(0xFFFEF3C7),
          onWarningContainer: Color(0xFFB45309),
          success: Color(0xFF047857),
          onSuccess: Color(0xFFFFFFFF),
          successContainer: Color(0xFFD1FAE5),
          onSuccessContainer: Color(0xFF047857),
          info: Color(0xFF0E7490),
          onInfo: Color(0xFFFFFFFF),
          infoContainer: Color(0xFFCFFAFE),
          onInfoContainer: Color(0xFF0E7490),
          link: Color(0xFF2563EB),
          linkHover: Color(0xFF1E40AF),
          panelBg: Color(0xFFF9FAFB),
          textTertiary: Color(0xFF4B5563),
          primaryBg: Color(0xFFEFF6FF),
        ),
        spacing = const SduiSpacingTokens(),
        textStyles = const SduiTextStyleTokens(),
        elevation = const SduiElevationTokens(),
        radius = const SduiRadiusTokens(),
        lineWeight = const SduiLineWeightTokens(),
        panel = const SduiPanelTokens(),
        controlHeight = const SduiControlHeightTokens(),
        fontFamily = 'Fira Sans',
        window = const SduiWindowTokens(),
        opacity = const SduiOpacityTokens(),
        animation = const SduiAnimationTokens(),
        dataTable = const SduiDataTableTokens(),
        internalTab = const SduiInternalTabTokens(),
        button = const SduiButtonTokens(),
        iconSize = const SduiIconSizeTokens();

  /// Dark theme.
  const SduiTheme.dark()
      : colors = const SduiColorTokens(
          primary: Color(0xFF14B8A6),
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFF153D47),
          onPrimaryContainer: Color(0xFF2DD4BF),
          secondary: Color(0xFF2DD4BF),
          onSecondary: Color(0xFF111827),
          secondaryContainer: Color(0xFF153D47),
          onSecondaryContainer: Color(0xFF2DD4BF),
          tertiary: Color(0xFFA78BFA),
          onTertiary: Color(0xFF0F172A),
          tertiaryContainer: Color(0xFF2E1065),
          onTertiaryContainer: Color(0xFFA78BFA),
          error: Color(0xFFF87171),
          onError: Color(0xFFFFFFFF),
          errorContainer: Color(0xFF450A0A),
          onErrorContainer: Color(0xFFF87171),
          background: Color(0xFF0A0A0A),
          onBackground: Color(0xFFF9FAFB),
          surface: Color(0xFF111827),
          onSurface: Color(0xFFF9FAFB),
          onSurfaceVariant: Color(0xFFE5E7EB),
          onSurfaceMuted: Color(0xFF6B7280),
          onSurfaceDisabled: Color(0xFF4B5563),
          surfaceContainerLowest: Color(0xFF0A0A0A),
          surfaceContainerLow: Color(0xFF111827),
          surfaceContainer: Color(0xFF1F2937),
          surfaceContainerHigh: Color(0xFF1F2937),
          surfaceContainerHighest: Color(0xFF374151),
          outline: Color(0xFF374151),
          outlineVariant: Color(0xFF374151),
          inverseSurface: Color(0xFFF9FAFB),
          onInverseSurface: Color(0xFF111827),
          inversePrimary: Color(0xFF0D9488),
          scrim: Color(0xFF000000),
          shadow: Color(0xFF000000),
          warning: Color(0xFFFBBF24),
          onWarning: Color(0xFF111827),
          warningContainer: Color(0xFF451A03),
          onWarningContainer: Color(0xFFFBBF24),
          success: Color(0xFF10B981),
          onSuccess: Color(0xFF111827),
          successContainer: Color(0xFF14532D),
          onSuccessContainer: Color(0xFF4ADE80),
          info: Color(0xFF60A5FA),
          onInfo: Color(0xFF111827),
          infoContainer: Color(0xFF083344),
          onInfoContainer: Color(0xFF67E8F9),
          link: Color(0xFF60A5FA),
          linkHover: Color(0xFF3B82F6),
          panelBg: Color(0xFF111827),
          textTertiary: Color(0xFF9CA3AF),
          primaryBg: Color(0xFF122E35),
        ),
        spacing = const SduiSpacingTokens(),
        textStyles = const SduiTextStyleTokens(),
        elevation = const SduiElevationTokens(),
        radius = const SduiRadiusTokens(),
        lineWeight = const SduiLineWeightTokens(),
        panel = const SduiPanelTokens(),
        controlHeight = const SduiControlHeightTokens(),
        fontFamily = 'Fira Sans',
        window = const SduiWindowTokens(),
        opacity = const SduiOpacityTokens(),
        animation = const SduiAnimationTokens(),
        dataTable = const SduiDataTableTokens(),
        internalTab = const SduiInternalTabTokens(),
        button = const SduiButtonTokens(),
        iconSize = const SduiIconSizeTokens();

  /// Convert to Flutter's MaterialApp ThemeData.
  ThemeData toMaterialTheme() {
    final isDark = colors.background.computeLuminance() < 0.5;
    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      fontFamily: fontFamily,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: colors.primary,
        onPrimary: colors.onPrimary,
        primaryContainer: colors.primaryContainer,
        onPrimaryContainer: colors.onPrimaryContainer,
        secondary: colors.secondary,
        onSecondary: colors.onSecondary,
        secondaryContainer: colors.secondaryContainer,
        onSecondaryContainer: colors.onSecondaryContainer,
        tertiary: colors.tertiary,
        onTertiary: colors.onTertiary,
        tertiaryContainer: colors.tertiaryContainer,
        onTertiaryContainer: colors.onTertiaryContainer,
        error: colors.error,
        onError: colors.onError,
        errorContainer: colors.errorContainer,
        onErrorContainer: colors.onErrorContainer,
        surface: colors.surface,
        onSurface: colors.onSurface,
        onSurfaceVariant: colors.onSurfaceVariant,
        surfaceContainerLowest: colors.surfaceContainerLowest,
        surfaceContainerLow: colors.surfaceContainerLow,
        surfaceContainer: colors.surfaceContainer,
        surfaceContainerHigh: colors.surfaceContainerHigh,
        surfaceContainerHighest: colors.surfaceContainerHighest,
        outline: colors.outline,
        outlineVariant: colors.outlineVariant,
        inverseSurface: colors.inverseSurface,
        onInverseSurface: colors.onInverseSurface,
        inversePrimary: colors.inversePrimary,
        scrim: colors.scrim,
        shadow: colors.shadow,
      ),
      scaffoldBackgroundColor: colors.background,
      dividerColor: colors.outlineVariant,
      hintColor: colors.onSurfaceMuted,
      textTheme: textStyles.toTextTheme(fontFamily: fontFamily),
      useMaterial3: true,
      // Approved component themes (from tercen-style/testboard-controls)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          padding: EdgeInsets.symmetric(horizontal: button.paddingH, vertical: button.paddingV),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(button.borderRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.primary, width: button.outlinedBorderWidth),
          padding: EdgeInsets.symmetric(horizontal: button.paddingH, vertical: button.paddingV),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(button.borderRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          padding: EdgeInsets.symmetric(horizontal: button.paddingH, vertical: button.paddingV),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(button.borderRadius),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(colors.onPrimary),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return isDark ? colors.surfaceContainerHighest : colors.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return colors.surface;
        }),
        checkColor: WidgetStateProperty.all(colors.onPrimary),
        side: BorderSide(color: colors.outline, width: button.outlinedBorderWidth),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.sm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: BorderSide(color: colors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: BorderSide(color: colors.primary, width: button.outlinedBorderWidth),
        ),
        isDense: true,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          iconSize: iconSize.md,
          minimumSize: Size(window.toolbarButtonSize, window.toolbarButtonSize),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(window.toolbarButtonRadius),
          ),
        ),
      ),
      iconTheme: IconThemeData(
        size: iconSize.md,
        color: colors.onSurface,
      ),
    );
  }
}
