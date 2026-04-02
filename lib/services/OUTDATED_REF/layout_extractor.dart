import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sdui/sdui.dart';

/// Extracts SDUI layout operations from text containing ```json code blocks
/// and dispatches them to the EventBus.
///
/// Layout ops are JSON objects with an "op" field (addWindow, removeWindow,
/// updateContent). Non-op JSON blocks are ignored.
///
/// Also handles raw JSON strings that start with '{' and contain an "op" field,
/// since MCP tool results may not always be wrapped in code fences.
void extractAndDispatchLayoutOps(String text, EventBus eventBus) {
  var dispatched = 0;

  // 1. Try ```json code blocks (primary path).
  final pattern = RegExp(r'```json\s*\n([\s\S]*?)\n```');
  for (final match in pattern.allMatches(text)) {
    final jsonStr = match.group(1)?.trim();
    if (jsonStr == null) continue;
    if (_tryDispatch(jsonStr, eventBus)) dispatched++;
  }

  // 2. Fallback: if no code-block ops found, try the whole text as raw JSON.
  if (dispatched == 0) {
    final trimmed = text.trim();
    if (trimmed.startsWith('{')) {
      // Could be raw JSON followed by trailing text — extract first object.
      final end = _findJsonObjectEnd(trimmed);
      if (end > 0) {
        if (_tryDispatch(trimmed.substring(0, end), eventBus)) dispatched++;
      }
    }
  }

  if (dispatched == 0 && text.contains('"op"')) {
    debugPrint('[layout] WARNING: text contains "op" but no layout ops dispatched. '
        'Text (first 200 chars): ${text.substring(0, text.length.clamp(0, 200))}');
  }
}

/// Try to parse [jsonStr] as a layout op and dispatch it. Returns true if dispatched.
bool _tryDispatch(String jsonStr, EventBus eventBus) {
  try {
    final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
    if (parsed.containsKey('op')) {
      debugPrint('[layout] dispatching op: ${parsed['op']} id=${parsed['id']}');
      eventBus.publish(
        'system.layout.op',
        EventPayload(
          type: 'layout.op',
          sourceWidgetId: 'agent-client',
          data: parsed,
        ),
      );
      return true;
    }
  } catch (e) {
    debugPrint('[layout] failed to parse JSON: $e');
  }
  return false;
}

/// Find the end index of the first balanced JSON object in [text].
/// Returns -1 if not found.
int _findJsonObjectEnd(String text) {
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (escaped) { escaped = false; continue; }
    if (c == '\\' && inString) { escaped = true; continue; }
    if (c == '"') { inString = !inString; continue; }
    if (inString) continue;
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return -1;
}

