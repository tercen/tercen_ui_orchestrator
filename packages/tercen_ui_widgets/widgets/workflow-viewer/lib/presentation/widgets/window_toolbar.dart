import 'package:flutter/material.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'window_shell.dart';

/// 48px toolbar with left-aligned action buttons and optional trailing widgets.
///
/// Buttons use Ghost, Secondary, or Primary styling per the Tercen style guide.
/// Height matches the app header height (AppSpacing.headerHeight).
class WindowToolbar extends StatelessWidget {
  final List<ToolbarAction> actions;
  final List<Widget> trailing;

  const WindowToolbar({
    super.key,
    required this.actions,
    this.trailing = const [],
  });

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
          if (trailing.isNotEmpty) ...[
            const SizedBox(width: WindowConstants.toolbarGap),
            ...trailing,
          ],
        ],
      ),
    );
  }
}

/// Ghost-style icon-only toolbar button (36x36, 8px radius).
///
/// - Default: transparent background, neutral icon
/// - Primary: primaryBg background, primary icon, 1px primarySurface border
/// - Disabled: transparent, neutral400/neutral600 icon, no hover
/// - Hover: animated 150ms transition
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
    final _ButtonColors colors = _resolveColors(
      isDark: isDark,
      variant: action.variant,
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

/// Ghost-style labeled toolbar button (36px height, 8px radius, icon + text).
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
      variant: action.variant,
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
  required ToolbarButtonVariant variant,
  required bool isDisabled,
  required bool isHovered,
}) {
  // Disabled — same for all variants.
  if (isDisabled) {
    return _ButtonColors(
      background: Colors.transparent,
      foreground: isDark ? AppColorsDark.neutral600 : AppColors.neutral400,
      borderColor: null,
    );
  }

  final primary = isDark ? AppColorsDark.primary : AppColors.primary;
  final primaryDarker = isDark ? AppColorsDark.primaryDarker : AppColors.primaryDarker;

  switch (variant) {
    // Filled blue background, white text.
    case ToolbarButtonVariant.primary:
      return _ButtonColors(
        background: isHovered ? primaryDarker : primary,
        foreground: Colors.white,
        borderColor: null,
      );

    // Transparent bg, primary border & text. Hover: primarySurface bg.
    case ToolbarButtonVariant.secondary:
      return _ButtonColors(
        background: isHovered
            ? (isDark ? AppColorsDark.primarySurface : AppColors.primarySurface)
            : Colors.transparent,
        foreground: primary,
        borderColor: primary,
      );

    // Transparent bg, neutral icon, no border. Hover: neutral bg.
    case ToolbarButtonVariant.ghost:
      return _ButtonColors(
        background: isHovered
            ? (isDark ? AppColorsDark.neutral700 : AppColors.neutral200)
            : Colors.transparent,
        foreground: isDark ? AppColorsDark.neutral400 : AppColors.neutral600,
        borderColor: null,
      );
  }
}
