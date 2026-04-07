import '../models/workflow_models.dart';

/// Abstract data service for the workflow viewer.
/// Phase 2: Mock implementation returns placeholder workflow data.
/// Phase 3: Real implementation queries Tercen API.
abstract class DataService {
  /// Fetch the full workflow with all steps and links.
  Future<WorkflowModel> fetchWorkflow(String workflowId, String projectId);

  /// Rename a step (persists the change).
  Future<void> renameStep(String stepId, String newName);

  /// Persist a step's new position after drag-to-reposition.
  Future<void> moveStep(String stepId, double x, double y);
}
