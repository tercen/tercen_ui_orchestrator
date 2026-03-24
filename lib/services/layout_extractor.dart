import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sdui/sdui.dart';

/// Extracts SDUI layout operations from text containing ```json code blocks
/// and dispatches them to the EventBus.
///
/// Layout ops are JSON objects with an "op" field (addWindow, removeWindow,
/// updateContent). Non-op JSON blocks are ignored.
void extractAndDispatchLayoutOps(String text, EventBus eventBus) {
  final pattern = RegExp(r'```json\s*\n([\s\S]*?)\n```');
  for (final match in pattern.allMatches(text)) {
    final jsonStr = match.group(1)?.trim();
    if (jsonStr == null) continue;

    try {
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (parsed.containsKey('op')) {
        debugPrint('[layout] dispatching op: ${parsed['op']}');
        eventBus.publish(
          'system.layout.op',
          EventPayload(
            type: 'layout.op',
            sourceWidgetId: 'agent-client',
            data: parsed,
          ),
        );
      }
    } catch (e) {
      debugPrint('[layout] failed to parse JSON block: $e');
    }
  }
}

/// Remove ```json code blocks from text for clean chat display.
String stripJsonCodeBlocks(String text) {
  return text.replaceAll(RegExp(r'```json\s*\n[\s\S]*?\n```'), '').trim();
}
