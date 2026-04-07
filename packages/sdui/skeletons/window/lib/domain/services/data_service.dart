/// Abstract data service interface.
/// Replace with your window type's domain-specific service.
///
/// Phase 2: Create mock implementation that returns placeholder data.
/// Phase 3: Create real implementation that queries Tercen API.
abstract class DataService {
  /// Load the window's data. Returns a map as a placeholder.
  /// Replace the return type with your domain model.
  Future<Map<String, dynamic>> loadData();
}
