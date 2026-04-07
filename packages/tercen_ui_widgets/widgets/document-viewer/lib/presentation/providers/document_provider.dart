import 'dart:async';

import 'package:flutter/material.dart';
import '../../di/service_locator.dart';
import '../../domain/models/content_state.dart';
import '../../domain/models/document_model.dart';
import '../../domain/models/edit_mode.dart';
import '../../domain/models/window_identity.dart';
import '../../domain/services/data_service.dart';
import '../../domain/services/event_bus.dart';
import '../../domain/services/event_payload.dart';
import '../../domain/services/window_channels.dart';

/// Manages document editor state: loading, editing, saving, mode switching.
///
/// Extends the window state pattern but owns document-specific state
/// (content, editMode, dirty tracking, save flow).
class DocumentProvider extends ChangeNotifier {
  final DataService _dataService = serviceLocator<DataService>();
  final EventBus _eventBus = serviceLocator<EventBus>();

  final WindowIdentity identity;
  final String windowId;

  // ── Window state ──

  ContentState _contentState = ContentState.loading;
  ContentState get contentState => _contentState;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _focused = false;
  bool get focused => _focused;

  StreamSubscription<EventPayload>? _commandSubscription;

  // ── Document state ──

  DocumentModel? _document;
  DocumentModel? get document => _document;

  String _content = '';
  String get content => _content;

  String _originalContent = '';
  String get originalContent => _originalContent;

  EditMode _editMode = EditMode.source;
  EditMode get editMode => _editMode;

  bool get isDirty => _content != _originalContent;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _saveError;
  String? get saveError => _saveError;

  /// Briefly true after a successful save (auto-clears after 2 s).
  bool _saveSuccess = false;
  bool get saveSuccess => _saveSuccess;

  /// Wall-clock time of the last successful save.
  DateTime? _lastSavedAt;
  DateTime? get lastSavedAt => _lastSavedAt;

  Timer? _saveSuccessTimer;

  // ── Text editing controller (shared between source and rendered) ──

  late TextEditingController textController;

  // ── Undo/Redo stack ──

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  static const int _maxUndoDepth = 50;

  DocumentProvider({
    required this.identity,
    required this.windowId,
  }) {
    textController = TextEditingController();
    textController.addListener(_onControllerChanged);

    _commandSubscription = _eventBus
        .subscribe(WindowChannels.commandChannel(windowId))
        .listen(_handleCommand);
  }

  // ── Inbound command handling ──

  void _handleCommand(EventPayload payload) {
    switch (payload.type) {
      case WindowChannels.typeFocus:
        _focused = true;
        notifyListeners();
        break;
      case WindowChannels.typeBlur:
        _focused = false;
        notifyListeners();
        break;
    }
  }

  // ── Outbound intents ──

  void _publishIntent(String type, [Map<String, dynamic> extra = const {}]) {
    _eventBus.publish(
      WindowChannels.windowIntent,
      EventPayload(
        type: type,
        sourceWidgetId: windowId,
        data: {'windowId': windowId, ...extra},
      ),
    );
  }

  void requestClose() => _publishIntent(WindowChannels.typeClose);

  // ── Document loading ──

  Future<void> loadDocument(String fileId, String projectId) async {
    _contentState = ContentState.loading;
    _errorMessage = null;
    _saveError = null;
    notifyListeners();

    try {
      _document = await _dataService.loadDocument(fileId, projectId);
      _content = _document!.content;
      _originalContent = _document!.content;
      textController.removeListener(_onControllerChanged);
      textController.text = _content;
      textController.addListener(_onControllerChanged);
      _undoStack.clear();
      _redoStack.clear();
      _undoStack.add(_content);

      identity.label = _document!.name;
      _publishIntent(WindowChannels.typeContentChanged, {
        'label': _document!.name,
      });

      _contentState = ContentState.active;
    } catch (e) {
      _errorMessage = e.toString();
      _contentState = ContentState.error;
    }
    notifyListeners();
  }

  // ── Text and selection change tracking ──

  /// Tracks the last known selection so we can detect cursor/selection moves.
  TextSelection _lastSelection = const TextSelection.collapsed(offset: 0);

  void _onControllerChanged() {
    final newText = textController.text;
    final newSelection = textController.selection;
    bool changed = false;

    if (newText != _content) {
      _content = newText;
      _saveError = null;

      // Push to undo stack.
      if (_undoStack.isEmpty || _undoStack.last != newText) {
        _undoStack.add(newText);
        if (_undoStack.length > _maxUndoDepth) {
          _undoStack.removeAt(0);
        }
        _redoStack.clear();
      }

      changed = true;
    }

    // Also notify when cursor/selection moves (for toolbar active states).
    if (newSelection != _lastSelection) {
      _lastSelection = newSelection;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Update content programmatically (e.g., from formatting actions).
  void updateContent(String newContent) {
    textController.removeListener(_onControllerChanged);
    final selection = textController.selection;
    textController.text = newContent;
    // Try to restore selection.
    if (selection.isValid &&
        selection.start <= newContent.length &&
        selection.end <= newContent.length) {
      textController.selection = selection;
    }
    textController.addListener(_onControllerChanged);
    _content = newContent;
    _saveError = null;

    if (_undoStack.isEmpty || _undoStack.last != newContent) {
      _undoStack.add(newContent);
      if (_undoStack.length > _maxUndoDepth) {
        _undoStack.removeAt(0);
      }
      _redoStack.clear();
    }

    notifyListeners();
  }

  // ── Mode switching ──

  void setEditMode(EditMode mode) {
    if (_editMode != mode) {
      _editMode = mode;
      notifyListeners();
    }
  }

  // ── Save ──

  Future<void> save() async {
    if (!isDirty || _isSaving || _document == null) return;

    _isSaving = true;
    _saveError = null;
    _saveSuccess = false;
    notifyListeners();

    try {
      final success =
          await _dataService.saveDocument(_document!.id, _content);
      if (success) {
        _originalContent = _content;
        _document = _document!.copyWith(content: _content);
        _lastSavedAt = DateTime.now();
        _saveSuccess = true;
        // Auto-clear the success flag after 2 seconds.
        _saveSuccessTimer?.cancel();
        _saveSuccessTimer = Timer(const Duration(seconds: 2), () {
          _saveSuccess = false;
          notifyListeners();
        });
      } else {
        _saveError = 'Save failed -- please try again';
      }
    } catch (e) {
      _saveError = 'Save failed: $e';
    }

    _isSaving = false;
    notifyListeners();
  }

  // ── Undo / Redo ──

  bool get canUndo => _undoStack.length > 1;
  bool get canRedo => _redoStack.isNotEmpty;

  void undo() {
    if (!canUndo) return;
    _redoStack.add(_undoStack.removeLast());
    final previous = _undoStack.last;
    textController.removeListener(_onControllerChanged);
    textController.text = previous;
    textController.addListener(_onControllerChanged);
    _content = previous;
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    final next = _redoStack.removeLast();
    _undoStack.add(next);
    textController.removeListener(_onControllerChanged);
    textController.text = next;
    textController.addListener(_onControllerChanged);
    _content = next;
    notifyListeners();
  }

  // ── Formatting helpers ──

  /// Wrap the current selection with prefix/suffix markdown.
  ///
  /// If the selection already has the markers, removes them (toggle off).
  /// Trims leading/trailing whitespace from the selection so that markers
  /// wrap the actual text content, e.g. "hello " → "*hello* " not "*hello *".
  void wrapSelection(String prefix, String suffix) {
    final sel = textController.selection;
    if (!sel.isValid) return;
    final text = textController.text;
    final selected = sel.textInside(text);

    // Check if already wrapped — toggle off.
    final before = text.substring(0, sel.start);
    final after = text.substring(sel.end);
    if (before.endsWith(prefix) && after.startsWith(suffix)) {
      final unwrapStart = sel.start - prefix.length;
      final unwrapEnd = sel.end + suffix.length;
      final newText = text.replaceRange(unwrapStart, unwrapEnd, selected);
      updateContent(newText);
      textController.selection = TextSelection(
        baseOffset: unwrapStart,
        extentOffset: unwrapStart + selected.length,
      );
      return;
    }

    // Trim spaces from selection edges so markers wrap the text content.
    final leadingSpaces = selected.length - selected.trimLeft().length;
    final trailingSpaces = selected.length - selected.trimRight().length;
    final trimmed = selected.trim();

    if (trimmed.isEmpty && !sel.isCollapsed) {
      // Only whitespace selected — insert markers at cursor start.
      final newText = text.replaceRange(sel.start, sel.end,
          '$prefix$suffix$selected');
      updateContent(newText);
      textController.selection = TextSelection.collapsed(
        offset: sel.start + prefix.length,
      );
      return;
    }

    final leadingWs = selected.substring(0, leadingSpaces);
    final trailingWs = trailingSpaces > 0
        ? selected.substring(selected.length - trailingSpaces)
        : '';

    final replacement = '$leadingWs$prefix$trimmed$suffix$trailingWs';
    final newText = text.replaceRange(sel.start, sel.end, replacement);
    final newSelStart = sel.start + leadingSpaces + prefix.length;
    final newSelEnd = newSelStart + trimmed.length;
    updateContent(newText);
    textController.selection = TextSelection(
      baseOffset: newSelStart,
      extentOffset: newSelEnd,
    );
  }

  /// Prefix the current line with a string, or remove it if already present.
  void prefixLine(String prefix) {
    final sel = textController.selection;
    if (!sel.isValid) return;
    final text = textController.text;
    // Find start of the current line.
    int lineStart = sel.start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    // Check if line already starts with this prefix — toggle off.
    final lineEnd = text.indexOf('\n', lineStart);
    final line = text.substring(
        lineStart, lineEnd == -1 ? text.length : lineEnd);

    // For headings, remove any existing heading prefix first.
    if (prefix.startsWith('#')) {
      final headingMatch = RegExp(r'^#{1,3}\s').firstMatch(line);
      if (headingMatch != null) {
        final existing = headingMatch.group(0)!;
        if (existing == prefix) {
          // Same heading — toggle off.
          final newText = text.replaceRange(
              lineStart, lineStart + existing.length, '');
          updateContent(newText);
          textController.selection = TextSelection.collapsed(
            offset: sel.start - existing.length,
          );
          return;
        }
        // Different heading level — replace.
        final newText = text.replaceRange(
            lineStart, lineStart + existing.length, prefix);
        updateContent(newText);
        textController.selection = TextSelection.collapsed(
          offset: sel.start + prefix.length - existing.length,
        );
        return;
      }
    } else if (line.startsWith(prefix)) {
      // Non-heading prefix (list markers) — toggle off.
      final newText = text.replaceRange(
          lineStart, lineStart + prefix.length, '');
      updateContent(newText);
      textController.selection = TextSelection.collapsed(
        offset: sel.start - prefix.length,
      );
      return;
    }

    // Add prefix.
    final newText = text.replaceRange(lineStart, lineStart, prefix);
    updateContent(newText);
    textController.selection = TextSelection.collapsed(
      offset: sel.start + prefix.length,
    );
  }

  /// Insert text at the current cursor position.
  void insertAtCursor(String insertion) {
    final sel = textController.selection;
    if (!sel.isValid) return;
    final text = textController.text;
    final newText = text.replaceRange(sel.start, sel.end, insertion);
    updateContent(newText);
    textController.selection = TextSelection.collapsed(
      offset: sel.start + insertion.length,
    );
  }

  /// Get the currently selected text.
  String getSelectedText() {
    final sel = textController.selection;
    if (!sel.isValid) return '';
    return sel.textInside(textController.text);
  }

  // ── Cursor-position formatting analysis ──

  /// Returns the current line (the line where the cursor sits).
  String _currentLine() {
    final sel = textController.selection;
    if (!sel.isValid) return '';
    final text = textController.text;
    int lineStart = sel.start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    int lineEnd = sel.start;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }
    return text.substring(lineStart, lineEnd);
  }

  /// Check if the selection/cursor is immediately wrapped by [marker].
  /// For a selection: checks if marker appears right before sel.start
  /// and right after sel.end.
  /// For a collapsed cursor: checks if marker appears on both sides.
  bool _isWrappedBy(String marker) {
    final sel = textController.selection;
    if (!sel.isValid) return false;
    final text = textController.text;
    final mLen = marker.length;

    // Check if markers exist immediately outside the selection.
    if (sel.start >= mLen && sel.end + mLen <= text.length) {
      final before = text.substring(sel.start - mLen, sel.start);
      final after = text.substring(sel.end, sel.end + mLen);
      if (before == marker && after == marker) return true;
    }

    // For collapsed cursor: scan outward on the same line to find
    // balanced markers surrounding the cursor position.
    if (sel.isCollapsed) {
      final lineText = _currentLine();
      final lineSelStart = sel.start;
      // Find line start offset in full text.
      int lineStart = sel.start;
      while (lineStart > 0 && text[lineStart - 1] != '\n') {
        lineStart--;
      }
      final posInLine = lineSelStart - lineStart;

      // Find the nearest marker pair surrounding posInLine.
      int searchFrom = 0;
      while (true) {
        final openIdx = lineText.indexOf(marker, searchFrom);
        if (openIdx == -1 || openIdx >= posInLine) break;
        final closeIdx = lineText.indexOf(marker, openIdx + mLen);
        if (closeIdx == -1) break;
        if (posInLine > openIdx && posInLine <= closeIdx + mLen) {
          return true;
        }
        searchFrom = closeIdx + mLen;
      }
    }

    return false;
  }

  /// Whether the cursor/selection is inside bold formatting.
  bool get isBoldActive => _isWrappedBy('**');

  /// Whether the cursor/selection is inside italic formatting.
  /// Scans the current line for single `*` pairs (excluding `**` bold markers).
  bool get isItalicActive {
    final sel = textController.selection;
    if (!sel.isValid) return false;
    final text = textController.text;

    // Check immediate single * wrapping (but not **).
    if (sel.start >= 1 && sel.end + 1 <= text.length) {
      final charBefore = text.substring(sel.start - 1, sel.start);
      final charAfter = text.substring(sel.end, sel.end + 1);
      if (charBefore == '*' && charAfter == '*') {
        final doubleBefore = sel.start >= 2
            ? text.substring(sel.start - 2, sel.start)
            : '';
        final doubleAfter = sel.end + 2 <= text.length
            ? text.substring(sel.end, sel.end + 2)
            : '';
        if (doubleBefore != '**' && doubleAfter != '**') {
          return true;
        }
      }
    }

    // For collapsed cursor: scan line for single-* pairs excluding ** bold.
    if (sel.isCollapsed) {
      final lineText = _currentLine();
      int lineStart = sel.start;
      while (lineStart > 0 && text[lineStart - 1] != '\n') {
        lineStart--;
      }
      final posInLine = sel.start - lineStart;

      // Find single-* positions (positions where * is NOT part of **).
      final singleStarPositions = <int>[];
      for (int i = 0; i < lineText.length; i++) {
        if (lineText[i] == '*') {
          final isDoubleBefore = i > 0 && lineText[i - 1] == '*';
          final isDoubleAfter =
              i + 1 < lineText.length && lineText[i + 1] == '*';
          if (!isDoubleBefore && !isDoubleAfter) {
            singleStarPositions.add(i);
          }
        }
      }

      // Check if cursor falls between a pair of single stars.
      for (int i = 0; i + 1 < singleStarPositions.length; i += 2) {
        final open = singleStarPositions[i];
        final close = singleStarPositions[i + 1];
        if (posInLine > open && posInLine <= close) {
          return true;
        }
      }
    }

    return false;
  }

  /// Whether the cursor/selection is inside strikethrough formatting.
  bool get isStrikethroughActive => _isWrappedBy('~~');

  /// Returns the heading level (1-3) if the cursor is on a heading line, else 0.
  int get activeHeadingLevel {
    final line = _currentLine().trimLeft();
    if (line.startsWith('### ')) return 3;
    if (line.startsWith('## ')) return 2;
    if (line.startsWith('# ')) return 1;
    return 0;
  }

  /// Whether the cursor is on a bullet list line.
  bool get isBulletListActive {
    final line = _currentLine().trimLeft();
    return line.startsWith('- ') || line.startsWith('* ');
  }

  /// Whether the cursor is on a numbered list line.
  bool get isNumberedListActive {
    final line = _currentLine().trimLeft();
    return RegExp(r'^\d+\.\s').hasMatch(line);
  }

  // ── Available documents (for DEV panel) ──

  List<String> get availableDocumentIds => _dataService.availableDocumentIds;

  @override
  void dispose() {
    _saveSuccessTimer?.cancel();
    _commandSubscription?.cancel();
    textController.removeListener(_onControllerChanged);
    textController.dispose();
    super.dispose();
  }
}
