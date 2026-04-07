/// Channel names for workflow-viewer-specific EventBus communication.
///
/// These extend the base WindowChannels with workflow-specific events.
///
/// Orchestrator integration:
/// - Outbound events are published by the viewer and forwarded by the
///   orchestrator to the server via the `/ws/ui` WebSocket (similar to
///   how `system.selection.*` events are forwarded).
/// - Inbound events originate from server pushes through the WebSocket
///   and are re-published by the orchestrator onto the EventBus.
/// - In mock mode the [MockExecutionEngine] self-publishes
///   [stepStateChanged] events to simulate server-driven state updates.
class WorkflowChannels {
  WorkflowChannels._();

  // -- Outbound (viewer -> frame/orchestrator) --
  //
  // The orchestrator should subscribe to these and forward them to the
  // server via OrchestratorClient.sendUiEvent().

  /// Focus changed: user selected a step in the flowchart.
  /// Orchestrator maps to: system.selection.step (onTap)
  static const String focusChanged = 'workflow.focusChanged';

  /// Open step viewer: user double-clicked a step.
  /// Orchestrator maps to: window.intent type=openResource
  static const String openStepViewer = 'workflow.openStepViewer';

  /// Run workflow: action button when workflow focused + Init.
  /// Orchestrator maps to: server TaskService.runTask
  static const String runWorkflow = 'workflow.runWorkflow';

  /// Stop workflow: action button when workflow focused + Running.
  /// Orchestrator maps to: server TaskService.cancelTask
  static const String stopWorkflow = 'workflow.stopWorkflow';

  /// Reset workflow: action button when workflow focused + Done/Error.
  /// Orchestrator maps to: server workflow reset API
  static const String resetWorkflow = 'workflow.resetWorkflow';

  /// Run step: action button when step focused + Init.
  /// Orchestrator maps to: server TaskService.runTask (single step)
  static const String runStep = 'workflow.runStep';

  /// Stop step: action button when step focused + Running.
  /// Orchestrator maps to: server TaskService.cancelTask (single step)
  static const String stopStep = 'workflow.stopStep';

  /// Reset step: action button when step focused + Done/Error.
  /// Orchestrator maps to: server step reset API
  static const String resetStep = 'workflow.resetStep';

  /// Step renamed: inline rename confirmed.
  /// Orchestrator maps to: server workflowService.update
  static const String stepRenamed = 'workflow.stepRenamed';

  /// Step moved: drag-to-reposition completed.
  /// Orchestrator maps to: server workflowService.update
  static const String stepMoved = 'workflow.stepMoved';

  // -- Inbound (frame/orchestrator -> viewer) --
  //
  // The orchestrator publishes these when it receives server events
  // via the /ws/ui WebSocket, or in response to layout operations.

  /// Open a specific workflow.
  /// Orchestrator publishes when: AddWindow layout op with workflow context.
  static const String openWorkflow = 'workflow.openWorkflow';

  /// Step state changed: server notifies state transitions.
  /// Orchestrator publishes when: server pushes task state updates.
  /// Payload: {stepId: String, newState: String (StepState.name)}
  static const String stepStateChanged = 'workflow.stepStateChanged';

  /// Workflow updated: re-fetch and re-render.
  /// Orchestrator publishes when: server signals workflow mutation.
  static const String workflowUpdated = 'workflow.workflowUpdated';

  /// Navigate to a specific step: scroll and focus.
  /// Orchestrator publishes when: chat panel or another widget requests it.
  static const String navigateToStep = 'workflow.navigateToStep';
}
