import 'dart:async';

import 'event_payload.dart';

/// Unified event bus: publish/subscribe with channel-based routing.
///
/// Mirrors the orchestrator's EventBus exactly.
/// See: tercen_ui_orchestrator/lib/sdui/event_bus/event_bus.dart
///
/// In production the orchestrator provides the singleton instance.
/// In mock/standalone mode the skeleton creates its own local instance.
class EventBus {
  final Map<String, StreamController<EventPayload>> _channels = {};

  /// Publish a payload to a channel.
  void publish(String channel, EventPayload payload) {
    _channels[channel]?.add(payload);
  }

  /// Subscribe to a channel. Creates the channel if it doesn't exist.
  Stream<EventPayload> subscribe(String channel) {
    return _getOrCreate(channel).stream;
  }

  /// Subscribe to all channels matching a prefix (e.g. "system.data.").
  Stream<EventPayload> subscribePrefix(String prefix) {
    final controller = StreamController<EventPayload>.broadcast();

    // Forward existing matching channels
    for (final entry in _channels.entries) {
      if (entry.key.startsWith(prefix)) {
        entry.value.stream.listen(controller.add);
      }
    }

    return controller.stream;
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
