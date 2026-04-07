import 'dart:async';

import 'package:flutter/foundation.dart';

import '../event_bus/event_bus.dart';
import '../event_bus/event_payload.dart';
import '../registry/widget_metadata.dart';
import '../registry/widget_registry.dart';
import '../schema/prop_converter.dart';

/// Generic intent router. Listens on `system.intent` and creates windows
/// by publishing `addWindow` layout ops to `system.layout.op`.
///
/// The routing table is built from [WidgetMetadata.handlesIntent] declarations
/// in the widget catalog. Rebuilds automatically when the registry changes.
class IntentRouter {
  final EventBus eventBus;
  final WidgetRegistry registry;

  final Map<String, _Route> _routes = {};
  StreamSubscription<EventPayload>? _subscription;

  IntentRouter({required this.eventBus, required this.registry}) {
    // Auto-rebuild when the catalog changes (loadCatalog, registerTemplate, etc.)
    registry.addListener(_buildRoutingTable);
  }

  /// Rebuild the routing table from current registry catalog.
  void _buildRoutingTable() {
    _routes.clear();
    for (final meta in registry.catalog) {
      for (final spec in meta.handlesIntent) {
        if (_routes.containsKey(spec.intent)) {
          debugPrint('[IntentRouter] WARNING: duplicate handler for '
              '"${spec.intent}" — ${meta.type} shadows '
              '${_routes[spec.intent]!.widgetType}');
        }
        _routes[spec.intent] = _Route(widgetType: meta.type, spec: spec);
      }
    }
    if (_routes.isNotEmpty) {
      debugPrint('[IntentRouter] Routes: ${_routes.keys.toList()}');
    }
  }

  /// Start listening on the `system.intent` channel.
  void start() {
    _subscription?.cancel();
    _subscription = eventBus.subscribe('system.intent').listen(_handleIntent);
    _buildRoutingTable();
    debugPrint('[IntentRouter] Listening on system.intent');
  }

  void _handleIntent(EventPayload event) {
    // Prefer explicit 'intent' field in data (used by Action widgets),
    // fall back to event.type (used by programmatic emitters).
    final intentName =
        PropConverter.to<String>(event.data['intent']) ?? event.type;
    final route = _routes[intentName];
    if (route == null) {
      debugPrint('[IntentRouter] No handler for intent "$intentName"');
      return;
    }

    final spec = route.spec;
    final intentData = event.data;

    // Map intent params → widget props
    final props = <String, dynamic>{};
    if (spec.propsMap.isEmpty) {
      // No explicit mapping — pass all intent params as props directly
      props.addAll(intentData);
    } else {
      for (final entry in spec.propsMap.entries) {
        final intentParam = entry.key;
        final widgetProp = entry.value;
        if (intentData.containsKey(intentParam)) {
          props[widgetProp] = intentData[intentParam];
        }
      }
    }

    // Remove internal keys from props
    props.remove('intent');
    props.remove('_channel');

    // Build window title — interpolate {{paramName}} from intent data
    var title = spec.windowTitle ?? route.widgetType;
    for (final entry in intentData.entries) {
      title = title.replaceAll('{{${entry.key}}}', '${entry.value}');
    }

    // Deterministic window ID from intent + first param value
    final firstValue = props.values.firstOrNull?.toString() ?? '';
    final windowId = 'win-$intentName-${firstValue.hashCode.abs()}';

    debugPrint('[IntentRouter] Routing "$intentName" → ${route.widgetType} '
        '(window: $windowId, title: $title)');

    // Publish addWindow layout op
    eventBus.publish(
      'system.layout.op',
      EventPayload(
        type: 'layout.op',
        sourceWidgetId: 'intent-router',
        data: {
          'op': 'addWindow',
          'id': windowId,
          'size': spec.windowSize,
          'align': spec.windowAlign,
          'title': title,
          'content': {
            'type': route.widgetType,
            'id': '$windowId-root',
            'props': props,
            'children': <dynamic>[],
          },
        },
      ),
    );
  }

  void dispose() {
    _subscription?.cancel();
    registry.removeListener(_buildRoutingTable);
  }
}

class _Route {
  final String widgetType;
  final IntentSpec spec;
  const _Route({required this.widgetType, required this.spec});
}
