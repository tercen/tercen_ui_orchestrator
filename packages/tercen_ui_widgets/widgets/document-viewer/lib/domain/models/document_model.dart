/// Represents a document loaded in the editor.
class DocumentModel {
  final String id;
  final String name;
  final String content;
  final String projectId;
  final String mimeType;

  const DocumentModel({
    required this.id,
    required this.name,
    required this.content,
    required this.projectId,
    required this.mimeType,
  });

  /// Whether this document is a markdown file.
  bool get isMarkdown => name.endsWith('.md');

  /// Whether this document is a plain text file.
  bool get isPlainText => name.endsWith('.txt');

  DocumentModel copyWith({
    String? id,
    String? name,
    String? content,
    String? projectId,
    String? mimeType,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      projectId: projectId ?? this.projectId,
      mimeType: mimeType ?? this.mimeType,
    );
  }
}
