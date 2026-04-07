import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/pane_constants.dart';
import '../../core/theme/pane_colors.dart';
import '../../core/widgets/tab_type_icon.dart';

/// A single tab within a pane's tab strip.
///
/// Shows: [color square] [title] [close button]
/// Supports active/inactive/hover states with proper styling.
/// Theme-aware: works in both light and dark modes.
class PaneTab extends StatefulWidget {
  final Color typeColor;
  final String title;
  final bool isActive;
  final bool isFocusedPane;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  const PaneTab({
    super.key,
    required this.typeColor,
    required this.title,
    this.isActive = false,
    this.isFocusedPane = true,
    this.onTap,
    this.onClose,
  });

  @override
  State<PaneTab> createState() => _PaneTabState();
}

class _PaneTabState extends State<PaneTab> {
  bool _hovered = false;
  bool _closeHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = PaneColors.of(context);

    final fontWeight = !widget.isActive
        ? PaneConstants.tabWeightInactive
        : widget.isFocusedPane
            ? PaneConstants.tabWeightFocused
            : PaneConstants.tabWeightBlurred;

    final textColor = widget.isActive
        ? (widget.isFocusedPane ? c.textPrimary : c.textSecondary)
        : (_hovered ? c.textSecondary : c.textMuted);

    final backgroundColor = widget.isActive
        ? c.primaryBg
        : (_hovered ? c.surfaceElevated : Colors.transparent);

    // Focused pane: primary accent. Blurred/inactive: matches background (invisible).
    final accentColor = (widget.isActive && widget.isFocusedPane)
        ? c.primary
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: PaneConstants.tabMaxWidth,
            minWidth: PaneConstants.tabMinWidth,
          ),
          height: PaneConstants.tabHeight,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              left: BorderSide(color: c.borderSubtle, width: 0.5),
              right: BorderSide(color: c.borderSubtle, width: 0.5),
              bottom: BorderSide(
                color: accentColor,
                width: PaneConstants.tabAccentWidth,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: PaneConstants.tabPaddingH,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabTypeIcon(color: widget.typeColor),
              const SizedBox(width: PaneConstants.tabGap),
              Flexible(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: PaneConstants.tabFontSize,
                    fontWeight: fontWeight,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: PaneConstants.tabGap),
              _CloseButton(
                hovered: _closeHovered,
                onHoverChanged: (h) => setState(() => _closeHovered = h),
                onTap: widget.onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final bool hovered;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback? onTap;

  const _CloseButton({
    required this.hovered,
    required this.onHoverChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = PaneColors.of(context);

    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: PaneConstants.tabButtonSize,
          height: PaneConstants.tabButtonSize,
          decoration: BoxDecoration(
            color: hovered ? c.errorLight : Colors.transparent,
            borderRadius: BorderRadius.circular(PaneConstants.tabIconRadius),
          ),
          child: Center(
            child: FaIcon(
              FontAwesomeIcons.xmark,
              size: PaneConstants.tabButtonIconSize,
              color: hovered ? c.error : c.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
