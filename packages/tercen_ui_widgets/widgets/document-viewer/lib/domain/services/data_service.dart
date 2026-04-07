import '../models/document_model.dart';

/// Abstract document service interface.
///
/// Phase 2: Mock implementation with sample documents.
/// Phase 3: Real implementation querying Tercen API.
abstract class DataService {
  /// Load a document by file ID and project ID.
  Future<DocumentModel> loadDocument(String fileId, String projectId);

  /// Save document content. Returns true on success, false on failure.
  Future<bool> saveDocument(String fileId, String content);

  /// List available mock document IDs (mock only).
  List<String> get availableDocumentIds;
}
