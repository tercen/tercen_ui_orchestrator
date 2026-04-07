import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/chat_provider.dart';

/// Multi-line input area for composing messages.
///
/// Uses the shared inputController from ChatProvider so the bottom bar
/// can trigger send. Enter sends, Shift+Enter inserts newline.
/// Starts at 4 visible lines for comfortable typing.
/// Background is transparent — the compose container provides the fill colour.
class ChatInputArea extends StatefulWidget {
  const ChatInputArea({super.key});

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      final provider = context.read<ChatProvider>();
      if (provider.canSend) {
        provider.sendFromInput();
        _focusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<ChatProvider>();

    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final hintColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: _handleKey,
        child: TextField(
          controller: provider.inputController,
          focusNode: _focusNode,
          enabled: !provider.isSending,
          minLines: 4,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: AppTextStyles.body.copyWith(color: textColor),
          decoration: InputDecoration(
            hintText: 'Type a message...',
            hintStyle: AppTextStyles.body.copyWith(color: hintColor),
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: AppSpacing.xs,
            ),
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
