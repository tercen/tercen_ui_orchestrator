import 'package:flutter/material.dart';
import '../../../core/constants/window_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_line_weights.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Error body state: centred error icon + message + optional retry button.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorColor = isDark ? AppColorsDark.error : AppColors.error;
    final detailColor =
        isDark ? AppColorsDark.textDisabled : AppColors.textDisabled;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: WindowConstants.bodyStateMaxWidth,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: WindowConstants.bodyStateIconSize,
              color: errorColor,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Something went wrong',
              style: AppTextStyles.body.copyWith(color: errorColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: detailColor),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: onRetry,
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(errorColor),
                  side: WidgetStateProperty.all(BorderSide(
                    color: errorColor,
                    width: AppLineWeights.lineStandard,
                  )),
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  )),
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  minimumSize: WidgetStateProperty.all(
                    const Size(0, AppSpacing.controlHeightSm),
                  ),
                  backgroundColor:
                      WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return isDark
                          ? errorColor.withValues(alpha: 0.12)
                          : AppColors.errorLight;
                    }
                    return Colors.transparent;
                  }),
                  overlayColor:
                      WidgetStateProperty.all(Colors.transparent),
                ),
                child: Text(
                  'Retry',
                  style: AppTextStyles.labelSmall.copyWith(color: errorColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
