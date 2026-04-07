import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/tree_node.dart';
import '../providers/navigator_provider.dart';

/// Type filter dropdown button matching the 36x36 primary toolbar button style.
///
/// Shows "All" text when no filter, or the matching icon when filtered.
/// Dropdown items are icon-only (no text labels) with tooltips.
/// The popup is narrow — just wide enough for centred icons.
class TypeFilterButton extends StatefulWidget {
  const TypeFilterButton({super.key});

  @override
  State<TypeFilterButton> createState() => _TypeFilterButtonState();
}

class _TypeFilterButtonState extends State<TypeFilterButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<NavigatorProvider>();

    // Secondary styling per Tercen style guide
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final bgColor = _hovered
        ? (isDark ? AppColorsDark.primarySurface : AppColors.primarySurface)
        : Colors.transparent;
    final fgColor = primary;
    final borderColor = primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: PopupMenuButton<TypeFilter>(
        tooltip: 'Filter',
        offset: const Offset(0, WindowConstants.toolbarButtonSize),
        constraints: const BoxConstraints(
          minWidth: 48,
          maxWidth: 56,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        color: isDark ? AppColorsDark.surfaceElevated : AppColors.surface,
        onSelected: (filter) => provider.setTypeFilter(filter),
        itemBuilder: (context) => [
          _buildMenuItem(context, TypeFilter.all, provider.typeFilter),
          _buildMenuItem(context, TypeFilter.file, provider.typeFilter),
          _buildMenuItem(context, TypeFilter.dataset, provider.typeFilter),
          _buildMenuItem(context, TypeFilter.workflow, provider.typeFilter),
        ],
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: WindowConstants.toolbarButtonSize,
          height: WindowConstants.toolbarButtonSize,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
            borderRadius:
                BorderRadius.circular(WindowConstants.toolbarButtonRadius),
          ),
          child: Center(
            child: _buildFilterIcon(provider.typeFilter, fgColor),
          ),
        ),
      ),
    );
  }


  Widget _buildFilterIcon(TypeFilter filter, Color fgColor) {
    switch (filter) {
      case TypeFilter.all:
        return Text(
          'All',
          style: AppTextStyles.body.copyWith(
            color: fgColor,
          ),
        );
      case TypeFilter.file:
        return FaIcon(FontAwesomeIcons.file, size: 14, color: fgColor);
      case TypeFilter.dataset:
        return FaIcon(FontAwesomeIcons.table, size: 14, color: fgColor);
      case TypeFilter.workflow:
        return FaIcon(FontAwesomeIcons.sitemap, size: 14, color: fgColor);
    }
  }

  PopupMenuItem<TypeFilter> _buildMenuItem(
    BuildContext context,
    TypeFilter filter,
    TypeFilter currentFilter,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = currentFilter == filter;

    final IconData? icon;
    final String tooltipText;
    final String? text;
    final Color color;

    switch (filter) {
      case TypeFilter.all:
        icon = null;
        text = 'All';
        tooltipText = 'All';
        color = isActive
            ? (isDark ? AppColorsDark.primary : AppColors.primary)
            : (isDark ? AppColorsDark.textSecondary : AppColors.textSecondary);
        break;
      case TypeFilter.file:
        icon = FontAwesomeIcons.file;
        text = null;
        tooltipText = 'File';
        color = isActive
            ? (isDark ? AppColorsDark.primary : AppColors.primary)
            : (isDark ? AppColorsDark.neutral300 : AppColors.neutral700);
        break;
      case TypeFilter.dataset:
        icon = FontAwesomeIcons.table;
        text = null;
        tooltipText = 'Data Set';
        color = isActive
            ? (isDark ? AppColorsDark.primary : AppColors.primary)
            : (isDark ? AppColorsDark.warning : AppColors.warning);
        break;
      case TypeFilter.workflow:
        icon = FontAwesomeIcons.sitemap;
        text = null;
        tooltipText = 'Workflow';
        color = isActive
            ? (isDark ? AppColorsDark.primary : AppColors.primary)
            : (isDark ? AppColorsDark.info : AppColors.info);
        break;
    }

    return PopupMenuItem<TypeFilter>(
      value: filter,
      height: 36,
      padding: EdgeInsets.zero,
      child: Tooltip(
        message: tooltipText,
        child: Center(
          child: icon != null
              ? FaIcon(icon, size: 16, color: color)
              : Text(
                  text ?? '',
                  style: AppTextStyles.body.copyWith(color: color),
                ),
        ),
      ),
    );
  }
}
