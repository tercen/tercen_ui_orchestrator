import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// A general-purpose responsive search field for window toolbars.
///
/// Wraps itself in [Flexible] so it absorbs available toolbar space.
/// Constrained between [toolbarButtonSize] (min) and [maxWidth] (max).
/// Accepts a generic [onChanged] callback — not tied to any provider.
class ToolbarSearchField extends StatefulWidget {
  /// Called on every text change with the current value.
  final ValueChanged<String> onChanged;

  /// Optional callback when the clear button is pressed.
  /// If null, the field is simply cleared and [onChanged] is called with ''.
  final VoidCallback? onClear;

  /// Placeholder text shown when the field is empty.
  final String hintText;

  /// Maximum width the field can grow to. Defaults to 440px.
  final double maxWidth;

  const ToolbarSearchField({
    super.key,
    required this.onChanged,
    this.onClear,
    this.hintText = 'Search...',
    this.maxWidth = 440.0,
  });

  @override
  State<ToolbarSearchField> createState() => _ToolbarSearchFieldState();
}

class _ToolbarSearchFieldState extends State<ToolbarSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      // Rebuild to show/hide the clear button.
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onClear() {
    _controller.clear();
    widget.onChanged('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryColor = isDark ? AppColorsDark.primary : AppColors.primary;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final hintColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final bgColor = isDark ? AppColorsDark.surface : AppColors.surface;

    return Flexible(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: WindowConstants.toolbarButtonSize,
          maxWidth: widget.maxWidth,
        ),
        child: SizedBox(
          height: WindowConstants.toolbarButtonSize,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            style: AppTextStyles.body.copyWith(color: textColor),
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: AppTextStyles.body.copyWith(color: hintColor),
              filled: true,
              fillColor: bgColor,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.sm,
              ),
              prefixIcon: SizedBox(
                width: WindowConstants.toolbarButtonSize,
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.magnifyingGlass,
                    size: WindowConstants.toolbarButtonIconSize,
                    color: hintColor,
                  ),
                ),
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? GestureDetector(
                      onTap: _onClear,
                      child: SizedBox(
                        width: WindowConstants.toolbarButtonSize,
                        child: Center(
                          child: FaIcon(
                            FontAwesomeIcons.xmark,
                            size: WindowConstants.toolbarButtonIconSize,
                            color: hintColor,
                          ),
                        ),
                      ),
                    )
                  : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                    WindowConstants.toolbarButtonRadius),
                borderSide: BorderSide(color: borderColor, width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                    WindowConstants.toolbarButtonRadius),
                borderSide: BorderSide(color: primaryColor, width: 2.0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
