import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sdui/sdui.dart';

/// Panel that shows the full JSON of the last item involved in an event.
///
/// Listens to all EventBus events and displays the event data as pretty JSON.
/// Click the copy button to get the full JSON on the clipboard.
class ItemInspector extends StatefulWidget {
  final EventBus eventBus;

  const ItemInspector({super.key, required this.eventBus});

  @override
  State<ItemInspector> createState() => _ItemInspectorState();
}

class _ItemInspectorState extends State<ItemInspector> {
  StreamSubscription<EventPayload>? _sub;
  Map<String, dynamic>? _lastPayload;
  String? _lastChannel;
  DateTime? _lastTime;

  @override
  void initState() {
    super.initState();
    _sub = widget.eventBus.subscribePrefix('').listen((event) {
      // Skip internal layout events.
      final ch = event.data['_channel'] as String? ?? event.type;
      if (ch.startsWith('system.layout')) return;
      setState(() {
        _lastPayload = Map<String, dynamic>.from(event.data);
        _lastChannel = ch;
        _lastTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_lastPayload == null) {
      return Center(
        child: Text('Click an item to inspect',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      );
    }

    final display = Map<String, dynamic>.from(_lastPayload!)..remove('_channel');
    final json = const JsonEncoder.withIndent('  ').convert(display);
    final time = _lastTime != null
        ? '${_lastTime!.hour.toString().padLeft(2, '0')}:'
          '${_lastTime!.minute.toString().padLeft(2, '0')}:'
          '${_lastTime!.second.toString().padLeft(2, '0')}'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: cs.surfaceContainerHigh,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.data_object, size: 14, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$_lastChannel  $time',
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: json));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('JSON copied'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Icon(Icons.copy, size: 14, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: SelectableText(
              json,
              style: tt.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: cs.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
