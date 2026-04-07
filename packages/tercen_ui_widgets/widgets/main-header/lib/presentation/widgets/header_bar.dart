import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/header_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_line_weights.dart';
import '../../core/theme/app_spacing.dart';
import '../providers/theme_provider.dart';
import 'brand_mark_slot.dart';
import 'user_avatar.dart';

/// The main header chrome bar. Fixed height of 36px.
/// Brand mark on the left, user avatar with dropdown on the right.
class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    final bgColor = isDark ? AppColorsDark.surface : AppColors.white;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;

    return Container(
      height: HeaderConstants.headerChromeHeight,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: borderColor,
            width: AppLineWeights.lineStandard,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          const BrandMarkSlot(),
          const Spacer(),
          const UserAvatar(),
        ],
      ),
    );
  }
}
