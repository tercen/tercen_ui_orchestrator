/// Step execution state matching the Tercen task-state hierarchy.
enum StepState {
  init,
  pending,
  runningDependent,
  running,
  done,
  failed,
  canceled,
}

/// Step kind enumeration matching the Tercen type hierarchy.
enum StepKind {
  workflow,
  groupStep,
  tableStep,
  joinStep,
  dataStep,
  viewStep,
  inStep,
  outStep,
  meltStep,
  exportStep,
  wizardStep,
}

/// Rectangle position from the Tercen model (topLeft + extent).
class StepRectangle {
  double x;
  double y;
  final double width;
  final double height;

  StepRectangle({
    required this.x,
    required this.y,
    this.width = 120.0,
    this.height = 55.0,
  });

  double get centerX => x + width / 2;
  double get centerY => y + height / 2;
}

/// Represents a single step in the workflow.
class StepModel {
  final String id;
  String name;
  final String groupId;
  final StepKind kind;
  StepState state;
  final String description;

  /// Position and size from the Tercen model. When non-null, the widget
  /// reads x/y directly instead of computing layout algorithmically.
  StepRectangle? rectangle;

  StepModel({
    required this.id,
    required this.name,
    required this.groupId,
    required this.kind,
    this.state = StepState.done,
    this.description = '',
    this.rectangle,
  });
}

/// Represents a data-flow connection between steps.
class LinkModel {
  final String inputStepId;
  final String outputStepId;

  const LinkModel({
    required this.inputStepId,
    required this.outputStepId,
  });
}

/// Represents the loaded workflow.
class WorkflowModel {
  final String id;
  String name;
  final String projectId;
  final List<StepModel> steps;
  final List<LinkModel> links;

  WorkflowModel({
    required this.id,
    required this.name,
    required this.projectId,
    required this.steps,
    required this.links,
  });
}
