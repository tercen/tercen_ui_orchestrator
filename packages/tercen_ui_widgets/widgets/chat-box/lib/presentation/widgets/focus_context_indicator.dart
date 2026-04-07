import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/models/focus_context.dart';

/// Small unobtrusive indicator showing the current focus context.
///
/// Displayed below the toolbar, above the message list.
/// Shows the focused item name and source window in muted styling.
class FocusContextIndicator extends StatelessWidget {
  final FocusContext focusContext;

  const FocusContextIndicator({super.key, required this.focusContext});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final bgColor = isDark ? AppColorsDark.panelBackground : AppColors.panelBackground;
    final borderColor = isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.crosshairs,
            size: 10,
            color: mutedColor,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Focus: ${focusContext.displayLabel}',
              style: AppTextStyles.bodySmall.copyWith(color: mutedColor),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
