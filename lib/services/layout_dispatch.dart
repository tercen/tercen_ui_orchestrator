import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sdui/sdui.dart';

/// Parses a JSON string as a LayoutOp and dispatches it to the EventBus.
///
/// LayoutOp contract (from render_widget MCP tool):
///   {
///     "op":      "addWindow" | "removeWindow" | "updateContent",
///     "id":      "unique-window-id",
///     "title":   "Window Title",
///     "size":    "small" | "medium" | "large" | "column",
///     "align":   "center" | "left" | "right",
///     "content": { type, id, props, children }   // SduiNode tree
///   }
///
/// Returns true if a layout op was dispatched.
bool dispatchLayoutOp(String json, EventBus eventBus) {
  try {
    final parsed = jsonDecode(json);
    if (parsed is! Map<String, dynamic>) {
      debugPrint('[layout] Expected JSON object, got ${parsed.runtimeType}');
      return false;
    }
    if (!parsed.containsKey('op')) {
      debugPrint('[layout] JSON has no "op" field — not a layout op');
      return false;
    }
    debugPrint('[layout] dispatching op=${parsed['op']} id=${parsed['id']}');
    eventBus.publish(
      'system.layout.op',
      EventPayload(
        type: 'layout.op',
        sourceWidgetId: 'agent-client',
        data: parsed,
      ),
    );
    return true;
  } on FormatException catch (e) {
    debugPrint('[layout] JSON parse error: $e');
    debugPrint('[layout] Input (first 300 chars): '
        '${json.substring(0, json.length.clamp(0, 300))}');
    return false;
  }
}
