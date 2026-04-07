import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/models/home_models.dart';
import '../../providers/home_panel_provider.dart';
import 'dashboard_card.dart';

class HelpDocsCard extends StatefulWidget {
  const HelpDocsCard({super.key});

  @override
  State<HelpDocsCard> createState() => _HelpDocsCardState();
}

class _HelpDocsCardState extends State<HelpDocsCard> {
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.read<HomePanelProvider>();
    final allLinks = provider.helpLinks;
    final iconColor =
        isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;
    final activeColor = isDark ? AppColorsDark.primary : AppColors.primary;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;

    final filtered = _filter.isEmpty
        ? allLinks
        : allLinks
            .where(
                (l) => l.label.toLowerCase().contains(_filter.toLowerCase()))
            .toList();

    return DashboardCard(
      title: 'Help & Documentation',
      titleIcon: FontAwesomeIcons.circleQuestion,
      trailing: Tooltip(
        message: _showSearch ? 'Close search' : 'Search help',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardSearchField(
            controller: _searchController,
            hintText: 'Search help...',
            isActive: _showSearch,
            onChanged: (query) => setState(() => _filter = query),
            onClear: () {
              _searchController.clear();
              setState(() => _filter = '');
            },
          ),
          if (filtered.isEmpty)
            Text(
              'No results',
              style: AppTextStyles.body.copyWith(color: mutedColor),
            )
          else
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children:
                  filtered.map((link) => _HelpLink(link: link)).toList(),
            ),
        ],
      ),
    );
  }
}

class _HelpLink extends StatefulWidget {
  final HelpLink link;
  const _HelpLink({required this.link});

  @override
  State<_HelpLink> createState() => _HelpLinkState();
}

class _HelpLinkState extends State<_HelpLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linkColor = isDark ? AppColorsDark.link : AppColors.link;
    final hoverColor = isDark ? AppColorsDark.linkHover : AppColors.linkHover;
    final color = _hovered ? hoverColor : linkColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          web.window.open(widget.link.url, '_blank');
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.arrowUpRightFromSquare,
              size: 12,
              color: color,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              widget.link.label,
              style: AppTextStyles.label.copyWith(
                color: color,
                decoration: _hovered ? TextDecoration.underline : null,
                decorationColor: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
