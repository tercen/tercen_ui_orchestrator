import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sdui/sdui.dart';

/// Panel that shows all EventBus events and lets the user inject events.
class EventInspector extends StatefulWidget {
  final EventBus eventBus;

  /// Channels the loaded widget is known to listen on (from metadata +
  /// template analysis). Shown as quick-send buttons.
  final List<String> knownChannels;

  const EventInspector({
    super.key,
    required this.eventBus,
    this.knownChannels = const [],
  });

  @override
  State<EventInspector> createState() => _EventInspectorState();
}

class _EventInspectorState extends State<EventInspector>
    with SingleTickerProviderStateMixin {
  final _events = <_RecordedEvent>[];
  StreamSubscription<EventPayload>? _sub;
  late final TabController _tabController;

  // Injector fields
  final _channelCtrl = TextEditingController();
  final _payloadCtrl = TextEditingController(text: '{}');
  String? _payloadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _sub = widget.eventBus.subscribePrefix('').listen(_onEvent);
  }

  void _onEvent(EventPayload event) {
    setState(() {
      _events.insert(
        0,
        _RecordedEvent(
          channel: event.data['_channel'] as String? ?? event.type,
          payload: event,
          timestamp: DateTime.now(),
        ),
      );
      // Cap at 200 events.
      if (_events.length > 200) _events.removeLast();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tabController.dispose();
    _channelCtrl.dispose();
    _payloadCtrl.dispose();
    super.dispose();
  }

  void _sendEvent() {
    final channel = _channelCtrl.text.trim();
    if (channel.isEmpty) return;

    Map<String, dynamic> data;
    try {
      final raw = jsonDecode(_payloadCtrl.text);
      data = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);
      _payloadError = null;
    } catch (e) {
      setState(() => _payloadError = e.toString());
      return;
    }

    widget.eventBus.publish(
      channel,
      EventPayload(
        type: channel,
        sourceWidgetId: '_inspector',
        data: data,
      ),
    );
    setState(() => _payloadError = null);
  }

  void _quickSend(String channel) {
    _channelCtrl.text = channel;
    _tabController.animateTo(1); // Switch to Injector tab
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          indicatorColor: cs.primary,
          tabs: const [
            Tab(text: 'Events', icon: Icon(Icons.monitor_heart, size: 16)),
            Tab(text: 'Inject', icon: Icon(Icons.send, size: 16)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildEventLog(cs, tt),
              _buildInjector(cs, tt),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventLog(ColorScheme cs, TextTheme tt) {
    if (_events.isEmpty) {
      return Center(
        child: Text('No events yet', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final e = _events[index];
        final time =
            '${e.timestamp.hour.toString().padLeft(2, '0')}:'
            '${e.timestamp.minute.toString().padLeft(2, '0')}:'
            '${e.timestamp.second.toString().padLeft(2, '0')}.'
            '${e.timestamp.millisecond.toString().padLeft(3, '0')}';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.arrow_forward, size: 12, color: cs.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        e.channel,
                        style: tt.labelSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        final text = '${e.channel}: ${_compactJson(e.payload.data)}';
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Event copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Icon(Icons.copy, size: 12, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 6),
                    Text(time, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
                if (e.payload.sourceWidgetId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'from: ${e.payload.sourceWidgetId}',
                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                if (e.payload.data.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _compactJson(e.payload.data),
                      style: tt.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        color: cs.onSurface,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInjector(ColorScheme cs, TextTheme tt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick-send buttons from known channels
          if (widget.knownChannels.isNotEmpty) ...[
            Text('Quick send', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: widget.knownChannels
                  .map((ch) => ActionChip(
                        label: Text(ch, style: tt.labelSmall),
                        onPressed: () => _quickSend(ch),
                        avatar: const Icon(Icons.bolt, size: 14),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],

          Text('Channel', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          TextField(
            controller: _channelCtrl,
            style: tt.bodySmall,
            decoration: InputDecoration(
              hintText: 'e.g. navigator.focusChanged',
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              hintStyle: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),

          Text('Payload (JSON)', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          TextField(
            controller: _payloadCtrl,
            style: tt.bodySmall?.copyWith(fontFamily: 'monospace'),
            maxLines: 6,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(8),
              errorText: _payloadError,
            ),
          ),
          const SizedBox(height: 8),

          FilledButton.icon(
            onPressed: _sendEvent,
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Send Event'),
          ),
        ],
      ),
    );
  }

  String _compactJson(Map<String, dynamic> data) {
    // Remove the internal _channel key from display.
    final display = Map<String, dynamic>.from(data)..remove('_channel');
    try {
      return const JsonEncoder.withIndent('  ').convert(display);
    } catch (_) {
      return display.toString();
    }
  }
}

class _RecordedEvent {
  final String channel;
  final EventPayload payload;
  final DateTime timestamp;

  const _RecordedEvent({
    required this.channel,
    required this.payload,
    required this.timestamp,
  });
}
