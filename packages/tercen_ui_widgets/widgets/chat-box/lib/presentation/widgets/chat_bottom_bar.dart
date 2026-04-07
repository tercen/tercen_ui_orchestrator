import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/chat_provider.dart';

/// Bottom toolbar inside the compose box, below the input area.
///
/// Contains: [Focus context indicator] ... spacer ... [Send button (primary)]
/// The send button uses the Tercen Primary Button style:
///   - Solid primary-base background, white text/icon
///   - Hover: primary-darker
///   - Disabled: neutral-200/neutral-700 background
///   - 8px radius, 10px×20px padding, 0.15s transition
class ChatBottomBar extends StatelessWidget {
  const ChatBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<ChatProvider>();
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final canSend = provider.canSend;
    final focusCtx = provider.focusContext;

    return Container(
      height: 44,
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: 2,
      ),
      child: Row(
        children: [
          // Focus context indicator
          if (focusCtx != null) ...[
            FaIcon(
              FontAwesomeIcons.crosshairs,
              size: 10,
              color: mutedColor,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                'Focus: ${focusCtx.displayLabel}',
                style: AppTextStyles.bodySmall.copyWith(color: mutedColor),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
          const Spacer(),
          // Send button — Primary Button style per Tercen style guide
          _SendButton(canSend: canSend, onSend: () => provider.sendFromInput()),
        ],
      ),
    );
  }
}

/// Send button — always primary styled (solid primary bg, white icon).
/// Hover darkens slightly. No disabled visual state.
class _SendButton extends StatefulWidget {
  final bool canSend;
  final VoidCallback onSend;

  const _SendButton({required this.canSend, required this.onSend});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = _hovered
        ? (isDark ? AppColorsDark.primaryDarker : AppColors.primaryDarker)
        : (isDark ? AppColorsDark.primary : AppColors.primary);
    const fg = Color(0xFFFFFFFF);

    return Tooltip(
      message: 'Send',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.canSend ? widget.onSend : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.ease,
            width: AppSpacing.controlHeight,
            height: AppSpacing.controlHeight,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Center(
              child: FaIcon(
                FontAwesomeIcons.paperPlane,
                size: 14,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
