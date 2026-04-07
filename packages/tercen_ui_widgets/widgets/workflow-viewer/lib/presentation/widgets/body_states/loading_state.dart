import 'package:flutter/material.dart';
import '../../../core/constants/window_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_text_styles.dart';

/// Loading body state: centred spinner with optional message.
class LoadingState extends StatelessWidget {
  final String message;

  const LoadingState({super.key, this.message = 'Loading workflow...'});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final trackColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;
    final textColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: WindowConstants.spinnerSize,
            height: WindowConstants.spinnerSize,
            child: CircularProgressIndicator(
              strokeWidth: WindowConstants.spinnerStrokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(primary),
              backgroundColor: trackColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTextStyles.body.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}
