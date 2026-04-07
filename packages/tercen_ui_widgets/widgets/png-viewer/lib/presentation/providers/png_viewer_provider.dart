import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../di/service_locator.dart';
import '../../domain/models/annotation_model.dart';
import '../../domain/models/content_state.dart';
import '../../domain/models/image_model.dart';
import '../../domain/services/data_service.dart';
import '../../domain/services/event_payload.dart';
import '../../domain/services/window_channels.dart';
import 'window_state_provider.dart';

/// Provider for the PNG Viewer window.
///
/// Extends WindowStateProvider to inherit content state management,
/// EventBus command handling (focus/blur), and window intent publishing.
/// Adds domain-specific state: image data, drawing tools, annotations, zoom/pan.
class PngViewerProvider extends WindowStateProvider {
  final DataService _dataService = serviceLocator<DataService>();

  // -- Image data --

  ImageModel? _image;
  ImageModel? get image => _image;

  // -- Drawing tool --

  DrawingTool? _activeTool;
  DrawingTool? get activeTool => _activeTool;

  // -- Annotations --

  final List<AnnotationModel> _annotations = [];
  List<AnnotationModel> get annotations => List.unmodifiable(_annotations);

  // -- In-progress annotation --

  List<ImagePoint>? _inProgressPoints;
  List<ImagePoint>? get inProgressPoints => _inProgressPoints;

  // -- Zoom and pan --

  double _zoomLevel = 1.0;
  double get zoomLevel => _zoomLevel;

  Offset _panOffset = Offset.zero;
  Offset get panOffset => _panOffset;

  // -- Last load command (for retry) --

  String? _lastResourceType;
  String? _lastResourceId;

  StreamSubscription<EventPayload>? _loadImageSubscription;

  PngViewerProvider({
    required super.identity,
    required super.windowId,
  }) {
    // Subscribe to load image commands.
    _loadImageSubscription = eventBus
        .subscribe('visualization.$windowId.loadImage')
        .listen(_handleLoadImage);
  }

  // -- Inbound load image handling --

  void _handleLoadImage(EventPayload payload) {
    if (payload.type == 'loadImage') {
      final resourceType = payload.data['resourceType'] as String? ?? '';
      final resourceId = payload.data['resourceId'] as String? ?? '';
      loadImage(resourceType: resourceType, resourceId: resourceId);
    }
  }

  // -- Image loading --

  Future<void> loadImage({
    required String resourceType,
    required String resourceId,
  }) async {
    _lastResourceType = resourceType;
    _lastResourceId = resourceId;
    setContentState(ContentState.loading);
    setErrorMessage(null);
    notifyListeners();

    try {
      final img = await _dataService.fetchImage(
        resourceType: resourceType,
        resourceId: resourceId,
      );
      _image = img;
      _annotations.clear();
      _activeTool = null;
      _inProgressPoints = null;
      _zoomLevel = 1.0;
      _panOffset = Offset.zero;
      setContentState(ContentState.active);

      // Update window label to filename.
      identity.label = img.name;
      publishIntent(WindowChannels.typeContentChanged, {'label': img.name});
    } catch (e) {
      setErrorMessage(e.toString());
      setContentState(ContentState.error);
    }
    notifyListeners();
  }

  /// Override loadData for WindowBody error-retry compatibility.
  @override
  Future<void> loadData() async {
    retryLoad();
  }

  /// Retry the last load image command.
  void retryLoad() {
    if (_lastResourceType != null && _lastResourceId != null) {
      loadImage(
        resourceType: _lastResourceType!,
        resourceId: _lastResourceId!,
      );
    }
  }

  // -- Drawing tool management --

  void setActiveTool(DrawingTool? tool) {
    if (_activeTool == tool) {
      // Toggle off.
      _activeTool = null;
    } else {
      _activeTool = tool;
    }
    // Clear any in-progress annotation when switching tools.
    _inProgressPoints = null;
    notifyListeners();
  }

  // -- Annotation management --

  void addAnnotation(AnnotationModel annotation) {
    _annotations.add(annotation);
    _inProgressPoints = null;
    notifyListeners();
  }

  void setInProgressPoints(List<ImagePoint>? points) {
    _inProgressPoints = points;
    notifyListeners();
  }

  /// Translate an annotation by index.
  void translateAnnotation(int index, double dx, double dy) {
    if (index >= 0 && index < _annotations.length) {
      _annotations[index].translate(dx, dy);
      notifyListeners();
    }
  }

  void clearAllAnnotations() {
    _annotations.clear();
    _inProgressPoints = null;
    notifyListeners();
  }

  bool get hasAnnotations => _annotations.isNotEmpty;

  // -- Zoom and pan --

  void setZoomLevel(double zoom) {
    _zoomLevel = zoom.clamp(0.1, 10.0);
    notifyListeners();
  }

  void zoomIn() {
    setZoomLevel(_zoomLevel * 1.25);
  }

  void zoomOut() {
    setZoomLevel(_zoomLevel / 1.25);
  }

  void fitToWindow(Size viewportSize) {
    if (_image == null) return;
    final scaleX = viewportSize.width / _image!.width;
    final scaleY = viewportSize.height / _image!.height;
    _zoomLevel = scaleX < scaleY ? scaleX : scaleY;
    if (_zoomLevel > 1.0) _zoomLevel = 1.0; // Don't upscale beyond native.
    _panOffset = Offset.zero;
    notifyListeners();
  }

  void setPanOffset(Offset offset) {
    _panOffset = offset;
    notifyListeners();
  }

  // -- Send to Chat --

  void sendToChat() {
    if (_image == null || _annotations.isEmpty) return;

    final annotatedImageBase64 = base64Encode(_image!.imageBytes);

    final payload = {
      'annotatedImageBase64':
          '${annotatedImageBase64.substring(0, 80)}... [truncated]',
      'annotations': _annotations.map((a) => a.toJson()).toList(),
      'sourceImage': {
        'resourceId': _image!.resourceId,
        'resourceType': _image!.resourceType,
      },
    };

    // Log to console (mock behaviour).
    debugPrint('=== Send to Chat ===');
    debugPrint(
        'annotatedImageBase64: ${annotatedImageBase64.substring(0, 80)}... [${annotatedImageBase64.length} chars total]');
    debugPrint(
        'annotations: ${const JsonEncoder.withIndent('  ').convert(_annotations.map((a) => a.toJson()).toList())}');
    debugPrint(
        'sourceImage: {resourceId: ${_image!.resourceId}, resourceType: ${_image!.resourceType}}');
    debugPrint('====================');

    // Publish on EventBus.
    eventBus.publish(
      'visualization.annotations.send',
      EventPayload(
        type: 'annotationBundle',
        sourceWidgetId: windowId,
        data: payload,
      ),
    );
  }

  // -- Save to Project (mock: exports annotated PNG as browser download) --

  Future<void> saveToProject() async {
    if (_image == null) return;

    try {
      // 1. Decode original image bytes to ui.Image.
      final codec = await ui.instantiateImageCodec(_image!.imageBytes);
      final frame = await codec.getNextFrame();
      final baseImage = frame.image;

      // 2. Create a recording canvas at image dimensions.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder,
          Rect.fromLTWH(0, 0, baseImage.width.toDouble(),
              baseImage.height.toDouble()));

      // 3. Draw the base image.
      canvas.drawImage(baseImage, Offset.zero, Paint());

      // 4. Draw annotations on top.
      _paintAnnotations(canvas);

      // 5. Convert to PNG.
      final picture = recorder.endRecording();
      final rendered = await picture.toImage(
          baseImage.width, baseImage.height);
      final byteData =
          await rendered.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint('Save failed: could not encode PNG');
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final b64 = base64Encode(pngBytes);

      // 6. Trigger browser download.
      final dataUrl = 'data:image/png;base64,$b64';
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = dataUrl;
      anchor.download = '${_image!.name}_annotated.png';
      anchor.click();

      debugPrint(
          '=== Saved annotated PNG (${pngBytes.length} bytes, ${_annotations.length} annotations) ===');
    } catch (e) {
      debugPrint('Save to project failed: $e');
    }
  }

  /// Paint all annotations onto a canvas (used by saveToProject).
  void _paintAnnotations(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFFFF5722)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = const Color(0x33FF5722)
      ..style = PaintingStyle.fill;

    for (final ann in _annotations) {
      switch (ann.type) {
        case DrawingTool.polygon:
          if (ann.points.length < 3) continue;
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
          if (ann.points.length < 2) continue;
          final rect = Rect.fromPoints(
            Offset(ann.points[0].x, ann.points[0].y),
            Offset(ann.points[1].x, ann.points[1].y),
          );
          canvas.drawRect(rect, fillPaint);
          canvas.drawRect(rect, paint);
          break;

        case DrawingTool.circle:
          if (ann.points.isEmpty || ann.radius == null) continue;
          final centre = Offset(ann.points[0].x, ann.points[0].y);
          canvas.drawCircle(centre, ann.radius!, fillPaint);
          canvas.drawCircle(centre, ann.radius!, paint);
          break;

        case DrawingTool.arrow:
          if (ann.points.length < 2) continue;
          final start = Offset(ann.points[0].x, ann.points[0].y);
          final end = Offset(ann.points[1].x, ann.points[1].y);
          canvas.drawLine(start, end, paint);
          // Arrowhead.
          final dir = end - start;
          final len = dir.distance;
          if (len > 1) {
            final unit = dir / len;
            final headLen = math.min(20.0, len * 0.3);
            final headW = headLen * 0.5;
            final normal = Offset(-unit.dy, unit.dx);
            final base = end - unit * headLen;
            final arrowPath = Path()
              ..moveTo(end.dx, end.dy)
              ..lineTo((base + normal * headW).dx, (base + normal * headW).dy)
              ..lineTo((base - normal * headW).dx, (base - normal * headW).dy)
              ..close();
            canvas.drawPath(
                arrowPath,
                Paint()
                  ..color = const Color(0xFFFF5722)
                  ..style = PaintingStyle.fill);
          }
          break;

        case DrawingTool.freehand:
          if (ann.points.length < 2) continue;
          final path = Path();
          path.moveTo(ann.points.first.x, ann.points.first.y);
          for (int i = 1; i < ann.points.length; i++) {
            path.lineTo(ann.points[i].x, ann.points[i].y);
          }
          canvas.drawPath(path, paint);
          break;

        case DrawingTool.text:
          if (ann.points.isEmpty || ann.label == null) continue;
          final textSpan = TextSpan(
            text: ann.label!,
            style: const TextStyle(
              color: Color(0xFFFF5722),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          );
          final tp = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(canvas, Offset(ann.points[0].x, ann.points[0].y));
          break;
      }
    }
  }

  @override
  void dispose() {
    _loadImageSubscription?.cancel();
    super.dispose();
  }
}
