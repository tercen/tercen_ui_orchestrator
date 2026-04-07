import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Excel-style column header filter popup.
///
/// Spec Section 5.5: clicking a column header opens a popup with checkboxes
/// for each unique value in that column.
class ColumnFilterPopup extends StatefulWidget {
  final String columnName;
  final Set<String> allValues;
  final Set<String> checkedValues;
  /// Called immediately on every toggle with the current checked set.
  final ValueChanged<Set<String>> onChanged;

  const ColumnFilterPopup({
    super.key,
    required this.columnName,
    required this.allValues,
    required this.checkedValues,
    required this.onChanged,
  });

  @override
  State<ColumnFilterPopup> createState() => _ColumnFilterPopupState();
}

class _ColumnFilterPopupState extends State<ColumnFilterPopup> {
  late Set<String> _checked;

  @override
  void initState() {
    super.initState();
    _checked = Set.from(widget.checkedValues.isEmpty
        ? widget.allValues
        : widget.checkedValues);
  }

  bool get _allChecked => _checked.length == widget.allValues.length;

  void _toggleAll() {
    setState(() {
      if (_allChecked) {
        _checked.clear();
      } else {
        _checked = Set.from(widget.allValues);
      }
    });
    widget.onChanged(Set.from(_checked));
  }

  void _toggle(String value) {
    setState(() {
      if (_checked.contains(value)) {
        _checked.remove(value);
      } else {
        _checked.add(value);
      }
    });
    widget.onChanged(Set.from(_checked));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColorsDark.surfaceElevated : AppColors.surface;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;

    final sortedValues = widget.allValues.toList()..sort();

    return Container(
      width: 220,
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Select All / Deselect All
          InkWell(
            onTap: _toggleAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _allChecked,
                      tristate: true,
                      onChanged: (_) => _toggleAll(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _allChecked ? 'Deselect All' : 'Select All',
                    style: AppTextStyles.labelSmall.copyWith(color: mutedColor),
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            color: borderColor,
          ),
          // Values list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              itemCount: sortedValues.length,
              itemBuilder: (context, index) {
                final value = sortedValues[index];
                final isChecked = _checked.contains(value);
                return InkWell(
                  onTap: () => _toggle(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: isChecked,
                            onChanged: (_) => _toggle(value),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            value,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: textColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Column header with filter icon that opens the filter popup.
class FilterableColumnHeader extends StatelessWidget {
  final String label;
  final String columnKey;
  final bool isFilterActive;
  final VoidCallback onTap;

  const FilterableColumnHeader({
    super.key,
    required this.label,
    required this.columnKey,
    required this.isFilterActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final activeColor = isDark ? AppColorsDark.primary : AppColors.primary;

    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 3),
          FaIcon(
            FontAwesomeIcons.filter,
            size: 10,
            color: isFilterActive ? activeColor : textColor,
          ),
        ],
      ),
    );
  }
}
