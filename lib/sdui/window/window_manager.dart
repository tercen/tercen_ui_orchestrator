import 'dart:async';

import 'package:flutter/material.dart';

import '../event_bus/event_bus.dart';
import '../event_bus/event_payload.dart';
import '../renderer/sdui_render_context.dart';
import '../registry/widget_registry.dart';
import '../schema/layout_operation.dart';
import '../schema/sdui_node.dart';
import 'floating_window.dart';
import 'window_state.dart';

/// Manages all floating windows. Listens to EventBus for layout operations.
class WindowManager extends ChangeNotifier {
  final List<WindowState> _windows = [];
  final EventBus eventBus;
  final WidgetRegistry registry;
  final SduiRenderContext renderContext;
  StreamSubscription<EventPayload>? _subscription;
  int _nextZIndex = 0;

  WindowManager({
    required this.eventBus,
    required this.registry,
    required this.renderContext,
  }) {
    _subscription = eventBus.subscribe('system.layout.op').listen(_handleEvent);
  }

  List<WindowState> get windows => List.unmodifiable(_windows);

  /// Current layout state — exposed for AI queries.
  List<Map<String, dynamic>> get layoutState =>
      _windows.map((w) => w.toJson()).toList();

  // -- Apply a layout operation --

  Map<String, dynamic> applyOperation(LayoutOperation op) {
    return switch (op) {
      AddWindow op => _addWindow(op),
      RemoveWindow op => _removeWindow(op),
      MoveWindow op => _moveWindow(op),
      ResizeWindow op => _resizeWindow(op),
      FocusWindow op => _focusWindow(op),
      MinimizeWindow op => _minimizeWindow(op),
      RestoreWindow op => _restoreWindow(op),
      UpdateContent op => _updateContent(op),
      AddChild op => _addChild(op),
      RemoveChild op => _removeChild(op),
      UpdateProps op => _updateProps(op),
    };
  }

  /// Apply a batch of operations atomically.
  List<Map<String, dynamic>> applyBatch(List<LayoutOperation> ops) {
    return ops.map(applyOperation).toList();
  }

  // -- Build the window stack widget --

  Widget buildStack(double viewportW, double viewportH) {
    // Recompute positions for any windows that haven't been manually moved
    for (final w in _windows) {
      if (w.width == 0 || w.height == 0) {
        w.computePosition(viewportW, viewportH);
      }
    }

    final sorted = List<WindowState>.from(_windows)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return Stack(
      children: sorted.map((w) {
        return FloatingWindow(
          key: ValueKey(w.id),
          state: w,
          registry: registry,
          renderContext: renderContext,
          onClose: (id) => _applyAndNotify(RemoveWindow(windowId: id)),
          onMinimize: (id) => _applyAndNotify(MinimizeWindow(windowId: id)),
          onFocus: (id) => _applyAndNotify(FocusWindow(windowId: id)),
          onDrag: _handleDrag,
          onResize: _handleResize,
        );
      }).toList(),
    );
  }

  // -- Event handling --

  void _handleEvent(EventPayload payload) {
    try {
      final data = payload.data;
      if (data.containsKey('ops')) {
        final ops = LayoutOperation.fromBatch(data);
        applyBatch(ops);
      } else if (data.containsKey('op')) {
        applyOperation(LayoutOperation.fromJson(data));
      }
    } catch (e) {
      // Structured error — could publish to an error channel
      debugPrint('WindowManager: error handling event: $e');
    }
  }

  void _applyAndNotify(LayoutOperation op) {
    applyOperation(op);
    notifyListeners();
  }

  void _handleDrag(String windowId, double dx, double dy) {
    final w = _findWindow(windowId);
    if (w == null) return;
    w.x += dx;
    w.y += dy;
    notifyListeners();
  }

  void _handleResize(String windowId, double dw, double dh) {
    final w = _findWindow(windowId);
    if (w == null) return;
    w.width = (w.width + dw).clamp(200, double.infinity);
    w.height = (w.height + dh).clamp(100, double.infinity);
    notifyListeners();
  }

  // -- Operation implementations --

  Map<String, dynamic> _addWindow(AddWindow op) {
    if (_windows.any((w) => w.id == op.id)) {
      return _error('window_exists', 'Window "${op.id}" already exists', 'addWindow');
    }
    _windows.add(WindowState(
      id: op.id,
      title: op.title,
      content: op.content,
      size: WindowSize.fromName(op.size),
      alignment: WindowAlignment.fromName(op.align),
      zIndex: _nextZIndex++,
    ));
    notifyListeners();
    return _success('addWindow', {'windowId': op.id});
  }

  Map<String, dynamic> _removeWindow(RemoveWindow op) {
    final idx = _windows.indexWhere((w) => w.id == op.windowId);
    if (idx == -1) return _windowNotFound(op.windowId, 'removeWindow');
    _windows.removeAt(idx);
    notifyListeners();
    return _success('removeWindow', {'windowId': op.windowId});
  }

  Map<String, dynamic> _moveWindow(MoveWindow op) {
    final w = _findWindow(op.windowId);
    if (w == null) return _windowNotFound(op.windowId, 'moveWindow');
    if (op.align != null) {
      w.alignment = WindowAlignment.fromName(op.align!);
      // Reset pixel position so it's recomputed from alignment
      w.width = 0;
      w.height = 0;
    }
    if (op.x != null) w.x = op.x!;
    if (op.y != null) w.y = op.y!;
    notifyListeners();
    return _success('moveWindow', {'windowId': op.windowId});
  }

  Map<String, dynamic> _resizeWindow(ResizeWindow op) {
    final w = _findWindow(op.windowId);
    if (w == null) return _windowNotFound(op.windowId, 'resizeWindow');
    if (op.size != null) {
      w.size = WindowSize.fromName(op.size!);
      w.width = 0;
      w.height = 0;
    }
    if (op.width != null) w.width = op.width!;
    if (op.height != null) w.height = op.height!;
    notifyListeners();
    return _success('resizeWindow', {'windowId': op.windowId});
  }

  Map<String, dynamic> _focusWindow(FocusWindow op) {
    final w = _findWindow(op.windowId);
    if (w == null) return _windowNotFound(op.windowId, 'focusWindow');
    w.zIndex = _nextZIndex++;
    notifyListeners();
    return _success('focusWindow', {'windowId': op.windowId});
  }

  Map<String, dynamic> _minimizeWindow(MinimizeWindow op) {
    final w = _findWindow(op.windowId);
    if (w == null) return _windowNotFound(op.windowId, 'minimizeWindow');
    w.minimized = true;
    notifyListeners();
    return _success('minimizeWindow', {'windowId': op.windowId});
  }

  Map<String, dynamic> _restoreWindow(RestoreWindow op) {
    final w = _findWindow(op.windowId);
    if (w == null) return _windowNotFound(op.windowId, 'restoreWindow');
    w.minimized = false;
    w.zIndex = _nextZIndex++;
    notifyListeners();
    return _success('restoreWindow', {'windowId': op.windowId});
  }

  Map<String, dynamic> _updateContent(UpdateContent op) {
    final w = _findWindow(op.windowId);
    if (w == null) return _windowNotFound(op.windowId, 'updateContent');
    w.content = op.content;
    notifyListeners();
    return _success('updateContent', {'windowId': op.windowId});
  }

  Map<String, dynamic> _addChild(AddChild op) {
    final parent = _findNode(op.parentId);
    if (parent == null) return _error('node_not_found', 'Node "${op.parentId}" not found', 'addChild');
    final children = List<SduiNode>.from(parent.children);
    final idx = op.index?.clamp(0, children.length) ?? children.length;
    children.insert(idx, op.content);
    _replaceNode(op.parentId, parent.copyWith(children: children));
    notifyListeners();
    return _success('addChild', {'parentId': op.parentId, 'childId': op.content.id});
  }

  Map<String, dynamic> _removeChild(RemoveChild op) {
    for (final w in _windows) {
      if (_removeNodeFromTree(w, op.nodeId)) {
        notifyListeners();
        return _success('removeChild', {'nodeId': op.nodeId});
      }
    }
    return _error('node_not_found', 'Node "${op.nodeId}" not found', 'removeChild');
  }

  Map<String, dynamic> _updateProps(UpdateProps op) {
    final node = _findNode(op.nodeId);
    if (node == null) return _error('node_not_found', 'Node "${op.nodeId}" not found', 'updateProps');
    final merged = Map<String, dynamic>.from(node.props)..addAll(op.props);
    _replaceNode(op.nodeId, node.copyWith(props: merged));
    notifyListeners();
    return _success('updateProps', {'nodeId': op.nodeId});
  }

  // -- Helpers --

  WindowState? _findWindow(String id) {
    for (final w in _windows) {
      if (w.id == id) return w;
    }
    return null;
  }

  SduiNode? _findNode(String nodeId) {
    for (final w in _windows) {
      final found = _findNodeInTree(w.content, nodeId);
      if (found != null) return found;
    }
    return null;
  }

  SduiNode? _findNodeInTree(SduiNode node, String nodeId) {
    if (node.id == nodeId) return node;
    for (final child in node.children) {
      final found = _findNodeInTree(child, nodeId);
      if (found != null) return found;
    }
    return null;
  }

  void _replaceNode(String nodeId, SduiNode replacement) {
    for (final w in _windows) {
      final updated = _replaceNodeInTree(w.content, nodeId, replacement);
      if (updated != null) {
        w.content = updated;
        return;
      }
    }
  }

  SduiNode? _replaceNodeInTree(
      SduiNode node, String nodeId, SduiNode replacement) {
    if (node.id == nodeId) return replacement;
    var changed = false;
    final newChildren = node.children.map((child) {
      final updated = _replaceNodeInTree(child, nodeId, replacement);
      if (updated != null) {
        changed = true;
        return updated;
      }
      return child;
    }).toList();
    return changed ? node.copyWith(children: newChildren) : null;
  }

  bool _removeNodeFromTree(WindowState window, String nodeId) {
    final updated = _removeNodeFromNode(window.content, nodeId);
    if (updated != null) {
      window.content = updated;
      return true;
    }
    return false;
  }

  SduiNode? _removeNodeFromNode(SduiNode node, String nodeId) {
    var changed = false;
    final newChildren = <SduiNode>[];
    for (final child in node.children) {
      if (child.id == nodeId) {
        changed = true;
        continue;
      }
      final updated = _removeNodeFromNode(child, nodeId);
      if (updated != null) {
        changed = true;
        newChildren.add(updated);
      } else {
        newChildren.add(child);
      }
    }
    return changed ? node.copyWith(children: newChildren) : null;
  }

  Map<String, dynamic> _success(String op, Map<String, dynamic> data) =>
      {'success': true, 'op': op, ...data};

  Map<String, dynamic> _error(String error, String message, String op) =>
      {'success': false, 'error': error, 'message': message, 'op': op};

  Map<String, dynamic> _windowNotFound(String windowId, String op) =>
      _error('window_not_found', 'Window "$windowId" does not exist', op);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
