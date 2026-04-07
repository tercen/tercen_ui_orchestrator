import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/document_provider.dart';
import 'link_dialog.dart';
import 'image_dialog.dart';

/// Popover/dialog showing all formatting controls when toolbar is collapsed.
///
/// Displays the 13 formatting buttons arranged in their groups with separators.
class FormatPopover extends StatelessWidget {
  final DocumentProvider provider;

  const FormatPopover({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColorsDark.surface : AppColors.surface;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final borderColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Formatting',
                style: AppTextStyles.h3.copyWith(color: textColor),
              ),
              const SizedBox(height: AppSpacing.md),

              // Text group.
              _GroupLabel(label: 'Text', color: textColor),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 4,
                children: [
                  _PopoverButton(
                    icon: FontAwesomeIcons.bold,
                    label: 'Bold',
                    primary: primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.wrapSelection('**', '**');
                    },
                  ),
                  _PopoverButton(
                    icon: FontAwesomeIcons.italic,
                    label: 'Italic',
                    primary: primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.wrapSelection('*', '*');
                    },
                  ),
                  _PopoverButton(
                    icon: FontAwesomeIcons.strikethrough,
                    label: 'Strikethrough',
                    primary: primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.wrapSelection('~~', '~~');
                    },
                  ),
                ],
              ),

              Divider(color: borderColor, height: AppSpacing.md),

              // Headings group.
              _GroupLabel(label: 'Headings', color: textColor),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 4,
                children: [
                  _PopoverButton(
                    icon: FontAwesomeIcons.heading,
                    label: 'H1',
                    primary: primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.prefixLine('# ');
                    },
                  ),
                  _PopoverButton(
                    icon: FontAwesomeIcons.heading,
                    label: 'H2',
                    primary: primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.prefixLine('## ');
                    },
                  ),
                  _PopoverButton(
                    icon: FontAwesomeIcons.heading,
                    label: 'H3',
                    primary: primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.prefixLine('### ');
                    },
                  ),
                ],
              ),

              Divider(color: borderColor, height: AppSpacing.md),

              // Lists group.
              _GroupLabel(label: 'Lists', color: textColor),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 4,
                children: [
                  _PopoverButton(
                    icon: FontAwesomeIcons.listUl,
                    label: 'Bullet',
                    primary: primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.prefixLine('- ');
                    },
                  ),
                  _PopoverButton(
                    icon: FontAwesomeIcons.listOl,
                    label: 'Numbered',
                    primary: primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.prefixLine('1. ');
                    },
                  ),
                ],
              ),

              Divider(color: borderColor, height: AppSpacing.md),

              // Insert group.
              _GroupLabel(label: 'Insert', color: textColor),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _PopoverButton(
                    icon: FontAwesomeIcons.link,
                    label: 'Link',
                    primary: primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      _showLinkDialog(context);
                    },
                  ),
                  _PopoverButton(
                    icon: FontAwesomeIcons.image,
                    label: 'Image',
                    primary: primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      _showImageDialog(context);
                    },
                  ),
                  _PopoverButton(
                    icon: FontAwesomeIcons.code,
                    label: 'Code',
                    primary: primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.wrapSelection('`', '`');
                    },
                  ),
                  _PopoverButton(
                    icon: FontAwesomeIcons.laptopCode,
                    label: 'Code Block',
                    primary: primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.wrapSelection('\n```\n', '\n```\n');
                    },
                  ),
                ],
              ),

              Divider(color: borderColor, height: AppSpacing.md),

              // Divider group.
              _PopoverButton(
                icon: FontAwesomeIcons.minus,
                label: 'Horizontal Rule',
                primary: primary,
                onTap: () {
                  Navigator.of(context).pop();
                  provider.insertAtCursor('\n---\n');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLinkDialog(BuildContext context) {
    final selectedText = provider.getSelectedText();
    showDialog(
      context: context,
      builder: (ctx) => LinkDialog(
        initialText: selectedText,
        onInsert: (url, text) {
          provider.insertAtCursor('[$text]($url)');
        },
      ),
    );
  }

  void _showImageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ImageDialog(
        onInsert: (url, size) {
          final sizeHint = size != 'Medium' ? ' <!-- size: $size -->' : '';
          provider.insertAtCursor('![image]($url)$sizeHint');
        },
      ),
    );
  }
}

// ── Helper widgets ───────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _GroupLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.labelSmall.copyWith(color: color),
    );
  }
}

class _PopoverButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color primary;
  final VoidCallback onTap;

  const _PopoverButton({
    required this.icon,
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 13, color: primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: primary),
            ),
          ],
        ),
      ),
    );
  }
}
