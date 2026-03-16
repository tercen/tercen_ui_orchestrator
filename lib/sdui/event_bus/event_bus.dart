import 'dart:async';

import 'event_payload.dart';

/// Unified event bus: publish/subscribe with channel-based routing.
/// Local transport for now; backend transport to be added when sci_tercen_client
/// is integrated.
class EventBus {
  final Map<String, StreamController<EventPayload>> _channels = {};
  final List<_PrefixSubscription> _prefixSubs = [];

  /// Publish a payload to a channel.
  void publish(String channel, EventPayload payload) {
    _getOrCreate(channel).add(payload);
  }

  /// Subscribe to a channel. Creates the channel if it doesn't exist.
  Stream<EventPayload> subscribe(String channel) {
    return _getOrCreate(channel).stream;
  }

  /// Subscribe to all channels matching a prefix (e.g. "system.selection.").
  /// Also forwards events from channels created after this subscription.
  Stream<EventPayload> subscribePrefix(String prefix) {
    final controller = StreamController<EventPayload>.broadcast();

    // Forward existing matching channels
    for (final entry in _channels.entries) {
      if (entry.key.startsWith(prefix)) {
        entry.value.stream.listen(controller.add);
      }
    }

    // Track this prefix subscription so new channels get wired automatically
    _prefixSubs.add(_PrefixSubscription(prefix: prefix, controller: controller));

    return controller.stream;
  }

  StreamController<EventPayload> _getOrCreate(String channel) {
    return _channels.putIfAbsent(channel, () {
      final sc = StreamController<EventPayload>.broadcast();
      // Wire to any existing prefix subscriptions that match
      for (final sub in _prefixSubs) {
        if (channel.startsWith(sub.prefix)) {
          sc.stream.listen(sub.controller.add);
        }
      }
      return sc;
    });
  }

  void dispose() {
    for (final controller in _channels.values) {
      controller.close();
    }
    for (final sub in _prefixSubs) {
      sub.controller.close();
    }
    _channels.clear();
    _prefixSubs.clear();
  }
}

class _PrefixSubscription {
  final String prefix;
  final StreamController<EventPayload> controller;
  const _PrefixSubscription({required this.prefix, required this.controller});
}
