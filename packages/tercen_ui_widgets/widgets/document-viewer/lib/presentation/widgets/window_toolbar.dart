import 'package:flutter/material.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_line_weights.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'window_shell.dart';

/// 48px toolbar with left-aligned action buttons and an optional trailing widget.
///
/// Icon-only buttons use Secondary (outlined) styling; labeled buttons use
/// Primary (filled, isPrimary) or Secondary (outlined) variant per the style guide.
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
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Secondary-styled icon-only toolbar button (36x36, 8px radius).
///
/// - Default: transparent background, primary icon, 1.5px primary border
/// - Disabled: transparent, neutral icon, neutral border, no hover
/// - Hover: animated 150ms to primarySurface background
/// - Focus: 2px primary ring with 2px offset
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
    final _ButtonColors colors = _resolveSecondaryColors(
      isDark: isDark,
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
                          width: AppLineWeights.lineStandard,
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

/// Labeled toolbar button: Primary (filled) or Secondary (outlined) variant.
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

    final _ButtonColors colors = _resolveLabeledColors(
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
                          width: AppLineWeights.lineStandard,
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
                    const SizedBox(width: AppSpacing.sm),
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

// ── Colour resolution helpers ─────────────────────────────────────────────────

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

/// Secondary (outlined) styling for icon-only buttons.
_ButtonColors _resolveSecondaryColors({
  required bool isDark,
  required bool isDisabled,
  required bool isHovered,
}) {
  if (isDisabled) {
    return _ButtonColors(
      background: Colors.transparent,
      foreground: isDark ? AppColorsDark.neutral600 : AppColors.neutral400,
      borderColor: isDark ? AppColorsDark.neutral600 : AppColors.neutral300,
    );
  }

  final primary = isDark ? AppColorsDark.primary : AppColors.primary;
  final bg = isHovered
      ? (isDark ? AppColorsDark.primarySurface : AppColors.primarySurface)
      : Colors.transparent;
  return _ButtonColors(
    background: bg,
    foreground: primary,
    borderColor: primary,
  );
}

/// Primary (filled) or Secondary (outlined) styling for labeled buttons.
_ButtonColors _resolveLabeledColors({
  required bool isDark,
  required bool isPrimary,
  required bool isDisabled,
  required bool isHovered,
}) {
  if (isDisabled) {
    if (isPrimary) {
      return _ButtonColors(
        background: isDark ? AppColorsDark.neutral700 : AppColors.neutral200,
        foreground: isDark ? AppColorsDark.neutral500 : AppColors.neutral400,
      );
    }
    return _ButtonColors(
      background: Colors.transparent,
      foreground: isDark ? AppColorsDark.neutral600 : AppColors.neutral400,
      borderColor: isDark ? AppColorsDark.neutral600 : AppColors.neutral300,
    );
  }

  if (isPrimary) {
    // Primary filled button.
    final bg = isHovered
        ? (isDark ? AppColorsDark.primaryDarker : AppColors.primaryDarker)
        : (isDark ? AppColorsDark.primary : AppColors.primary);
    return _ButtonColors(
      background: bg,
      foreground: Colors.white,
    );
  }

  // Secondary outlined button.
  final primary = isDark ? AppColorsDark.primary : AppColors.primary;
  final bg = isHovered
      ? (isDark ? AppColorsDark.primarySurface : AppColors.primarySurface)
      : Colors.transparent;
  return _ButtonColors(
    background: bg,
    foreground: primary,
    borderColor: primary,
  );
}
