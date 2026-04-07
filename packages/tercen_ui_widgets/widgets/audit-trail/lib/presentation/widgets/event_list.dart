import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_line_weights.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/audit_event.dart';
import '../providers/audit_trail_provider.dart';
import 'column_filter_popup.dart';
import 'date_range_filter_popup.dart';
import 'event_type_chip.dart';

/// Full-width event table with dynamic column visibility and resizable widths.
class EventList extends StatefulWidget {
  const EventList({super.key});

  @override
  State<EventList> createState() => _EventListState();
}

class _EventListState extends State<EventList> {
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _hScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _verticalScroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _verticalScroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_verticalScroll.position.pixels >=
        _verticalScroll.position.maxScrollExtent - 100) {
      context.read<AuditTrailProvider>().loadMore();
    }
  }

  /// Total row width = checkbox + all visible column widths.
  double _totalRowWidth(AuditTrailProvider provider) {
    double w = 32; // checkbox column
    for (final col in provider.visibleColumnDefs) {
      w += provider.getColumnWidth(col.key);
    }
    return w;
  }

  void _showColumnFilter(BuildContext context, GlobalKey headerKey,
      String columnKey, String label) {
    final provider = context.read<AuditTrailProvider>();
    final colDef =
        AuditTrailProvider.allColumns.firstWhere((c) => c.key == columnKey);

    // Position popup under the header cell.
    final RenderBox? box =
        headerKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset offset = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final double top = offset.dy + (box?.size.height ?? 28);

    if (colDef.isDate) {
      _showDateRangeFilter(
          context, provider, columnKey, label, offset.dx, top);
    } else {
      final allValues = provider.getColumnValues(columnKey);
      final currentFilter = provider.columnFilters[columnKey] ?? allValues;

      showDialog(
        context: context,
        barrierColor: Colors.transparent,
        builder: (ctx) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: offset.dx,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: ColumnFilterPopup(
                  columnName: label,
                  allValues: allValues,
                  checkedValues: currentFilter,
                  onChanged: (values) =>
                      provider.setColumnFilter(columnKey, values),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showDateRangeFilter(BuildContext context,
      AuditTrailProvider provider, String columnKey, String label,
      double left, double top) {
    final existing = provider.dateRangeFilters[columnKey];

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: Material(
              color: Colors.transparent,
              child: DateRangeFilterPopup(
                columnName: label,
                initialRange: existing,
                onApply: (range) {
                  provider.setDateRangeFilter(columnKey, range);
                  Navigator.of(ctx).pop();
                },
                onClear: () {
                  provider.clearDateRangeFilter(columnKey);
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<AuditTrailProvider>();
    final events = provider.filteredEvents;
    final columns = provider.visibleColumnDefs;
    final totalWidth = _totalRowWidth(provider);

    final headerBg =
        isDark ? AppColorsDark.surfaceElevated : AppColors.neutral100;
    final borderColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final effectiveWidth =
            totalWidth > viewportWidth ? totalWidth : viewportWidth;
        final needsHScroll = totalWidth > viewportWidth;

        return Scrollbar(
          controller: _hScroll,
          thumbVisibility: needsHScroll,
          child: SingleChildScrollView(
            controller: _hScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: effectiveWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: headerBg,
                      border: Border(
                        bottom: BorderSide(
                          color: borderColor,
                          width: AppLineWeights.lineSubtle,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Select All checkbox
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (provider.multiSelectedCount ==
                                events.length &&
                                events.isNotEmpty) {
                              provider.clearMultiSelection();
                            } else {
                              provider.selectAll();
                            }
                          },
                          child: SizedBox(
                            width: 32,
                            child: Center(
                              child: Icon(
                                provider.multiSelectedCount == events.length &&
                                        events.isNotEmpty
                                    ? Icons.check_box
                                    : provider.multiSelectedCount > 0
                                        ? Icons.indeterminate_check_box
                                        : Icons.check_box_outline_blank,
                                size: 18,
                                color: provider.multiSelectedCount > 0
                                    ? (isDark
                                        ? AppColorsDark.primary
                                        : AppColors.primary)
                                    : (isDark
                                        ? AppColorsDark.textMuted
                                        : AppColors.textMuted),
                              ),
                            ),
                          ),
                        ),
                        for (final col in columns)
                          _ResizableHeader(
                            key: ValueKey('hdr_${col.key}'),
                            col: col,
                            width: provider.getColumnWidth(col.key),
                            onResize: (delta) {
                              final cur = provider.getColumnWidth(col.key);
                              provider.setColumnWidth(col.key, cur + delta);
                            },
                            onFilterTap: (headerKey) {
                              _showColumnFilter(
                                  context, headerKey, col.key, col.label);
                            },
                            isFilterActive:
                                provider.isColumnFilterActive(col.key) ||
                                    provider.isDateRangeFilterActive(col.key),
                          ),
                      ],
                    ),
                  ),
                  // ── Rows ──
                  Expanded(
                    child: events.isEmpty
                        ? _buildEmptyFilters(context)
                        : Scrollbar(
                            controller: _verticalScroll,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _verticalScroll,
                              itemCount: events.length +
                                  (provider.isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == events.length) {
                                  return _buildLoadingMore(context);
                                }
                                return _EventRow(
                                  event: events[index],
                                  columns: columns,
                                  isSelected:
                                      provider.selectedEvent?.id ==
                                          events[index].id,
                                  isMultiSelected: provider
                                      .isMultiSelected(events[index].id),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyFilters(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_list_off, size: 32, color: textColor),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No events match the current filters',
            style: AppTextStyles.body.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMore(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(primary),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resizable header cell
// ─────────────────────────────────────────────────────────────────────────────

class _ResizableHeader extends StatefulWidget {
  final ColumnDef col;
  final double width;
  final ValueChanged<double> onResize;
  final void Function(GlobalKey headerKey) onFilterTap;
  final bool isFilterActive;

  const _ResizableHeader({
    super.key,
    required this.col,
    required this.width,
    required this.onResize,
    required this.onFilterTap,
    required this.isFilterActive,
  });

  @override
  State<_ResizableHeader> createState() => _ResizableHeaderState();
}

class _ResizableHeaderState extends State<_ResizableHeader> {
  final GlobalKey _headerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final activeColor = isDark ? AppColorsDark.primary : AppColors.primary;
    final borderColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;

    return SizedBox(
      key: _headerKey,
      width: widget.width,
      child: Row(
        children: [
          // Header content (clickable for filter)
          Expanded(
            child: InkWell(
              onTap: () => widget.onFilterTap(_headerKey),
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.col.label,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.filter_list,
                      size: 12,
                      color:
                          widget.isFilterActive ? activeColor : textColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Drag handle for resize
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                widget.onResize(details.delta.dx);
              },
              child: Container(
                width: 5,
                height: double.infinity,
                color: borderColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event row
// ─────────────────────────────────────────────────────────────────────────────

class _EventRow extends StatelessWidget {
  final AuditEvent event;
  final List<ColumnDef> columns;
  final bool isSelected;
  final bool isMultiSelected;

  static final DateFormat _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  const _EventRow({
    required this.event,
    required this.columns,
    required this.isSelected,
    required this.isMultiSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.read<AuditTrailProvider>();

    final selectedBg =
        isDark ? AppColorsDark.primarySurface : AppColors.primarySurface;
    final multiSelectedBg = isDark
        ? AppColorsDark.primary.withValues(alpha: 0.08)
        : AppColors.primary.withValues(alpha: 0.06);
    final hoverBg = isDark ? AppColorsDark.neutral800 : AppColors.neutral50;
    final borderColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;

    Color rowBg;
    if (isSelected) {
      rowBg = selectedBg;
    } else if (isMultiSelected) {
      rowBg = multiSelectedBg;
    } else {
      rowBg = Colors.transparent;
    }

    return Material(
      color: rowBg,
      child: InkWell(
        hoverColor: hoverBg,
        onTap: () {
          final isCtrl = HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;
          final isShift = HardwareKeyboard.instance.isShiftPressed;

          if (isCtrl) {
            provider.toggleMultiSelect(event);
          } else if (isShift) {
            provider.shiftSelect(event);
          } else {
            provider.selectEvent(event);
          }
        },
        onDoubleTap: () => provider.navigateToTarget(event),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: borderColor,
                width: AppLineWeights.lineSubtle,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
          child: Row(
            children: [
              // Checkbox — separate tap target
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => provider.toggleMultiSelect(event),
                child: SizedBox(
                  width: 32,
                  height: 24,
                  child: Center(child: _buildCheckbox(context)),
                ),
              ),
              // Dynamic columns — each at its stored width
              for (final col in columns)
                SizedBox(
                  width: provider.getColumnWidth(col.key),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, right: 4),
                      child: _buildCell(context, col.key),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;

    if (isMultiSelected) {
      return Icon(
        Icons.check_box,
        size: 18,
        color: isDark ? AppColorsDark.primary : AppColors.primary,
      );
    }
    return Icon(
      Icons.check_box_outline_blank,
      size: 18,
      color: mutedColor.withValues(alpha: 0.4),
    );
  }

  Widget _buildCell(BuildContext context, String key) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final linkColor = isDark ? AppColorsDark.link : AppColors.link;
    final provider = context.read<AuditTrailProvider>();

    switch (key) {
      case 'date':
        return Text(
          _dateFmt.format(event.displayDate),
          style: AppTextStyles.bodySmall.copyWith(color: mutedColor),
          overflow: TextOverflow.ellipsis,
        );
      case 'type':
        return EventTypeChip(eventType: event.eventType, compact: true);
      case 'target':
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => provider.navigateToTarget(event),
            child: Text(
              event.targetName,
              style: AppTextStyles.body.copyWith(
                color: linkColor,
                decoration: TextDecoration.underline,
                decorationColor: linkColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case 'error':
        final error = event.details['error'] ?? '';
        if (error.isEmpty) return const SizedBox.shrink();
        final errorColor = isDark ? AppColorsDark.error : AppColors.error;
        return Text(
          error,
          style: AppTextStyles.bodySmall.copyWith(color: errorColor),
          overflow: TextOverflow.ellipsis,
        );
      case 'duration':
        return Text(
          _formatDuration(event.details['duration'] ?? ''),
          style: AppTextStyles.bodySmall.copyWith(color: textColor),
          overflow: TextOverflow.ellipsis,
        );
      default:
        final value = provider.getColumnDisplayValue(event, key);
        return Text(
          value,
          style: AppTextStyles.body.copyWith(color: textColor),
          overflow: TextOverflow.ellipsis,
        );
    }
  }

  String _formatDuration(String seconds) {
    if (seconds.isEmpty) return '';
    final secs = double.tryParse(seconds) ?? 0;
    final mins = (secs / 60).floor();
    final remainSecs = (secs % 60).floor();
    if (mins > 0) return '${mins}m ${remainSecs}s';
    return '${remainSecs}s';
  }
}
