/// Payload carried on the EventBus.
///
/// Mirrors the orchestrator's EventPayload exactly.
class EventPayload {
  final String type;
  final String? sourceWidgetId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  EventPayload({
    required this.type,
    this.sourceWidgetId,
    this.data = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type,
        'sourceWidgetId': sourceWidgetId,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };
}
