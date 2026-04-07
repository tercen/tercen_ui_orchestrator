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
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/body_states/active_state.dart';
import '../widgets/body_states/loading_state.dart';
import '../widgets/body_states/empty_state.dart';
import '../widgets/body_states/error_state.dart';
import '../widgets/history_popover.dart';
import '../widgets/window_shell.dart';
import '../widgets/window_toolbar.dart';

/// Chat Box home screen.
///
/// Mock tab bar (top, mock-only convenience) + theme toggle.
/// Toolbar: [New Session icon] ... spacer ... [History]
/// Body: routes to Loading / Empty / Active / Error based on content state.
/// Primary colour border around the chat area.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().initialize();
    });
  }

  List<ToolbarAction> _toolbarActions(ChatProvider provider) => [
        ToolbarAction(
          icon: FontAwesomeIcons.plus,
          tooltip: 'New Session',
          isPrimary: true,
          onPressed: () => provider.createNewSession(),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<ChatProvider>();
    return Scaffold(
      body: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: WindowConstants.minWidgetWidth,
        ),
        child: Column(
          children: [
            // ── Mock tab bar (mock convenience only) ──
            _MockTabBar(isDark: isDark),
            // ── Primary-bordered chat area ──
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF181A20) : Colors.white,
                child: Column(
                  children: [
                    // Toolbar: [New Session] ... [History]
                    WindowToolbar(
                      actions: _toolbarActions(provider),
                      trailing: const HistoryPopoverButton(),
                    ),
                    Divider(
                      height: AppLineWeights.lineSubtle,
                      thickness: AppLineWeights.lineSubtle,
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.5),
                    ),
                    // Body state routing
                    Expanded(
                      child: _buildBody(provider),
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

  Widget _buildBody(ChatProvider provider) {
    switch (provider.contentState) {
      case ContentState.loading:
        return const LoadingState(message: 'Loading chat...');
      case ContentState.empty:
        return EmptyState(
          icon: FontAwesomeIcons.comments,
          message: 'Start a conversation',
          detail: 'Ask a question or give an instruction',
          actionLabel: 'New Chat',
          onAction: () => provider.createNewSession(),
        );
      case ContentState.active:
        return const ActiveState();
      case ContentState.error:
        return ErrorState(
          message: provider.errorMessage ?? 'An error occurred',
          onRetry: () => provider.initialize(),
        );
    }
  }
}

/// Mock-only tab bar at the top of the screen.
/// Contains a "Chat" tab indicator and a light/dark theme toggle.
/// NOT a real widget control — exists for standalone testing only.
class _MockTabBar extends StatelessWidget {
  final bool isDark;

  const _MockTabBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final provider = context.watch<ChatProvider>();
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
                  'Chat',
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
