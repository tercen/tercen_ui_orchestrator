import 'annotation_model.dart';

/// Payload sent to Chat when the user clicks "Send to Chat".
class AnnotationBundleModel {
  /// Composite PNG with annotations baked in, base64 encoded.
  final String annotatedImageBase64;

  /// List of structured annotation objects.
  final List<AnnotationModel> annotations;

  /// Reference to the original image.
  final String sourceResourceId;
  final String sourceResourceType;

  const AnnotationBundleModel({
    required this.annotatedImageBase64,
    required this.annotations,
    required this.sourceResourceId,
    required this.sourceResourceType,
  });

  Map<String, dynamic> toJson() => {
        'annotatedImageBase64': annotatedImageBase64,
        'annotations': annotations.map((a) => a.toJson()).toList(),
        'sourceImage': {
          'resourceId': sourceResourceId,
          'resourceType': sourceResourceType,
        },
      };
}
