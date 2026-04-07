/// The six annotation drawing tools.
enum DrawingTool { polygon, rectangle, circle, arrow, freehand, text }

/// A point in image-pixel space.
class ImagePoint {
  final double x;
  final double y;

  const ImagePoint(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

/// A single annotation drawn on the image.
class AnnotationModel {
  /// Annotation type.
  final DrawingTool type;

  /// Vertex coordinates in image-pixel space.
  List<ImagePoint> points;

  /// Circle radius in image pixels (null for non-circle types).
  final double? radius;

  /// User-entered text string (null for non-text types).
  final String? label;

  AnnotationModel({
    required this.type,
    required this.points,
    this.radius,
    this.label,
  });

  /// Translate all points by a delta offset.
  void translate(double dx, double dy) {
    points = points.map((p) => ImagePoint(p.x + dx, p.y + dy)).toList();
  }

  /// Bounding box centre point for hit-testing.
  ImagePoint get centre {
    if (points.isEmpty) return const ImagePoint(0, 0);
    double minX = points.first.x, maxX = points.first.x;
    double minY = points.first.y, maxY = points.first.y;
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    return ImagePoint((minX + maxX) / 2, (minY + maxY) / 2);
  }

  /// Convert to JSON-serializable map.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'points': points.map((p) => p.toJson()).toList(),
        if (radius != null) 'radius': radius,
        if (label != null) 'label': label,
      };
}
