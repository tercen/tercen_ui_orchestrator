import 'dart:async';

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import '../../di/service_locator.dart';
import '../../domain/models/content_state.dart';
import '../../domain/models/layout_node.dart';
import '../../domain/models/workflow_models.dart';
import '../../domain/models/window_identity.dart';
import '../../domain/services/data_service.dart';
import '../../domain/services/event_bus.dart';
import '../../domain/services/event_payload.dart';
import '../../domain/services/window_channels.dart';
import '../../domain/services/workflow_channels.dart';
import '../../implementations/services/mock_execution_engine.dart';

/// Manages workflow viewer state: workflow data, layout, focus, search.
class WorkflowProvider extends ChangeNotifier {
  final DataService _dataService = serviceLocator<DataService>();
  final EventBus _eventBus = serviceLocator<EventBus>();
  late final MockExecutionEngine _executionEngine;

  final WindowIdentity identity;
  final String windowId;

  // -- Content state --
  ContentState _contentState = ContentState.loading;
  ContentState get contentState => _contentState;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // -- Workflow data --
  WorkflowModel? _workflow;
  WorkflowModel? get workflow => _workflow;

  // -- Layout --
  List<LayoutNode> _layoutNodes = [];
  List<LayoutNode> get layoutNodes => _layoutNodes;

  // -- Focus --
  String? _focusedNodeId;
  String? get focusedNodeId => _focusedNodeId;

  LayoutNode? get focusedNode {
    if (_focusedNodeId == null) return null;
    try {
      return _layoutNodes.firstWhere((n) => n.id == _focusedNodeId);
    } catch (_) {
      return null;
    }
  }

  /// Whether the workflow root (not a specific step) is focused.
  bool get isWorkflowRootFocused => _focusedNodeId == _workflowRootId;

  String? get _workflowRootId => _layoutNodes.isNotEmpty &&
          _layoutNodes.first.kind == StepKind.workflow
      ? _layoutNodes.first.id
      : null;

  // -- Search --
  String _searchText = '';
  String get searchText => _searchText;

  Set<String> _searchMatches = {};
  Set<String> get searchMatches => _searchMatches;

  // -- Zoom / pan --
  final TransformationController transformController =
      TransformationController();
  bool initialFitApplied = false;

  // -- Drag state --
  String? _draggingNodeId;
  String? get draggingNodeId => _draggingNodeId;

  // -- Inline rename --
  String? _editingNodeId;
  String? get editingNodeId => _editingNodeId;

  // -- Subscriptions --
  StreamSubscription<EventPayload>? _commandSub;
  StreamSubscription<EventPayload>? _openWorkflowSub;
  StreamSubscription<EventPayload>? _stepStateSub;
  StreamSubscription<EventPayload>? _workflowUpdatedSub;
  StreamSubscription<EventPayload>? _navigateToStepSub;

  WorkflowProvider({
    required this.identity,
    required this.windowId,
  }) {
    _executionEngine = MockExecutionEngine(
      eventBus: _eventBus,
      sourceWidgetId: windowId,
    );
    _commandSub = _eventBus
        .subscribe(WindowChannels.commandChannel(windowId))
        .listen(_handleCommand);
    _openWorkflowSub = _eventBus
        .subscribe(WorkflowChannels.openWorkflow)
        .listen(_handleOpenWorkflow);
    _stepStateSub = _eventBus
        .subscribe(WorkflowChannels.stepStateChanged)
        .listen(_handleStepStateChanged);
    _workflowUpdatedSub = _eventBus
        .subscribe(WorkflowChannels.workflowUpdated)
        .listen((_) => loadWorkflow());
    _navigateToStepSub = _eventBus
        .subscribe(WorkflowChannels.navigateToStep)
        .listen(_handleNavigateToStep);

    // Auto-load on creation
    loadWorkflow();
  }

  void _handleCommand(EventPayload payload) {
    // Handle focus/blur from frame
  }

  void _handleOpenWorkflow(EventPayload payload) {
    loadWorkflow();
  }

  void _handleStepStateChanged(EventPayload payload) {
    final stepId = payload.data['stepId'] as String?;
    final newStateStr = payload.data['newState'] as String?;
    if (stepId == null || newStateStr == null) return;

    final newState = StepState.values.firstWhere(
      (s) => s.name == newStateStr,
      orElse: () => StepState.init,
    );

    final node = _findLayoutNode(stepId);
    if (node != null) {
      node.step.state = newState;
      notifyListeners();
    }
  }

  void _handleNavigateToStep(EventPayload payload) {
    final stepId = payload.data['stepId'] as String?;
    if (stepId != null) {
      focusNode(stepId);
    }
  }

  // -- Loading --

  Future<void> loadWorkflow() async {
    _contentState = ContentState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _workflow = await _dataService.fetchWorkflow(
        '2cdf2d2d4f0adbadc5f95636b10e2cd9',
        '2cdf2d2d4f0adbadc5f95636b10e6b08',
      );
      if (_workflow == null || _workflow!.steps.isEmpty) {
        _contentState = ContentState.empty;
      } else {
        _contentState = ContentState.active;
        _buildLayout();
        // Focus the workflow root by default
        if (_layoutNodes.isNotEmpty) {
          _focusedNodeId = _layoutNodes.first.id;
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
      _contentState = ContentState.error;
    }
    notifyListeners();
  }

  // -- Layout computation --

  /// Meta layout types that drive positioning rules.
  /// - entrypoint: always col 1, row +1
  /// - pathway: diagonal (+1 row, +1 col)
  /// - connector: diagonal (+1 row, +1 col), connect-back from secondary chains
  /// - output: same row as parent, +1 col
  static _LayoutMeta _metaType(StepKind kind) {
    switch (kind) {
      case StepKind.workflow:
      case StepKind.tableStep:
      case StepKind.inStep:
        return _LayoutMeta.entrypoint;
      case StepKind.dataStep:
      case StepKind.meltStep:
      case StepKind.wizardStep:
        return _LayoutMeta.pathway;
      case StepKind.joinStep:
        return _LayoutMeta.connector;
      case StepKind.groupStep:
      case StepKind.viewStep:
      case StepKind.outStep:
      case StepKind.exportStep:
        return _LayoutMeta.output;
    }
  }

  void _buildLayout() {
    if (_workflow == null) return;
    _fitted = false;
    _layoutNodes = [];

    final steps = _workflow!.steps;
    final links = _workflow!.links;

    // Build adjacency: parentMap[id] = steps feeding INTO id
    //                   childMap[id] = steps consuming FROM id
    final parentMap = <String, List<String>>{};
    final childMap = <String, List<String>>{};
    final stepMap = <String, StepModel>{};
    for (final s in steps) {
      parentMap[s.id] = [];
      childMap[s.id] = [];
      stepMap[s.id] = s;
    }
    for (final link in links) {
      parentMap[link.inputStepId]?.add(link.outputStepId);
      childMap[link.outputStepId]?.add(link.inputStepId);
    }

    // 1. Synthetic workflow root at (0, 0)
    final rootStep = StepModel(
      id: 'workflow-root',
      name: _workflow!.name,
      groupId: '',
      kind: StepKind.workflow,
      state: _deriveWorkflowState(),
    );
    final rootConfig = _getDisplayConfig(StepKind.workflow);
    _layoutNodes.add(LayoutNode(
      step: rootStep,
      displayStyle: rootConfig.displayStyle,
      shape: rootConfig.shape,
      nameDisplay: rootConfig.nameDisplay,
      editableName: rootConfig.editableName,
      row: 0,
      col: 0, // Header row, outside the grid columns
    ));

    // 2. Find main spine (longest entry→terminal path)
    final mainSpine = _findMainSpine(steps, stepMap, parentMap, childMap);
    final placed = <String>{};

    // 3. Interleaved layout: walk the main spine, but when we hit a join,
    //    lay out its secondary chains first, then place the join below them.
    //    This ensures all connectors flow downward.
    double nextRow = 1;
    // Track the primary-pipeline column for each spine step
    double nextCol = 1;

    final spineIds = mainSpine.map((s) => s.id).toSet();

    for (int i = 0; i < mainSpine.length; i++) {
      final step = mainSpine[i];
      final config = _getDisplayConfig(step.kind);
      final meta = _metaType(step.kind);

      // Before placing this spine step (except the first), check if the
      // previous spine step has non-spine children. Place them first,
      // sorted by: output-type first, then ascending descendant count.
      // This ensures leaf branches appear above deep spine continuations.
      if (i > 0) {
        final prevStep = mainSpine[i - 1];
        final prevChildren = childMap[prevStep.id] ?? [];
        final nonSpineSiblings = prevChildren.where((cid) {
          if (placed.contains(cid)) return false;
          if (spineIds.contains(cid)) return false;
          return stepMap.containsKey(cid);
        }).toList();

        // Sort: output-type first, then by ascending descendant count
        nonSpineSiblings.sort((a, b) {
          final metaA = _metaType(stepMap[a]!.kind);
          final metaB = _metaType(stepMap[b]!.kind);
          final isOutputA = metaA == _LayoutMeta.output ? 0 : 1;
          final isOutputB = metaB == _LayoutMeta.output ? 0 : 1;
          if (isOutputA != isOutputB) return isOutputA.compareTo(isOutputB);
          final da = _countDescendants(a, childMap, {});
          final db = _countDescendants(b, childMap, {});
          return da.compareTo(db);
        });

        final prevNode = _findLayoutNode(prevStep.id)!;
        for (final sibId in nonSpineSiblings) {
          if (placed.contains(sibId)) continue;
          // Walk the forward chain from this sibling
          final chain =
              _walkChainForward(sibId, stepMap, childMap, placed);
          for (int ci = 0; ci < chain.length; ci++) {
            final chainStep = chain[ci];
            if (placed.contains(chainStep.id)) continue;
            final cConfig = _getDisplayConfig(chainStep.kind);
            double col;
            if (ci == 0) {
              col = prevNode.col + 1;
            } else {
              final prev = _findLayoutNode(chain[ci - 1].id)!;
              col = prev.col + 1;
            }
            _layoutNodes.add(LayoutNode(
              step: chainStep,
              displayStyle: cConfig.displayStyle,
              shape: cConfig.shape,
              nameDisplay: cConfig.nameDisplay,
              editableName: cConfig.editableName,
              row: nextRow,
              col: col,
            ));
            placed.add(chainStep.id);
            nextRow++;
          }
        }
      }

      if (meta == _LayoutMeta.connector) {
        // This is a join step. Before placing it, lay out secondary chains.
        final inputIds = parentMap[step.id] ?? [];
        for (final inputId in inputIds) {
          if (placed.contains(inputId)) continue;
          final chain =
              _walkChainBackward(inputId, stepMap, parentMap, placed);
          _layoutChain(chain, nextRow, placed);
          nextRow += chain.length;
        }
        // Place the join below the deepest secondary parent
        _layoutNodes.add(LayoutNode(
          step: step,
          displayStyle: config.displayStyle,
          shape: config.shape,
          nameDisplay: config.nameDisplay,
          editableName: config.editableName,
          row: nextRow,
          col: nextCol,
        ));
        placed.add(step.id);
        nextRow++;
        nextCol++;
      } else if (i == 0) {
        // First step on spine
        _layoutNodes.add(LayoutNode(
          step: step,
          displayStyle: config.displayStyle,
          shape: config.shape,
          nameDisplay: config.nameDisplay,
          editableName: config.editableName,
          row: nextRow,
          col: nextCol,
        ));
        placed.add(step.id);
        nextRow++;
        nextCol++;
      } else {
        // Non-join spine step
        if (meta == _LayoutMeta.entrypoint) {
          // Entrypoints reset to col 1
          _layoutNodes.add(LayoutNode(
            step: step,
            displayStyle: config.displayStyle,
            shape: config.shape,
            nameDisplay: config.nameDisplay,
            editableName: config.editableName,
            row: nextRow,
            col: 1,
          ));
          placed.add(step.id);
          nextRow++;
          nextCol = 2; // Next non-entrypoint will be col 2
        } else {
          _layoutNodes.add(LayoutNode(
            step: step,
            displayStyle: config.displayStyle,
            shape: config.shape,
            nameDisplay: config.nameDisplay,
            editableName: config.editableName,
            row: nextRow,
            col: nextCol,
          ));
          placed.add(step.id);
          nextRow++;
          nextCol++;
        }
      }
    }

    // 4. Fan-out branches: for each placed node, find unplaced children
    //    and lay them out. Leaf children first, then by ascending chain depth.
    //    This handles cases where one parent feeds multiple parallel branches.
    _placeFanOutBranches(placed, stepMap, childMap, parentMap, nextRow);
    // Update nextRow after fan-out placement
    for (final node in _layoutNodes) {
      if (node.row >= nextRow) nextRow = node.row + 1;
    }

    // 5. Place remaining unplaced steps (ViewSteps, isolated nodes, etc.)
    for (final step in steps) {
      if (placed.contains(step.id)) continue;
      final config = _getDisplayConfig(step.kind);

      if (step.kind == StepKind.viewStep) {
        final parentIds = parentMap[step.id] ?? [];
        if (parentIds.isNotEmpty) {
          final parentNode = _findLayoutNode(parentIds.first);
          if (parentNode != null) {
            final existingViews = _layoutNodes
                .where((n) =>
                    n.kind == StepKind.viewStep &&
                    (n.row - parentNode.row).abs() < 0.5)
                .length;
            _layoutNodes.add(LayoutNode(
              step: step,
              displayStyle: config.displayStyle,
              shape: config.shape,
              nameDisplay: config.nameDisplay,
              editableName: config.editableName,
              row: parentNode.row,
              col: parentNode.col + 1 + existingViews,
            ));
            placed.add(step.id);
            continue;
          }
        }
      }

      // Fallback for any unplaced step
      _layoutNodes.add(LayoutNode(
        step: step,
        displayStyle: config.displayStyle,
        shape: config.shape,
        nameDisplay: config.nameDisplay,
        editableName: config.editableName,
        row: nextRow,
        col: 1,
      ));
      placed.add(step.id);
      nextRow++;
    }

    _computePixelPositions();
  }

  /// Find the longest path from any entry to any terminal node.
  /// This becomes the main spine that is laid out first.
  List<StepModel> _findMainSpine(
    List<StepModel> steps,
    Map<String, StepModel> stepMap,
    Map<String, List<String>> parentMap,
    Map<String, List<String>> childMap,
  ) {
    // Terminal nodes have no children
    final terminals =
        steps.where((s) => childMap[s.id]?.isEmpty ?? true).toList();
    if (terminals.isEmpty) return steps;

    List<StepModel> longest = [];
    for (final terminal in terminals) {
      final path = _longestPathTo(terminal.id, stepMap, parentMap);
      if (path.length > longest.length) longest = path;
    }
    return longest;
  }

  /// Recursively find the longest path ending at [stepId],
  /// choosing the longest branch at each join.
  List<StepModel> _longestPathTo(
    String stepId,
    Map<String, StepModel> stepMap,
    Map<String, List<String>> parentMap,
  ) {
    final step = stepMap[stepId];
    if (step == null) return [];

    final parentIds = parentMap[stepId] ?? [];
    if (parentIds.isEmpty) return [step];

    List<StepModel> longestParent = [];
    for (final pid in parentIds) {
      final path = _longestPathTo(pid, stepMap, parentMap);
      if (path.length > longestParent.length) longestParent = path;
    }
    return [...longestParent, step];
  }

  /// Walk backward from [startId] collecting unplaced steps
  /// until reaching an entry point or an already-placed step.
  List<StepModel> _walkChainBackward(
    String startId,
    Map<String, StepModel> stepMap,
    Map<String, List<String>> parentMap,
    Set<String> alreadyPlaced,
  ) {
    final chain = <StepModel>[];
    String? currentId = startId;

    while (currentId != null) {
      if (alreadyPlaced.contains(currentId)) break;
      final step = stepMap[currentId];
      if (step == null) break;
      chain.add(step);
      final pids = parentMap[currentId] ?? [];
      currentId = pids.isEmpty ? null : pids.first;
    }

    return chain.reversed.toList();
  }

  /// Layout a chain of steps starting at [startRow], col 1.
  void _layoutChain(
    List<StepModel> chain,
    double startRow,
    Set<String> placed,
  ) {
    for (int i = 0; i < chain.length; i++) {
      final step = chain[i];
      if (placed.contains(step.id)) continue;

      final config = _getDisplayConfig(step.kind);

      double row = 0;
      double col = 0;

      if (i == 0) {
        row = startRow;
        col = 1;
      } else {
        final prev = _findLayoutNode(chain[i - 1].id)!;
        final meta = _metaType(step.kind);
        if (meta == _LayoutMeta.entrypoint) {
          row = prev.row + 1;
          col = 1;
        } else {
          // All non-entrypoint steps: diagonal +1 row, +1 col
          row = prev.row + 1;
          col = prev.col + 1;
        }
      }

      _layoutNodes.add(LayoutNode(
        step: step,
        displayStyle: config.displayStyle,
        shape: config.shape,
        nameDisplay: config.nameDisplay,
        editableName: config.editableName,
        row: row,
        col: col,
      ));
      placed.add(step.id);
    }
  }

  /// Count total descendants of a step (for fan-out ordering).
  int _countDescendants(
    String stepId,
    Map<String, List<String>> childMap,
    Set<String> visited,
  ) {
    if (visited.contains(stepId)) return 0;
    visited.add(stepId);
    final children = childMap[stepId] ?? [];
    int count = children.length;
    for (final cid in children) {
      count += _countDescendants(cid, childMap, visited);
    }
    return count;
  }

  /// Walk forward from [startId] collecting unplaced steps until reaching
  /// a terminal or an already-placed step.
  List<StepModel> _walkChainForward(
    String startId,
    Map<String, StepModel> stepMap,
    Map<String, List<String>> childMap,
    Set<String> alreadyPlaced,
  ) {
    final chain = <StepModel>[];
    String? currentId = startId;

    while (currentId != null) {
      if (alreadyPlaced.contains(currentId)) break;
      final step = stepMap[currentId];
      if (step == null) break;
      chain.add(step);
      // Follow the first unplaced child (linear chain)
      final children = childMap[currentId] ?? [];
      currentId = null;
      for (final cid in children) {
        if (!alreadyPlaced.contains(cid)) {
          currentId = cid;
          break;
        }
      }
    }

    return chain;
  }

  /// Place fan-out branches: for each already-placed node that has unplaced
  /// children, lay them out. Leaf branches first, then by ascending depth.
  void _placeFanOutBranches(
    Set<String> placed,
    Map<String, StepModel> stepMap,
    Map<String, List<String>> childMap,
    Map<String, List<String>> parentMap,
    double startRow,
  ) {
    double nextRow = startRow;
    bool progress = true;

    // Iterate until no more unplaced fan-out branches remain
    while (progress) {
      progress = false;

      // Snapshot of currently placed nodes (to avoid modifying while iterating)
      final placedSnapshot = _layoutNodes.toList();

      for (final parentNode in placedSnapshot) {
        final children = childMap[parentNode.id] ?? [];
        final unplacedChildren =
            children.where((cid) => !placed.contains(cid)).toList();
        if (unplacedChildren.isEmpty) continue;

        // Sort: output-type children (View, Output, Export) first,
        // then by ascending descendant count (leaf nodes before deep chains)
        unplacedChildren.sort((a, b) {
          final stepA = stepMap[a]!;
          final stepB = stepMap[b]!;
          final metaA = _metaType(stepA.kind);
          final metaB = _metaType(stepB.kind);
          final isOutputA = metaA == _LayoutMeta.output ? 0 : 1;
          final isOutputB = metaB == _LayoutMeta.output ? 0 : 1;
          if (isOutputA != isOutputB) return isOutputA.compareTo(isOutputB);
          final da = _countDescendants(a, childMap, {});
          final db = _countDescendants(b, childMap, {});
          return da.compareTo(db);
        });

        for (final childId in unplacedChildren) {
          if (placed.contains(childId)) continue;

          // Walk forward to build the branch chain
          final chain = _walkChainForward(childId, stepMap, childMap, placed);
          if (chain.isEmpty) continue;

          // Place the chain: first step at parent's col + 1, then diagonal
          for (int i = 0; i < chain.length; i++) {
            final step = chain[i];
            if (placed.contains(step.id)) continue;

            final config = _getDisplayConfig(step.kind);
            double row;
            double col;

            if (i == 0) {
              row = nextRow;
              col = parentNode.col + 1;
            } else {
              final prev = _findLayoutNode(chain[i - 1].id)!;
              final meta = _metaType(step.kind);
              if (meta == _LayoutMeta.entrypoint) {
                row = prev.row + 1;
                col = 1;
              } else {
                row = prev.row + 1;
                col = prev.col + 1;
              }
            }

            _layoutNodes.add(LayoutNode(
              step: step,
              displayStyle: config.displayStyle,
              shape: config.shape,
              nameDisplay: config.nameDisplay,
              editableName: config.editableName,
              row: row,
              col: col,
            ));
            placed.add(step.id);
            if (row >= nextRow) nextRow = row + 1;
          }

          progress = true;
        }
      }
    }
  }

  void _computePixelPositions() {
    const double colGap = 16.0;
    const double rowGap = 12.0;
    const double marginX = 8.0;
    const double marginY = 8.0;
    const double headerHeight = 56.0; // Height of workflow header row

    // Estimate each node's width and shape dimensions
    for (final node in _layoutNodes) {
      node.width = _estimateNodeWidth(node);
      final shapeDims = _shapeSize(node);
      node.shapeWidth = shapeDims.$1;
      node.shapeHeight = shapeDims.$2;
    }

    // For agent-provided rectangles, extract lane/depth grid indices
    // so all nodes go through the same column-width system.
    _extractGridFromRectangles();

    // Find max column and max row
    int maxCol = 0;
    int maxRow = 0;
    for (final node in _layoutNodes) {
      final c = node.col.toInt();
      final r = node.row.toInt();
      if (c > maxCol) maxCol = c;
      if (r > maxRow) maxRow = r;
    }

    // Compute column widths using shapeWidth (exclude header col 0)
    final colWidths = List.filled(maxCol + 1, 36.0);
    for (final node in _layoutNodes) {
      if (node.col.toInt() == 0) continue;
      final c = node.col.toInt();
      final w = node.shapeWidth > 0 ? node.shapeWidth : 36.0;
      if (w > colWidths[c]) colWidths[c] = w;
    }

    // Cumulative x positions per column (left edge of each column)
    final colX = List.filled(maxCol + 1, 0.0);
    colX[0] = marginX;
    for (int c = 1; c <= maxCol; c++) {
      colX[c] = colX[c - 1] + colWidths[c - 1] + colGap;
    }

    // Compute row heights from max shapeHeight in each row
    final rowHeights = List.filled(maxRow + 1, 36.0);
    for (final node in _layoutNodes) {
      if (node.kind == StepKind.workflow) continue;
      final r = node.row.toInt();
      final h = node.shapeHeight > 0 ? node.shapeHeight : 36.0;
      if (h > rowHeights[r]) rowHeights[r] = h;
    }

    // Cumulative y positions per row (top edge)
    final rowY = List.filled(maxRow + 1, 0.0);
    rowY[0] = headerHeight;
    for (int r = 1; r <= maxRow; r++) {
      rowY[r] = rowY[r - 1] + rowHeights[r - 1] + rowGap;
    }

    for (final node in _layoutNodes) {
      if (node.kind == StepKind.workflow) {
        // Header row: center-aligned with grid col 1
        final col1Center = colX.length > 1
            ? colX[1] + colWidths[1] / 2
            : marginX;
        node.x = col1Center - node.shapeWidth / 2;
        node.y = marginY + (headerHeight - node.shapeHeight) / 2;
      } else {
        // All nodes: center within their column and row
        final c = node.col.toInt();
        final r = node.row.toInt();
        node.x = colX[c] + (colWidths[c] - node.shapeWidth) / 2;
        node.y = rowY[r] + (rowHeights[r] - node.shapeHeight) / 2;
      }
    }
  }

  /// Extract lane/depth grid indices from agent-provided rectangles.
  /// Clusters x-centers into columns and y-centers into rows by sorting
  /// unique positions, so the widget controls spacing regardless of the
  /// agent's pixel coordinates.
  void _extractGridFromRectangles() {
    // Check if any non-header nodes have rectangles
    final rectNodes = _layoutNodes.where(
      (n) => n.step.rectangle != null && n.kind != StepKind.workflow,
    ).toList();
    if (rectNodes.isEmpty) return;

    // Collect unique x-centers and y-centers (rounded to avoid float issues)
    final xSet = <int>{};
    final ySet = <int>{};
    for (final node in rectNodes) {
      final cx = (node.step.rectangle!.x + 60).round(); // recover center
      final cy = (node.step.rectangle!.y + 27.5).round();
      xSet.add(cx);
      ySet.add(cy);
    }

    final sortedX = xSet.toList()..sort();
    final sortedY = ySet.toList()..sort();

    // Map positions to 1-based indices (col/row 0 is the header)
    final xToCol = <int, int>{};
    for (int i = 0; i < sortedX.length; i++) {
      xToCol[sortedX[i]] = i + 1;
    }
    final yToRow = <int, int>{};
    for (int i = 0; i < sortedY.length; i++) {
      yToRow[sortedY[i]] = i + 1;
    }

    // Override row/col for nodes with rectangles
    for (final node in rectNodes) {
      final cx = (node.step.rectangle!.x + 60).round();
      final cy = (node.step.rectangle!.y + 27.5).round();
      node.col = (xToCol[cx] ?? 1).toDouble();
      node.row = (yToRow[cy] ?? 1).toDouble();
    }
  }

  /// Whether a fitting pass has already been applied for the current layout.
  bool _fitted = false;
  bool get fitted => _fitted;

  /// Apply measured sizes from the rendered widgets and recompute positions.
  /// Called by FlowchartView after the first frame to correct estimates.
  void fitMeasuredSizes(Map<String, Size> measuredSizes) {
    bool changed = false;
    for (final node in _layoutNodes) {
      final measured = measuredSizes[node.id];
      if (measured == null) continue;
      final mw = measured.width;
      final mh = measured.height;
      if ((mw - node.shapeWidth).abs() > 1 ||
          (mh - node.shapeHeight).abs() > 1) {
        node.shapeWidth = mw;
        node.shapeHeight = mh;
        changed = true;
      }
    }
    if (changed) {
      _recomputePixelPositions();
    }
    _fitted = true;
    notifyListeners();
  }

  /// Recompute only pixel positions (not row/col assignments) using
  /// current shapeWidth/shapeHeight values.
  void _recomputePixelPositions() {
    const double colGap = 16.0;
    const double rowGap = 12.0;
    const double marginX = 8.0;
    const double marginY = 8.0;
    const double headerHeight = 56.0;

    int maxCol = 0;
    int maxRow = 0;
    for (final node in _layoutNodes) {
      final c = node.col.toInt();
      final r = node.row.toInt();
      if (c > maxCol) maxCol = c;
      if (r > maxRow) maxRow = r;
    }

    final colWidths = List.filled(maxCol + 1, 36.0);
    for (final node in _layoutNodes) {
      if (node.col.toInt() == 0) continue;
      final c = node.col.toInt();
      final w = node.shapeWidth > 0 ? node.shapeWidth : 36.0;
      if (w > colWidths[c]) colWidths[c] = w;
    }

    final colX = List.filled(maxCol + 1, 0.0);
    colX[0] = marginX;
    for (int c = 1; c <= maxCol; c++) {
      colX[c] = colX[c - 1] + colWidths[c - 1] + colGap;
    }

    final rowHeights = List.filled(maxRow + 1, 36.0);
    for (final node in _layoutNodes) {
      if (node.kind == StepKind.workflow) continue;
      final r = node.row.toInt();
      final h = node.shapeHeight > 0 ? node.shapeHeight : 36.0;
      if (h > rowHeights[r]) rowHeights[r] = h;
    }

    final rowY = List.filled(maxRow + 1, 0.0);
    rowY[0] = headerHeight;
    for (int r = 1; r <= maxRow; r++) {
      rowY[r] = rowY[r - 1] + rowHeights[r - 1] + rowGap;
    }

    for (final node in _layoutNodes) {
      if (node.kind == StepKind.workflow) {
        final col1Center = colX.length > 1
            ? colX[1] + colWidths[1] / 2
            : marginX;
        node.x = col1Center - node.shapeWidth / 2;
        node.y = marginY + (headerHeight - node.shapeHeight) / 2;
      } else {
        final c = node.col.toInt();
        final r = node.row.toInt();
        node.x = colX[c] + (colWidths[c] - node.shapeWidth) / 2;
        node.y = rowY[r] + (rowHeights[r] - node.shapeHeight) / 2;
      }
    }
  }

  /// Measure text width using TextPainter for accurate shape sizing.
  static double _measureText(String text, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize),
      ),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  /// Returns (shapeWidth, shapeHeight) — the actual shape dimensions
  /// for connector attachment, NOT including external labels.
  static (double, double) _shapeSize(LayoutNode node) {
    switch (node.shape) {
      case NodeShape.circleBadge:
        // Header (workflow) badge is 48px; all others are 36px
        if (node.kind == StepKind.workflow) return (48.0, 48.0);
        return (36.0, 36.0);
      case NodeShape.roundedSquare:
        return (36.0, 36.0);
      case NodeShape.hexagon90:
        if (node.displayStyle == DisplayStyle.box) {
          // icon(14) + gap(4) + text + horizontal padding(14*2=28)
          final textW = _measureText(node.name, 12.0);
          final w = (textW + 36).clamp(60.0, 300.0);
          return (w, 36.0);
        }
        return (36.0, 36.0);
      case NodeShape.roundedRect:
        if (node.nameDisplay == NameDisplay.alwaysVisible) {
          // padding(4) + icon(14) + gap(4) + text + padding(4) = 26 + text
          final textW = _measureText(node.name, 12.0);
          final w = (textW + 26).clamp(80.0, 180.0);
          return (w, 36.0);
        }
        return (80.0, 36.0);
    }
  }

  /// Estimate rendered width of a node for column sizing (includes labels).
  static double _estimateNodeWidth(LayoutNode node) {
    if (node.displayStyle == DisplayStyle.icon) {
      if (node.shape == NodeShape.roundedSquare) {
        if (node.nameDisplay == NameDisplay.labelOutside) {
          // Square(36) + gap(6) + text
          final textW = _measureText(node.name, 12.0);
          return 42 + textW;
        }
        return 36.0;
      }
      if (node.shape == NodeShape.hexagon90) {
        if (node.nameDisplay == NameDisplay.labelOutside) {
          // Hexagon(36) + gap(6) + text
          final textW = _measureText(node.name, 12.0);
          return 42 + textW;
        }
        return 36.0;
      }
      // circleBadge: workflow/group has label to the right (Row)
      if (node.nameDisplay == NameDisplay.labelOutside) {
        if (node.kind == StepKind.workflow ||
            node.kind == StepKind.groupStep) {
          // Circle(48) + gap(8) + text (h3 = 16px)
          final textW = _measureText(node.name, 16.0);
          return 56 + textW;
        }
        // Other circleBadges (36px): label below, column width = max(circle, text)
        final textW = _measureText(node.name, 12.0);
        return textW > 36 ? textW : 36.0;
      }
      // Header badge 48, others 36
      return (node.kind == StepKind.workflow) ? 48.0 : 36.0;
    }
    // Box display: use shape width
    return _shapeSize(node).$1;
  }

  _DisplayConfig _getDisplayConfig(StepKind kind) {
    switch (kind) {
      case StepKind.workflow:
        return _DisplayConfig(
          displayStyle: DisplayStyle.icon,
          shape: NodeShape.circleBadge,
          nameDisplay: NameDisplay.labelOutside,
          editableName: true,
        );
      case StepKind.groupStep:
        return _DisplayConfig(
          displayStyle: DisplayStyle.icon,
          shape: NodeShape.circleBadge,
          nameDisplay: NameDisplay.labelOutside,
          editableName: true,
        );
      case StepKind.tableStep:
        return _DisplayConfig(
          displayStyle: DisplayStyle.box,
          shape: NodeShape.roundedRect,
          nameDisplay: NameDisplay.alwaysVisible,
          editableName: true,
        );
      case StepKind.joinStep:
        return _DisplayConfig(
          displayStyle: DisplayStyle.icon,
          shape: NodeShape.hexagon90,
          nameDisplay: NameDisplay.labelOutside,
          editableName: true,
        );
      case StepKind.dataStep:
        return _DisplayConfig(
          displayStyle: DisplayStyle.box,
          shape: NodeShape.roundedRect,
          nameDisplay: NameDisplay.alwaysVisible,
          editableName: true,
        );
      case StepKind.viewStep:
        return _DisplayConfig(
          displayStyle: DisplayStyle.icon,
          shape: NodeShape.circleBadge,
          nameDisplay: NameDisplay.labelOutside,
          editableName: true,
        );
      case StepKind.inStep:
        return _DisplayConfig(
          displayStyle: DisplayStyle.icon,
          shape: NodeShape.roundedSquare,
          nameDisplay: NameDisplay.hoverOnly,
          editableName: false,
        );
      case StepKind.outStep:
        return _DisplayConfig(
          displayStyle: DisplayStyle.icon,
          shape: NodeShape.roundedSquare,
          nameDisplay: NameDisplay.labelOutside,
          editableName: false,
        );
      case StepKind.meltStep:
        return _DisplayConfig(
          displayStyle: DisplayStyle.box,
          shape: NodeShape.hexagon90,
          nameDisplay: NameDisplay.alwaysVisible,
          editableName: true,
        );
      case StepKind.exportStep:
        return _DisplayConfig(
          displayStyle: DisplayStyle.icon,
          shape: NodeShape.roundedSquare,
          nameDisplay: NameDisplay.labelOutside,
          editableName: true,
        );
      case StepKind.wizardStep:
        return _DisplayConfig(
          displayStyle: DisplayStyle.icon,
          shape: NodeShape.roundedRect,
          nameDisplay: NameDisplay.hoverOnly,
          editableName: true,
        );
    }
  }

  StepState _deriveWorkflowState() {
    if (_workflow == null) return StepState.init;
    final steps = _workflow!.steps;
    if (steps.any((s) =>
        s.state == StepState.running ||
        s.state == StepState.runningDependent)) return StepState.running;
    if (steps.any((s) => s.state == StepState.failed)) return StepState.failed;
    if (steps.any((s) => s.state == StepState.canceled)) {
      return StepState.canceled;
    }
    if (steps.any((s) =>
        s.state == StepState.pending ||
        s.state == StepState.init)) return StepState.init;
    return StepState.done;
  }

  // -- Focus --

  void focusNode(String nodeId) {
    _focusedNodeId = nodeId;
    _editingNodeId = null; // Cancel any active edit
    notifyListeners();

    final node = _findLayoutNode(nodeId);
    if (node != null) {
      _publishIntent(WorkflowChannels.focusChanged, 'focusChanged', {
        'stepId': node.id,
        'stepType': node.kind.name,
        'stepName': node.name,
        'workflowId': _workflow?.id ?? '',
      });
    }
  }

  void clearFocus() {
    if (_workflowRootId != null) {
      focusNode(_workflowRootId!);
    }
  }

  void openStepViewer(String nodeId) {
    final node = _findLayoutNode(nodeId);
    if (node != null && node.kind != StepKind.workflow) {
      _publishIntent(WorkflowChannels.openStepViewer, 'openStepViewer', {
        'stepId': node.id,
        'stepType': node.kind.name,
        'workflowId': _workflow?.id ?? '',
      });
    }
  }

  // -- Inline rename --

  void startEditing(String nodeId) {
    final node = _findLayoutNode(nodeId);
    if (node != null && node.editableName && nodeId == _focusedNodeId) {
      _editingNodeId = nodeId;
      notifyListeners();
    }
  }

  Future<void> confirmRename(String nodeId, String newName) async {
    final node = _findLayoutNode(nodeId);
    if (node != null && newName.isNotEmpty && newName != node.name) {
      node.step.name = newName;
      await _dataService.renameStep(nodeId, newName);
      _publishIntent(WorkflowChannels.stepRenamed, 'stepRenamed', {
        'stepId': nodeId,
        'newName': newName,
        'workflowId': _workflow?.id ?? '',
      });
    }
    _editingNodeId = null;
    notifyListeners();
  }

  void cancelEditing() {
    _editingNodeId = null;
    notifyListeners();
  }

  // -- Drag-to-reposition --

  /// Begin dragging a node. Called on pan start.
  void startDrag(String nodeId) {
    _draggingNodeId = nodeId;
    focusNode(nodeId);
  }

  /// Update a node's position during drag. [dx]/[dy] are canvas-space deltas.
  void updateDrag(String nodeId, double dx, double dy) {
    final node = _findLayoutNode(nodeId);
    if (node == null) return;
    node.x += dx;
    node.y += dy;
    // Keep the step rectangle in sync (for persistence)
    if (node.step.rectangle != null) {
      node.step.rectangle!.x += dx;
      node.step.rectangle!.y += dy;
    }
    notifyListeners();
  }

  /// Finish dragging: persist the new position.
  Future<void> commitDrag(String nodeId) async {
    _draggingNodeId = null;
    final node = _findLayoutNode(nodeId);
    if (node == null) return;

    // Ensure rectangle is up to date
    node.step.rectangle ??= StepRectangle(x: node.x, y: node.y);
    node.step.rectangle!.x = node.x;
    node.step.rectangle!.y = node.y;

    await _dataService.moveStep(nodeId, node.x, node.y);

    _publishIntent(WorkflowChannels.stepMoved, 'stepMoved', {
      'stepId': nodeId,
      'x': node.x,
      'y': node.y,
      'workflowId': _workflow?.id ?? '',
    });
    notifyListeners();
  }

  // -- Search --

  void setSearchText(String text) {
    _searchText = text;
    _searchMatches = {};

    if (text.isNotEmpty) {
      final lowerText = text.toLowerCase();
      for (final node in _layoutNodes) {
        if (node.name.toLowerCase().contains(lowerText)) {
          _searchMatches.add(node.id);
        }
      }
    }

    notifyListeners();
  }

  // -- Action button --

  /// Get the action button configuration based on current focus.
  ActionButtonConfig get actionButtonConfig {
    if (isWorkflowRootFocused || _focusedNodeId == null) {
      final state = _deriveWorkflowState();
      switch (state) {
        case StepState.init:
        case StepState.pending:
          return ActionButtonConfig(
            label: 'Run All',
            tooltip:
                'Run all steps in ${_workflow?.name ?? "workflow"}',
            action: ActionButtonAction.runWorkflow,
          );
        case StepState.running:
        case StepState.runningDependent:
          return ActionButtonConfig(
            label: 'Stop All',
            tooltip: 'Stop all running steps',
            action: ActionButtonAction.stopWorkflow,
          );
        case StepState.done:
        case StepState.failed:
        case StepState.canceled:
          return ActionButtonConfig(
            label: 'Reset All',
            tooltip:
                'Reset all steps in ${_workflow?.name ?? "workflow"}',
            action: ActionButtonAction.resetWorkflow,
          );
      }
    } else {
      final node = focusedNode;
      if (node == null) {
        return ActionButtonConfig(
          label: 'Run All',
          tooltip: 'Run all steps',
          action: ActionButtonAction.runWorkflow,
        );
      }
      switch (node.state) {
        case StepState.init:
        case StepState.pending:
          return ActionButtonConfig(
            label: 'Run Step',
            tooltip: 'Run ${node.name}',
            action: ActionButtonAction.runStep,
          );
        case StepState.running:
        case StepState.runningDependent:
          return ActionButtonConfig(
            label: 'Stop Step',
            tooltip: 'Stop ${node.name}',
            action: ActionButtonAction.stopStep,
          );
        case StepState.done:
        case StepState.failed:
        case StepState.canceled:
          return ActionButtonConfig(
            label: 'Reset Step',
            tooltip: 'Reset ${node.name}',
            action: ActionButtonAction.resetStep,
          );
      }
    }
  }

  void executeAction() {
    if (_workflow == null) return;
    final config = actionButtonConfig;

    // Publish the intent to the frame (orchestrator will handle in production)
    switch (config.action) {
      case ActionButtonAction.runWorkflow:
        _publishIntent(WorkflowChannels.runWorkflow, 'runWorkflow', {
          'workflowId': _workflow!.id,
        });
        // Mock: execution engine drives state via stepStateChanged events
        _executionEngine.runWorkflow(_workflow!);
        break;
      case ActionButtonAction.stopWorkflow:
        _publishIntent(WorkflowChannels.stopWorkflow, 'stopWorkflow', {
          'workflowId': _workflow!.id,
        });
        _executionEngine.stopWorkflow(_workflow!);
        break;
      case ActionButtonAction.resetWorkflow:
        _publishIntent(WorkflowChannels.resetWorkflow, 'resetWorkflow', {
          'workflowId': _workflow!.id,
        });
        _executionEngine.resetWorkflow(_workflow!);
        break;
      case ActionButtonAction.runStep:
        final node = focusedNode;
        if (node != null) {
          _publishIntent(WorkflowChannels.runStep, 'runStep', {
            'stepId': node.id,
            'workflowId': _workflow!.id,
          });
          _executionEngine.runStep(node.id, _workflow!);
        }
        break;
      case ActionButtonAction.stopStep:
        final node = focusedNode;
        if (node != null) {
          _publishIntent(WorkflowChannels.stopStep, 'stopStep', {
            'stepId': node.id,
            'workflowId': _workflow!.id,
          });
          _executionEngine.stopStep(node.id, _workflow!);
        }
        break;
      case ActionButtonAction.resetStep:
        final node = focusedNode;
        if (node != null) {
          _publishIntent(WorkflowChannels.resetStep, 'resetStep', {
            'stepId': node.id,
            'workflowId': _workflow!.id,
          });
          _executionEngine.resetStep(node.id, _workflow!);
        }
        break;
    }
  }

  // -- Path highlighting --

  /// Returns the set of node IDs on the path from root to the focused node.
  Set<String> get focusedPath {
    if (_focusedNodeId == null || _workflow == null) return {};
    final path = <String>{};
    _buildPathToNode(_focusedNodeId!, path);
    return path;
  }

  bool _buildPathToNode(String targetId, Set<String> path) {
    path.add(targetId);
    if (targetId == 'workflow-root') return true;

    // Find parent via links (outputStepId -> inputStepId)
    final parentLinks = _workflow!.links
        .where((l) => l.inputStepId == targetId)
        .toList();

    bool found = false;
    // Follow ALL parent links (not just the first match) so that
    // join steps highlight every incoming branch.
    for (final link in parentLinks) {
      if (_buildPathToNode(link.outputStepId, path)) found = true;
    }
    if (found) return true;

    // Also check if this step is inside a group
    final node = _findLayoutNode(targetId);
    if (node != null && node.step.groupId.isNotEmpty) {
      if (_buildPathToNode(node.step.groupId, path)) return true;
    }

    // If workflow root not found via links, add it
    if (_workflowRootId != null) {
      path.add(_workflowRootId!);
      return true;
    }

    return false;
  }

  // -- Keyboard navigation --

  void moveFocus(int rowDelta, int colDelta) {
    if (_layoutNodes.isEmpty) return;

    final current = focusedNode;
    if (current == null) {
      focusNode(_layoutNodes.first.id);
      return;
    }

    // Find nearest node in the direction
    LayoutNode? best;
    double bestDist = double.infinity;

    for (final node in _layoutNodes) {
      if (node.id == current.id) continue;

      if (rowDelta != 0) {
        final dr = (node.row - current.row) * rowDelta;
        if (dr > 0) {
          final dist = (node.row - current.row).abs() +
              (node.col - current.col).abs() * 0.1;
          if (dist < bestDist) {
            bestDist = dist;
            best = node;
          }
        }
      }

      if (colDelta != 0) {
        final dc = (node.col - current.col) * colDelta;
        if (dc > 0) {
          final dist = (node.col - current.col).abs() +
              (node.row - current.row).abs() * 0.1;
          if (dist < bestDist) {
            bestDist = dist;
            best = node;
          }
        }
      }
    }

    if (best != null) {
      focusNode(best.id);
    }
  }

  // -- Helpers --

  LayoutNode? _findLayoutNode(String nodeId) {
    try {
      return _layoutNodes.firstWhere((n) => n.id == nodeId);
    } catch (_) {
      return null;
    }
  }

  void _publishIntent(String channel, String type,
      [Map<String, dynamic> extra = const {}]) {
    _eventBus.publish(
      channel,
      EventPayload(
        type: type,
        sourceWidgetId: windowId,
        data: {'windowId': windowId, ...extra},
      ),
    );
  }

  // -- Zoom controls --

  static const double _zoomStep = 1.25;
  static const double _minScale = 0.1;
  static const double _maxScale = 5.0;

  double get currentScale => transformController.value.getMaxScaleOnAxis();

  void zoomIn() {
    final scale = (currentScale * _zoomStep).clamp(_minScale, _maxScale);
    _applyScale(scale);
  }

  void zoomOut() {
    final scale = (currentScale / _zoomStep).clamp(_minScale, _maxScale);
    _applyScale(scale);
  }

  void zoomToFit(double viewportWidth, double viewportHeight) {
    if (_layoutNodes.isEmpty) return;

    double maxX = 0;
    double maxY = 0;
    for (final node in _layoutNodes) {
      final nw = node.width > 0 ? node.width : 40.0;
      final nh = node.shapeHeight > 0 ? node.shapeHeight : 36.0;
      final right = node.x + nw + 32;
      final bottom = node.y + nh + 48;
      if (right > maxX) maxX = right;
      if (bottom > maxY) maxY = bottom;
    }

    if (maxX <= 0 || maxY <= 0) return;
    final scaleX = viewportWidth / maxX;
    final scaleY = viewportHeight / maxY;
    final fitScale = (scaleX < scaleY ? scaleX : scaleY).clamp(_minScale, 1.0);
    transformController.value = Matrix4.diagonal3Values(fitScale, fitScale, 1.0);
    notifyListeners();
  }

  void _applyScale(double newScale) {
    final matrix = transformController.value;
    final oldScale = matrix.getMaxScaleOnAxis();
    if (oldScale == 0) return;
    final ratio = newScale / oldScale;
    // Preserve current pan offset, only change scale
    final tx = matrix.storage[12] * ratio;
    final ty = matrix.storage[13] * ratio;
    final m = Matrix4.diagonal3Values(newScale, newScale, 1.0);
    m.storage[12] = tx;
    m.storage[13] = ty;
    transformController.value = m;
    notifyListeners();
  }

  @override
  void dispose() {
    _executionEngine.dispose();
    transformController.dispose();
    _commandSub?.cancel();
    _openWorkflowSub?.cancel();
    _stepStateSub?.cancel();
    _workflowUpdatedSub?.cancel();
    _navigateToStepSub?.cancel();
    super.dispose();
  }
}

enum _LayoutMeta { entrypoint, pathway, connector, output }

class _DisplayConfig {
  final DisplayStyle displayStyle;
  final NodeShape shape;
  final NameDisplay nameDisplay;
  final bool editableName;

  const _DisplayConfig({
    required this.displayStyle,
    required this.shape,
    required this.nameDisplay,
    required this.editableName,
  });
}

enum ActionButtonAction {
  runWorkflow,
  stopWorkflow,
  resetWorkflow,
  runStep,
  stopStep,
  resetStep,
}

class ActionButtonConfig {
  final String label;
  final String tooltip;
  final ActionButtonAction action;

  const ActionButtonConfig({
    required this.label,
    required this.tooltip,
    required this.action,
  });
}
