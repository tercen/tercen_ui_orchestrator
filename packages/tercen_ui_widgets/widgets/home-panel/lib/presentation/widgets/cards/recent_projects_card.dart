import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/models/home_models.dart';
import '../../providers/home_panel_provider.dart';
import 'dashboard_card.dart';

class RecentProjectsCard extends StatefulWidget {
  const RecentProjectsCard({super.key});

  @override
  State<RecentProjectsCard> createState() => _RecentProjectsCardState();
}

class _RecentProjectsCardState extends State<RecentProjectsCard> {
  bool _showSearch = false;
  final _searchController = TextEditingController();
  int _pageSize = 5;
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
    final allProjects = provider.recentProjects;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final iconColor =
        isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;
    final activeColor = isDark ? AppColorsDark.primary : AppColors.primary;

    // Apply local filter
    final filtered = _filter.isEmpty
        ? allProjects
        : allProjects
            .where((p) =>
                p.name.toLowerCase().contains(_filter.toLowerCase()) ||
                p.owner.toLowerCase().contains(_filter.toLowerCase()))
            .toList();
    final visible = filtered.take(_pageSize).toList();

    return DashboardCard(
      title: 'Recent Projects',
      titleIcon: FontAwesomeIcons.folderOpen,
      trailing: Tooltip(
        message: _showSearch ? 'Close search' : 'Search projects',
        child: GestureDetector(
          onTap: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchController.clear();
                _filter = '';
                provider.clearSearch();
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
              color: _showSearch ? activeColor : iconColor,
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
            hintText: 'Search projects...',
            isActive: _showSearch,
            onChanged: (query) {
              setState(() => _filter = query);
              provider.searchProjects(query);
            },
            onClear: () {
              _searchController.clear();
              setState(() => _filter = '');
              provider.clearSearch();
            },
          ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                _filter.isNotEmpty
                    ? 'No projects match your search'
                    : 'No recent projects',
                style: AppTextStyles.body.copyWith(color: mutedColor),
              ),
            )
          else
            ...visible.map((p) => _ProjectRow(
                  project: p,
                  onTap: () => provider.openProject(p),
                )),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatefulWidget {
  final RecentProject project;
  final VoidCallback onTap;
  const _ProjectRow({required this.project, required this.onTap});

  @override
  State<_ProjectRow> createState() => _ProjectRowState();
}

class _ProjectRowState extends State<_ProjectRow> {
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
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: _hovered ? hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  border: Border.all(color: primary, width: 1.5),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.folder,
                    size: 14,
                    color: primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.project.name,
                      style:
                          AppTextStyles.label.copyWith(color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.project.owner,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: secondaryColor),
                    ),
                  ],
                ),
              ),
              Text(
                widget.project.lastModified,
                style: AppTextStyles.bodySmall
                    .copyWith(color: secondaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
