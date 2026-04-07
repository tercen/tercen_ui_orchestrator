import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../providers/document_provider.dart';

/// Source mode: full-width text area displaying raw markdown/text.
///
/// Vertically scrollable, word-wrap enabled, no line numbers,
/// no syntax highlighting. Tab inserts two spaces.
class SourceEditor extends StatelessWidget {
  const SourceEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DocumentProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final bgColor = isDark ? AppColorsDark.surface : AppColors.surface;

    return Container(
      color: bgColor,
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.tab): const _InsertTabIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _InsertTabIntent: _InsertTabAction(provider.textController),
          },
          child: TextField(
            controller: provider.textController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              height: 1.6,
              color: textColor,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hoverColor: Colors.transparent,
              contentPadding: const EdgeInsets.all(AppSpacing.md),
              fillColor: bgColor,
              filled: true,
            ),
            inputFormatters: [
              _TabToSpacesFormatter(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Intent for the Tab key shortcut.
class _InsertTabIntent extends Intent {
  const _InsertTabIntent();
}

/// Action that inserts two spaces at the cursor position when Tab is pressed.
class _InsertTabAction extends Action<_InsertTabIntent> {
  final TextEditingController controller;

  _InsertTabAction(this.controller);

  @override
  Object? invoke(_InsertTabIntent intent) {
    final sel = controller.selection;
    if (!sel.isValid) return null;
    final text = controller.text;
    final newText = text.replaceRange(sel.start, sel.end, '  ');
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + 2),
    );
    return null;
  }
}

/// Fallback formatter that replaces any tab characters that slip through.
class _TabToSpacesFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.contains('\t')) {
      final newText = newValue.text.replaceAll('\t', '  ');
      final diff = newText.length - newValue.text.length;
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: newValue.selection.baseOffset + diff,
        ),
      );
    }
    return newValue;
  }
}
