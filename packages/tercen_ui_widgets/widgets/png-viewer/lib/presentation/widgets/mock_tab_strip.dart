import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/tab_type_icon.dart';

/// Inert mock tab strip rendered above the toolbar.
///
/// Purely visual — no click handling. Shows a single "PNG Viewer" tab
/// with a green TabTypeIcon square and a theme toggle on the right.
class MockTabStrip extends StatelessWidget {
  final VoidCallback? onToggleTheme;
  final bool isDark;

  const MockTabStrip({
    super.key,
    this.onToggleTheme,
    this.isDark = false,
  });

  // Window type colour — matches visualization type from identity.
  static const Color _typeColor = Color(0xFF66FF7F);

  @override
  Widget build(BuildContext context) {
    final dark = isDark;

    final stripBg = dark
        ? AppColorsDark.surfaceElevated
        : AppColors.neutral200;
    final tabBg = dark
        ? AppColorsDark.surface
        : AppColors.surface;
    final textColor = dark
        ? AppColorsDark.textPrimary
        : AppColors.textPrimary;
    final mutedColor = dark
        ? AppColorsDark.textMuted
        : AppColors.textMuted;

    return Container(
      height: WindowConstants.tabStripHeight,
      color: stripBg,
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        top: 4,
      ),
      alignment: Alignment.bottomLeft,
      child: Row(
        children: [
          Container(
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
                  'PNG Viewer',
                  style: TextStyle(
                    fontSize: WindowConstants.tabFontSize,
                    fontWeight: WindowConstants.tabWeightFocused,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Theme toggle (dev convenience only)
          if (onToggleTheme != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Tooltip(
                message:
                    dark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                child: GestureDetector(
                  onTap: onToggleTheme,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: FaIcon(
                      dark
                          ? FontAwesomeIcons.solidSun
                          : FontAwesomeIcons.solidMoon,
                      size: 14,
                      color: mutedColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
