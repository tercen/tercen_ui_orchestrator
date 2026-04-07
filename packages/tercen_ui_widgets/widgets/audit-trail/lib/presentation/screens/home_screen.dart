import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_line_weights.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/content_state.dart';
import '../providers/audit_trail_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/audit_toolbar.dart';
import '../widgets/body_states/loading_state.dart';
import '../widgets/body_states/empty_state.dart';
import '../widgets/body_states/error_state.dart';
import '../widgets/event_list.dart';

/// Main screen for the Audit Trail window.
///
/// Spec Section 3.2-3.3: four body states, toolbar at top,
/// master-detail horizontal split in active state.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<AuditTrailProvider>();

    return Scaffold(
      body: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: WindowConstants.minWidgetWidth,
        ),
        child: Column(
          children: [
            // ── Mock tab bar (dev convenience only) ──
            _MockTabBar(isDark: isDark),
            // ── Widget content ──
            Expanded(
              child: Container(
                color: isDark ? AppColorsDark.background : AppColors.surface,
                child: Focus(
                  autofocus: true,
                  onKeyEvent: (node, event) {
                    return provider.handleKeyEvent(event);
                  },
                  child: Column(
                    children: [
                      // Toolbar — always visible
                      const AuditToolbar(),
                      Divider(
                        height: AppLineWeights.lineSubtle,
                        thickness: AppLineWeights.lineSubtle,
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.5),
                      ),
                      // Body — switches on content state
                      Expanded(
                        child: _buildBody(context, provider),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AuditTrailProvider provider) {
    switch (provider.contentState) {
      case ContentState.loading:
        return const LoadingState(message: 'Loading audit trail...');

      case ContentState.empty:
        return EmptyState(
          icon: FontAwesomeIcons.clipboardList,
          message: 'No events found',
          detail: 'Select a scope to view audit events',
        );

      case ContentState.error:
        return ErrorState(
          message: provider.errorMessage ?? 'An error occurred',
          onRetry: () => provider.retry(),
        );

      case ContentState.active:
        return _buildActiveContent(context);
    }
  }

  Widget _buildActiveContent(BuildContext context) {
    return const EventList();
  }
}

/// Mock-only tab bar at the top of the screen.
/// Contains an "Audit Trail" tab indicator and a light/dark theme toggle.
/// NOT a real widget control — exists for standalone testing only.
class _MockTabBar extends StatelessWidget {
  final bool isDark;

  const _MockTabBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final provider = context.watch<AuditTrailProvider>();
    final tabColor = provider.identity.typeColor;
    final bgColor = isDark ? AppColorsDark.surface : AppColors.neutral100;
    final borderColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;
    final primaryColor = isDark ? AppColorsDark.primary : AppColors.primary;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          // Mock tab indicator
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: primaryColor, width: 2.0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tabColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Audit Trail',
                  style: AppTextStyles.labelSmall.copyWith(color: textColor),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Mock label
          Text(
            'MOCK',
            style: AppTextStyles.bodySmall.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Theme toggle
          Tooltip(
            message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            child: GestureDetector(
              onTap: () => themeProvider.toggleTheme(),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: FaIcon(
                  isDark
                      ? FontAwesomeIcons.solidSun
                      : FontAwesomeIcons.solidMoon,
                  size: 14,
                  color: mutedColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
