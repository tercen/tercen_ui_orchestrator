import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Inline date-time range filter with editable text fields.
///
/// From/To rows each have date (yyyy-MM-dd) and time (HH:mm) text inputs.
/// Changes apply immediately on valid input; a Clear link resets the filter.
class DateRangeFilterPopup extends StatefulWidget {
  final String columnName;
  final DateTimeRange? initialRange;
  final ValueChanged<DateTimeRange> onApply;
  final VoidCallback onClear;

  const DateRangeFilterPopup({
    super.key,
    required this.columnName,
    this.initialRange,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<DateRangeFilterPopup> createState() => _DateRangeFilterPopupState();
}

class _DateRangeFilterPopupState extends State<DateRangeFilterPopup> {
  late final TextEditingController _fromDateCtl;
  late final TextEditingController _fromTimeCtl;
  late final TextEditingController _toDateCtl;
  late final TextEditingController _toTimeCtl;

  @override
  void initState() {
    super.initState();
    final from = widget.initialRange?.start ?? DateTime(2020);
    final to = widget.initialRange?.end ?? DateTime.now();

    _fromDateCtl = TextEditingController(text: _fmtDate(from));
    _fromTimeCtl = TextEditingController(text: _fmtTime(from));
    _toDateCtl = TextEditingController(text: _fmtDate(to));
    _toTimeCtl = TextEditingController(text: _fmtTime(to));
  }

  @override
  void dispose() {
    _fromDateCtl.dispose();
    _fromTimeCtl.dispose();
    _toDateCtl.dispose();
    _toTimeCtl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _tryApply() {
    final from = _parse(_fromDateCtl.text, _fromTimeCtl.text);
    final to = _parse(_toDateCtl.text, _toTimeCtl.text);
    if (from != null && to != null && !to.isBefore(from)) {
      widget.onApply(DateTimeRange(start: from, end: to));
    }
  }

  DateTime? _parse(String date, String time) {
    final dp = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(date);
    final tp = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time);
    if (dp == null) return null;
    final y = int.parse(dp.group(1)!);
    final m = int.parse(dp.group(2)!);
    final d = int.parse(dp.group(3)!);
    final h = tp != null ? int.parse(tp.group(1)!) : 0;
    final min = tp != null ? int.parse(tp.group(2)!) : 0;
    return DateTime(y, m, d, h, min);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColorsDark.surfaceElevated : AppColors.surface;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;

    return Container(
      width: 260,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.xs),
            child: Text(
              'Filter ${widget.columnName}',
              style: AppTextStyles.labelSmall.copyWith(color: mutedColor),
            ),
          ),
          Divider(height: 1, color: borderColor),

          // From row
          _buildRow(context, 'From', _fromDateCtl, _fromTimeCtl),
          // To row
          _buildRow(context, 'To', _toDateCtl, _toTimeCtl),

          Divider(height: 1, color: borderColor),

          // Clear link
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onClear,
                child: Text(
                  'Clear filter',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: primary,
                    decoration: TextDecoration.underline,
                    decorationColor: primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label,
      TextEditingController dateCtl, TextEditingController timeCtl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final borderColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(color: mutedColor),
            ),
          ),
          // Date field
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 28,
              child: TextField(
                controller: dateCtl,
                style: AppTextStyles.bodySmall.copyWith(color: textColor),
                decoration: InputDecoration(
                  hintText: 'yyyy-MM-dd',
                  hintStyle:
                      AppTextStyles.bodySmall.copyWith(color: mutedColor),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColorsDark.primary
                          : AppColors.primary,
                    ),
                  ),
                ),
                onChanged: (_) => _tryApply(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Time field
          SizedBox(
            width: 56,
            height: 28,
            child: TextField(
              controller: timeCtl,
              style: AppTextStyles.bodySmall.copyWith(color: textColor),
              decoration: InputDecoration(
                hintText: 'HH:mm',
                hintStyle:
                    AppTextStyles.bodySmall.copyWith(color: mutedColor),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColorsDark.primary
                        : AppColors.primary,
                  ),
                ),
              ),
              onChanged: (_) => _tryApply(),
            ),
          ),
        ],
      ),
    );
  }
}
