import 'dart:convert';

import 'package:sdui/sdui.dart';

/// Generates an event spec by walking the widget catalog.
///
/// Extracts all EventBus channels, their publishers/subscribers,
/// payload shapes, and intent declarations.
class EventSpecGenerator {
  final WidgetRegistry registry;
  final Map<String, dynamic>? catalogJson;

  EventSpecGenerator(this.registry, {this.catalogJson});

  Map<String, dynamic> generate() {
    final channels = <String, _ChannelInfo>{};
    final intents = <String, Map<String, dynamic>>{};

    // Walk all catalog widget metadata for emittedEvents and handlesIntent.
    for (final meta in registry.catalog) {
      // Emitted events → publisher.
      for (final channel in meta.emittedEvents) {
        channels.putIfAbsent(channel, () => _ChannelInfo(channel));
        channels[channel]!.publishers.add(meta.type);
      }

      // Handled intents → intent registry.
      for (final intent in meta.handlesIntent) {
        intents[intent.intent] = {
          'handler': meta.type,
          'propsMap': intent.propsMap,
          if (intent.windowTitle != null) 'windowTitle': intent.windowTitle,
          if (intent.windowSize != null) 'windowSize': intent.windowSize,
        };
      }
    }

    // Walk all catalog templates for Action channels, ReactTo, refreshOn, payload shapes.
    if (catalogJson != null) {
      final widgets = catalogJson!['widgets'] as List<dynamic>? ?? [];
      for (final entry in widgets) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        final metaJson = map['metadata'] as Map<String, dynamic>?;
        final templateJson = map['template'] as Map<String, dynamic>?;
        if (metaJson == null || templateJson == null) continue;

        final widgetType = metaJson['type'] as String? ?? '';
        final template = SduiNode.fromJson(templateJson);
        _walkTemplate(template, widgetType, channels);
      }
    }

    // Add well-known system channels that aren't in any template.
    _addSystemChannels(channels);

    // Build output.
    final sortedChannels = channels.keys.toList()..sort();
    final channelSpecs = <String, dynamic>{};
    for (final name in sortedChannels) {
      channelSpecs[name] = channels[name]!.toJson();
    }

    final sortedIntents = intents.keys.toList()..sort();
    final intentSpecs = <String, dynamic>{};
    for (final name in sortedIntents) {
      intentSpecs[name] = intents[name];
    }

    return {
      'title': 'SDUI Event Specification',
      'description': 'All EventBus channels, their publishers/subscribers, '
          'payload shapes, and intent declarations. '
          'Auto-seeded from the widget catalog.',
      'version': '1.0.0',
      'channels': channelSpecs,
      'intents': intentSpecs,
      'patterns': _intraWidgetPatterns(),
    };
  }

  String toJson() {
    return const JsonEncoder.withIndent('  ').convert(generate());
  }

  void _walkTemplate(
      SduiNode node, String widgetType, Map<String, _ChannelInfo> channels) {
    final props = node.props;

    // Action → publisher with payload shape.
    if (node.type == 'Action' ||
        node.type == 'ElevatedButton' ||
        node.type == 'TextButton' ||
        node.type == 'IconButton') {
      final channel = props['channel'] as String?;
      if (channel != null && channel.isNotEmpty && !_isTemplateExpr(channel)) {
        channels.putIfAbsent(channel, () => _ChannelInfo(channel));
        channels[channel]!.publishers.add(widgetType);

        // Extract payload keys.
        final payload = props['payload'];
        if (payload is Map) {
          for (final key in payload.keys) {
            channels[channel]!.payloadKeys.add(key.toString());
          }
        }
      }
    }

    // ReactTo → subscriber.
    if (node.type == 'ReactTo') {
      final channel = props['channel'] as String?;
      if (channel != null && channel.isNotEmpty && !_isTemplateExpr(channel)) {
        channels.putIfAbsent(channel, () => _ChannelInfo(channel));
        channels[channel]!.subscribers.add(widgetType);

        // Extract match keys.
        final match = props['match'];
        if (match is Map) {
          for (final key in match.keys) {
            channels[channel]!.payloadKeys.add(key.toString());
          }
        }
      }
    }

    // DataSource.refreshOn → subscriber.
    if (node.type == 'DataSource') {
      final refreshOn = props['refreshOn'] as String?;
      if (refreshOn != null &&
          refreshOn.isNotEmpty &&
          !_isTemplateExpr(refreshOn)) {
        channels.putIfAbsent(refreshOn, () => _ChannelInfo(refreshOn));
        channels[refreshOn]!.subscribers.add(widgetType);
      }
    }

    for (final child in node.children) {
      _walkTemplate(child, widgetType, channels);
    }
  }

  void _addSystemChannels(Map<String, _ChannelInfo> channels) {
    channels.putIfAbsent('system.intent', () => _ChannelInfo('system.intent'))
      ..description =
          'Inter-widget navigation via intent routing. '
          'Payload must include "intent" field matching a registered intent name.'
      ..payloadKeys.addAll(['intent']);

    channels.putIfAbsent(
        'system.layout.op', () => _ChannelInfo('system.layout.op'))
      ..description =
          'Window management operations (addWindow, removeWindow, clearAll).'
      ..payloadKeys.addAll(['op', 'id', 'title', 'size', 'align', 'content']);

    channels.putIfAbsent(
        'system.layout.region', () => _ChannelInfo('system.layout.region'))
      ..description = 'Fixed region placement (e.g., header).'
      ..payloadKeys.addAll(['region', 'content']);

    channels.putIfAbsent(
        'system.notification', () => _ChannelInfo('system.notification'))
      ..description = 'User-facing notifications (error, info, success).'
      ..payloadKeys.addAll(['severity', 'message']);
  }

  Map<String, dynamic> _intraWidgetPatterns() {
    return {
      'state-mutation': {
        'channelPattern': 'state.{nodeId}.set',
        'description':
            'Mutate a StateHolder state. Sent via Action payload to this channel.',
        'payloadKeys': ['op', 'key', 'values', 'amount'],
        'ops': ['merge', 'increment', 'decrement', 'toggle', 'reset'],
      },
      'input-changed': {
        'channelPattern': 'input.{nodeId}.changed',
        'description': 'Interactive widget value changed.',
        'payloadKeys': ['value'],
        'emitters': [
          'TextField',
          'Switch',
          'Checkbox',
          'DropdownButton',
        ],
      },
      'input-submitted': {
        'channelPattern': 'input.{nodeId}.submitted',
        'description': 'TextField submitted (Enter key).',
        'payloadKeys': ['value'],
        'emitters': ['TextField'],
      },
    };
  }

  bool _isTemplateExpr(String value) => value.contains('{{');
}

class _ChannelInfo {
  final String name;
  String? description;
  final Set<String> publishers = {};
  final Set<String> subscribers = {};
  final Set<String> payloadKeys = {};

  _ChannelInfo(this.name);

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (description != null) json['description'] = description;
    if (publishers.isNotEmpty) {
      json['publishers'] = publishers.toList()..sort();
    }
    if (subscribers.isNotEmpty) {
      json['subscribers'] = subscribers.toList()..sort();
    }
    if (payloadKeys.isNotEmpty) {
      json['payloadKeys'] = payloadKeys.toList()..sort();
    }
    return json;
  }
}
