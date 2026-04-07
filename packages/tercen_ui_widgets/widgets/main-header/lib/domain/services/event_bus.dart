/// Abstract EventBus for header intent publishing and state subscription.
abstract class EventBus {
  /// Publish an intent or state event.
  void publish(String channel, String intentType, Map<String, dynamic> payload);

  /// Subscribe to events on a channel.
  Stream<Map<String, dynamic>> subscribe(String channel);
}
