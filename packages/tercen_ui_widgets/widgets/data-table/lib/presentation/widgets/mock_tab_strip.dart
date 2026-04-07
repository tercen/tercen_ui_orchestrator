import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/tab_type_icon.dart';
import '../providers/data_table_provider.dart';
import '../providers/theme_provider.dart';

/// Inert mock tab strip rendered above the toolbar.
///
/// Shows a single "Data" tab with a yellow TabTypeIcon square,
/// plus mock-only controls on the right: Simulate Refresh and theme toggle.
class MockTabStrip extends StatelessWidget {
  const MockTabStrip({super.key});

  static const Color _typeColor = Color(0xFFF59E0B); // warning/data yellow

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();

    final stripBg = isDark
        ? AppColorsDark.surfaceElevated
        : AppColors.neutral200;
    final tabBg = isDark
        ? AppColorsDark.surface
        : AppColors.surface;
    final textColor = isDark
        ? AppColorsDark.textPrimary
        : AppColors.textPrimary;
    final mutedColor = isDark
        ? AppColorsDark.textMuted
        : AppColors.textMuted;

    return Container(
      height: WindowConstants.tabStripHeight,
      color: stripBg,
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        top: 4,
        right: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Tab
          Align(
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
                    'Data',
                    style: TextStyle(
                      fontSize: WindowConstants.tabFontSize,
                      fontWeight: WindowConstants.tabWeightFocused,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Mock-only controls
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Simulate Refresh (mock-only)
                GestureDetector(
                  onTap: () =>
                      context.read<DataTableProvider>().simulateRefresh(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Tooltip(
                      message: 'Simulate Refresh (mock)',
                      child: FaIcon(
                        FontAwesomeIcons.arrowsRotate,
                        size: 13,
                        color: mutedColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Theme toggle (mock-only)
                GestureDetector(
                  onTap: () => themeProvider.toggleTheme(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Tooltip(
                      message: isDark
                          ? 'Switch to light mode'
                          : 'Switch to dark mode',
                      child: FaIcon(
                        isDark
                            ? FontAwesomeIcons.sun
                            : FontAwesomeIcons.moon,
                        size: 13,
                        color: mutedColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
