/// Unified audit event model that abstracts over Activity and Task data sources.
///
/// Phase 2: constructed from mock data.
/// Phase 3: constructed from real Activity and Task API responses.
class AuditEvent {
  final String id;
  final EventSource source;
  final DateTime timestamp;
  final String eventType; // create, update, delete, run, complete, fail, cancel
  final String objectKind; // Project, Workflow, TableSchema, FileDocument, etc.
  final String userId;
  final String teamId;
  final String projectId;
  final String projectName;
  final String targetId;
  final String targetName;
  final bool isPublic;
  final Map<String, String> details;

  const AuditEvent({
    required this.id,
    required this.source,
    required this.timestamp,
    required this.eventType,
    required this.objectKind,
    required this.userId,
    required this.teamId,
    required this.projectId,
    required this.projectName,
    required this.targetId,
    required this.targetName,
    this.isPublic = false,
    this.details = const {},
  });

  /// Best available date for display: completedDate from task details,
  /// falling back to the event timestamp.
  DateTime get displayDate {
    final completed = details['completedDate'];
    if (completed != null) {
      final parsed = DateTime.tryParse(completed);
      if (parsed != null) return parsed;
    }
    return timestamp;
  }

  /// Scope string: "teamId > projectName".
  String get scope => '$teamId > $projectName';

  /// Human-readable action summary derived from eventType + objectKind.
  String get actionSummary {
    switch (eventType) {
      case 'create':
        return 'Created $objectKind';
      case 'update':
        return 'Updated $objectKind';
      case 'delete':
        return 'Deleted $objectKind';
      case 'run':
        return 'Ran Task';
      case 'complete':
        return 'Task Completed';
      case 'fail':
        return 'Task Failed';
      case 'cancel':
        return 'Task Cancelled';
      default:
        return '$eventType $objectKind';
    }
  }

  /// Serialise to a map for EventBus payloads.
  Map<String, dynamic> toMap() => {
        'id': id,
        'source': source.name,
        'timestamp': timestamp.toIso8601String(),
        'eventType': eventType,
        'objectKind': objectKind,
        'userId': userId,
        'teamId': teamId,
        'projectId': projectId,
        'projectName': projectName,
        'targetId': targetId,
        'targetName': targetName,
        'isPublic': isPublic,
        'details': details,
      };

  /// Whether this event is searchable by the given query.
  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return actionSummary.toLowerCase().contains(q) ||
        targetName.toLowerCase().contains(q) ||
        userId.toLowerCase().contains(q) ||
        projectName.toLowerCase().contains(q) ||
        objectKind.toLowerCase().contains(q);
  }
}

/// Which data source this event came from.
enum EventSource {
  activity,
  task,
}
