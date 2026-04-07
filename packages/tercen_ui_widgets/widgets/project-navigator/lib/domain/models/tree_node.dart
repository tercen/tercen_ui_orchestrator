/// Domain models for the project navigator tree hierarchy.

/// The types of nodes in the navigator tree.
enum NodeType {
  team,
  project,
  folder,
  file,
  dataset,
  workflow,
}

/// File sub-types for icon resolution.
enum FileCategory {
  generic,
  zip,
  image,
}

/// Filter options for the type filter dropdown.
enum TypeFilter {
  all,
  file,
  dataset,
  workflow,
}

/// A single node in the navigator tree.
class TreeNode {
  final String id;
  final String name;
  final NodeType nodeType;
  final String? parentId;
  final List<TreeNode> children;
  final bool isLeaf;

  // Team-specific
  final bool isPersonalTeam;

  // Project-specific
  final bool isPublic;
  final String? githubUrl;
  final String? gitVersion;

  // File-specific
  final FileCategory fileCategory;

  TreeNode({
    required this.id,
    required this.name,
    required this.nodeType,
    this.parentId,
    this.children = const [],
    this.isLeaf = false,
    this.isPersonalTeam = false,
    this.isPublic = false,
    this.githubUrl,
    this.gitVersion,
    this.fileCategory = FileCategory.generic,
  });

  /// Whether this node is a branch (can be expanded).
  bool get isBranch => !isLeaf;

  /// The full path segments from root to this node.
  /// Built lazily by the provider.
  String get displayPath => name;
}
