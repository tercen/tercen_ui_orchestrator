import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/app_logo_colors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/models/chat_message.dart';

/// Renders a single chat message bubble.
///
/// User messages: left-aligned with primary tint background and an orange
/// FontAwesome message icon (Tercen logo orange #FF8200).
/// Assistant messages: left-aligned with panel background, markdown rendered,
/// and a coloured square bullet from the Tercen App logo palette.
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  /// Index of this message in the full message list — used to pick
  /// the rotating palette colour for assistant bullet squares.
  final int messageIndex;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.messageIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.role == MessageRole.user;

    if (isUser) {
      return _UserBubble(message: message, isDark: isDark);
    } else {
      return _AssistantBubble(
        message: message,
        isDark: isDark,
        messageIndex: messageIndex,
      );
    }
  }
}

class _UserBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const _UserBubble({required this.message, required this.isDark});

  /// Tercen logo orange used for user message icon.
  static const _tercenOrange = Color(0xFFFF8200);

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColorsDark.primaryBg : AppColors.primaryBg;
    final borderColor =
        isDark ? AppColorsDark.primarySurface : AppColors.primarySurface;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final timeColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;

    return LayoutBuilder(builder: (context, constraints) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * 0.75,
          ),
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Orange FA message icon (Tercen logo orange)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
              child: FaIcon(
                FontAwesomeIcons.solidMessage,
                size: 12,
                color: _tercenOrange,
              ),
            ),
            // Message bubble
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(color: borderColor, width: 1.0),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.content,
                      style: AppTextStyles.body.copyWith(color: textColor),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _formatTime(message.timestamp),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: timeColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    });
  }
}

class _AssistantBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  final int messageIndex;

  const _AssistantBubble({
    required this.message,
    required this.isDark,
    required this.messageIndex,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isDark ? AppColorsDark.panelBackground : AppColors.panelBackground;
    final borderColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;
    final timeColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final bulletColor = AppLogoColors.atIndex(messageIndex);

    return LayoutBuilder(builder: (context, constraints) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * 0.85,
          ),
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Coloured square bullet from App logo palette
            Padding(
              padding: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: bulletColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Message bubble
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(color: borderColor, width: 1.0),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MarkdownContent(
                      content: message.content,
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatTime(message.timestamp),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: timeColor,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    });
  }
}

/// Renders markdown content for assistant messages.
///
/// Uses flutter_markdown with theme-aware styling for code blocks,
/// inline code, links, headings, tables, and block quotes.
class _MarkdownContent extends StatelessWidget {
  final String content;
  final bool isDark;

  const _MarkdownContent({required this.content, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final secondaryColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final linkColor = isDark ? AppColorsDark.link : AppColors.link;
    final codeBlockBg = isDark
        ? AppColorsDark.surfaceElevated
        : AppColors.panelBackground;
    final codeBg = isDark
        ? AppColorsDark.surfaceElevated
        : const Color(0xFFF1F5F9);
    final borderColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;
    final blockquoteBorder =
        isDark ? AppColorsDark.primary : AppColors.primary;

    return MarkdownBody(
      data: content,
      selectable: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet(
        // Headings
        h1: AppTextStyles.h1.copyWith(color: textColor),
        h2: AppTextStyles.h2.copyWith(color: textColor),
        h3: AppTextStyles.h3.copyWith(color: textColor),
        // Paragraphs
        p: AppTextStyles.body.copyWith(color: textColor),
        // Links
        a: AppTextStyles.body.copyWith(color: linkColor),
        // Bold / italic
        strong: AppTextStyles.body
            .copyWith(color: textColor, fontWeight: FontWeight.w700),
        em: AppTextStyles.body
            .copyWith(color: textColor, fontStyle: FontStyle.italic),
        // Strikethrough
        del: AppTextStyles.body.copyWith(
          color: secondaryColor,
          decoration: TextDecoration.lineThrough,
        ),
        // Inline code
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: textColor,
          backgroundColor: codeBg,
        ),
        // Fenced code blocks
        codeblockDecoration: BoxDecoration(
          color: codeBlockBg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: borderColor),
        ),
        codeblockPadding: const EdgeInsets.all(AppSpacing.md),
        // Block quotes
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: blockquoteBorder,
              width: 3.0,
            ),
          ),
        ),
        blockquotePadding:
            const EdgeInsets.only(left: AppSpacing.md, top: 4, bottom: 4),
        // Tables
        tableBorder: TableBorder.all(color: borderColor, width: 1.0),
        tableHead: AppTextStyles.label.copyWith(color: textColor),
        tableBody: AppTextStyles.body.copyWith(color: textColor),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        // Horizontal rule
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: borderColor, width: 1.0),
          ),
        ),
        // Lists
        listBullet: AppTextStyles.body.copyWith(color: textColor),
        // Spacing
        h1Padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
        h2Padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
        h3Padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
        pPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
        blockSpacing: AppSpacing.sm,
      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
