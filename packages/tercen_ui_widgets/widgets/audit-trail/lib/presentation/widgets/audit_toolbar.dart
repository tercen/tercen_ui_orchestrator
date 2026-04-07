import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/audit_trail_provider.dart';
import 'app_snackbar.dart';
import 'window_toolbar.dart';

/// Toolbar for the Audit Trail window.
///
/// Left-aligned: Columns (icon), Sort, Export CSV, Search, Send to Chat.
class AuditToolbar extends StatefulWidget {
  const AuditToolbar({super.key});

  @override
  State<AuditToolbar> createState() => _AuditToolbarState();
}

class _AuditToolbarState extends State<AuditToolbar> {
  bool _sendConfirmation = false;

  void _showColumnsMenu(BuildContext context) {
    final provider = context.read<AuditTrailProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renderBox = context.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return Stack(
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
              top: offset.dy + 48,
              child: Material(
                color: Colors.transparent,
                child: _ColumnsMenu(provider: provider, isDark: isDark),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleSendToChat(AuditTrailProvider provider) {
    provider.sendToChat();
    setState(() => _sendConfirmation = true);

    showAppSnackbar(
      context,
      type: SnackbarType.success,
      message: 'Sent ${provider.multiSelectedCount} events to Chat',
      duration: const Duration(seconds: 2),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _sendConfirmation = false);
    });
  }

  void _handleExportCsv(AuditTrailProvider provider) {
    final csv = provider.exportCsv();
    final filename = provider.exportFilename;

    final bytes = utf8.encode(csv);
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'text/csv'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;
    web.document.body!.appendChild(anchor);
    anchor.click();
    web.document.body!.removeChild(anchor);
    web.URL.revokeObjectURL(url);

    showAppSnackbar(
      context,
      type: SnackbarType.success,
      message: 'Exported $filename',
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuditTrailProvider>();
    final hasEvents = provider.filteredEvents.isNotEmpty;
    final hasMultiSelect = provider.multiSelectedCount > 0;

    // All left-aligned: Columns, Sort, Export, Search, Send to Chat
    return WindowToolbar(
      actions: [
        // 1. Columns visibility (icon-only)
        ToolbarAction(
          icon: FontAwesomeIcons.tableColumns,
          tooltip: 'Columns',
          onPressed: () => _showColumnsMenu(context),
        ),
        // 2. Sort toggle
        ToolbarAction(
          icon: provider.newestFirst
              ? FontAwesomeIcons.arrowDownWideShort
              : FontAwesomeIcons.arrowUpWideShort,
          tooltip:
              provider.newestFirst ? 'Sort: Newest first' : 'Sort: Oldest first',
          onPressed: () => provider.toggleSort(),
        ),
        // 3. Export CSV
        ToolbarAction(
          icon: FontAwesomeIcons.fileExport,
          tooltip: 'Export CSV',
          onPressed: hasEvents ? () => _handleExportCsv(provider) : null,
        ),
      ],
      // Search + Send to Chat left-aligned after action buttons
      trailing: _TrailingGroup(
        sendConfirmation: _sendConfirmation,
        hasMultiSelect: hasMultiSelect,
        onSearch: (value) => provider.setSearchText(value),
        onSendToChat: hasMultiSelect ? () => _handleSendToChat(provider) : null,
      ),
    );
  }
}

/// Trailing group: Search field + Send to Chat button, left-aligned.
class _TrailingGroup extends StatefulWidget {
  final bool sendConfirmation;
  final bool hasMultiSelect;
  final ValueChanged<String> onSearch;
  final VoidCallback? onSendToChat;

  const _TrailingGroup({
    required this.sendConfirmation,
    required this.hasMultiSelect,
    required this.onSearch,
    this.onSendToChat,
  });

  @override
  State<_TrailingGroup> createState() => _TrailingGroupState();
}

class _TrailingGroupState extends State<_TrailingGroup> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Inline search field (not wrapped in Flexible)
        SizedBox(
          width: 220,
          height: 36,
          child: TextField(
            controller: _searchController,
            style: AppTextStyles.body.copyWith(color: textColor),
            onChanged: widget.onSearch,
            decoration: InputDecoration(
              hintText: 'Search events...',
              hintStyle: AppTextStyles.body.copyWith(color: hintColor),
              filled: true,
              fillColor: bgColor,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.sm,
              ),
              prefixIcon: SizedBox(
                width: 36,
                child: Center(
                  child: Icon(Icons.search, size: 16, color: hintColor),
                ),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        widget.onSearch('');
                      },
                      child: SizedBox(
                        width: 36,
                        child: Center(
                          child:
                              Icon(Icons.close, size: 16, color: hintColor),
                        ),
                      ),
                    )
                  : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: BorderSide(color: borderColor, width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: BorderSide(color: primaryColor, width: 2.0),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _buildSendButton(context),
      ],
    );
  }

  Widget _buildSendButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;

    return Tooltip(
      message: 'Send to Chat',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onSendToChat,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(
              widget.sendConfirmation
                  ? FontAwesomeIcons.check
                  : FontAwesomeIcons.paperPlane,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Popup menu for toggling column visibility with checkboxes.
class _ColumnsMenu extends StatefulWidget {
  final AuditTrailProvider provider;
  final bool isDark;

  const _ColumnsMenu({required this.provider, required this.isDark});

  @override
  State<_ColumnsMenu> createState() => _ColumnsMenuState();
}

class _ColumnsMenuState extends State<_ColumnsMenu> {
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark ? AppColorsDark.surfaceElevated : AppColors.surface;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;

    final allCols = AuditTrailProvider.allColumns;
    final visible = widget.provider.visibleColumns;
    final allVisible = visible.length == allCols.length;

    return Container(
      width: 200,
      constraints: const BoxConstraints(maxHeight: 420),
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show All / Reset toggle
            InkWell(
              onTap: () {
                for (final col in allCols) {
                  if (allVisible) {
                    if (!col.defaultVisible &&
                        widget.provider.isColumnVisible(col.key)) {
                      widget.provider.toggleColumnVisibility(col.key);
                    } else if (col.defaultVisible &&
                        !widget.provider.isColumnVisible(col.key)) {
                      widget.provider.toggleColumnVisibility(col.key);
                    }
                  } else {
                    if (!widget.provider.isColumnVisible(col.key)) {
                      widget.provider.toggleColumnVisibility(col.key);
                    }
                  }
                }
                setState(() {});
              },
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
                        value: allVisible,
                        onChanged: (_) {},
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      allVisible ? 'Reset to Defaults' : 'Show All',
                      style:
                          AppTextStyles.labelSmall.copyWith(color: mutedColor),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: borderColor),
            for (final col in allCols)
              InkWell(
                onTap: () {
                  widget.provider.toggleColumnVisibility(col.key);
                  setState(() {});
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: visible.contains(col.key),
                          onChanged: (_) {
                            widget.provider.toggleColumnVisibility(col.key);
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        col.label,
                        style:
                            AppTextStyles.bodySmall.copyWith(color: textColor),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
