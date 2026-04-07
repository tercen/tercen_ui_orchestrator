import 'dart:typed_data';

/// Represents a loaded PNG image.
class ImageModel {
  /// Unique identifier of the image in Tercen.
  final String resourceId;

  /// Either "stepOutput" or "projectFile".
  final String resourceType;

  /// Display name (filename).
  final String name;

  /// Raw PNG image data.
  final Uint8List imageBytes;

  /// Image width in pixels.
  final int width;

  /// Image height in pixels.
  final int height;

  const ImageModel({
    required this.resourceId,
    required this.resourceType,
    required this.name,
    required this.imageBytes,
    required this.width,
    required this.height,
  });
}
