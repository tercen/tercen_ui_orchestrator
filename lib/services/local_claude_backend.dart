import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'chat_backend.dart';

/// Chat backend that calls the local dev proxy's /api/local-chat endpoint,
/// which spawns the `claude` CLI and returns the full response as JSON.
///
/// Uses the browser's native fetch API directly to avoid XHR timeout issues
/// (claude CLI can take 30+ seconds to respond).
///
/// This allows the SDUI ChatBox to use Claude Code directly without
/// a separate Anthropic API key. When an API key IS provided, the app
/// uses [AgentClient] instead (via the Tercen agent operator).
class LocalClaudeBackend extends ChatBackend {
  final String baseUrl;
  bool _processing = false;
  String? _sessionId;

  final _chatMessages = StreamController<Map<String, dynamic>>.broadcast();

  LocalClaudeBackend({required this.baseUrl});

  @override
  Stream<Map<String, dynamic>> get chatMessages => _chatMessages.stream;

  @override
  bool get isConnected => true;

  @override
  bool get isProcessing => _processing;

  @override
  void sendChat(String message) {
    if (_processing) return;
    _processing = true;
    notifyListeners();
    _chatMessages.add({'type': 'thinking'});
    _doSend(message);
  }

  Future<void> _doSend(String message) async {
    try {
      final payload = jsonEncode({
        'message': message,
        if (_sessionId != null) 'sessionId': _sessionId,
      });

      final url = '$baseUrl/api/local-chat';
      debugPrint('[local-claude] POST $url');

      // Use native fetch to avoid XHR timeout issues
      final headers = web.Headers();
      headers.append('Content-Type', 'application/json');
      final init = web.RequestInit(
        method: 'POST',
        headers: headers,
        body: payload.toJS,
      );

      final response = await web.window.fetch(url.toJS, init).toDart;

      if (!response.ok) {
        debugPrint('[local-claude] Error: ${response.status}');
        _chatMessages.add({
          'type': 'error',
          'text': 'Local chat error: ${response.status}',
        });
        _finish();
        return;
      }

      final bodyText = (await response.text().toDart).toDart;
      final result = jsonDecode(bodyText) as Map<String, dynamic>;

      // Check for error
      if (result.containsKey('error')) {
        _chatMessages.add({
          'type': 'error',
          'text': result['error'] as String? ?? 'Unknown error',
        });
        _finish();
        return;
      }

      // Store session ID for conversation continuity
      final sid = result['sessionId'] as String?;
      if (sid != null && sid.isNotEmpty) {
        _sessionId = sid;
        debugPrint('[local-claude] Session: $_sessionId');
      }

      // Replay any tool events
      final events = result['events'] as List? ?? [];
      for (final evt in events) {
        _chatMessages.add(Map<String, dynamic>.from(evt as Map));
      }

      // Deliver the final assistant message
      final text = result['text'] as String? ?? '';
      debugPrint('[local-claude] Response: ${text.length} chars');
      _chatMessages.add({
        'type': 'assistant_message',
        'text': text,
      });

      _finish();
    } catch (e, st) {
      debugPrint('[local-claude] Failed: $e\n$st');
      _chatMessages.add({'type': 'error', 'text': '$e'});
      _finish();
    }
  }

  void _finish() {
    _processing = false;
    _chatMessages.add({'type': 'done'});
    notifyListeners();
  }

  @override
  void dispose() {
    _chatMessages.close();
    super.dispose();
  }
}
