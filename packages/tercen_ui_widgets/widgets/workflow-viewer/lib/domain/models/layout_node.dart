import 'workflow_models.dart';

/// Display style for a step node.
enum DisplayStyle {
  /// Shape containing only the icon; name outside or on hover.
  icon,

  /// Larger shape containing icon + name inline.
  box,
}

/// Shape geometry for a step node.
enum NodeShape {
  circleBadge,
  roundedRect,
  roundedSquare,
  hexagon90,
}

/// Name display mode.
enum NameDisplay {
  alwaysVisible,
  labelOutside,
  hoverOnly,
}

/// A positioned node in the flowchart layout.
class LayoutNode {
  final StepModel step;
  final DisplayStyle displayStyle;
  final NodeShape shape;
  final NameDisplay nameDisplay;
  final bool editableName;

  /// Row index (vertical position). 0 = top.
  double row;

  /// Column index (horizontal position). 0 = leftmost.
  double col;

  /// Pixel position computed from row/col.
  double x;
  double y;

  /// Estimated width in pixels (set during layout, includes labels).
  double width = 0;

  /// Shape-only width for connector attachment points.
  double shapeWidth = 0;

  /// Shape-only height for connector attachment points.
  double shapeHeight = 0;

  LayoutNode({
    required this.step,
    required this.displayStyle,
    required this.shape,
    required this.nameDisplay,
    required this.editableName,
    this.row = 0,
    this.col = 0,
    this.x = 0,
    this.y = 0,
  });

  String get id => step.id;
  String get name => step.name;
  StepKind get kind => step.kind;
  StepState get state => step.state;
}

/// A connector line between two layout nodes.
class LayoutConnector {
  final String fromNodeId;
  final String toNodeId;
  final List<Offset> points;

  const LayoutConnector({
    required this.fromNodeId,
    required this.toNodeId,
    required this.points,
  });
}

/// Simple offset for connector points (avoids dart:ui dependency here).
class Offset {
  final double dx;
  final double dy;

  const Offset(this.dx, this.dy);
}
