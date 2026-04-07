import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/theme_provider.dart';
import '../widgets/header_bar.dart';

/// Root screen wrapping the HeaderBar with a placeholder content area below.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    final placeholderColor = isDark
        ? AppColorsDark.textMuted
        : AppColors.textMuted;
    final bgColor = isDark
        ? AppColorsDark.background
        : AppColors.background;

    return Scaffold(
      body: Column(
        children: [
          const HeaderBar(),
          Expanded(
            child: Container(
              color: bgColor,
              child: Center(
                child: Text(
                  'Content area (tab bar + windows would appear here)',
                  style: AppTextStyles.body.copyWith(color: placeholderColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
