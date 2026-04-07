import '../models/tree_node.dart';

/// Abstract data service for the project navigator.
/// Phase 2: Mock implementation returns placeholder tree data.
/// Phase 3: Real implementation queries Tercen API.
abstract class DataService {
  /// Fetch the full tree of teams, projects, and their contents.
  Future<List<TreeNode>> fetchTree();

  /// Upload a file to a project or folder (mock: simulates delay).
  Future<void> uploadFile(String targetNodeId, String fileName);
}
