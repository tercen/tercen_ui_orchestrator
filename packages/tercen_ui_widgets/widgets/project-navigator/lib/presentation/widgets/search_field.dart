import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/navigator_provider.dart';

/// Compact search text field for the toolbar.
///
/// Exactly 36px tall to match toolbar buttons, vertically centred in the
/// 48px toolbar. Uses Flexible + ConstrainedBox(maxWidth: 440) so it
/// takes available space but shrinks when the window is narrow.
class ToolbarSearchField extends StatefulWidget {
  const ToolbarSearchField({super.key});

  @override
  State<ToolbarSearchField> createState() => _ToolbarSearchFieldState();
}

class _ToolbarSearchFieldState extends State<ToolbarSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final hintColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final fillColor = isDark ? AppColorsDark.surface : AppColors.white;

    return Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: WindowConstants.toolbarButtonSize,
          maxWidth: 440,
        ),
        child: SizedBox(
          height: WindowConstants.toolbarButtonSize,
          child: Center(
            child: TextField(
              controller: _controller,
              onChanged: (value) {
                context.read<NavigatorProvider>().setSearchText(value);
                setState(() {});
              },
              style: AppTextStyles.body.copyWith(
                color: textColor,
                height: 1.0,
              ),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: AppTextStyles.body.copyWith(
                  color: hintColor,
                  height: 1.0,
                ),
                prefixIcon: SizedBox(
                  width: 36,
                  height: WindowConstants.toolbarButtonSize,
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.magnifyingGlass,
                      size: 16,
                      color: hintColor,
                    ),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  maxWidth: 36,
                  minHeight: WindowConstants.toolbarButtonSize,
                  maxHeight: WindowConstants.toolbarButtonSize,
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _controller.clear();
                          context
                              .read<NavigatorProvider>()
                              .setSearchText('');
                          setState(() {});
                        },
                        child: SizedBox(
                          width: 32,
                          height: WindowConstants.toolbarButtonSize,
                          child: Center(
                            child: FaIcon(
                              FontAwesomeIcons.xmark,
                              size: 16,
                              color: hintColor,
                            ),
                          ),
                        ),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  maxWidth: 32,
                  minHeight: WindowConstants.toolbarButtonSize,
                  maxHeight: WindowConstants.toolbarButtonSize,
                ),
                filled: true,
                fillColor: fillColor,
                isDense: true,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: (WindowConstants.toolbarButtonSize - 14) / 2,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                      WindowConstants.toolbarButtonRadius),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                      WindowConstants.toolbarButtonRadius),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                      WindowConstants.toolbarButtonRadius),
                  borderSide: BorderSide(
                    color:
                        isDark ? AppColorsDark.primary : AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
