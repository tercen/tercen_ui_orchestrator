import 'window_state.dart';

/// Grid constants.
const int gridColumns = 12;
const int gridRows = 12;

/// Minimum column span per docked pane. When adding a new pane would make
/// all panes narrower than this, the new pane auto-merges as a tab instead.
const int minPaneColSpan = 2;

/// A pane is a tab container that holds 1+ windows (tabs) in the workspace.
///
/// The pane owns position/size/zIndex. Each tab is a [WindowState] with
/// its own content tree. The pane renders a tab strip + the active tab's content.
///
/// Panes can be **docked** (snapped to the 12x12 grid) or **floating**
/// (pixel-positioned, no grid coords). Docked is the default; floating is
/// the exception (user explicitly undocks or a special widget requests it).
class PaneState {
  final String id;
  final List<WindowState> tabs;
  int activeTabIndex;

  // Pixel coordinates (always computed, even for docked panes)
  double x;
  double y;
  double width;
  double height;
  int zIndex;

  // Grid coordinates (null = floating, non-null = docked)
  int? gridCol;
  int? gridRow;
  int? gridColSpan;
  int? gridRowSpan;

  // Size/alignment presets (used for initial computation when not docked)
  WindowSize size;
  WindowAlignment alignment;

  PaneState({
    required this.id,
    required this.tabs,
    this.activeTabIndex = 0,
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
    this.zIndex = 0,
    this.gridCol,
    this.gridRow,
    this.gridColSpan,
    this.gridRowSpan,
    this.size = WindowSize.medium,
    this.alignment = WindowAlignment.center,
  });

  /// Whether this pane is docked to the grid.
  bool get isDocked => gridCol != null;

  /// Whether this pane is floating (no grid coordinates).
  bool get isFloating => gridCol == null;

  /// The currently active tab, or null if no tabs.
  WindowState? get activeTab =>
      (activeTabIndex >= 0 && activeTabIndex < tabs.length)
          ? tabs[activeTabIndex]
          : null;

  /// Convenience: the active tab's title, or the pane ID.
  String get title => activeTab?.title ?? id;

  /// Compute pixel position from presets within a viewport (floating mode).
  void computePosition(double viewportW, double viewportH) {
    if (isDocked) {
      computePositionFromGrid(viewportW, viewportH);
    } else {
      width = viewportW * size.widthFraction;
      height = viewportH * size.heightFraction;
      x = (viewportW - width) * alignment.xFraction;
      y = (viewportH - height) * alignment.yFraction;
    }
  }

  /// Compute pixel position from grid coordinates.
  void computePositionFromGrid(double viewportW, double viewportH) {
    final cellW = viewportW / gridColumns;
    final cellH = viewportH / gridRows;
    x = gridCol! * cellW;
    y = gridRow! * cellH;
    width = gridColSpan! * cellW;
    height = gridRowSpan! * cellH;
  }

  /// Snap this pane to the nearest grid cell based on current pixel position.
  void snapToGrid(double viewportW, double viewportH) {
    final cellW = viewportW / gridColumns;
    final cellH = viewportH / gridRows;

    // Compute span from current size
    gridColSpan = (width / cellW).round().clamp(1, gridColumns);
    gridRowSpan = (height / cellH).round().clamp(1, gridRows);

    // Compute position from current location
    gridCol = (x / cellW).round().clamp(0, gridColumns - gridColSpan!);
    gridRow = (y / cellH).round().clamp(0, gridRows - gridRowSpan!);

    // Recompute pixel position from snapped grid
    computePositionFromGrid(viewportW, viewportH);
  }

  /// Dock to a specific grid position.
  void dockAt(int col, int row, int colSpan, int rowSpan) {
    gridCol = col;
    gridRow = row;
    gridColSpan = colSpan;
    gridRowSpan = rowSpan;
  }

  /// Undock from the grid (becomes floating).
  void undock() {
    gridCol = null;
    gridRow = null;
    gridColSpan = null;
    gridRowSpan = null;
  }

  /// Add a tab. Returns the index of the new tab.
  int addTab(WindowState window) {
    tabs.add(window);
    activeTabIndex = tabs.length - 1;
    return activeTabIndex;
  }

  /// Remove a tab by window ID. Returns true if the pane is now empty.
  bool removeTab(String windowId) {
    final idx = tabs.indexWhere((t) => t.id == windowId);
    if (idx == -1) return false;
    tabs.removeAt(idx);
    if (activeTabIndex >= tabs.length) {
      activeTabIndex = tabs.length - 1;
    }
    return tabs.isEmpty;
  }

  /// Find a tab by window ID.
  WindowState? findTab(String windowId) {
    for (final t in tabs) {
      if (t.id == windowId) return t;
    }
    return null;
  }

  /// Full serialization for layout save/restore.
  Map<String, dynamic> toFullJson() => {
        'id': id,
        'x': x.round(),
        'y': y.round(),
        'width': width.round(),
        'height': height.round(),
        'zIndex': zIndex,
        'activeTabIndex': activeTabIndex,
        if (gridCol != null) 'gridCol': gridCol,
        if (gridRow != null) 'gridRow': gridRow,
        if (gridColSpan != null) 'gridColSpan': gridColSpan,
        if (gridRowSpan != null) 'gridRowSpan': gridRowSpan,
        'tabs': tabs.map((t) => t.toFullJson()).toList(),
      };

  /// Restore from saved layout JSON.
  factory PaneState.fromFullJson(Map<String, dynamic> json) {
    final tabList = (json['tabs'] as List?)
            ?.map((t) =>
                WindowState.fromFullJson(Map<String, dynamic>.from(t as Map)))
            .toList() ??
        [];
    return PaneState(
      id: json['id'] as String,
      tabs: tabList,
      activeTabIndex: json['activeTabIndex'] as int? ?? 0,
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
      zIndex: json['zIndex'] as int? ?? 0,
      gridCol: json['gridCol'] as int?,
      gridRow: json['gridRow'] as int?,
      gridColSpan: json['gridColSpan'] as int?,
      gridRowSpan: json['gridRowSpan'] as int?,
    );
  }

  /// Create a single-tab pane from a WindowState (backward compat with AddWindow).
  factory PaneState.fromWindow(WindowState window, {int zIndex = 0}) {
    return PaneState(
      id: 'pane-${window.id}',
      tabs: [window],
      activeTabIndex: 0,
      size: window.size,
      alignment: window.alignment,
      zIndex: zIndex,
    );
  }
}
