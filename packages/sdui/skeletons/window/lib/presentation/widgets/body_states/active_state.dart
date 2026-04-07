import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/window_state_provider.dart';

/// Default active body state: placeholder content for the skeleton.
///
/// Replace this widget with your window type's actual content.
/// This placeholder demonstrates padding, scroll behaviour, and theme response.
class ActiveState extends StatelessWidget {
  const ActiveState({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<WindowStateProvider>();
    final panelBg =
        isDark ? AppColorsDark.panelBackground : AppColors.panelBackground;
    final borderColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;
    final titleColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final bodyColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: panelBg,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.identity.label,
                  style: AppTextStyles.h3.copyWith(color: titleColor),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Active content placeholder. Replace this widget with '
                  'your window type\'s content.',
                  style: AppTextStyles.bodySmall.copyWith(color: bodyColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: panelBg,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Window State',
                  style: AppTextStyles.h3.copyWith(color: titleColor),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Type: ${provider.identity.typeId}\n'
                  'Data items: ${provider.data?['itemCount'] ?? 'none'}',
                  style: AppTextStyles.bodySmall.copyWith(color: bodyColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
