import 'dart:async';

import 'package:flutter/material.dart';

import '../error_reporter.dart';
import '../event_bus/event_bus.dart';
import '../event_bus/event_payload.dart';
import '../renderer/sdui_render_context.dart';
import '../renderer/sdui_renderer.dart';
import '../registry/widget_registry.dart';
import '../schema/layout_operation.dart';
import '../schema/sdui_node.dart';
import '../theme/sdui_theme.dart';
import 'pane_chrome.dart';
import 'pane_state.dart';
import 'window_state.dart';

/// Configuration for how a resource type maps to a window.
class ResourceMapping {
  /// The widget type to use for the window content.
  final String widgetType;

  /// Default window size preset name.
  final String size;

  /// Default window alignment preset name.
  final String align;

  /// Whether to deduplicate: if true, focus an existing window with the same
  /// resourceId instead of creating a new one.
  final bool deduplicate;

  const ResourceMapping({
    required this.widgetType,
    this.size = 'medium',
    this.align = 'center',
    this.deduplicate = false,
  });
}

/// Default neutral color for tabs when widget metadata has no typeColor.
const _defaultTypeColor = Color(0xFF6B7280);

/// Manages all panes (tab containers). Listens to EventBus for layout operations.
///
/// Internally uses [PaneState] (each pane holds 1+ tabs as [WindowState]).
/// Backward compatible: [AddWindow] creates a single-tab pane.
class WindowManager extends ChangeNotifier {
  final List<PaneState> _panes = [];
  final EventBus eventBus;
  final WidgetRegistry registry;
  final SduiRenderContext renderContext;
  StreamSubscription<EventPayload>? _layoutSubscription;
  StreamSubscription<EventPayload>? _intentSubscription;
  StreamSubscription<EventPayload>? _dirtySubscription;
  int _nextZIndex = 0;
  String? _focusedPaneId;

  /// Last-known viewport dimensions (updated every buildStack call).
  double viewportWidth = 0;
  double viewportHeight = 0;

  /// Resource type → window mapping registry.
  final Map<String, ResourceMapping> _resourceMappings = {};

  /// Tracks dirty state per window (windowId → isDirty).
  final Map<String, bool> _dirtyWindows = {};

  WindowManager({
    required this.eventBus,
    required this.registry,
    required this.renderContext,
  }) {
    _layoutSubscription =
        eventBus.subscribe('system.layout.op').listen(_handleEvent);
    _intentSubscription =
        eventBus.subscribe('window.intent').listen(_handleWindowIntent);
    _dirtySubscription =
        eventBus.subscribe('system.document.dirty').listen(_handleDirtyEvent);
  }

  /// All panes.
  List<PaneState> get panes => List.unmodifiable(_panes);

  /// Backward-compatible: flat list of all windows across all panes.
  List<WindowState> get windows =>
      _panes.expand((p) => p.tabs).toList(growable: false);

  /// The currently focused pane ID, or null if none.
  String? get focusedPaneId => _focusedPaneId;

  /// The currently focused pane, or null.
  PaneState? get focusedPane =>
      _focusedPaneId == null ? null : _findPane(_focusedPaneId!);

  /// Focus context: what entity is currently in focus across the UI.
  /// Extracts entity-identifying props from the focused window's content root.
  /// Returns null if no window is focused.
  Map<String, dynamic>? get focusContext {
    final pane = focusedPane;
    if (pane == null) return null;
    final window = pane.activeTab;
    if (window == null) return null;

    final ctx = <String, dynamic>{
      'windowId': window.id,
      'windowTitle': window.title,
      'widgetType': window.content.type,
      'paneId': pane.id,
    };

    // Extract entity-identifying props from content root.
    const entityProps = [
      'projectId', 'workflowId', 'fileId', 'stepId', 'taskId',
      'teamId', 'userId', 'documentId', 'schemaId',
    ];
    for (final prop in entityProps) {
      final value = window.content.props[prop];
      if (value != null && value.toString().isNotEmpty) {
        ctx[prop] = value;
      }
    }

    return ctx;
  }

  /// Current layout state — summary for AI queries (filtered props).
  List<Map<String, dynamic>> get layoutState =>
      windows.map((w) => w.toJson()).toList();

  /// Full layout snapshot for save/restore — includes complete content trees.
  Map<String, dynamic> toLayoutJson() => {
        'version': 1,
        'viewport': {
          'width': viewportWidth.round(),
          'height': viewportHeight.round(),
        },
        'windows': windows.map((w) => w.toFullJson()).toList(),
      };

  /// Clear all panes and reset state.
  void clearAll() {
    _panes.clear();
    _dirtyWindows.clear();
    _focusedPaneId = null;
    _nextZIndex = 0;
    notifyListeners();
  }

  /// Restore a saved layout. Clears all current panes and loads saved windows
  /// as single-tab panes. Pixel positions are scaled if viewport changed.
  void loadLayout(Map<String, dynamic> json) {
    final savedViewport = json['viewport'] as Map<String, dynamic>?;
    final savedW = (savedViewport?['width'] as num?)?.toDouble() ?? 0;
    final savedH = (savedViewport?['height'] as num?)?.toDouble() ?? 0;

    final scaleX = (savedW > 0 && viewportWidth > 0)
        ? viewportWidth / savedW
        : 1.0;
    final scaleY = (savedH > 0 && viewportHeight > 0)
        ? viewportHeight / savedH
        : 1.0;

    _panes.clear();
    _dirtyWindows.clear();
    _focusedPaneId = null;

    final windowList = json['windows'] as List? ?? [];
    for (final w in windowList) {
      final ws = WindowState.fromFullJson(
          Map<String, dynamic>.from(w as Map));

      if (scaleX != 1.0 || scaleY != 1.0) {
        ws.x *= scaleX;
        ws.y *= scaleY;
        ws.width *= scaleX;
        ws.height *= scaleY;
      }

      // Wrap each window in a single-tab pane
      final pane = PaneState.fromWindow(ws, zIndex: ws.zIndex);
      pane.x = ws.x;
      pane.y = ws.y;
      pane.width = ws.width;
      pane.height = ws.height;
      if (pane.zIndex >= _nextZIndex) _nextZIndex = pane.zIndex + 1;
      _panes.add(pane);
    }

    notifyListeners();
  }

  /// Register a mapping from a resource type to a window configuration.
  void registerResource(String resourceType, ResourceMapping mapping) {
    _resourceMappings[resourceType] = mapping;
  }

  /// Whether a window has unsaved changes.
  bool isWindowDirty(String windowId) => _dirtyWindows[windowId] == true;

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
      AddTab op => _addTab(op),
      RemoveTab op => _removeTab(op),
      ActivateTab op => _activateTab(op),
    };
  }

  /// Apply a batch of operations atomically.
  List<Map<String, dynamic>> applyBatch(List<LayoutOperation> ops) {
    return ops.map(applyOperation).toList();
  }

  // -- Build the pane stack widget --

  Widget buildStack(double viewportW, double viewportH) {
    viewportWidth = viewportW;
    viewportHeight = viewportH;

    for (final p in _panes) {
      if (p.isDocked) {
        // Docked panes always recompute from grid (responsive to viewport resize)
        p.computePositionFromGrid(viewportW, viewportH);
      } else if (p.width == 0 || p.height == 0) {
        // First-time position computation for floating panes
        p.computePosition(viewportW, viewportH);
      }

      // Clamp to viewport bounds
      if (p.width > viewportW) p.width = viewportW;
      if (p.height > viewportH) p.height = viewportH;
      p.x = p.x.clamp(0, (viewportW - p.width).clamp(0, double.infinity));
      p.y = p.y.clamp(0, (viewportH - p.height).clamp(0, double.infinity));
    }

    final sorted = List<PaneState>.from(_panes)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    // Build splitters between adjacent docked panes
    final docked = _panes.where((p) => p.isDocked).toList();
    final splitters = <Widget>[];
    for (var i = 0; i < docked.length - 1; i++) {
      final left = docked[i];
      final right = docked[i + 1];
      splitters.add(_buildSplitter(left, right, viewportW, viewportH));
    }

    return Stack(
      children: [
        ...sorted.map((p) => _buildPane(p)),
        ...splitters,
      ],
    );
  }

  Widget _buildPane(PaneState pane) {
    final activeTab = pane.activeTab;
    if (activeTab == null) return const SizedBox.shrink();

    final theme = renderContext.theme;

    // Build tab data from pane tabs
    final tabDataList = pane.tabs.map((t) {
      // Resolve typeColor from widget metadata
      final meta = registry.getMetadata(t.content.type);
      Color typeColor = _defaultTypeColor;
      if (meta?.typeColor != null) {
        typeColor = _parseColor(meta!.typeColor!);
      }
      return PaneTabData(
        id: t.id,
        typeColor: typeColor,
        title: t.title ?? t.content.type,
      );
    }).toList();

    // Render the active tab's content inside a RepaintBoundary
    // to isolate rebuilds from other panes.
    final content = RepaintBoundary(
      child: _PaneContent(
        key: ValueKey('pane-content-${pane.id}-${activeTab.id}'),
        registry: registry,
        renderContext: renderContext,
        contentNode: activeTab.content,
      ),
    );

    final isFocused = _focusedPaneId == pane.id;

    void focusThisPane() {
      if (_focusedPaneId != pane.id) {
        _applyAndNotify(FocusWindow(windowId: pane.id));
      }
    }

    return Positioned(
      key: ValueKey(pane.id),
      left: pane.x,
      top: pane.y,
      width: pane.width,
      height: pane.height,
      // Listener catches all pointer-down events without competing with GestureDetectors
      child: Listener(
        onPointerDown: (_) => focusThisPane(),
        child: Stack(
          children: [
            PaneChrome(
              tabs: tabDataList,
              activeIndex: pane.activeTabIndex,
              isFocused: isFocused,
              isFloating: pane.isFloating,
              theme: theme,
              onTabTap: (i) {
                pane.activeTabIndex = i;
                focusThisPane();
                notifyListeners();
              },
              onTabClose: (i) {
                final tabId = pane.tabs[i].id;
                _applyAndNotify(RemoveTab(windowId: tabId));
              },
              onTabDraggedOut: (tabData, globalPos) {
                _undockTab(pane, tabData.id, globalPos);
              },
              onTabDroppedIn: (tabData) {
                _mergeTab(pane, tabData.id);
              },
              onPaneDrag: (dx, dy) {
                _handleDrag(pane.id, dx, dy);
              },
              onPaneDragEnd: () {
                _handleDragEnd(pane.id);
              },
              onPopOut: () {
                _popOutPane(pane);
              },
              child: content,
            ),
            // Resize handle (bottom-right corner)
            Positioned(
              right: 0,
              bottom: 0,
              child: _ResizeHandle(
                paneId: pane.id,
                onResize: _handleResize,
                onResizeEnd: () => _handleResizeEnd(pane.id),
                handleColor: theme.colors.onSurfaceMuted,
                visible: pane.isFloating,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Window intent handling --

  void _handleWindowIntent(EventPayload payload) {
    final data = payload.data;

    // Determine intent: check data['intent'] first (from Action payloads),
    // then fall back to payload.type (from direct event publishers).
    final intent = data['intent'] as String? ?? payload.type;

    // openResource doesn't need a windowId — handle it before the guard.
    if (intent == 'openResource') {
      _handleOpenResource(data, payload.sourceWidgetId);
      return;
    }

    final windowId = data['windowId'] as String?;
    if (windowId == null) return;

    switch (intent) {
      case 'close':
        if (_dirtyWindows[windowId] == true) {
          eventBus.publish(
            'window.$windowId.command',
            EventPayload(
              type: 'confirmClose',
              data: {'windowId': windowId},
            ),
          );
        } else {
          _dirtyWindows.remove(windowId);
          _applyAndNotify(RemoveTab(windowId: windowId));
        }
        break;
      case 'forceClose':
        _dirtyWindows.remove(windowId);
        _applyAndNotify(RemoveTab(windowId: windowId));
        break;
      case 'maximize':
        final pane = _findPaneForWindow(windowId);
        if (pane != null) {
          _applyAndNotify(ResizeWindow(windowId: pane.id, size: 'full'));
        }
        break;
      case 'restore':
        final pane = _findPaneForWindow(windowId);
        if (pane != null) {
          _applyAndNotify(RestoreWindow(windowId: pane.id));
        }
        break;
      case 'contentChanged':
        final label = data['label'] as String?;
        if (label != null) {
          final w = _findWindow(windowId);
          if (w != null) {
            w.title = label;
            notifyListeners();
          }
        }
        break;
    }
  }

  // -- Open resource handling --

  void _handleOpenResource(Map<String, dynamic> data, String? sourceWidgetId) {
    final resourceType = data['resourceType'] as String?;
    final resourceId = data['resourceId'] as String?;
    if (resourceType == null || resourceId == null) {
      debugPrint('WindowManager: openResource missing resourceType or resourceId');
      return;
    }

    final mapping = _resourceMappings[resourceType];
    if (mapping == null) {
      debugPrint('WindowManager: no mapping registered for resourceType=$resourceType');
      return;
    }

    // Dedup: focus existing pane if one already has this resource open.
    if (mapping.deduplicate) {
      for (final p in _panes) {
        for (final t in p.tabs) {
          if (t.content.props['resourceId'] == resourceId) {
            _applyAndNotify(FocusWindow(windowId: p.id));
            return;
          }
        }
      }
    }

    final windowId = 'win-$resourceType-${resourceId.hashCode.abs()}';
    final resourceName = data['resourceName'] as String? ?? resourceType;

    final props = Map<String, dynamic>.from(data);
    props.remove('windowId');
    props.remove('placement');
    props.remove('sourceWindowId');

    final content = SduiNode(
      type: mapping.widgetType,
      id: 'content-$windowId',
      props: props,
    );

    // Support placement: "samePane" to open as tab in source widget's pane.
    // sourceWindowId in data takes precedence over EventPayload.sourceWidgetId.
    final placement = data['placement'] as String? ?? 'newPane';
    final source = data['sourceWindowId'] as String? ?? sourceWidgetId;

    _applyAndNotify(AddWindow(
      id: windowId,
      content: content,
      size: mapping.size,
      align: mapping.align,
      title: resourceName,
      placement: placement,
      sourceWidgetId: source,
    ));
  }

  // -- Splitters --

  Widget _buildSplitter(PaneState left, PaneState right,
      double viewportW, double viewportH) {
    final theme = renderContext.theme;
    final splitterX = left.x + left.width;
    final hitWidth = 12.0; // wide enough to grab easily

    return Positioned(
      left: splitterX - hitWidth / 2,
      top: left.y,
      width: hitWidth,
      height: left.height,
      child: _SplitterHandle(
        theme: theme,
        onDrag: (dx) => _handleSplitterDrag(left, right, dx, viewportW),
      ),
    );
  }

  void _handleSplitterDrag(PaneState left, PaneState right,
      double dx, double viewportW) {
    if (!left.isDocked || !right.isDocked) return;

    final cellW = viewportW / gridColumns;
    // Accumulate pixel delta and convert to grid columns when threshold crossed
    final totalLeftWidth = left.width + dx;
    final totalRightWidth = right.width - dx;

    // Compute new spans
    final newLeftSpan = (totalLeftWidth / cellW).round()
        .clamp(minPaneColSpan, gridColumns - minPaneColSpan);
    final newRightSpan = (left.gridColSpan! + right.gridColSpan!) - newLeftSpan;

    if (newRightSpan < minPaneColSpan) return;
    if (newLeftSpan == left.gridColSpan) {
      // No grid change, but update pixel positions for smooth dragging
      left.width = totalLeftWidth.clamp(cellW * minPaneColSpan, viewportW);
      right.x = left.x + left.width;
      right.width = totalRightWidth.clamp(cellW * minPaneColSpan, viewportW);
      notifyListeners();
      return;
    }

    left.gridColSpan = newLeftSpan;
    right.gridCol = left.gridCol! + newLeftSpan;
    right.gridColSpan = newRightSpan;

    left.computePositionFromGrid(viewportW, viewportHeight);
    right.computePositionFromGrid(viewportW, viewportHeight);
    notifyListeners();
  }

  // -- Pop out / Tab drag & drop --

  /// Pop out a docked pane into a floating pane. Explicit user action.
  void _popOutPane(PaneState pane) {
    if (pane.isFloating) return;

    // Remember current pixel position before undocking
    final px = pane.x;
    final py = pane.y;
    final pw = pane.width;
    final ph = pane.height;

    // Undock
    pane.undock();

    // Shrink slightly and offset so it's clearly floating
    pane.width = pw * 0.7;
    pane.height = ph * 0.7;
    pane.x = (px + pw * 0.15).clamp(0, (viewportWidth - pane.width).clamp(0, double.infinity));
    pane.y = (py + ph * 0.15).clamp(0, (viewportHeight - pane.height).clamp(0, double.infinity));
    pane.zIndex = _nextZIndex++;

    _focusedPaneId = pane.id;
    _retileAll();
    notifyListeners();
  }

  /// Separate a tab from its pane into a new docked pane and retile.
  /// All tab drag behaviors produce docked panes; floating requires explicit Pop Out.
  void _undockTab(PaneState sourcePane, String tabId, Offset globalPos) {
    final tab = sourcePane.findTab(tabId);
    if (tab == null) return;

    // Remove from source pane
    final wasEmpty = sourcePane.removeTab(tabId);
    if (wasEmpty) {
      _panes.remove(sourcePane);
      if (_focusedPaneId == sourcePane.id) _focusedPaneId = null;
    }

    // Create new docked pane and retile to fill workspace
    final newPane = PaneState.fromWindow(tab, zIndex: _nextZIndex++);
    _dockNewPane(newPane);
    _panes.add(newPane);
    _focusedPaneId = newPane.id;

    _retileAll();
    notifyListeners();
  }

  /// Merge a tab from another pane into the target pane.
  void _mergeTab(PaneState targetPane, String tabId) {
    // Find the source pane and tab
    final sourcePane = _findPaneForWindow(tabId);
    if (sourcePane == null || sourcePane.id == targetPane.id) return;

    final tab = sourcePane.findTab(tabId);
    if (tab == null) return;

    // Remove from source
    final wasEmpty = sourcePane.removeTab(tabId);
    if (wasEmpty) {
      _panes.remove(sourcePane);
      if (_focusedPaneId == sourcePane.id) _focusedPaneId = null;
    }

    // Add to target
    targetPane.addTab(tab);
    _focusedPaneId = targetPane.id;

    if (wasEmpty) _retileAll();
    notifyListeners();
  }

  // -- Dirty state handling --

  void _handleDirtyEvent(EventPayload payload) {
    final data = payload.data;
    final windowId = data['windowId'] as String?;
    final isDirty = data['isDirty'] as bool?;
    if (windowId == null || isDirty == null) return;

    final previous = _dirtyWindows[windowId] ?? false;
    if (previous == isDirty) return;

    _dirtyWindows[windowId] = isDirty;

    final w = _findWindow(windowId);
    if (w != null && w.title != null) {
      if (isDirty && !w.title!.startsWith('\u2022 ')) {
        w.title = '\u2022 ${w.title}';
      } else if (!isDirty && w.title!.startsWith('\u2022 ')) {
        w.title = w.title!.substring(2);
      }
      notifyListeners();
    }
  }

  // -- Event handling --

  void _handleEvent(EventPayload payload) {
    try {
      final data = Map<String, dynamic>.from(payload.data);
      if (data.containsKey('ops')) {
        final ops = LayoutOperation.fromBatch(data);
        applyBatch(ops);
      } else if (data.containsKey('op')) {
        applyOperation(LayoutOperation.fromJson(data));
      }
    } catch (e, st) {
      ErrorReporter.instance.report(e,
        stackTrace: st,
        source: 'sdui.windowManager',
        context: 'handling layout event',
      );
    }
  }

  void _applyAndNotify(LayoutOperation op) {
    applyOperation(op);
    notifyListeners();
  }

  /// Tracks whether a pane was floating before drag started.
  /// Floating panes stay floating after drag; docked panes re-dock.
  final Map<String, bool> _wasFloatingBeforeDrag = {};

  void _handleDrag(String paneId, double dx, double dy) {
    final p = _findPane(paneId);
    if (p == null) return;

    // Remember original state on first drag event
    _wasFloatingBeforeDrag.putIfAbsent(paneId, () => p.isFloating);

    // Undock during drag for free movement (docked panes only)
    if (p.isDocked) p.undock();
    p.x = (p.x + dx).clamp(0, (viewportWidth - p.width).clamp(0, double.infinity));
    p.y = (p.y + dy).clamp(0, (viewportHeight - p.height).clamp(0, double.infinity));
    notifyListeners();
  }

  void _handleDragEnd(String paneId) {
    final p = _findPane(paneId);
    if (p == null) return;

    final wasFloating = _wasFloatingBeforeDrag.remove(paneId) ?? false;

    // Floating panes stay floating -- no grid snap
    if (wasFloating) {
      notifyListeners();
      return;
    }

    // Docked pane: determine drop position among existing docked panes
    // Use the pane's center X to determine its insertion order
    final centerX = p.x + p.width / 2;
    final docked = _panes.where((o) => o.isDocked && o.id != p.id).toList();

    // Find insertion index based on center X relative to other panes
    int insertIdx = docked.length;
    for (var i = 0; i < docked.length; i++) {
      final otherCenter = docked[i].x + docked[i].width / 2;
      if (centerX < otherCenter) {
        insertIdx = i;
        break;
      }
    }

    // Re-dock the pane (temporary coords, retile will fix)
    p.dockAt(0, 0, 1, gridRows);

    // Reorder: remove from _panes, insert at correct position among docked panes
    _panes.remove(p);
    // Find the position in _panes where insertIdx-th docked pane is
    if (docked.isEmpty) {
      _panes.add(p);
    } else if (insertIdx >= docked.length) {
      // After all docked panes
      final lastDocked = docked.last;
      final pos = _panes.indexOf(lastDocked);
      _panes.insert(pos + 1, p);
    } else {
      final target = docked[insertIdx];
      final pos = _panes.indexOf(target);
      _panes.insert(pos, p);
    }

    _retileAll();
    notifyListeners();
  }

  void _handleResize(String paneId, double dw, double dh) {
    final p = _findPane(paneId);
    if (p == null) return;
    final maxW = viewportWidth > 0 ? viewportWidth - p.x : double.infinity;
    final maxH = viewportHeight > 0 ? viewportHeight - p.y : double.infinity;
    p.width = (p.width + dw).clamp(200, maxW);
    p.height = (p.height + dh).clamp(100, maxH);
    notifyListeners();
  }

  void _handleResizeEnd(String paneId) {
    final p = _findPane(paneId);
    if (p == null || p.isDocked) return;
    // Snap floating pane to grid after resize
    p.snapToGrid(viewportWidth, viewportHeight);
    notifyListeners();
  }

  // -- Operation implementations --

  /// Validate a content node tree against the registry.
  /// Returns a list of unknown widget types found. Empty = valid.
  List<String> _validateContent(SduiNode node) {
    final unknown = <String>[];
    _walkValidate(node, unknown);
    return unknown;
  }

  void _walkValidate(SduiNode node, List<String> unknown) {
    final type = node.type;
    // Check if type exists as a builder, scope builder, or template.
    if (!registry.has(type)) {
      unknown.add(type);
    }
    for (final child in node.children) {
      _walkValidate(child, unknown);
    }
  }

  Map<String, dynamic> _addWindow(AddWindow op) {
    // Validate content against registry before rendering.
    final unknownTypes = _validateContent(op.content);
    if (unknownTypes.isNotEmpty) {
      final unique = unknownTypes.toSet().toList();
      final msg = 'Widget rejected: unknown type(s) ${unique.join(", ")}. '
          'Only types from the SDUI spec are valid. '
          'The agent must call get_primitives before generating widgets.';
      debugPrint('[WindowManager] VALIDATION FAILED: $msg');
      // Show error as a notification (appears in ErrorBar).
      ErrorReporter.instance.report(msg,
        source: 'sdui.validation',
        context: 'addWindow id=${op.id}',
        severity: ErrorSeverity.error,
      );
      return _error('validation_failed', msg, 'addWindow');
    }

    // Check if a window with this ID already exists in any pane
    if (_findWindow(op.id) != null) {
      final pane = _findPaneForWindow(op.id);
      if (pane != null) {
        _focusPane(pane);
        return _success('addWindow', {'windowId': op.id, 'action': 'focused'});
      }
      return _error('window_exists', 'Window "${op.id}" already exists', 'addWindow');
    }

    final ws = WindowState(
      id: op.id,
      title: op.title,
      content: op.content,
      size: WindowSize.fromName(op.size),
      alignment: WindowAlignment.fromName(op.align),
    );

    // Resolve source pane -- check tab IDs and content trees
    final sourcePane = op.sourceWidgetId != null
        ? _findPaneContaining(op.sourceWidgetId!)
        : null;
    // Handle floating placement with explicit coords (LLM use)
    if (op.placement == 'floating') {
      final newPane = PaneState.fromWindow(ws, zIndex: _nextZIndex++);
      // Use explicit coords if provided, otherwise use preset
      if (op.x != null) newPane.x = op.x!;
      if (op.y != null) newPane.y = op.y!;
      if (op.width != null) newPane.width = op.width!;
      if (op.height != null) newPane.height = op.height!;
      // Ensure it stays floating (no grid coords)
      newPane.undock();
      _panes.add(newPane);
      _focusedPaneId = newPane.id;
      notifyListeners();
      return _success('addWindow', {
        'windowId': op.id,
        'paneId': newPane.id,
        'placement': 'floating',
      });
    }

    // Handle samePane placement
    if (op.placement == 'samePane' && sourcePane != null) {
      sourcePane.addTab(ws);
      _focusPane(sourcePane);
      notifyListeners();
      return _success('addWindow', {
        'windowId': op.id,
        'paneId': sourcePane.id,
        'placement': 'samePane',
      });
    }

    // For beside/newPane/default: check if workspace has room
    final dockedCount = _panes.where((p) => p.isDocked).length;
    final wouldFit = (dockedCount + 1) * minPaneColSpan <= gridColumns;

    if (!wouldFit) {
      // Auto-group: merge as tab into source pane or nearest neighbor
      final target = sourcePane ?? _panes.lastWhere((p) => p.isDocked,
          orElse: () => _panes.last);
      target.addTab(ws);
      _focusPane(target);
      notifyListeners();
      return _success('addWindow', {
        'windowId': op.id,
        'paneId': target.id,
        'placement': 'autoGrouped',
      });
    }

    // Room available: create new docked pane beside source
    final pane = PaneState.fromWindow(ws, zIndex: _nextZIndex++);
    _dockNewPane(pane);
    _insertAfter(pane, sourcePane);
    _focusedPaneId = pane.id;
    _retileAll();
    notifyListeners();
    return _success('addWindow', {
      'windowId': op.id,
      'paneId': pane.id,
      'placement': op.placement,
    });
  }

  Map<String, dynamic> _removeWindow(RemoveWindow op) {
    // Remove the entire pane that contains this window
    final pane = _findPaneForWindow(op.windowId);
    if (pane == null) {
      // Maybe it's a pane ID directly
      final idx = _panes.indexWhere((p) => p.id == op.windowId);
      if (idx == -1) return _windowNotFound(op.windowId, 'removeWindow');
      _panes.removeAt(idx);
    } else {
      _panes.remove(pane);
    }
    _dirtyWindows.remove(op.windowId);
    if (_focusedPaneId == op.windowId) _focusedPaneId = null;
    _retileAll();
    notifyListeners();
    return _success('removeWindow', {'windowId': op.windowId});
  }

  Map<String, dynamic> _moveWindow(MoveWindow op) {
    // Move the pane containing this window (or the pane itself)
    final p = _findPane(op.windowId) ?? _findPaneForWindow(op.windowId);
    if (p == null) return _windowNotFound(op.windowId, 'moveWindow');
    if (op.align != null) {
      p.alignment = WindowAlignment.fromName(op.align!);
      p.width = 0;
      p.height = 0;
    }
    if (op.x != null) p.x = op.x!;
    if (op.y != null) p.y = op.y!;
    notifyListeners();
    return _success('moveWindow', {'windowId': op.windowId});
  }

  Map<String, dynamic> _resizeWindow(ResizeWindow op) {
    final p = _findPane(op.windowId) ?? _findPaneForWindow(op.windowId);
    if (p == null) return _windowNotFound(op.windowId, 'resizeWindow');
    if (op.size != null) {
      p.size = WindowSize.fromName(op.size!);
      p.width = 0;
      p.height = 0;
    }
    if (op.width != null) p.width = op.width!;
    if (op.height != null) p.height = op.height!;
    notifyListeners();
    return _success('resizeWindow', {'windowId': op.windowId});
  }

  Map<String, dynamic> _focusWindow(FocusWindow op) {
    final p = _findPane(op.windowId) ?? _findPaneForWindow(op.windowId);
    if (p == null) return _windowNotFound(op.windowId, 'focusWindow');
    _focusPane(p);
    notifyListeners();
    return _success('focusWindow', {'windowId': op.windowId});
  }

  void _focusPane(PaneState pane) {
    pane.zIndex = _nextZIndex++;

    final previousId = _focusedPaneId;
    _focusedPaneId = pane.id;

    if (previousId != null && previousId != pane.id) {
      eventBus.publish(
        'window.$previousId.command',
        EventPayload(type: 'blur', data: {}),
      );
    }
    eventBus.publish(
      'window.${pane.id}.command',
      EventPayload(type: 'focus', data: {}),
    );
  }

  Map<String, dynamic> _minimizeWindow(MinimizeWindow op) {
    // Minimized not supported in pane model (decision D6)
    return _success('minimizeWindow', {'windowId': op.windowId, 'action': 'noop'});
  }

  Map<String, dynamic> _restoreWindow(RestoreWindow op) {
    return _success('restoreWindow', {'windowId': op.windowId, 'action': 'noop'});
  }

  Map<String, dynamic> _updateContent(UpdateContent op) {
    final w = _findWindow(op.windowId);
    if (w == null) return _windowNotFound(op.windowId, 'updateContent');
    w.content = op.content;
    notifyListeners();
    return _success('updateContent', {'windowId': op.windowId});
  }

  // -- Tab operations --

  Map<String, dynamic> _addTab(AddTab op) {
    final pane = _findPane(op.paneId);
    if (pane == null) return _error('pane_not_found', 'Pane "${op.paneId}" not found', 'addTab');

    final windowId = op.content.id.isNotEmpty
        ? op.content.id
        : 'tab-${DateTime.now().millisecondsSinceEpoch}';
    final ws = WindowState(
      id: windowId,
      title: op.title,
      content: op.content,
    );
    pane.addTab(ws);
    notifyListeners();
    return _success('addTab', {'paneId': op.paneId, 'windowId': windowId});
  }

  Map<String, dynamic> _removeTab(RemoveTab op) {
    final pane = _findPaneForWindow(op.windowId);
    if (pane == null) return _windowNotFound(op.windowId, 'removeTab');

    final isEmpty = pane.removeTab(op.windowId);
    _dirtyWindows.remove(op.windowId);

    if (isEmpty) {
      _panes.remove(pane);
      if (_focusedPaneId == pane.id) _focusedPaneId = null;
      _retileAll();
    }

    notifyListeners();
    return _success('removeTab', {'windowId': op.windowId, 'paneRemoved': isEmpty});
  }

  Map<String, dynamic> _activateTab(ActivateTab op) {
    final pane = _findPaneForWindow(op.windowId);
    if (pane == null) return _windowNotFound(op.windowId, 'activateTab');

    final idx = pane.tabs.indexWhere((t) => t.id == op.windowId);
    if (idx >= 0) pane.activeTabIndex = idx;

    notifyListeners();
    return _success('activateTab', {'windowId': op.windowId});
  }

  // -- Content tree operations --

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
    for (final p in _panes) {
      for (final t in p.tabs) {
        if (_removeNodeFromTree(t, op.nodeId)) {
          notifyListeners();
          return _success('removeChild', {'nodeId': op.nodeId});
        }
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

  PaneState? _findPane(String paneId) {
    for (final p in _panes) {
      if (p.id == paneId) return p;
    }
    return null;
  }

  /// Find the pane containing a widget ID -- searches tab IDs, content roots,
  /// and prefix matches (for template-expanded IDs like "chat-box-root-root"
  /// which derive from content root "chat-box-root").
  PaneState? _findPaneContaining(String widgetId) {
    // First check tab IDs
    final byTab = _findPaneForWindow(widgetId);
    if (byTab != null) return byTab;
    // Then check content tree nodes
    for (final p in _panes) {
      for (final t in p.tabs) {
        if (_findNodeInTree(t.content, widgetId) != null) return p;
      }
    }
    // Finally, prefix match: template-expanded IDs start with the content root ID
    for (final p in _panes) {
      for (final t in p.tabs) {
        if (widgetId.startsWith(t.content.id)) return p;
      }
    }
    return null;
  }

  PaneState? _findPaneForWindow(String windowId) {
    for (final p in _panes) {
      if (p.findTab(windowId) != null) return p;
    }
    return null;
  }

  WindowState? _findWindow(String id) {
    for (final p in _panes) {
      final t = p.findTab(id);
      if (t != null) return t;
    }
    return null;
  }

  SduiNode? _findNode(String nodeId) {
    for (final p in _panes) {
      for (final t in p.tabs) {
        final found = _findNodeInTree(t.content, nodeId);
        if (found != null) return found;
      }
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
    for (final p in _panes) {
      for (final t in p.tabs) {
        final updated = _replaceNodeInTree(t.content, nodeId, replacement);
        if (updated != null) {
          t.content = updated;
          return;
        }
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

  /// Insert a pane into _panes right after the reference pane.
  /// If reference is null, appends to the end.
  void _insertAfter(PaneState pane, PaneState? reference) {
    if (reference != null) {
      final idx = _panes.indexOf(reference);
      if (idx >= 0) {
        _panes.insert(idx + 1, pane);
        return;
      }
    }
    _panes.add(pane);
  }

  /// Dock a new pane to the grid based on its size/alignment presets.
  void _dockNewPane(PaneState pane) {
    // Map size presets to grid spans
    final colSpan = (pane.size.widthFraction * gridColumns).round().clamp(1, gridColumns);
    final rowSpan = (pane.size.heightFraction * gridRows).round().clamp(1, gridRows);

    // Map alignment presets to grid position
    final col = ((gridColumns - colSpan) * pane.alignment.xFraction).round().clamp(0, gridColumns - colSpan);
    final row = ((gridRows - rowSpan) * pane.alignment.yFraction).round().clamp(0, gridRows - rowSpan);

    pane.dockAt(col, row, colSpan, rowSpan);
    if (viewportWidth > 0 && viewportHeight > 0) {
      pane.computePositionFromGrid(viewportWidth, viewportHeight);
    }
  }

  /// Re-tile all docked panes to fill the entire workspace.
  ///
  /// Uses equal horizontal splits: N docked panes each get 12/N columns,
  /// full height (12 rows). Floating panes are not affected.
  void _retileAll() {
    final docked = _panes.where((p) => p.isDocked).toList();
    if (docked.isEmpty) return;

    final n = docked.length;
    for (var i = 0; i < n; i++) {
      final colStart = (i * gridColumns) ~/ n;
      final colEnd = ((i + 1) * gridColumns) ~/ n;
      docked[i].dockAt(colStart, 0, colEnd - colStart, gridRows);
      if (viewportWidth > 0 && viewportHeight > 0) {
        docked[i].computePositionFromGrid(viewportWidth, viewportHeight);
      }
    }
  }

  /// Resolve a hex color string to a Color.
  static Color _parseColor(String hex) {
    final h = hex.startsWith('#') ? hex.substring(1) : hex;
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    if (h.length == 8) return Color(int.parse(h, radix: 16));
    return _defaultTypeColor;
  }

  Map<String, dynamic> _success(String op, Map<String, dynamic> data) =>
      {'success': true, 'op': op, ...data};

  Map<String, dynamic> _error(String error, String message, String op) =>
      {'success': false, 'error': error, 'message': message, 'op': op};

  Map<String, dynamic> _windowNotFound(String windowId, String op) =>
      _error('window_not_found', 'Window "$windowId" does not exist', op);

  @override
  void dispose() {
    _layoutSubscription?.cancel();
    _intentSubscription?.cancel();
    _dirtySubscription?.cancel();
    super.dispose();
  }
}


/// Resize handle at bottom-right of a floating pane.
class _ResizeHandle extends StatelessWidget {
  final String paneId;
  final void Function(String paneId, double dw, double dh) onResize;
  final VoidCallback? onResizeEnd;
  final Color handleColor;
  final bool visible;

  const _ResizeHandle({
    required this.paneId,
    required this.onResize,
    this.onResizeEnd,
    required this.handleColor,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return GestureDetector(
      onPanUpdate: (details) {
        onResize(paneId, details.delta.dx, details.delta.dy);
      },
      onPanEnd: (_) => onResizeEnd?.call(),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeDownRight,
        child: SizedBox(
          width: 16,
          height: 16,
          child: CustomPaint(
            painter: _GripPainter(color: handleColor),
          ),
        ),
      ),
    );
  }
}

class _GripPainter extends CustomPainter {
  final Color color;
  _GripPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    // Draw 3 diagonal lines as grip indicator
    for (var i = 0; i < 3; i++) {
      final offset = 4.0 + i * 4;
      canvas.drawLine(
        Offset(size.width, offset),
        Offset(offset, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GripPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Draggable splitter handle between two docked panes.
class _SplitterHandle extends StatefulWidget {
  final SduiTheme theme;
  final ValueChanged<double> onDrag;

  const _SplitterHandle({required this.theme, required this.onDrag});

  @override
  State<_SplitterHandle> createState() => _SplitterHandleState();
}

class _SplitterHandleState extends State<_SplitterHandle> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.theme.colors;
    final isActive = _hovered || _dragging;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() => _dragging = true),
        onPanUpdate: (details) => widget.onDrag(details.delta.dx),
        onPanEnd: (_) => setState(() => _dragging = false),
        child: Center(
          child: Container(
            width: isActive ? 3 : widget.theme.lineWeight.subtle,
            height: double.infinity,
            color: isActive ? colors.primary : colors.borderSubtle,
          ),
        ),
      ),
    );
  }
}

/// Stateful widget that renders SDUI content for a pane tab.
/// Preserves its subtree across parent rebuilds (e.g., when another
/// pane is focused or dragged) because the key is stable per tab.
class _PaneContent extends StatelessWidget {
  final WidgetRegistry registry;
  final SduiRenderContext renderContext;
  final SduiNode contentNode;

  const _PaneContent({
    super.key,
    required this.registry,
    required this.renderContext,
    required this.contentNode,
  });

  @override
  Widget build(BuildContext context) {
    final renderer = SduiRenderer(
      registry: registry,
      renderContext: renderContext,
    );
    return renderer.render(contentNode);
  }
}
