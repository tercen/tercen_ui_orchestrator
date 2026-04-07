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

class FeaturedAppsCard extends StatefulWidget {
  const FeaturedAppsCard({super.key});

  @override
  State<FeaturedAppsCard> createState() => _FeaturedAppsCardState();
}

class _FeaturedAppsCardState extends State<FeaturedAppsCard> {
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
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final trackColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;
    final iconColor =
        isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;
    final activeColor = isDark ? AppColorsDark.primary : AppColors.primary;

    if (provider.appsLoading) {
      return DashboardCard(
        title: 'Featured Apps',
        titleIcon: FontAwesomeIcons.puzzlePiece,
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

    final allApps = provider.featuredApps;
    final filtered = _filter.isEmpty
        ? allApps
        : allApps
            .where((a) =>
                a.name.toLowerCase().contains(_filter.toLowerCase()) ||
                a.description.toLowerCase().contains(_filter.toLowerCase()))
            .toList();
    final visible = filtered.take(_pageSize).toList();

    return DashboardCard(
      title: 'Featured Apps',
      titleIcon: FontAwesomeIcons.puzzlePiece,
      trailing: Tooltip(
        message: _showSearch ? 'Close search' : 'Search apps',
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
              color: _showSearch ? activeColor : iconColor,
            ),
          ),
        ),
      ),
      footer: PageSizeSelector(
        currentSize: _pageSize,
        onChanged: (size) {
          setState(() => _pageSize = size);
          // Load more if needed
          if (size > allApps.length && provider.hasMoreApps) {
            provider.loadMoreApps();
          }
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardSearchField(
            controller: _searchController,
            hintText: 'Search apps...',
            isActive: _showSearch,
            onChanged: (query) => setState(() => _filter = query),
            onClear: () {
              _searchController.clear();
              setState(() => _filter = '');
            },
          ),
          if (allApps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'No featured apps available',
                style: AppTextStyles.body.copyWith(color: mutedColor),
              ),
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'No apps match your search',
                style: AppTextStyles.body.copyWith(color: mutedColor),
              ),
            )
          else
            ...visible.map((app) => _AppRow(
                  app: app,
                  onTap: () => provider.openApp(app),
                )),
        ],
      ),
    );
  }
}

class _AppRow extends StatefulWidget {
  final FeaturedApp app;
  final VoidCallback onTap;
  const _AppRow({required this.app, required this.onTap});

  @override
  State<_AppRow> createState() => _AppRowState();
}

class _AppRowState extends State<_AppRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final descColor =
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
                    FontAwesomeIcons.puzzlePiece,
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
                      widget.app.name,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.app.description,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: descColor, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
