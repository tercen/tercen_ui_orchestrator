import 'package:flutter/material.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'window_shell.dart';

/// 48px toolbar with left-aligned action buttons and an optional trailing widget.
///
/// Buttons use Primary or Secondary styling per the Tercen style guide.
/// isPrimary=true → solid primary background, white icon/text.
/// isPrimary=false → transparent background, primary border, primary icon/text.
/// Height matches the app header height (AppSpacing.headerHeight).
///
/// The optional [trailing] widget is placed after a spacer, right-aligned.
/// Use it for search fields, dropdowns, or other non-button toolbar controls.
class WindowToolbar extends StatelessWidget {
  final List<ToolbarAction> actions;

  /// Optional widget placed after a flexible spacer (right-aligned).
  /// Typically a [ToolbarSearchField] or similar control.
  final Widget? trailing;

  const WindowToolbar({super.key, required this.actions, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: WindowConstants.toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: WindowConstants.toolbarGap),
            actions[i].label != null
                ? _LabeledToolbarButton(action: actions[i])
                : _IconToolbarButton(action: actions[i]),
          ],
          if (trailing != null) ...[
            const SizedBox(width: WindowConstants.toolbarGap),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Toolbar button (36x36, 8px radius).
///
/// Primary (isPrimary=true): solid primary-base background, white icon.
///   Hover: primary-darker background.
///   Disabled: neutral-200/neutral-700 background, neutral-400/neutral-500 icon.
///
/// Secondary (isPrimary=false): transparent, 1.5px primary border, primary icon.
///   Hover: primary-surface background.
///   Disabled: transparent, neutral-300/neutral-600 border, neutral-400/neutral-600 icon.
///
/// Focus: 2px primary ring at 2px offset (both variants).
class _IconToolbarButton extends StatefulWidget {
  final ToolbarAction action;

  const _IconToolbarButton({required this.action});

  @override
  State<_IconToolbarButton> createState() => _IconToolbarButtonState();
}

class _IconToolbarButtonState extends State<_IconToolbarButton> {
  bool _hovered = false;
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final action = widget.action;
    final disabled = action.onPressed == null;

    // Resolve colours based on variant and state.
    final _ButtonColors colors = _resolveColors(
      isDark: isDark,
      isPrimary: action.isPrimary,
      isDisabled: disabled,
      isHovered: _hovered,
    );

    return Tooltip(
      message: action.tooltip,
      child: Focus(
        focusNode: _focusNode,
        child: MouseRegion(
          cursor: disabled
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onEnter: disabled ? null : (_) => setState(() => _hovered = true),
          onExit: disabled ? null : (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: action.onPressed,
            child: Container(
              width: WindowConstants.toolbarButtonSize,
              height: WindowConstants.toolbarButtonSize,
              decoration: _focused
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(
                          WindowConstants.toolbarButtonRadius + 2),
                      border: Border.all(
                        color: isDark
                            ? AppColorsDark.primary
                            : AppColors.primary,
                        width: 2.0,
                      ),
                    )
                  : null,
              padding: _focused ? const EdgeInsets.all(2.0) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.ease,
                width: _focused
                    ? WindowConstants.toolbarButtonSize - 8
                    : WindowConstants.toolbarButtonSize,
                height: _focused
                    ? WindowConstants.toolbarButtonSize - 8
                    : WindowConstants.toolbarButtonSize,
                decoration: BoxDecoration(
                  color: colors.background,
                  border: colors.borderColor != null
                      ? Border.all(
                          color: colors.borderColor!,
                          width: WindowConstants.toolbarButtonBorderWidth,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(
                      WindowConstants.toolbarButtonRadius),
                ),
                child: Icon(
                  action.icon,
                  size: WindowConstants.toolbarButtonIconSize,
                  color: colors.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Labeled toolbar button (36px height, 8px radius, icon + text).
class _LabeledToolbarButton extends StatefulWidget {
  final ToolbarAction action;

  const _LabeledToolbarButton({required this.action});

  @override
  State<_LabeledToolbarButton> createState() => _LabeledToolbarButtonState();
}

class _LabeledToolbarButtonState extends State<_LabeledToolbarButton> {
  bool _hovered = false;
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final action = widget.action;
    final disabled = action.onPressed == null;

    final _ButtonColors colors = _resolveColors(
      isDark: isDark,
      isPrimary: action.isPrimary,
      isDisabled: disabled,
      isHovered: _hovered,
    );

    return Tooltip(
      message: action.tooltip,
      child: Focus(
        focusNode: _focusNode,
        child: MouseRegion(
          cursor: disabled
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onEnter: disabled ? null : (_) => setState(() => _hovered = true),
          onExit: disabled ? null : (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: action.onPressed,
            child: Container(
              decoration: _focused
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(
                          WindowConstants.toolbarButtonRadius + 2),
                      border: Border.all(
                        color: isDark
                            ? AppColorsDark.primary
                            : AppColors.primary,
                        width: 2.0,
                      ),
                    )
                  : null,
              padding: _focused ? const EdgeInsets.all(2.0) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.ease,
                height: _focused
                    ? WindowConstants.toolbarButtonSize - 8
                    : WindowConstants.toolbarButtonSize,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.background,
                  border: colors.borderColor != null
                      ? Border.all(
                          color: colors.borderColor!,
                          width: WindowConstants.toolbarButtonBorderWidth,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(
                      WindowConstants.toolbarButtonRadius),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      action.icon,
                      size: WindowConstants.toolbarButtonIconSize,
                      color: colors.foreground,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      action.label!,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Colour resolution helper ──────────────────────────────────────────────────

class _ButtonColors {
  final Color background;
  final Color foreground;
  final Color? borderColor;

  const _ButtonColors({
    required this.background,
    required this.foreground,
    this.borderColor,
  });
}

_ButtonColors _resolveColors({
  required bool isDark,
  required bool isPrimary,
  required bool isDisabled,
  required bool isHovered,
}) {
  // ── Primary Button (solid background, white foreground) ──
  if (isPrimary) {
    if (isDisabled) {
      return _ButtonColors(
        background: isDark ? AppColorsDark.neutral700 : AppColors.neutral200,
        foreground: isDark ? AppColorsDark.neutral500 : AppColors.neutral400,
        borderColor: null,
      );
    }
    final bg = isHovered
        ? (isDark ? AppColorsDark.primaryDarker : AppColors.primaryDarker)
        : (isDark ? AppColorsDark.primary : AppColors.primary);
    return _ButtonColors(
      background: bg,
      foreground: const Color(0xFFFFFFFF),
      borderColor: null,
    );
  }

  // ── Secondary Button (transparent, primary border, primary foreground) ──
  if (isDisabled) {
    return _ButtonColors(
      background: Colors.transparent,
      foreground: isDark ? AppColorsDark.neutral600 : AppColors.neutral400,
      borderColor: isDark ? AppColorsDark.neutral600 : AppColors.neutral300,
    );
  }
  final bg = isHovered
      ? (isDark ? AppColorsDark.primarySurface : AppColors.primarySurface)
      : Colors.transparent;
  return _ButtonColors(
    background: bg,
    foreground: isDark ? AppColorsDark.primary : AppColors.primary,
    borderColor: isDark ? AppColorsDark.primary : AppColors.primary,
  );
}
