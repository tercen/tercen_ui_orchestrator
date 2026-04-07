import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../di/service_locator.dart';
import '../../domain/models/content_state.dart';
import '../../domain/models/tree_node.dart';
import '../../domain/models/window_identity.dart';
import '../../domain/services/data_service.dart';
import '../../domain/services/event_bus.dart';
import '../../domain/services/event_payload.dart';
import '../../domain/services/navigator_channels.dart';
import '../../domain/services/window_channels.dart';

/// Manages the navigator tree state, selection, filtering, and EventBus wiring.
///
/// Extends the base window state pattern with tree-specific logic.
class NavigatorProvider extends ChangeNotifier {
  final DataService _dataService = serviceLocator<DataService>();
  final EventBus _eventBus = serviceLocator<EventBus>();

  final WindowIdentity identity;
  final String windowId;

  // -- Content state --
  ContentState _contentState = ContentState.loading;
  ContentState get contentState => _contentState;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // -- Tree data --
  List<TreeNode> _treeData = [];
  List<TreeNode> get treeData => _treeData;

  // -- Expanded nodes --
  final Set<String> _expandedNodes = {};
  // Nodes auto-expanded by search (separate from manual expansions)
  final Set<String> _searchExpandedNodes = {};
  Set<String> get expandedNodes => {..._expandedNodes, ..._searchExpandedNodes};

  // -- Selection --
  String? _selectedNodeId;
  String? get selectedNodeId => _selectedNodeId;

  TreeNode? _selectedNode;
  TreeNode? get selectedNode => _selectedNode;

  // -- Filtering --
  TypeFilter _typeFilter = TypeFilter.all;
  TypeFilter get typeFilter => _typeFilter;

  String _searchText = '';
  String get searchText => _searchText;

  // -- Upload state --
  String? _uploadTargetId;
  String? get uploadTargetId => _uploadTargetId;

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  // -- Frame focus --
  bool _focused = false;
  bool get focused => _focused;

  // -- Subscriptions --
  StreamSubscription<EventPayload>? _commandSubscription;
  StreamSubscription<EventPayload>? _navigateToSubscription;
  StreamSubscription<EventPayload>? _refreshSubscription;

  NavigatorProvider({
    required this.identity,
    required this.windowId,
  }) {
    // Subscribe to frame commands
    _commandSubscription = _eventBus
        .subscribe(WindowChannels.commandChannel(windowId))
        .listen(_handleCommand);

    // Subscribe to navigator-specific inbound events
    _navigateToSubscription = _eventBus
        .subscribe(NavigatorChannels.navigateTo)
        .listen(_handleNavigateTo);

    _refreshSubscription = _eventBus
        .subscribe(NavigatorChannels.refreshTree)
        .listen((_) => loadTree());

    // Auto-load on creation
    loadTree();
  }

  // -- Command handling --

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

  void _handleNavigateTo(EventPayload payload) {
    final nodeId = payload.data['nodeId'] as String?;
    if (nodeId == null) return;

    // Expand all ancestors and select the node
    final node = _findNode(nodeId, _treeData);
    if (node != null) {
      _expandAncestors(nodeId);
      selectNode(node);
    }
  }

  // -- Intent publishing --

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

  // -- Tree loading --

  Future<void> loadTree() async {
    _contentState = ContentState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _treeData = await _dataService.fetchTree();
      if (_treeData.isEmpty) {
        _contentState = ContentState.empty;
      } else {
        _contentState = ContentState.active;
        // Sort project and folder contents
        _sortTree(_treeData);
        // Auto-expand personal team
        for (final team in _treeData) {
          if (team.nodeType == NodeType.team && team.isPersonalTeam) {
            _expandedNodes.add(team.id);
          }
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
      _contentState = ContentState.error;
    }
    notifyListeners();
  }

  // -- Expand/Collapse --

  void toggleExpanded(String nodeId) {
    final isCurrentlyExpanded =
        _expandedNodes.contains(nodeId) || _searchExpandedNodes.contains(nodeId);
    if (isCurrentlyExpanded) {
      _expandedNodes.remove(nodeId);
      _searchExpandedNodes.remove(nodeId);
    } else {
      _expandedNodes.add(nodeId);
    }
    notifyListeners();
  }

  bool isExpanded(String nodeId) =>
      _expandedNodes.contains(nodeId) || _searchExpandedNodes.contains(nodeId);

  void _expandAncestors(String nodeId) {
    // Walk the tree to find all ancestor ids
    final ancestors = <String>[];
    _findAncestors(nodeId, _treeData, ancestors);
    _expandedNodes.addAll(ancestors);
  }

  bool _findAncestors(
      String targetId, List<TreeNode> nodes, List<String> ancestors) {
    for (final node in nodes) {
      if (node.id == targetId) return true;
      if (node.children.isNotEmpty) {
        ancestors.add(node.id);
        if (_findAncestors(targetId, node.children, ancestors)) return true;
        ancestors.removeLast();
      }
    }
    return false;
  }

  // -- Selection --

  void selectNode(TreeNode node) {
    _selectedNodeId = node.id;
    _selectedNode = node;
    notifyListeners();

    // Emit focusChanged for project, folder, file, dataset, workflow
    if (node.nodeType != NodeType.team) {
      _publishIntent(NavigatorChannels.focusChanged, 'focusChanged', {
        'nodeId': node.id,
        'nodeType': node.nodeType.name,
        'nodeName': node.name,
        'nodePath': _buildPath(node.id),
      });
    }
  }

  void openViewer(TreeNode node) {
    if (!node.isLeaf) return;
    _publishIntent(NavigatorChannels.openViewer, 'openViewer', {
      'nodeId': node.id,
      'nodeType': node.nodeType.name,
    });
  }

  // -- Toolbar actions --

  void triggerTeamWidget() {
    if (_selectedNode == null ||
        _selectedNode!.nodeType != NodeType.team) return;
    _publishIntent(NavigatorChannels.openTeamWidget, 'openTeamWidget', {
      'teamId': _selectedNode!.id,
    });
  }

  void triggerDownload() {
    if (_selectedNode == null) return;
    if (_selectedNode!.nodeType != NodeType.file &&
        _selectedNode!.nodeType != NodeType.dataset) return;
    _publishIntent(NavigatorChannels.downloadFile, 'downloadFile', {
      'fileId': _selectedNode!.id,
    });
  }

  Future<void> uploadFile(String fileName) async {
    final target = _selectedNode;
    if (target == null) return;
    if (target.nodeType != NodeType.project &&
        target.nodeType != NodeType.folder) return;

    _uploadTargetId = target.id;
    _isUploading = true;
    notifyListeners();

    try {
      await _dataService.uploadFile(target.id, fileName);
      _publishIntent(NavigatorChannels.contentChanged, 'contentChanged');
      // Refresh tree after upload
      await loadTree();
    } finally {
      _isUploading = false;
      _uploadTargetId = null;
      notifyListeners();
    }
  }

  // -- Filtering --

  void setTypeFilter(TypeFilter filter) {
    _typeFilter = filter;
    notifyListeners();
  }

  void setSearchText(String text) {
    _searchText = text;
    // Clear previous search expansions
    _searchExpandedNodes.clear();
    // Auto-expand ancestors of matching nodes
    if (text.isNotEmpty) {
      _autoExpandForSearch(_treeData);
    }
    notifyListeners();
  }

  /// Recursively find nodes matching the current search/filter and expand
  /// their ancestors so results are visible in the tree.
  bool _autoExpandForSearch(List<TreeNode> nodes) {
    bool anyMatch = false;
    for (final node in nodes) {
      if (node.children.isNotEmpty) {
        // Check if any descendant matches
        final childMatch = _autoExpandForSearch(node.children);
        if (childMatch) {
          _searchExpandedNodes.add(node.id);
          anyMatch = true;
        }
      }
      // Check if this leaf/node itself matches
      if (_nodeMatchesSearch(node)) {
        anyMatch = true;
      }
    }
    return anyMatch;
  }

  /// Check if a node matches the current text search (leaf nodes only).
  bool _nodeMatchesSearch(TreeNode node) {
    if (_searchText.isEmpty) return false;
    // Only match leaf-level content nodes, not branches
    if (node.nodeType == NodeType.team ||
        node.nodeType == NodeType.project ||
        node.nodeType == NodeType.folder) {
      return false;
    }
    return node.name.toLowerCase().contains(_searchText.toLowerCase());
  }

  /// Returns the filtered tree for display.
  List<TreeNode> get filteredTree {
    if (_typeFilter == TypeFilter.all && _searchText.isEmpty) {
      return _treeData;
    }
    return _filterNodes(_treeData);
  }

  List<TreeNode> _filterNodes(List<TreeNode> nodes) {
    final result = <TreeNode>[];
    for (final node in nodes) {
      if (_nodeMatchesFilter(node)) {
        // Leaf matches — include it
        result.add(node);
      } else if (node.children.isNotEmpty) {
        // Branch — recurse and include if any children match
        final filteredChildren = _filterNodes(node.children);
        if (filteredChildren.isNotEmpty) {
          result.add(TreeNode(
            id: node.id,
            name: node.name,
            nodeType: node.nodeType,
            parentId: node.parentId,
            children: filteredChildren,
            isLeaf: node.isLeaf,
            isPersonalTeam: node.isPersonalTeam,
            isPublic: node.isPublic,
            githubUrl: node.githubUrl,
            gitVersion: node.gitVersion,
            fileCategory: node.fileCategory,
          ));
        }
      }
    }
    return result;
  }

  bool _nodeMatchesFilter(TreeNode node) {
    // Branch nodes (team, project, folder):
    // When a type filter is active, branches must NOT match directly —
    // they are only included via _filterNodes when they have matching
    // leaf children. This ensures empty branches are pruned.
    // When only text search is active, branches match if their name matches.
    if (node.nodeType == NodeType.team ||
        node.nodeType == NodeType.project ||
        node.nodeType == NodeType.folder) {
      if (_typeFilter != TypeFilter.all) {
        return false;
      }
      if (_searchText.isNotEmpty) {
        return node.name.toLowerCase().contains(_searchText.toLowerCase());
      }
      return true;
    }

    // Leaf nodes: check type filter
    if (_typeFilter != TypeFilter.all) {
      switch (_typeFilter) {
        case TypeFilter.file:
          if (node.nodeType != NodeType.file) return false;
          break;
        case TypeFilter.dataset:
          if (node.nodeType != NodeType.dataset) return false;
          break;
        case TypeFilter.workflow:
          if (node.nodeType != NodeType.workflow) return false;
          break;
        case TypeFilter.all:
          break;
      }
    }

    // Check text search
    if (_searchText.isNotEmpty) {
      return node.name.toLowerCase().contains(_searchText.toLowerCase());
    }

    return true;
  }

  // -- Sorting --

  /// Sort project and folder children in priority order:
  /// 1. README.md first
  /// 2. Data Sets (alphabetical)
  /// 3. Workflows (alphabetical)
  /// 4. Files excluding README.md (alphabetical)
  /// 5. Folders (alphabetical, recursively sorted)
  void _sortTree(List<TreeNode> nodes) {
    for (final node in nodes) {
      if (node.children.isNotEmpty) {
        // Recurse first so children are sorted before we sort this level
        _sortTree(node.children);

        // Only apply content sort inside projects and folders
        if (node.nodeType == NodeType.project ||
            node.nodeType == NodeType.folder) {
          _sortChildren(node.children);
        }
      }
    }
  }

  void _sortChildren(List<TreeNode> children) {
    children.sort((a, b) {
      final priorityA = _sortPriority(a);
      final priorityB = _sortPriority(b);
      if (priorityA != priorityB) return priorityA.compareTo(priorityB);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  int _sortPriority(TreeNode node) {
    // README.md always first
    if (node.name.toLowerCase() == 'readme.md') return 0;
    switch (node.nodeType) {
      case NodeType.workflow:
        return 1;
      case NodeType.dataset:
        return 2;
      case NodeType.file:
        return 3;
      case NodeType.folder:
        return 4;
      case NodeType.team:
      case NodeType.project:
        return 5;
    }
  }

  // -- Helpers --

  TreeNode? _findNode(String nodeId, List<TreeNode> nodes) {
    for (final node in nodes) {
      if (node.id == nodeId) return node;
      if (node.children.isNotEmpty) {
        final found = _findNode(nodeId, node.children);
        if (found != null) return found;
      }
    }
    return null;
  }

  String _buildPath(String nodeId) {
    final segments = <String>[];
    _buildPathSegments(nodeId, _treeData, segments);
    return segments.join(' / ');
  }

  bool _buildPathSegments(
      String targetId, List<TreeNode> nodes, List<String> segments) {
    for (final node in nodes) {
      segments.add(node.name);
      if (node.id == targetId) return true;
      if (node.children.isNotEmpty) {
        if (_buildPathSegments(targetId, node.children, segments)) return true;
      }
      segments.removeLast();
    }
    return false;
  }

  /// Whether the Upload button should be enabled.
  bool get canUpload =>
      _selectedNode != null &&
      (_selectedNode!.nodeType == NodeType.project ||
          _selectedNode!.nodeType == NodeType.folder);

  /// Whether the Download button should be enabled.
  bool get canDownload =>
      _selectedNode != null &&
      (_selectedNode!.nodeType == NodeType.file ||
          _selectedNode!.nodeType == NodeType.dataset);

  /// Whether the Team button should be enabled.
  bool get canOpenTeam =>
      _selectedNode != null && _selectedNode!.nodeType == NodeType.team;

  @override
  void dispose() {
    _commandSubscription?.cancel();
    _navigateToSubscription?.cancel();
    _refreshSubscription?.cancel();
    super.dispose();
  }
}
