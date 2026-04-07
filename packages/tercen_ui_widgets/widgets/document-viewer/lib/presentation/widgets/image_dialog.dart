import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Dialog for inserting a markdown image with size selection.
///
/// Fields: Image URL and Size selector (Small/Medium/Large/Full width).
class ImageDialog extends StatefulWidget {
  final void Function(String url, String size) onInsert;

  const ImageDialog({
    super.key,
    required this.onInsert,
  });

  @override
  State<ImageDialog> createState() => _ImageDialogState();
}

class _ImageDialogState extends State<ImageDialog> {
  late final TextEditingController _urlController;
  String _selectedSize = 'Medium';

  static const List<String> _sizes = ['Small', 'Medium', 'Large', 'Full width'];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColorsDark.surface : AppColors.surface;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Insert Image',
                style: AppTextStyles.h3.copyWith(color: textColor),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _urlController,
                autofocus: true,
                style: AppTextStyles.body.copyWith(color: textColor),
                decoration: const InputDecoration(
                  hintText: 'https://...',
                  labelText: 'Image URL',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Size',
                style: AppTextStyles.label.copyWith(color: textColor),
              ),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<String>(
                segments: _sizes
                    .map((s) => ButtonSegment(
                          value: s,
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
                selected: {_selectedSize},
                onSelectionChanged: (selected) {
                  setState(() => _selectedSize = selected.first);
                },
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: () {
                      final url = _urlController.text.trim();
                      if (url.isNotEmpty) {
                        widget.onInsert(url, _selectedSize);
                      }
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Insert'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
