import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_line_weights.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/data_table_provider.dart';

/// The main data grid — active body state.
///
/// Uses a single ListView.builder for both row numbers and data columns,
/// ensuring scroll synchronisation. The header scrolls horizontally with
/// the data via linked ScrollControllers.
class ActiveState extends StatefulWidget {
  const ActiveState({super.key});

  @override
  State<ActiveState> createState() => _ActiveStateState();
}

class _ActiveStateState extends State<ActiveState> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _headerHorizontalController = ScrollController();

  // Editing state (UI-only)
  int? _editingRow;
  String? _editingColumn;
  late TextEditingController _editController;

  static const double _rowNumWidth = 56.0;
  static const double _cellWidth = 140.0;
  static const double _rowHeight = 32.0;
  static const double _headerHeight = 36.0;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();

    // Sync horizontal scrolling between header and body
    _horizontalController.addListener(() {
      if (_headerHorizontalController.hasClients) {
        _headerHorizontalController.jumpTo(_horizontalController.offset);
      }
    });
    _headerHorizontalController.addListener(() {
      if (_horizontalController.hasClients) {
        _horizontalController.jumpTo(_headerHorizontalController.offset);
      }
    });
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _headerHorizontalController.dispose();
    _editController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<DataTableProvider>();
    final goTo = provider.goToRowValue;
    if (goTo != null && _verticalController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetOffset = goTo * _rowHeight;
        if (_verticalController.hasClients) {
          _verticalController.animateTo(
            targetOffset.clamp(
                0.0, _verticalController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _startEditing(int row, String column, dynamic currentValue) {
    setState(() {
      _editingRow = row;
      _editingColumn = column;
      _editController.text = currentValue?.toString() ?? '';
    });
  }

  void _commitEdit(DataTableProvider provider) {
    if (_editingRow != null && _editingColumn != null) {
      final text = _editController.text;
      final numVal = double.tryParse(text);
      provider.editCell(_editingRow!, _editingColumn!, numVal ?? text);
    }
    setState(() {
      _editingRow = null;
      _editingColumn = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingRow = null;
      _editingColumn = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataTableProvider>();
    final schema = provider.schema;
    final rows = provider.loadedRows?.rows ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (schema == null) return const SizedBox.shrink();

    final columns = schema.columns;
    final totalDataWidth = columns.length * _cellWidth;

    final headerBg =
        isDark ? AppColorsDark.surfaceElevated : AppColors.neutral100;
    final borderColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final mutedColor =
        isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final searchHighlight =
        isDark ? const Color(0x40FBBF24) : const Color(0x40F59E0B);
    final focusedHighlight =
        isDark ? const Color(0x80FBBF24) : const Color(0x80F59E0B);
    final editedBg =
        isDark ? const Color(0x3014B8A6) : const Color(0x301E40AF);
    final goToHighlight =
        isDark ? const Color(0x60FBBF24) : const Color(0x60FDE68A);
    final sortIconColor =
        isDark ? AppColorsDark.primary : AppColors.primary;
    final rowAltBg =
        isDark ? AppColorsDark.surface : AppColors.surface;
    final rowBg =
        isDark ? AppColorsDark.panelBackground : AppColors.panelBackground;

    return Column(
      children: [
        if (provider.isSorting)
          LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(sortIconColor),
          ),
        // Header row
        SizedBox(
          height: _headerHeight,
          child: Row(
            children: [
              Container(
                width: _rowNumWidth,
                height: _headerHeight,
                decoration: BoxDecoration(
                  color: headerBg,
                  border: Border(
                    right: BorderSide(
                        color: borderColor,
                        width: AppLineWeights.lineSubtle),
                    bottom: BorderSide(
                        color: borderColor,
                        width: AppLineWeights.lineSubtle),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#',
                  style:
                      AppTextStyles.labelSmall.copyWith(color: mutedColor),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _headerHorizontalController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    children: [
                      for (int c = 0; c < columns.length; c++)
                        _ColumnHeader(
                          column: columns[c],
                          width: _cellWidth,
                          height: _headerHeight,
                          isSorted:
                              provider.sortColumn == columns[c].name,
                          ascending: provider.sortAscending,
                          isSorting: provider.isSorting,
                          onSort: () => provider.sort(columns[c].name),
                          headerBg: headerBg,
                          borderColor: borderColor,
                          textColor: textColor,
                          sortIconColor: sortIconColor,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Data rows — single ListView for row numbers + data
        Expanded(
          child: _buildDataArea(
            provider: provider,
            rows: rows,
            columns: columns,
            isDark: isDark,
            totalDataWidth: totalDataWidth,
            borderColor: borderColor,
            textColor: textColor,
            mutedColor: mutedColor,
            searchHighlight: searchHighlight,
            focusedHighlight: focusedHighlight,
            editedBg: editedBg,
            goToHighlight: goToHighlight,
            rowBg: rowBg,
            rowAltBg: rowAltBg,
          ),
        ),
      ],
    );
  }

  Widget _buildDataArea({
    required DataTableProvider provider,
    required List<Map<String, dynamic>> rows,
    required List columns,
    required bool isDark,
    required double totalDataWidth,
    required Color borderColor,
    required Color textColor,
    required Color mutedColor,
    required Color searchHighlight,
    required Color focusedHighlight,
    required Color editedBg,
    required Color goToHighlight,
    required Color rowBg,
    required Color rowAltBg,
  }) {
    if (rows.isEmpty && provider.isLoadingPage) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: AppLineWeights.lineEmphasis,
            valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppColorsDark.primary : AppColors.primary),
          ),
        ),
      );
    }

    final itemCount = rows.length + (provider.isLoadingPage ? 1 : 0);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          final metrics = notification.metrics;
          if (metrics.pixels >= metrics.maxScrollExtent - 200) {
            final currentCount = rows.length;
            if (currentCount < provider.totalRows &&
                !provider.isLoadingPage) {
              provider.loadPage(currentCount, DataTableProvider.pageSize);
            }
          }
        }
        return false;
      },
      // Single ListView that renders each row as row-number + data cells
      child: ListView.builder(
        controller: _verticalController,
        itemCount: itemCount,
        itemExtent: _rowHeight,
        itemBuilder: (context, rowIndex) {
          if (rowIndex >= rows.length) {
            return _buildLoadingRow(
                borderColor, mutedColor, columns.length);
          }

          final row = rows[rowIndex];
          final isGoToRow = provider.goToRowValue == rowIndex;
          final bgColor = isGoToRow
              ? goToHighlight
              : (rowIndex.isEven ? rowBg : rowAltBg);

          return Container(
            height: _rowHeight,
            color: bgColor,
            child: Row(
              children: [
                // Row number (fixed)
                Container(
                  width: _rowNumWidth,
                  height: _rowHeight,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                          color: borderColor,
                          width: AppLineWeights.lineSubtle),
                      bottom: BorderSide(
                          color: borderColor,
                          width: AppLineWeights.lineSubtle),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$rowIndex',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: mutedColor,
                      height: 1.0,
                    ),
                  ),
                ),
                // Data cells (horizontally scrollable)
                Expanded(
                  child: SingleChildScrollView(
                    controller: rowIndex == 0
                        ? _horizontalController
                        : null,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: Row(
                      children: [
                        for (int c = 0; c < columns.length; c++)
                          _buildCell(
                            rowIndex: rowIndex,
                            column: columns[c],
                            value: row[columns[c].name],
                            provider: provider,
                            textColor: textColor,
                            borderColor: borderColor,
                            searchHighlight: searchHighlight,
                            focusedHighlight: focusedHighlight,
                            editedBg: editedBg,
                            isDark: isDark,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingRow(Color borderColor, Color mutedColor, int colCount) {
    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: borderColor, width: AppLineWeights.lineSubtle),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: _rowNumWidth,
            alignment: Alignment.center,
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: AppLineWeights.lineStandard,
                valueColor: AlwaysStoppedAnimation<Color>(mutedColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell({
    required int rowIndex,
    required dynamic column,
    required dynamic value,
    required DataTableProvider provider,
    required Color textColor,
    required Color borderColor,
    required Color searchHighlight,
    required Color focusedHighlight,
    required Color editedBg,
    required bool isDark,
  }) {
    final colName = column.name as String;
    final colType = column.type as String;
    final isNumeric = colType == 'double' ||
        colType == 'int32' ||
        colType == 'uint64' ||
        colType == 'uint16';

    final editedVal = provider.getEditedValue(rowIndex, colName);
    final isEdited = provider.isCellEdited(rowIndex, colName);
    final displayValue = isEdited ? editedVal : value;

    final isMatch = provider.isCellSearchMatch(rowIndex, colName);
    final isFocusedMatch = provider.isCellCurrentMatch(rowIndex, colName);

    Color? cellBg;
    if (isFocusedMatch) {
      cellBg = focusedHighlight;
    } else if (isMatch) {
      cellBg = searchHighlight;
    } else if (isEdited) {
      cellBg = editedBg;
    }

    final isEditingThis =
        _editingRow == rowIndex && _editingColumn == colName;

    if (isEditingThis && provider.annotationMode) {
      return Container(
        width: _cellWidth,
        height: _rowHeight * 2,
        decoration: BoxDecoration(
          color: cellBg ?? (isDark ? AppColorsDark.surface : AppColors.surface),
          border: Border(
            right: BorderSide(
                color: borderColor, width: AppLineWeights.lineSubtle),
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: TextField(
          controller: _editController,
          autofocus: true,
          expands: true,
          maxLines: null,
          minLines: null,
          style: AppTextStyles.body.copyWith(
            color: textColor,
          ),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: isDark ? AppColorsDark.primary : AppColors.primary,
                width: AppLineWeights.lineEmphasis,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: isDark ? AppColorsDark.primary : AppColors.primary,
                width: AppLineWeights.lineEmphasis,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          ),
          onSubmitted: (_) => _commitEdit(provider),
          onTapOutside: (_) => _commitEdit(provider),
        ),
      );
    }

    // Format display value
    String displayText;
    if (displayValue == null) {
      displayText = '';
    } else if (isNumeric && displayValue is num) {
      displayText = displayValue
          .toStringAsPrecision(displayValue.abs() >= 1 ? 6 : 4)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
      if (displayText.contains('e') || displayText.length > 12) {
        displayText = displayValue.toString();
      }
    } else {
      displayText = displayValue.toString();
    }

    return GestureDetector(
      onTap: provider.annotationMode
          ? () => _startEditing(rowIndex, colName, displayValue)
          : null,
      child: Tooltip(
        message: '$colName: $displayText',
        waitDuration: const Duration(milliseconds: 500),
        child: Container(
          width: _cellWidth,
          height: _rowHeight,
          decoration: BoxDecoration(
            color: cellBg,
            border: Border(
              right: BorderSide(
                  color: borderColor, width: AppLineWeights.lineSubtle),
              bottom: BorderSide(
                  color: borderColor, width: AppLineWeights.lineSubtle),
            ),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          alignment:
              isNumeric ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            displayText,
            style: AppTextStyles.bodySmall.copyWith(
              color: textColor,
              height: 1.0,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

/// Column header widget with sort indicator.
class _ColumnHeader extends StatefulWidget {
  final dynamic column;
  final double width;
  final double height;
  final bool isSorted;
  final bool ascending;
  final bool isSorting;
  final VoidCallback onSort;
  final Color headerBg;
  final Color borderColor;
  final Color textColor;
  final Color sortIconColor;

  const _ColumnHeader({
    required this.column,
    required this.width,
    required this.height,
    required this.isSorted,
    required this.ascending,
    required this.isSorting,
    required this.onSort,
    required this.headerBg,
    required this.borderColor,
    required this.textColor,
    required this.sortIconColor,
  });

  @override
  State<_ColumnHeader> createState() => _ColumnHeaderState();
}

class _ColumnHeaderState extends State<_ColumnHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.isSorting
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.isSorting ? null : widget.onSort,
        child: Tooltip(
          message: '${widget.column.name} (${widget.column.type})',
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.borderColor.withValues(alpha: 0.3)
                  : widget.headerBg,
              border: Border(
                right: BorderSide(
                    color: widget.borderColor,
                    width: AppLineWeights.lineSubtle),
                bottom: BorderSide(
                    color: widget.borderColor,
                    width: AppLineWeights.lineSubtle),
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.column.name,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: widget.textColor,
                      height: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (widget.isSorted) ...[
                  const SizedBox(width: 2),
                  FaIcon(
                    widget.ascending
                        ? FontAwesomeIcons.arrowUp
                        : FontAwesomeIcons.arrowDown,
                    size: 10,
                    color: widget.sortIconColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
