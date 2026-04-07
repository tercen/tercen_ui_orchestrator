import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_line_weights.dart';
import '../../domain/models/edit_mode.dart';
import '../providers/document_provider.dart';
import '../widgets/document_toolbar.dart';
import '../widgets/mock_tab_strip.dart';
import '../widgets/window_body.dart';

/// Main screen for the Document Editor window.
///
/// Structure: mock tab strip + toolbar + divider + body (loading/active/error).
/// Includes keyboard shortcut handling.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FocusNode _keyboardFocusNode;

  @override
  void initState() {
    super.initState();
    _keyboardFocusNode = FocusNode();

    // Load the first document on startup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DocumentProvider>();
      provider.loadDocument('doc-001', 'proj-001');
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final provider = context.read<DocumentProvider>();
    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (isCtrl) {
      // Ctrl+S: Save.
      if (event.logicalKey == LogicalKeyboardKey.keyS) {
        if (provider.isDirty) provider.save();
        return KeyEventResult.handled;
      }
      // Ctrl+B: Bold (source mode).
      if (event.logicalKey == LogicalKeyboardKey.keyB &&
          provider.editMode == EditMode.source) {
        provider.wrapSelection('**', '**');
        return KeyEventResult.handled;
      }
      // Ctrl+I: Italic (source mode).
      if (event.logicalKey == LogicalKeyboardKey.keyI &&
          provider.editMode == EditMode.source) {
        provider.wrapSelection('*', '*');
        return KeyEventResult.handled;
      }
      // Ctrl+Z: Undo, Ctrl+Shift+Z: Redo.
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        if (HardwareKeyboard.instance.isShiftPressed) {
          provider.redo();
        } else {
          provider.undo();
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<DocumentProvider>();

    final bgColor = isDark ? const Color(0xFF181A20) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: Focus(
        focusNode: _keyboardFocusNode,
        onKeyEvent: _handleKeyEvent,
        autofocus: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: WindowConstants.minWidgetWidth,
          ),
          child: Container(
            color: isDark ? const Color(0xFF181A20) : Colors.white,
            child: Column(
              children: [
                // Mock tab strip (DEV only): document tabs + theme toggle.
                const MockTabStrip(),
                // Custom document toolbar.
                const DocumentToolbar(),
                Divider(
                  height: AppLineWeights.lineSubtle,
                  thickness: AppLineWeights.lineSubtle,
                  color:
                      Theme.of(context).dividerColor.withValues(alpha: 0.5),
                ),
                // Body: loading / active / error.
                Expanded(
                  child: WindowBody(
                    onRetry: () {
                      final doc = provider.document;
                      provider.loadDocument(
                        doc?.id ?? 'doc-001',
                        doc?.projectId ?? 'proj-001',
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
