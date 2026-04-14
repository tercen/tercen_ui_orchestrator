import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_line_weights.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/data_table_provider.dart';

/// Compact search text field for the data table toolbar.
///
/// Shows match count and next/prev navigation buttons when there are results.
class DataTableSearchField extends StatefulWidget {
  const DataTableSearchField({super.key});

  @override
  State<DataTableSearchField> createState() => _DataTableSearchFieldState();
}

class _DataTableSearchFieldState extends State<DataTableSearchField> {
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
    final provider = context.watch<DataTableProvider>();
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final hintColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final fillColor = isDark ? AppColorsDark.surface : AppColors.white;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;

    final hasMatches = provider.searchMatches.isNotEmpty;
    final matchText = provider.searchText.isNotEmpty
        ? (provider.isSearching
            ? '...'
            : '${hasMatches ? provider.currentMatchIndex + 1 : 0}/${provider.searchMatches.length}')
        : null;

    return Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: WindowConstants.toolbarButtonSize,
          maxWidth: 320,
        ),
        child: SizedBox(
          height: WindowConstants.toolbarButtonSize,
          child: Center(
            child: TextField(
              controller: _controller,
              onChanged: (value) {
                final prov = context.read<DataTableProvider>();
                prov.search(value);
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
                    child: provider.isSearching
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: AppLineWeights.lineStandard,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(primary),
                            ),
                          )
                        : FaIcon(
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
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (matchText != null)
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: 4),
                              child: Text(
                                matchText,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: hintColor,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          if (hasMatches) ...[
                            GestureDetector(
                              onTap: () => provider.previousMatch(),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 2),
                                  child: FaIcon(
                                    FontAwesomeIcons.chevronUp,
                                    size: 10,
                                    color: hintColor,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => provider.nextMatch(),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 2),
                                  child: FaIcon(
                                    FontAwesomeIcons.chevronDown,
                                    size: 10,
                                    color: hintColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          GestureDetector(
                            onTap: () {
                              _controller.clear();
                              context
                                  .read<DataTableProvider>()
                                  .search('');
                              setState(() {});
                            },
                            child: SizedBox(
                              width: 24,
                              height: WindowConstants.toolbarButtonSize,
                              child: Center(
                                child: FaIcon(
                                  FontAwesomeIcons.xmark,
                                  size: 12,
                                  color: hintColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : null,
                suffixIconConstraints: BoxConstraints(
                  minWidth: 24,
                  maxWidth: hasMatches ? 140 : 80,
                  minHeight: WindowConstants.toolbarButtonSize,
                  maxHeight: WindowConstants.toolbarButtonSize,
                ),
                filled: true,
                fillColor: fillColor,
                isDense: true,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical:
                      (WindowConstants.toolbarButtonSize - 14) / 2,
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
                  borderSide: BorderSide(color: primary, width: 2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
