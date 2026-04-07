import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_line_weights.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/models/home_models.dart';
import '../../providers/home_panel_provider.dart';
import 'dashboard_card.dart';

class RecentActivityCard extends StatefulWidget {
  const RecentActivityCard({super.key});

  @override
  State<RecentActivityCard> createState() => _RecentActivityCardState();
}

class _RecentActivityCardState extends State<RecentActivityCard> {
  bool _showSearch = false;
  final _searchController = TextEditingController();
  int _pageSize = 10;
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<HomePanelProvider>();
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final trackColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;
    final iconColor =
        isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;

    if (provider.activityLoading) {
      return DashboardCard(
        title: 'Recent Activity',
        titleIcon: FontAwesomeIcons.clockRotateLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: AppLineWeights.lineEmphasis,
                valueColor: AlwaysStoppedAnimation<Color>(primary),
                backgroundColor: trackColor,
              ),
            ),
          ),
        ),
      );
    }

    final allActivities = provider.activities;
    final filtered = _filter.isEmpty
        ? allActivities
        : allActivities
            .where((a) =>
                a.objectName.toLowerCase().contains(_filter.toLowerCase()) ||
                a.user.toLowerCase().contains(_filter.toLowerCase()) ||
                a.projectName.toLowerCase().contains(_filter.toLowerCase()) ||
                a.type.toLowerCase().contains(_filter.toLowerCase()))
            .toList();
    final visible = filtered.take(_pageSize).toList();

    return DashboardCard(
      title: 'Recent Activity',
      titleIcon: FontAwesomeIcons.clockRotateLeft,
      trailing: Tooltip(
        message: _showSearch ? 'Close search' : 'Search activity',
        child: GestureDetector(
          onTap: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchController.clear();
                _filter = '';
              }
            });
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: FaIcon(
              _showSearch
                  ? FontAwesomeIcons.xmark
                  : FontAwesomeIcons.magnifyingGlass,
              size: 14,
              color: _showSearch ? primary : iconColor,
            ),
          ),
        ),
      ),
      footer: PageSizeSelector(
        currentSize: _pageSize,
        onChanged: (size) => setState(() => _pageSize = size),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardSearchField(
            controller: _searchController,
            hintText: 'Search activity...',
            isActive: _showSearch,
            onChanged: (query) => setState(() => _filter = query),
            onClear: () {
              _searchController.clear();
              setState(() => _filter = '');
            },
          ),
          if (allActivities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'No recent activity',
                style: AppTextStyles.body.copyWith(color: mutedColor),
              ),
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'No activity matches your search',
                style: AppTextStyles.body.copyWith(color: mutedColor),
              ),
            )
          else
            ...visible.map((a) => _ActivityRow(
                  activity: a,
                  onOpenResource: () =>
                      provider.openActivityResource(a),
                  onOpenProject: () => provider.openProject(
                    RecentProject(
                      projectId: a.projectId,
                      name: a.projectName,
                      owner: a.team,
                      lastModified: '',
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatefulWidget {
  final ActivityEvent activity;
  final VoidCallback onOpenResource;
  final VoidCallback onOpenProject;
  const _ActivityRow({
    required this.activity,
    required this.onOpenResource,
    required this.onOpenProject,
  });

  @override
  State<_ActivityRow> createState() => _ActivityRowState();
}

class _ActivityRowState extends State<_ActivityRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final secondaryColor =
        isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;
    final hoverBg =
        isDark ? AppColorsDark.surfaceElevated : AppColors.neutral50;
    final linkColor = isDark ? AppColorsDark.link : AppColors.link;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: _hovered ? hoverBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Row(
          children: [
            // Type chip — fixed width
            SizedBox(
              width: 62,
              child: _ActivityTypeChip(type: widget.activity.type),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Object name — flex 3, hyperlink
            Expanded(
              flex: 3,
              child: _HyperlinkText(
                text: widget.activity.objectName,
                color: linkColor,
                onTap: widget.onOpenResource,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // User — flex 1
            Expanded(
              flex: 1,
              child: Text(
                widget.activity.user,
                style: AppTextStyles.bodySmall.copyWith(color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Project — flex 2, hyperlink
            Expanded(
              flex: 2,
              child: _HyperlinkText(
                text: widget.activity.projectName,
                color: linkColor,
                onTap: widget.onOpenProject,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Date — fixed width right-aligned
            SizedBox(
              width: 72,
              child: Text(
                widget.activity.date,
                style: AppTextStyles.bodySmall.copyWith(color: secondaryColor),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clickable text styled as a hyperlink.
class _HyperlinkText extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onTap;
  const _HyperlinkText({
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HyperlinkText> createState() => _HyperlinkTextState();
}

class _HyperlinkTextState extends State<_HyperlinkText> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverColor =
        isDark ? AppColorsDark.linkHover : AppColors.linkHover;
    final color = _hovered ? hoverColor : widget.color;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.text,
          style: AppTextStyles.bodySmall.copyWith(
            color: color,
            decoration: _hovered ? TextDecoration.underline : null,
            decorationColor: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ActivityTypeChip extends StatelessWidget {
  final String type;
  const _ActivityTypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor;
    final Color fgColor;

    switch (type) {
      case 'create':
        bgColor = isDark ? const Color(0xFF064E3B) : AppColors.successLight;
        fgColor = isDark ? AppColorsDark.success : AppColors.success;
        break;
      case 'update':
        bgColor = isDark ? const Color(0xFF1E3A5F) : AppColors.infoLight;
        fgColor = isDark ? AppColorsDark.info : AppColors.info;
        break;
      case 'delete':
        bgColor = isDark ? const Color(0xFF5F1E1E) : AppColors.errorLight;
        fgColor = isDark ? AppColorsDark.error : AppColors.error;
        break;
      case 'run':
        bgColor = isDark ? const Color(0xFF4A3B1E) : AppColors.warningLight;
        fgColor = isDark ? AppColorsDark.warning : AppColors.warning;
        break;
      case 'complete':
        bgColor = isDark ? const Color(0xFF064E3B) : AppColors.successLight;
        fgColor = isDark ? AppColorsDark.success : AppColors.success;
        break;
      default:
        bgColor =
            isDark ? AppColorsDark.surfaceElevated : AppColors.neutral100;
        fgColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    }

    return Container(
      width: 58,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fgColor,
        ),
      ),
    );
  }
}
