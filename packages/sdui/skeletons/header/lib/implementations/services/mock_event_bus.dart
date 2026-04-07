import 'dart:async';

import '../../domain/services/event_bus.dart';

/// Mock EventBus that logs all published events to console.
/// Returns empty streams for subscriptions.
class MockEventBus implements EventBus {
  @override
  void publish(String channel, String intentType, Map<String, dynamic> payload) {
    print('[EventBus] $channel :: $intentType ${payload.isNotEmpty ? payload : ""}');
  }

  @override
  Stream<Map<String, dynamic>> subscribe(String channel) {
    // No inbound events in mock mode.
    return const Stream.empty();
  }
}
