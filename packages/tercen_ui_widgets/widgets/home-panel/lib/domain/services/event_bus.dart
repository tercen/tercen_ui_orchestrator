import 'dart:async';

import 'event_payload.dart';

/// Unified event bus: publish/subscribe with channel-based routing.
///
/// Mirrors the orchestrator's EventBus exactly.
class EventBus {
  final Map<String, StreamController<EventPayload>> _channels = {};

  void publish(String channel, EventPayload payload) {
    _channels[channel]?.add(payload);
  }

  Stream<EventPayload> subscribe(String channel) {
    return _getOrCreate(channel).stream;
  }

  StreamController<EventPayload> _getOrCreate(String channel) {
    return _channels.putIfAbsent(
      channel,
      () => StreamController<EventPayload>.broadcast(),
    );
  }

  void dispose() {
    for (final controller in _channels.values) {
      controller.close();
    }
    _channels.clear();
  }
}
