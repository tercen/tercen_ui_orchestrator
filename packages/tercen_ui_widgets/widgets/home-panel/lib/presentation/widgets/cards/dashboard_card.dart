import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_line_weights.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Reusable card wrapper for dashboard cards.
///
/// Tercen style guide card pattern:
/// - Light: white bg, 1px neutral-300 border, shadow-sm, radius-md (8px)
/// - Dark: neutral-900 bg, 1px neutral-700 border, no shadow, radius-md
/// - Header bar: neutral-100 (light) / neutral-800 (dark) with icon + title
/// - Body padding: space-md (16px)
/// - Optional footer for page-size controls
class DashboardCard extends StatelessWidget {
  final String? title;
  final IconData? titleIcon;
  final Widget child;
  final Widget? trailing;
  final Widget? footer;

  const DashboardCard({
    super.key,
    this.title,
    this.titleIcon,
    required this.child,
    this.trailing,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? AppColorsDark.surface : AppColors.surface;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;

    final headerBg =
        isDark ? AppColorsDark.surfaceElevated : AppColors.neutral100;
    final titleColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final iconColor = isDark ? AppColorsDark.primary : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(
          color: borderColor,
          width: AppLineWeights.lineSubtle,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0D000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: headerBg,
                border: Border(
                  bottom: BorderSide(
                    color: borderColor,
                    width: AppLineWeights.lineSubtle,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (titleIcon != null) ...[
                    Icon(titleIcon, size: 14, color: iconColor),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: AppTextStyles.sectionHeader.copyWith(
                        color: titleColor,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
          if (footer != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: borderColor,
                    width: AppLineWeights.lineSubtle,
                  ),
                ),
              ),
              child: footer!,
            ),
        ],
      ),
    );
  }
}

/// Page size selector shown in card footer: 5 | 10 | 20
class PageSizeSelector extends StatelessWidget {
  final int currentSize;
  final ValueChanged<int> onChanged;
  final List<int> options;

  const PageSizeSelector({
    super.key,
    required this.currentSize,
    required this.onChanged,
    this.options = const [5, 10, 20],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Show:', style: AppTextStyles.bodySmall.copyWith(color: mutedColor)),
        const SizedBox(width: AppSpacing.xs),
        for (int i = 0; i < options.length; i++) ...[
          if (i > 0)
            Text(' | ',
                style: AppTextStyles.bodySmall.copyWith(color: mutedColor)),
          _PageSizeOption(
            value: options[i],
            isActive: currentSize == options[i],
            primary: primary,
            mutedColor: mutedColor,
            onTap: () => onChanged(options[i]),
          ),
        ],
      ],
    );
  }
}

class _PageSizeOption extends StatefulWidget {
  final int value;
  final bool isActive;
  final Color primary;
  final Color mutedColor;
  final VoidCallback onTap;

  const _PageSizeOption({
    required this.value,
    required this.isActive,
    required this.primary,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  State<_PageSizeOption> createState() => _PageSizeOptionState();
}

class _PageSizeOptionState extends State<_PageSizeOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          '${widget.value}',
          style: AppTextStyles.bodySmall.copyWith(
            color: widget.isActive
                ? widget.primary
                : (_hovered ? widget.primary : widget.mutedColor),
            fontWeight:
                widget.isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Inline search field for card headers.
class CardSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool isActive;

  const CardSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final borderColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;

    if (!isActive) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SizedBox(
        height: 32,
        child: TextField(
          controller: controller,
          autofocus: true,
          style: AppTextStyles.bodySmall.copyWith(color: textColor),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTextStyles.bodySmall.copyWith(color: mutedColor),
            prefixIcon: Icon(Icons.search, size: 16, color: mutedColor),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
            suffixIcon: controller.text.isNotEmpty
                ? GestureDetector(
                    onTap: onClear,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(Icons.close, size: 14, color: mutedColor),
                    ),
                  )
                : null,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              borderSide: BorderSide(color: primary, width: 1.5),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
