import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_line_weights.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/home_panel_provider.dart';
import 'dashboard_card.dart';

/// Quick Actions Card: left column, bottom row.
/// Three action buttons: New Project, Teams, Audit.
/// Spec section 2.6.4.
class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<HomePanelProvider>();

    return DashboardCard(
      title: 'Quick Actions',
      titleIcon: FontAwesomeIcons.bolt,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          _ActionButton(
            icon: FontAwesomeIcons.folderPlus,
            label: 'New Project',
            onTap: provider.createProject,
          ),
          _ActionButton(
            icon: FontAwesomeIcons.users,
            label: 'Teams',
            onTap: provider.openTeamManagement,
          ),
          _ActionButton(
            icon: FontAwesomeIcons.clipboardList,
            label: 'Audit',
            onTap: provider.openAuditTrail,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final bg = _hovered
        ? (isDark ? AppColorsDark.primarySurface : AppColors.primarySurface)
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(
              color: primary,
              width: AppLineWeights.lineStandard,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(widget.icon, size: 14, color: primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                widget.label,
                style: AppTextStyles.labelSmall.copyWith(color: primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
