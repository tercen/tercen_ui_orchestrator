import 'package:flutter/material.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/tab_type_icon.dart';

/// Inert mock tab strip rendered above the toolbar.
///
/// Purely visual — no click handling. Shows a single "Workflow" tab
/// with a green TabTypeIcon square.
class MockTabStrip extends StatelessWidget {
  const MockTabStrip({super.key});

  // Window 3 = green colour from Tercen logo palette
  static const Color _typeColor = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final stripBg = isDark
        ? AppColorsDark.surfaceElevated
        : AppColors.neutral200;
    final tabBg = isDark
        ? AppColorsDark.surface
        : AppColors.surface;
    final textColor = isDark
        ? AppColorsDark.textPrimary
        : AppColors.textPrimary;

    return Container(
      height: WindowConstants.tabStripHeight,
      color: stripBg,
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        top: 4,
      ),
      alignment: Alignment.bottomLeft,
      child: Container(
        height: WindowConstants.tabHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: tabBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(WindowConstants.tabCornerRadius),
            topRight: Radius.circular(WindowConstants.tabCornerRadius),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TabTypeIcon(color: _typeColor),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Workflow',
              style: TextStyle(
                fontSize: WindowConstants.tabFontSize,
                fontWeight: WindowConstants.tabWeightFocused,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
