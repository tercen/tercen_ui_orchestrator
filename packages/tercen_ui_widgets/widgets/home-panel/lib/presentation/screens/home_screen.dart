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
import '../providers/home_panel_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/body_states/error_state.dart';
import '../widgets/body_states/loading_state.dart';
import '../widgets/cards/featured_apps_card.dart';
import '../widgets/cards/help_docs_card.dart';
import '../widgets/cards/recent_activity_card.dart';
import '../widgets/cards/recent_projects_card.dart';
import '../widgets/new_project_dialog.dart';
import '../widgets/window_toolbar.dart';

/// Main screen for the Home Panel window.
///
/// Toolbar: Refresh + Quick Action buttons (New Project, Teams, Audit).
/// Body: Welcome card, then 4-card grid.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<HomePanelProvider>();

    return Scaffold(
      body: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: WindowConstants.minWidgetWidth,
        ),
        child: Column(
          children: [
            // Mock tab bar (dev convenience only)
            _MockTabBar(isDark: isDark),
            // Widget content
            Expanded(
              child: Container(
                color: isDark ? AppColorsDark.background : AppColors.panelBackground,
                child: Column(
                  children: [
                    // Toolbar: Quick Actions only
                    WindowToolbar(
                      actions: [
                        ToolbarAction(
                          icon: FontAwesomeIcons.plus,
                          tooltip: 'New Project',
                          label: 'New Project',
                          onPressed: () async {
                            final teams = provider.user?.teams ?? [];
                            if (teams.isEmpty) return;
                            final result = await showNewProjectDialog(
                              context,
                              teams: teams,
                            );
                            if (result != null) {
                              provider.createProject(
                                name: result.name,
                                description: result.description,
                                teamId: result.teamId,
                                isPublic: result.isPublic,
                                gitUrl: result.gitUrl,
                                gitBranch: result.gitBranch,
                                gitCommit: result.gitCommit,
                                gitTag: result.gitTag,
                                gitToken: result.gitToken,
                              );
                            }
                          },
                        ),
                        ToolbarAction(
                          icon: FontAwesomeIcons.users,
                          tooltip: 'Teams',
                          label: 'Teams',
                          onPressed: () => provider.openTeamManagement(),
                        ),
                        ToolbarAction(
                          icon: FontAwesomeIcons.clipboardList,
                          tooltip: 'Audit',
                          label: 'Audit',
                          onPressed: () => provider.openAuditTrail(),
                        ),
                      ],
                    ),
                    Divider(
                      height: AppLineWeights.lineSubtle,
                      thickness: AppLineWeights.lineSubtle,
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.5),
                    ),
                    // Body: switches on content state
                    Expanded(
                      child: _buildBody(context, provider),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HomePanelProvider provider) {
    switch (provider.contentState) {
      case ContentState.loading:
        return const LoadingState(message: 'Loading...');

      case ContentState.empty:
        return const LoadingState(message: 'Loading...');

      case ContentState.error:
        return ErrorState(
          message: provider.errorMessage ?? 'An error occurred',
          onRetry: () => provider.retry(),
        );

      case ContentState.active:
        return _buildDashboard(context);
    }
  }

  Widget _buildDashboard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDoubleColumn = constraints.maxWidth >= 600;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            top: AppSpacing.sm,
            bottom: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (useDoubleColumn) ...[
                // Top row: Recent Projects + Featured Apps
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Expanded(child: RecentProjectsCard()),
                      SizedBox(width: AppSpacing.md),
                      Expanded(child: FeaturedAppsCard()),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Bottom row: Help & Docs + Recent Activity
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Expanded(child: HelpDocsCard()),
                      SizedBox(width: AppSpacing.md),
                      Expanded(child: RecentActivityCard()),
                    ],
                  ),
                ),
              ] else ...[
                // Single column stack
                const RecentProjectsCard(),
                const SizedBox(height: AppSpacing.md),
                const FeaturedAppsCard(),
                const SizedBox(height: AppSpacing.md),
                const HelpDocsCard(),
                const SizedBox(height: AppSpacing.md),
                const RecentActivityCard(),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Mock-only tab bar at the top of the screen.
class _MockTabBar extends StatelessWidget {
  final bool isDark;

  const _MockTabBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final provider = context.watch<HomePanelProvider>();
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
                    gradient: tabColor == Colors.transparent
                        ? const LinearGradient(
                            colors: [
                              Color(0xFF10B981),
                              Color(0xFF3B82F6),
                              Color(0xFFF59E0B),
                              Color(0xFFEF4444),
                            ],
                          )
                        : null,
                    color: tabColor == Colors.transparent ? null : tabColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Home, ${provider.user?.displayName ?? ""}',
                  style: AppTextStyles.labelSmall.copyWith(color: textColor),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'MOCK',
            style: AppTextStyles.bodySmall.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
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
