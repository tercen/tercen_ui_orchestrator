import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Animated thinking indicator shown while waiting for an assistant response.
///
/// Displays the animated Tercen logo (small) with a "Thinking..." label,
/// left-aligned like an assistant message bubble.
class ThinkingIndicator extends StatelessWidget {
  const ThinkingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated thinking indicator GIF — kept small so it doesn't dominate
          SizedBox(
            width: 24,
            height: 24,
            child: Image.asset(
              'assets/thinking_indicator.gif',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Thinking...',
            style: AppTextStyles.bodySmall.copyWith(
              color: mutedColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
