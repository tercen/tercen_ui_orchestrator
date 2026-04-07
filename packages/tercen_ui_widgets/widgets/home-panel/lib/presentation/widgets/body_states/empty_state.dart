import 'package:flutter/material.dart';
import '../../../core/constants/window_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_line_weights.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Empty body state: centred icon + message + optional action button.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor =
        isDark ? AppColorsDark.textDisabled : AppColors.textDisabled;
    final textColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final detailColor =
        isDark ? AppColorsDark.textDisabled : AppColors.textDisabled;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: WindowConstants.bodyStateMaxWidth,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: WindowConstants.bodyStateIconSize,
              color: iconColor,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.body.copyWith(color: textColor),
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail!,
                style: AppTextStyles.bodySmall.copyWith(color: detailColor),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: onAction,
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(primary),
                  side: WidgetStateProperty.all(BorderSide(
                    color: primary,
                    width: AppLineWeights.lineStandard,
                  )),
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  )),
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  minimumSize: WidgetStateProperty.all(
                    const Size(0, AppSpacing.controlHeightSm),
                  ),
                  backgroundColor:
                      WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return isDark
                          ? AppColorsDark.primarySurface
                          : AppColors.primarySurface;
                    }
                    return Colors.transparent;
                  }),
                  overlayColor:
                      WidgetStateProperty.all(Colors.transparent),
                ),
                child: Text(
                  actionLabel!,
                  style: AppTextStyles.labelSmall.copyWith(color: primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
