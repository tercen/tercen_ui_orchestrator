import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_line_weights.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/home_panel_provider.dart';

/// Welcome Card: full-width, top row.
/// Uses primary surface bg with card border treatment.
/// Spec section 2.6.1.
class WelcomeCard extends StatelessWidget {
  const WelcomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<HomePanelProvider>();
    final primaryColor = isDark ? AppColorsDark.primary : AppColors.primary;
    final bgColor =
        isDark ? AppColorsDark.primarySurface : AppColors.primaryBg;
    final borderColor =
        isDark ? AppColorsDark.primaryDarker : AppColors.primarySurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: borderColor,
          width: AppLineWeights.lineSubtle,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(
        provider.greeting,
        style: AppTextStyles.h2.copyWith(color: primaryColor),
      ),
    );
  }
}
