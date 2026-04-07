import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../chat_message_list.dart';
import '../chat_input_area.dart';
import '../chat_bottom_bar.dart';

/// Active body state: displays the chat message list and a bordered
/// compose box (input area + bottom toolbar).
///
/// Layout (top to bottom):
///   1. Message list (scrollable, fills remaining space)
///   2. Compose box with primary border, drop shadow, rounded corners:
///      a. Multi-line text field
///      b. Subtle divider
///      c. Bottom toolbar (focus context + send button)
class ActiveState extends StatelessWidget {
  const ActiveState({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColorsDark.primary : AppColors.primary;
    final composeBg = isDark ? AppColorsDark.surface : AppColors.surface;
    final dividerColor = isDark
        ? AppColorsDark.borderSubtle.withValues(alpha: 0.4)
        : AppColors.borderSubtle.withValues(alpha: 0.5);

    return Column(
      children: [
        // Message list (scrollable, fills remaining space)
        const Expanded(
          child: ChatMessageList(),
        ),
        // Compose box: primary-bordered container with shadow, max 720px wide
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.sm,
                bottom: AppSpacing.md,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: composeBg,
                  border: Border.all(color: primaryColor, width: 1.5),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.07),
                      blurRadius: 6.0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusLg - 1.5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Multi-line input area
                      const ChatInputArea(),
                      // Subtle divider
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm),
                        color: dividerColor,
                      ),
                      // Bottom toolbar: focus context + send button
                      const ChatBottomBar(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
