import 'dart:async';
import 'package:flutter/foundation.dart';

/// Abstract interface for chat backends.
///
/// Both the WebSocket-based [OrchestratorClient] (dev) and the
/// Tercen event service-based [AgentClient] (production) implement
/// this interface, allowing [ChatPanel] to be backend-agnostic.
abstract class ChatBackend extends ChangeNotifier {
  /// Stream of chat messages in the format expected by ChatPanel:
  ///   {type: 'text_delta', text: '...'}
  ///   {type: 'tool_start', toolName: '...', toolId: '...'}
  ///   {type: 'tool_end', toolId: '...', isError: bool}
  ///   {type: 'assistant_message', text: '...'}
  ///   {type: 'thinking'}
  ///   {type: 'error', text: '...'}
  ///   {type: 'done'}
  Stream<Map<String, dynamic>> get chatMessages;

  /// Send a user message to the AI backend.
  void sendChat(String message);

  /// Whether the backend is connected and ready.
  bool get isConnected;

  /// Whether the backend is currently processing a message.
  bool get isProcessing;
}
