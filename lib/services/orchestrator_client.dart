import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:sdui/sdui.dart';

import 'chat_backend.dart';

/// Connection state for the orchestrator client.
enum WsConnectionState { disconnected, connecting, connected }

/// WebSocket-based chat backend for development (Claude Code CLI).
///
/// Connects to the orchestrator backend via two WebSocket channels:
/// - /ws/chat: send user messages, receive assistant responses
/// - /ws/ui: receive layout operations from the server
///
/// Handles connection failures gracefully with automatic reconnection.
class OrchestratorClient extends ChatBackend {
  final String baseUrl;
  final EventBus eventBus;
  WebSocketChannel? _chatChannel;
  WebSocketChannel? _uiChannel;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  static const _maxReconnectDelay = Duration(seconds: 30);

  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;

  StreamSubscription? _selectionSub;
  final _chatMessages = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get chatMessages => _chatMessages.stream;

  @override
  bool get isConnected => _state == WsConnectionState.connected;

  @override
  bool get isProcessing => false; // WebSocket backend doesn't track this

  OrchestratorClient({
    required this.baseUrl,
    required this.eventBus,
  });

  Future<void> connect() async {
    if (_disposed) return;
    _state = WsConnectionState.connecting;
    notifyListeners();

    try {
      _chatChannel = WebSocketChannel.connect(Uri.parse('$baseUrl/ws/chat'));
      _uiChannel = WebSocketChannel.connect(Uri.parse('$baseUrl/ws/ui'));

      // Wait for both connections to be ready.
      await Future.wait([
        _chatChannel!.ready,
        _uiChannel!.ready,
      ]);

      _state = WsConnectionState.connected;
      _reconnectAttempts = 0;
      notifyListeners();

      // Chat responses → stream
      _chatChannel!.stream.listen(
        (data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _chatMessages.add(json);
        },
        onError: (e, st) {
          ErrorReporter.instance.report(e,
            stackTrace: st is StackTrace ? st : null,
            source: 'ws.chat',
          );
          _onDisconnect();
        },
        onDone: _onDisconnect,
      );

      // UI commands → EventBus
      _uiChannel!.stream.listen(
        (data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          eventBus.publish(
            'system.layout.op',
            EventPayload(type: 'layout.op', data: json),
          );
        },
        onError: (e, st) {
          ErrorReporter.instance.report(e,
            stackTrace: st is StackTrace ? st : null,
            source: 'ws.ui',
          );
          _onDisconnect();
        },
        onDone: _onDisconnect,
      );

      // Forward selection events from EventBus → server via /ws/ui
      _selectionSub?.cancel();
      _selectionSub = eventBus.subscribePrefix('system.selection.').listen((payload) {
        sendUiEvent({
          'type': 'selection',
          'channel': payload.data['_channel'] ?? 'unknown',
          'sourceWidgetId': payload.sourceWidgetId,
          'data': payload.data,
        });
      });
    } catch (e, st) {
      ErrorReporter.instance.report(e,
        stackTrace: st,
        source: 'ws.connect',
        context: 'baseUrl: $baseUrl',
      );
      _closeChannels();
      _state = WsConnectionState.disconnected;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _onDisconnect() {
    if (_disposed || _state == WsConnectionState.disconnected) return;
    _closeChannels();
    _state = WsConnectionState.disconnected;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    final delay = Duration(
      seconds: min(pow(2, _reconnectAttempts).toInt(), _maxReconnectDelay.inSeconds),
    );
    _reconnectAttempts++;
    debugPrint('Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    _reconnectTimer = Timer(delay, connect);
  }

  @override
  void sendChat(String message) {
    _chatChannel?.sink.add(message);
  }

  void sendUiEvent(Map<String, dynamic> event) {
    _uiChannel?.sink.add(jsonEncode(event));
  }

  void _closeChannels() {
    _chatChannel?.sink.close();
    _uiChannel?.sink.close();
    _chatChannel = null;
    _uiChannel = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _selectionSub?.cancel();
    _chatMessages.close();
    _closeChannels();
    super.dispose();
  }
}
