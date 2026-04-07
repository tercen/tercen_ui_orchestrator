import '../models/image_model.dart';

/// Abstract data service interface for fetching PNG images.
///
/// Phase 2: Mock implementation returns embedded sample PNG.
/// Phase 3: Real implementation queries Tercen API.
abstract class DataService {
  /// Fetch a PNG image by resource type and resource ID.
  Future<ImageModel> fetchImage({
    required String resourceType,
    required String resourceId,
  });
}
