import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_line_weights.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/table_schema.dart';
import 'app_snackbar.dart';

/// Shows table metadata: name, ID, kind, row/column count, column list.
class InfoPopover extends StatelessWidget {
  final TableSchema schema;
  final String tableKindLabel;

  const InfoPopover({
    super.key,
    required this.schema,
    required this.tableKindLabel,
  });

  static void show(BuildContext context, TableSchema schema, String kindLabel) {
    showDialog(
      context: context,
      builder: (_) => InfoPopover(schema: schema, tableKindLabel: kindLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColorsDark.surfaceElevated : AppColors.surface;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(color: borderColor, width: AppLineWeights.lineSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  FaIcon(FontAwesomeIcons.circleInfo,
                      size: 16, color: primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Table Info',
                      style: AppTextStyles.h3.copyWith(color: textColor),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: FaIcon(FontAwesomeIcons.xmark,
                          size: 14, color: mutedColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Table name
              _InfoRow(
                label: 'Name',
                value: schema.name,
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              const SizedBox(height: AppSpacing.sm),
              // Table ID with copy button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text('ID',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: mutedColor)),
                  ),
                  Expanded(
                    child: Text(
                      schema.id,
                      style:
                          AppTextStyles.bodySmall.copyWith(color: textColor),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: schema.id));
                      showAppSnackbar(
                        context,
                        type: SnackbarType.success,
                        message: 'ID copied to clipboard',
                        duration: const Duration(seconds: 2),
                      );
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: FaIcon(FontAwesomeIcons.copy,
                          size: 12, color: mutedColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                label: 'Rows',
                value: '${schema.nRows}',
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                label: 'Columns',
                value: '${schema.columns.length}',
                textColor: textColor,
                mutedColor: mutedColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: AppTextStyles.labelSmall.copyWith(color: mutedColor)),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(color: textColor),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
