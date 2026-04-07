import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import '../../domain/models/image_model.dart';
import '../../domain/services/data_service.dart';

/// Mock implementation that returns the embedded sample PNG asset.
class MockDataService implements DataService {
  /// Known mock resource IDs mapped to asset paths.
  static const String sampleResourceId = 'umap-clusters-001';
  static const String sampleResourceType = 'stepOutput';
  static const String _assetPath = 'assets/data/View UMAP vs. clusters.png';

  Uint8List? _cachedBytes;

  @override
  Future<ImageModel> fetchImage({
    required String resourceType,
    required String resourceId,
  }) async {
    // Simulate network latency.
    await Future.delayed(const Duration(milliseconds: 400));

    _cachedBytes ??= (await rootBundle.load(_assetPath)).buffer.asUint8List();

    final bytes = _cachedBytes!;

    // Parse PNG dimensions from the IHDR chunk.
    final width = _readPngWidth(bytes);
    final height = _readPngHeight(bytes);

    return ImageModel(
      resourceId: resourceId,
      resourceType: resourceType,
      name: 'View UMAP vs. clusters.png',
      imageBytes: bytes,
      width: width,
      height: height,
    );
  }

  /// Read image width from PNG IHDR chunk (bytes 16-19, big-endian).
  int _readPngWidth(Uint8List bytes) {
    if (bytes.length < 24) return 800;
    return (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
  }

  /// Read image height from PNG IHDR chunk (bytes 20-23, big-endian).
  int _readPngHeight(Uint8List bytes) {
    if (bytes.length < 24) return 600;
    return (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
  }
}
