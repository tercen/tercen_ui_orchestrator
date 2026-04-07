import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_line_weights.dart';
import '../../../domain/models/annotation_model.dart';
import '../../providers/png_viewer_provider.dart';
import '../../providers/window_state_provider.dart';

/// Active body state: PNG image on pannable/zoomable canvas with annotation overlay.
class ActiveState extends StatefulWidget {
  const ActiveState({super.key});

  @override
  State<ActiveState> createState() => _ActiveStateState();
}

class _ActiveStateState extends State<ActiveState> {
  // For text annotation input.
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  ImagePoint? _textAnchor;
  bool _showTextInput = false;

  // For tracking polygon vertices during construction.
  List<ImagePoint> _polygonVertices = [];

  // Current mouse position in image-pixel space (for polygon rubber-band line).
  ImagePoint? _mouseImagePoint;

  // Drag-based drawing for rectangle, circle, arrow, freehand.
  ImagePoint? _dragStart;
  List<ImagePoint> _freehandPoints = [];

  // Drag-to-move: index of annotation being dragged, and last image point.
  int? _movingAnnotationIndex;
  ImagePoint? _moveLastPoint;

  // Whether the mouse is currently hovering over an annotation (pan mode).
  bool _hoveringAnnotation = false;

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WindowStateProvider>() as PngViewerProvider;
    final image = provider.image;
    if (image == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // On first build, fit image to viewport.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (provider.zoomLevel == 1.0 &&
              provider.panOffset == Offset.zero) {
            provider.fitToWindow(
                Size(constraints.maxWidth, constraints.maxHeight));
          }
        });

        return ClipRect(
          child: _buildCanvas(context, provider, constraints),
        );
      },
    );
  }

  Widget _buildCanvas(
    BuildContext context,
    PngViewerProvider provider,
    BoxConstraints constraints,
  ) {
    final image = provider.image!;
    final zoom = provider.zoomLevel;
    final pan = provider.panOffset;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final imageWidget = Image.memory(
      image.imageBytes,
      width: image.width.toDouble(),
      height: image.height.toDouble(),
      fit: BoxFit.none,
      gaplessPlayback: true,
    );

    // The canvas is a stack: image + annotation overlay + in-progress drawing.
    final canvasContent = SizedBox(
      width: image.width.toDouble(),
      height: image.height.toDouble(),
      child: Stack(
        children: [
          imageWidget,
          // Completed annotations overlay.
          Positioned.fill(
            child: CustomPaint(
              painter: _AnnotationPainter(
                annotations: provider.annotations,
                inProgressPoints: provider.inProgressPoints,
                inProgressTool: provider.activeTool,
                polygonVertices:
                    provider.activeTool == DrawingTool.polygon
                        ? _polygonVertices
                        : [],
                mousePoint: provider.activeTool == DrawingTool.polygon
                    ? _mouseImagePoint
                    : null,
                movingAnnotationIndex: _movingAnnotationIndex,
              ),
            ),
          ),
          // Text input overlay.
          if (_showTextInput && _textAnchor != null)
            Positioned(
              left: _textAnchor!.x,
              top: _textAnchor!.y,
              child: _buildTextInput(context, provider),
            ),
        ],
      ),
    );

    // Centre the image in the viewport.
    final viewportCenterX = constraints.maxWidth / 2;
    final viewportCenterY = constraints.maxHeight / 2;
    final imageCenterX = image.width * zoom / 2;
    final imageCenterY = image.height * zoom / 2;

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          // Scroll-wheel zoom.
          final delta = event.scrollDelta.dy;
          if (delta < 0) {
            provider.zoomIn();
          } else if (delta > 0) {
            provider.zoomOut();
          }
        }
      },
      child: GestureDetector(
        // Pan mode (no tool active): drag to pan canvas OR drag to move annotation.
        onPanStart: provider.activeTool == null
            ? (details) {
                // Hit-test annotations — if we hit one, start moving it.
                final imgPt = _screenToImage(
                  details.localPosition,
                  provider.zoomLevel,
                  provider.panOffset,
                  viewportCenterX,
                  viewportCenterY,
                  imageCenterX,
                  imageCenterY,
                );
                final hitIndex = _hitTestAnnotation(
                    provider.annotations, imgPt, provider.zoomLevel);
                if (hitIndex != null) {
                  setState(() {
                    _movingAnnotationIndex = hitIndex;
                    _moveLastPoint = imgPt;
                  });
                }
              }
            : null,
        onPanUpdate: provider.activeTool == null
            ? (details) {
                if (_movingAnnotationIndex != null && _moveLastPoint != null) {
                  // Moving an annotation.
                  final imgPt = _screenToImage(
                    details.localPosition,
                    provider.zoomLevel,
                    provider.panOffset,
                    viewportCenterX,
                    viewportCenterY,
                    imageCenterX,
                    imageCenterY,
                  );
                  final dx = imgPt.x - _moveLastPoint!.x;
                  final dy = imgPt.y - _moveLastPoint!.y;
                  provider.translateAnnotation(
                      _movingAnnotationIndex!, dx, dy);
                  _moveLastPoint = imgPt;
                } else {
                  // Panning the canvas.
                  provider.setPanOffset(
                    provider.panOffset + details.delta,
                  );
                }
              }
            : _getDrawingPanUpdate(provider),
        onPanEnd: provider.activeTool == null
            ? (_) {
                setState(() {
                  _movingAnnotationIndex = null;
                  _moveLastPoint = null;
                });
              }
            : _getDrawingPanEnd(provider),
        onTapUp: provider.activeTool != null
            ? (details) => _handleTap(provider, details, zoom, pan,
                viewportCenterX, viewportCenterY, imageCenterX, imageCenterY)
            : null,
        onDoubleTapDown: provider.activeTool == DrawingTool.polygon
            ? (details) => _handleDoubleTap(provider, details, zoom, pan,
                viewportCenterX, viewportCenterY, imageCenterX, imageCenterY)
            : null,
        onDoubleTap: provider.activeTool == DrawingTool.polygon
            ? () {}
            : null,
        child: MouseRegion(
          cursor: _movingAnnotationIndex != null
              ? SystemMouseCursors.move
              : provider.activeTool == null
                  ? (_hoveringAnnotation
                      ? SystemMouseCursors.move
                      : SystemMouseCursors.grab)
                  : SystemMouseCursors.precise,
          onHover: (event) {
            final imgPt = _screenToImage(
              event.localPosition,
              provider.zoomLevel,
              provider.panOffset,
              viewportCenterX,
              viewportCenterY,
              imageCenterX,
              imageCenterY,
            );
            // Polygon rubber-band tracking.
            if (provider.activeTool == DrawingTool.polygon &&
                _polygonVertices.isNotEmpty) {
              setState(() => _mouseImagePoint = imgPt);
            }
            // Annotation hover detection (pan mode only).
            if (provider.activeTool == null) {
              final hit = _hitTestAnnotation(
                  provider.annotations, imgPt, provider.zoomLevel);
              final hovering = hit != null;
              if (hovering != _hoveringAnnotation) {
                setState(() => _hoveringAnnotation = hovering);
              }
            }
          },
          onExit: (_) {
            if (_hoveringAnnotation) {
              setState(() => _hoveringAnnotation = false);
            }
          },
          child: Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF3F4F6),
            child: Transform(
              transform: Matrix4.identity()
                ..translate(
                  viewportCenterX - imageCenterX + pan.dx,
                  viewportCenterY - imageCenterY + pan.dy,
                )
                ..scale(zoom),
              child: canvasContent,
            ),
          ),
        ),
      ),
    );
  }

  /// Convert screen coordinates to image-pixel coordinates.
  ImagePoint _screenToImage(
    Offset screenPos,
    double zoom,
    Offset pan,
    double viewportCenterX,
    double viewportCenterY,
    double imageCenterX,
    double imageCenterY,
  ) {
    final translateX = viewportCenterX - imageCenterX + pan.dx;
    final translateY = viewportCenterY - imageCenterY + pan.dy;
    final imgX = (screenPos.dx - translateX) / zoom;
    final imgY = (screenPos.dy - translateY) / zoom;
    return ImagePoint(imgX, imgY);
  }

  /// Hit-test annotations in reverse order (top-most first).
  /// Returns the index of the hit annotation, or null.
  int? _hitTestAnnotation(
      List<AnnotationModel> annotations, ImagePoint point, double zoom) {
    // Threshold in image pixels — 15 screen pixels converted to image space.
    final threshold = 15.0 / zoom;

    for (int i = annotations.length - 1; i >= 0; i--) {
      final ann = annotations[i];
      switch (ann.type) {
        case DrawingTool.rectangle:
          if (ann.points.length >= 2) {
            final r = Rect.fromPoints(
              Offset(ann.points[0].x, ann.points[0].y),
              Offset(ann.points[1].x, ann.points[1].y),
            ).inflate(threshold);
            if (r.contains(Offset(point.x, point.y))) return i;
          }
          break;
        case DrawingTool.circle:
          if (ann.points.isNotEmpty && ann.radius != null) {
            final dx = point.x - ann.points[0].x;
            final dy = point.y - ann.points[0].y;
            if (math.sqrt(dx * dx + dy * dy) <= ann.radius! + threshold) {
              return i;
            }
          }
          break;
        case DrawingTool.polygon:
          if (ann.points.length >= 3) {
            // Simple bounding-box hit test.
            double minX = ann.points.first.x, maxX = ann.points.first.x;
            double minY = ann.points.first.y, maxY = ann.points.first.y;
            for (final p in ann.points) {
              if (p.x < minX) minX = p.x;
              if (p.x > maxX) maxX = p.x;
              if (p.y < minY) minY = p.y;
              if (p.y > maxY) maxY = p.y;
            }
            final r = Rect.fromLTRB(minX, minY, maxX, maxY).inflate(threshold);
            if (r.contains(Offset(point.x, point.y))) return i;
          }
          break;
        case DrawingTool.arrow:
          if (ann.points.length >= 2) {
            // Distance from point to line segment.
            final dist = _distToSegment(
                point, ann.points[0], ann.points[1]);
            if (dist <= threshold) return i;
          }
          break;
        case DrawingTool.freehand:
          if (ann.points.length >= 2) {
            for (int j = 0; j < ann.points.length - 1; j++) {
              final dist =
                  _distToSegment(point, ann.points[j], ann.points[j + 1]);
              if (dist <= threshold) return i;
            }
          }
          break;
        case DrawingTool.text:
          if (ann.points.isNotEmpty) {
            // Approximate text bounding box.
            final textRect = Rect.fromLTWH(
                ann.points[0].x, ann.points[0].y - 16, 100, 20)
                .inflate(threshold);
            if (textRect.contains(Offset(point.x, point.y))) return i;
          }
          break;
      }
    }
    return null;
  }

  /// Distance from a point to a line segment.
  double _distToSegment(ImagePoint p, ImagePoint a, ImagePoint b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) {
      final ex = p.x - a.x;
      final ey = p.y - a.y;
      return math.sqrt(ex * ex + ey * ey);
    }
    var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    final projX = a.x + t * dx;
    final projY = a.y + t * dy;
    final ex = p.x - projX;
    final ey = p.y - projY;
    return math.sqrt(ex * ex + ey * ey);
  }

  void _handleTap(
    PngViewerProvider provider,
    TapUpDetails details,
    double zoom,
    Offset pan,
    double vcx,
    double vcy,
    double icx,
    double icy,
  ) {
    final imgPt =
        _screenToImage(details.localPosition, zoom, pan, vcx, vcy, icx, icy);

    switch (provider.activeTool) {
      case DrawingTool.polygon:
        // Add vertex. If clicking near first vertex and >= 3 vertices, close.
        if (_polygonVertices.length >= 3) {
          final first = _polygonVertices.first;
          final dist = math.sqrt(
              math.pow(imgPt.x - first.x, 2) + math.pow(imgPt.y - first.y, 2));
          if (dist < 15.0 / zoom) {
            // Close polygon.
            provider.addAnnotation(AnnotationModel(
              type: DrawingTool.polygon,
              points: List.from(_polygonVertices),
            ));
            setState(() {
              _polygonVertices = [];
              _mouseImagePoint = null;
            });
            return;
          }
        }
        setState(() => _polygonVertices.add(imgPt));
        break;

      case DrawingTool.text:
        // If there's already a text input showing, confirm it first.
        _confirmTextInput(provider);
        setState(() {
          _textAnchor = imgPt;
          _showTextInput = true;
          _textController.clear();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _textFocusNode.requestFocus();
        });
        break;

      case DrawingTool.circle:
        // Handled via pan gestures (click-drag).
        break;

      default:
        break;
    }
  }

  void _handleDoubleTap(
    PngViewerProvider provider,
    TapDownDetails details,
    double zoom,
    Offset pan,
    double vcx,
    double vcy,
    double icx,
    double icy,
  ) {
    if (provider.activeTool != DrawingTool.polygon) return;
    if (_polygonVertices.length >= 3) {
      final imgPt =
          _screenToImage(details.localPosition, zoom, pan, vcx, vcy, icx, icy);
      _polygonVertices.add(imgPt);
      provider.addAnnotation(AnnotationModel(
        type: DrawingTool.polygon,
        points: List.from(_polygonVertices),
      ));
      setState(() {
        _polygonVertices = [];
        _mouseImagePoint = null;
      });
    }
  }

  void Function(DragUpdateDetails)? _getDrawingPanUpdate(
      PngViewerProvider provider) {
    if (provider.activeTool == null) return null;

    return (details) {
      final zoom = provider.zoomLevel;
      final pan = provider.panOffset;
      final image = provider.image!;
      final vcx = (context.size?.width ?? 800) / 2;
      final vcy = (context.size?.height ?? 600) / 2;
      final icx = image.width * zoom / 2;
      final icy = image.height * zoom / 2;

      final imgPt =
          _screenToImage(details.localPosition, zoom, pan, vcx, vcy, icx, icy);

      switch (provider.activeTool) {
        case DrawingTool.rectangle:
        case DrawingTool.arrow:
          _dragStart ??= imgPt;
          provider.setInProgressPoints([_dragStart!, imgPt]);
          break;

        case DrawingTool.circle:
          _dragStart ??= imgPt;
          provider.setInProgressPoints([_dragStart!, imgPt]);
          break;

        case DrawingTool.freehand:
          if (_freehandPoints.isEmpty) _freehandPoints.add(imgPt);
          _freehandPoints.add(imgPt);
          provider.setInProgressPoints(List.from(_freehandPoints));
          break;

        default:
          break;
      }
    };
  }

  void Function(DragEndDetails)? _getDrawingPanEnd(
      PngViewerProvider provider) {
    if (provider.activeTool == null) return null;

    return (_) {
      switch (provider.activeTool) {
        case DrawingTool.rectangle:
          if (_dragStart != null && provider.inProgressPoints != null) {
            final pts = provider.inProgressPoints!;
            if (pts.length >= 2) {
              provider.addAnnotation(AnnotationModel(
                type: DrawingTool.rectangle,
                points: [pts.first, pts.last],
              ));
            }
          }
          break;

        case DrawingTool.arrow:
          if (_dragStart != null && provider.inProgressPoints != null) {
            final pts = provider.inProgressPoints!;
            if (pts.length >= 2) {
              provider.addAnnotation(AnnotationModel(
                type: DrawingTool.arrow,
                points: [pts.first, pts.last],
              ));
            }
          }
          break;

        case DrawingTool.circle:
          if (_dragStart != null && provider.inProgressPoints != null) {
            final pts = provider.inProgressPoints!;
            if (pts.length >= 2) {
              final dx = pts.last.x - pts.first.x;
              final dy = pts.last.y - pts.first.y;
              final radius = math.sqrt(dx * dx + dy * dy);
              provider.addAnnotation(AnnotationModel(
                type: DrawingTool.circle,
                points: [pts.first],
                radius: radius,
              ));
            }
          }
          break;

        case DrawingTool.freehand:
          if (_freehandPoints.length >= 2) {
            provider.addAnnotation(AnnotationModel(
              type: DrawingTool.freehand,
              points: List.from(_freehandPoints),
            ));
          }
          break;

        default:
          break;
      }

      _dragStart = null;
      _freehandPoints = [];
      provider.setInProgressPoints(null);
    };
  }

  /// Confirm and save text input if non-empty.
  void _confirmTextInput(PngViewerProvider provider) {
    if (_showTextInput &&
        _textAnchor != null &&
        _textController.text.trim().isNotEmpty) {
      provider.addAnnotation(AnnotationModel(
        type: DrawingTool.text,
        points: [_textAnchor!],
        label: _textController.text.trim(),
      ));
    }
    setState(() {
      _showTextInput = false;
      _textAnchor = null;
    });
  }

  Widget _buildTextInput(BuildContext context, PngViewerProvider provider) {
    // Annotation-coloured inline text field with transparent background.
    // No Material wrapper — avoids theme bleed-through.
    const annotationColor = Color(0xFFFF5722);

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 160,
        child: TextField(
          controller: _textController,
          focusNode: _textFocusNode,
          style: const TextStyle(
            color: annotationColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: annotationColor,
          decoration: const InputDecoration(
            hintText: 'Text',
            hintStyle: TextStyle(
              color: Color(0x88FF5722),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 2,
              vertical: 2,
            ),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onSubmitted: (value) {
            _confirmTextInput(provider);
          },
          onTapOutside: (_) {
            _confirmTextInput(provider);
          },
        ),
      ),
    );
  }
}

/// Custom painter that draws completed annotations and in-progress drawings.
class _AnnotationPainter extends CustomPainter {
  final List<AnnotationModel> annotations;
  final List<ImagePoint>? inProgressPoints;
  final DrawingTool? inProgressTool;
  final List<ImagePoint> polygonVertices;
  final ImagePoint? mousePoint;
  final int? movingAnnotationIndex;

  _AnnotationPainter({
    required this.annotations,
    this.inProgressPoints,
    this.inProgressTool,
    this.polygonVertices = const [],
    this.mousePoint,
    this.movingAnnotationIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Annotation stroke style: orange-red, visible on most images.
    final paint = Paint()
      ..color = const Color(0xFFFF5722)
      ..strokeWidth = AppLineWeights.vizData
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = const Color(0x33FF5722)
      ..style = PaintingStyle.fill;

    // Draw completed annotations.
    for (int i = 0; i < annotations.length; i++) {
      final isMoving = i == movingAnnotationIndex;
      final strokePaint = isMoving
          ? (Paint()
            ..color = const Color(0xFF2196F3)
            ..strokeWidth = AppLineWeights.vizData
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round)
          : paint;
      final fill = isMoving
          ? (Paint()
            ..color = const Color(0x332196F3)
            ..style = PaintingStyle.fill)
          : fillPaint;
      _drawAnnotation(canvas, annotations[i], strokePaint, fill);
    }

    // Draw in-progress polygon vertices + rubber-band line to mouse.
    if (polygonVertices.isNotEmpty) {
      final path = Path();
      path.moveTo(polygonVertices.first.x, polygonVertices.first.y);
      for (int i = 1; i < polygonVertices.length; i++) {
        path.lineTo(polygonVertices[i].x, polygonVertices[i].y);
      }
      // Rubber-band line from last vertex to current mouse position.
      if (mousePoint != null) {
        path.lineTo(mousePoint!.x, mousePoint!.y);
      }
      canvas.drawPath(path, paint);

      // Draw vertex dots.
      final dotPaint = Paint()
        ..color = const Color(0xFFFF5722)
        ..style = PaintingStyle.fill;
      for (final v in polygonVertices) {
        canvas.drawCircle(Offset(v.x, v.y), 4.0, dotPaint);
      }
    }

    // Draw in-progress shape (rectangle, circle, arrow, freehand).
    if (inProgressPoints != null && inProgressPoints!.length >= 2) {
      final draftPaint = Paint()
        ..color = const Color(0x99FF5722)
        ..strokeWidth = AppLineWeights.vizData
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      switch (inProgressTool) {
        case DrawingTool.rectangle:
          final p1 = inProgressPoints!.first;
          final p2 = inProgressPoints!.last;
          canvas.drawRect(
            Rect.fromPoints(Offset(p1.x, p1.y), Offset(p2.x, p2.y)),
            draftPaint,
          );
          break;

        case DrawingTool.circle:
          final centre = inProgressPoints!.first;
          final edge = inProgressPoints!.last;
          final dx = edge.x - centre.x;
          final dy = edge.y - centre.y;
          final radius = math.sqrt(dx * dx + dy * dy);
          canvas.drawCircle(Offset(centre.x, centre.y), radius, draftPaint);
          break;

        case DrawingTool.arrow:
          final p1 = inProgressPoints!.first;
          final p2 = inProgressPoints!.last;
          canvas.drawLine(
              Offset(p1.x, p1.y), Offset(p2.x, p2.y), draftPaint);
          break;

        case DrawingTool.freehand:
          if (inProgressPoints!.length >= 2) {
            final path = Path();
            path.moveTo(
                inProgressPoints!.first.x, inProgressPoints!.first.y);
            for (int i = 1; i < inProgressPoints!.length; i++) {
              path.lineTo(inProgressPoints![i].x, inProgressPoints![i].y);
            }
            canvas.drawPath(path, draftPaint);
          }
          break;

        default:
          break;
      }
    }
  }

  void _drawAnnotation(
      Canvas canvas, AnnotationModel ann, Paint paint, Paint fillPaint) {
    switch (ann.type) {
      case DrawingTool.polygon:
        if (ann.points.length < 3) return;
        final path = Path();
        path.moveTo(ann.points.first.x, ann.points.first.y);
        for (int i = 1; i < ann.points.length; i++) {
          path.lineTo(ann.points[i].x, ann.points[i].y);
        }
        path.close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, paint);
        break;

      case DrawingTool.rectangle:
        if (ann.points.length < 2) return;
        final rect = Rect.fromPoints(
          Offset(ann.points[0].x, ann.points[0].y),
          Offset(ann.points[1].x, ann.points[1].y),
        );
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, paint);
        break;

      case DrawingTool.circle:
        if (ann.points.isEmpty || ann.radius == null) return;
        final centre = Offset(ann.points[0].x, ann.points[0].y);
        canvas.drawCircle(centre, ann.radius!, fillPaint);
        canvas.drawCircle(centre, ann.radius!, paint);
        break;

      case DrawingTool.arrow:
        if (ann.points.length < 2) return;
        final start = Offset(ann.points[0].x, ann.points[0].y);
        final end = Offset(ann.points[1].x, ann.points[1].y);
        canvas.drawLine(start, end, paint);
        // Draw arrowhead.
        _drawArrowhead(canvas, start, end, paint);
        break;

      case DrawingTool.freehand:
        if (ann.points.length < 2) return;
        final path = Path();
        path.moveTo(ann.points.first.x, ann.points.first.y);
        for (int i = 1; i < ann.points.length; i++) {
          path.lineTo(ann.points[i].x, ann.points[i].y);
        }
        canvas.drawPath(path, paint);
        break;

      case DrawingTool.text:
        if (ann.points.isEmpty || ann.label == null) return;
        final textSpan = TextSpan(
          text: ann.label!,
          style: TextStyle(
            color: paint.color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
            canvas, Offset(ann.points[0].x, ann.points[0].y));
        break;
    }
  }

  void _drawArrowhead(Canvas canvas, Offset start, Offset end, Paint paint) {
    final direction = end - start;
    final length = direction.distance;
    if (length < 1) return;
    final unit = direction / length;
    final headLength = math.min(20.0, length * 0.3);
    final headWidth = headLength * 0.5;

    final normal = Offset(-unit.dy, unit.dx);
    final base = end - unit * headLength;
    final left = base + normal * headWidth;
    final right = base - normal * headWidth;

    final arrowFill = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, arrowFill);
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) {
    return true; // Always repaint for simplicity in mock.
  }
}
