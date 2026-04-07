import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Dialog for inserting a markdown link.
///
/// Two fields: URL and Link text. Pre-fills link text with current selection.
class LinkDialog extends StatefulWidget {
  final String initialText;
  final void Function(String url, String text) onInsert;

  const LinkDialog({
    super.key,
    this.initialText = '',
    required this.onInsert,
  });

  @override
  State<LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<LinkDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _textController.dispose();
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
                'Insert Link',
                style: AppTextStyles.h3.copyWith(color: textColor),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _urlController,
                autofocus: true,
                style: AppTextStyles.body.copyWith(color: textColor),
                decoration: const InputDecoration(
                  hintText: 'https://...',
                  labelText: 'URL',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _textController,
                style: AppTextStyles.body.copyWith(color: textColor),
                decoration: const InputDecoration(
                  hintText: 'Link text',
                  labelText: 'Link text',
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
                      final text = _textController.text.trim().isEmpty
                          ? url
                          : _textController.text.trim();
                      if (url.isNotEmpty) {
                        widget.onInsert(url, text);
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
