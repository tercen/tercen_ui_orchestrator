import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/data_table_provider.dart';
import '../widgets/mock_tab_strip.dart';
import '../widgets/data_table_search_field.dart';
import '../widgets/body_states/active_state.dart';
import '../widgets/info_popover.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/models/table_schema.dart';
import '../widgets/window_shell.dart';

/// The main screen for the Data Table window.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _goToRowController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DataTableProvider>();
      provider.confirmationCallback = _showConfirmation;
    });
  }

  Future<bool> _showConfirmation(BuildContext ctx, String message) async {
    final result = await showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _goToRowController.dispose();
    super.dispose();
  }

  String _tableKindLabel(TableKind kind) {
    switch (kind) {
      case TableKind.tableSchema:
        return 'Table Schema';
      case TableKind.computedTableSchema:
        return 'Computed Table';
      case TableKind.cubeQueryTableSchema:
        return 'Cube Query Table';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataTableProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final fillColor = isDark ? AppColorsDark.surface : AppColors.white;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;

    // All icon-only buttons use secondary (outlined primary accent).
    // Toggled/emphasized states use primary (filled).
    final actions = <ToolbarAction>[
      ToolbarAction(
        icon: FontAwesomeIcons.circleInfo,
        tooltip: 'Table Info',
        variant: ButtonVariant.secondary,
        onPressed: provider.schema != null
            ? () => InfoPopover.show(
                context, provider.schema!, _tableKindLabel(provider.tableKind))
            : null,
      ),
      ToolbarAction(
        icon: provider.isDownloading
            ? FontAwesomeIcons.spinner
            : FontAwesomeIcons.download,
        tooltip: 'Download CSV',
        variant: ButtonVariant.secondary,
        onPressed: provider.isDownloading ? null : () => provider.exportCsv(),
      ),
      ToolbarAction(
        icon: FontAwesomeIcons.penToSquare,
        tooltip: 'Annotation Mode',
        variant: provider.annotationMode
            ? ButtonVariant.primary
            : ButtonVariant.secondary,
        onPressed: () => provider.toggleAnnotationMode(context),
      ),
    ];

    if (provider.annotationMode) {
      // Save — icon-only, disabled when no edits, primary when active
      actions.add(ToolbarAction(
        icon: provider.isSaving
            ? FontAwesomeIcons.spinner
            : FontAwesomeIcons.floppyDisk,
        tooltip: 'Save Annotations',
        variant: (provider.editCount > 0 && !provider.isSaving)
            ? ButtonVariant.primary
            : ButtonVariant.secondary,
        onPressed: (provider.editCount > 0 && !provider.isSaving)
            ? () => provider.saveAnnotations()
            : null,
      ));
      actions.add(ToolbarAction(
        icon: FontAwesomeIcons.xmark,
        tooltip: 'Discard Changes',
        variant: ButtonVariant.secondary,
        onPressed: () => provider.discardAnnotations(context),
      ));
    }

    // Trailing: go-to-row + search
    final trailing = <Widget>[
      const SizedBox(width: 4),
      ConstrainedBox(
        constraints: BoxConstraints.tightFor(
          width: 72,
          height: WindowConstants.toolbarButtonSize,
        ),
        child: TextField(
          controller: _goToRowController,
          expands: true,
          maxLines: null,
          minLines: null,
          style: AppTextStyles.body.copyWith(
            color: textColor,
          ),
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.number,
          onSubmitted: (value) {
            final row = int.tryParse(value);
            if (row != null) {
              provider.goToRow(row);
            }
            _goToRowController.clear();
          },
          decoration: InputDecoration(
            hintText: 'Row',
            hintStyle: AppTextStyles.body.copyWith(
              color: mutedColor,
            ),
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(WindowConstants.toolbarButtonRadius),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(WindowConstants.toolbarButtonRadius),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(WindowConstants.toolbarButtonRadius),
              borderSide: BorderSide(
                color: isDark ? AppColorsDark.primary : AppColors.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      const DataTableSearchField(),
    ];

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final effectiveWidth =
              constraints.maxWidth < WindowConstants.minWidgetWidth
                  ? WindowConstants.minWidgetWidth
                  : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: effectiveWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  const MockTabStrip(),
                  Expanded(
                    child: WindowShell(
                      toolbarActions: actions,
                      toolbarTrailing: trailing,
                      activeContent: const ActiveState(),
                      emptyIcon: FontAwesomeIcons.table,
                      emptyMessage: 'No table selected',
                      emptyDetail:
                          'Open a data set from the File Navigator',
                      onRetry: () => provider.loadTable(
                        provider.tableId,
                        provider.tableName,
                        provider.tableKind,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
