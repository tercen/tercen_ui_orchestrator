import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_colors_dark.dart';

/// Resolves pane-specific colors based on the current brightness.
///
/// Use `PaneColors.of(context)` to get the correct colors for the
/// current theme mode. All pane widgets should use this instead of
/// referencing AppColors or AppColorsDark directly.
class PaneColors {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color borderSubtle;
  final Color border;
  final Color primary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color error;
  final Color errorLight;
  final Color textTertiary;
  final Color primaryBg;

  const PaneColors._({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.borderSubtle,
    required this.border,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.error,
    required this.errorLight,
    required this.textTertiary,
    required this.primaryBg,
  });

  static PaneColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const PaneColors._(
        background: AppColorsDark.background,
        surface: AppColorsDark.surface,
        surfaceElevated: AppColorsDark.surfaceElevated,
        borderSubtle: AppColorsDark.borderSubtle,
        border: AppColorsDark.border,
        primary: AppColorsDark.primary,
        textPrimary: AppColorsDark.textPrimary,
        textSecondary: AppColorsDark.textSecondary,
        textMuted: AppColorsDark.textMuted,
        error: AppColorsDark.error,
        errorLight: Color(0xFF3B1515), // dark error background
        textTertiary: AppColorsDark.textTertiary,
        primaryBg: AppColorsDark.primaryBg,
      );
    }
    return const PaneColors._(
      background: AppColors.background,
      surface: AppColors.surface,
      surfaceElevated: AppColors.surfaceElevated,
      borderSubtle: AppColors.borderSubtle,
      border: AppColors.border,
      primary: AppColors.primary,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      textMuted: AppColors.textMuted,
      error: AppColors.error,
      errorLight: AppColors.errorLight,
      textTertiary: AppColors.textTertiary,
      primaryBg: AppColors.primaryBg,
    );
  }
}
