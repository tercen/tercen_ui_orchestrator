import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sdui/sdui.dart';

/// Metadata for the ChatStream scope builder.
const chatStreamMetadata = WidgetMetadata(
  type: 'ChatStream',
  description: 'Bridges the chat backend stream into SDUI scope. '
      'Maintains a message list from streaming events and exposes '
      '{{messages}} (List), {{isStreaming}} (bool), {{connected}} (bool), '
      '{{hasMessages}} (bool) to children. '
      'Listens on sendChannel for send actions and on the TextField '
      'submit event for Enter-to-send.',
  props: {
    'inputId': PropSpec(
        type: 'string',
        description:
            'ID of the TextField to track for input text and submit events'),
    'sendChannel': PropSpec(
        type: 'string',
        defaultValue: 'chat.send',
        description: 'EventBus channel to listen on for send button taps'),
    'clearChannel': PropSpec(
        type: 'string',
        defaultValue: 'chat.inputCleared',
        description:
            'EventBus channel to publish on after sending, to clear the TextField'),
  },
);

/// Scope builder for the ChatStream widget.
Widget buildChatStream(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer) {
  return _ChatStreamWidget(
    key: ValueKey('chatstream-${node.id}'),
    node: node,
    context: ctx,
    childRenderer: childRenderer,
  );
}

class _ChatStreamWidget extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  final SduiChildRenderer childRenderer;

  const _ChatStreamWidget({
    super.key,
    required this.node,
    required this.context,
    required this.childRenderer,
  });

  @override
  State<_ChatStreamWidget> createState() => _ChatStreamWidgetState();
}

class _ChatStreamWidgetState extends State<_ChatStreamWidget> {
  final List<Map<String, dynamic>> _messages = [];
  bool _isStreaming = false;
  bool _connected = false;
  String _currentInputText = '';
  bool _rebuildScheduled = false;

  StreamSubscription<Map<String, dynamic>>? _chatSub;
  StreamSubscription? _sendSub;
  StreamSubscription? _submitSub;
  StreamSubscription? _changeSub;
  StreamSubscription? _newSessionSub;
  StreamSubscription? _systemMsgSub;

  String get _sendChannel =>
      PropConverter.to<String>(widget.node.props['sendChannel']) ?? 'chat.send';

  String get _clearChannel =>
      PropConverter.to<String>(widget.node.props['clearChannel']) ??
      'chat.inputCleared';

  String? get _inputId =>
      PropConverter.to<String>(widget.node.props['inputId']);

  @override
  void initState() {
    super.initState();
    _connectChat();
    _subscribeControls();
  }

  void _connectChat() {
    final provider = widget.context.chatStreamProvider;
    if (provider == null) {
      _connected = false;
      ErrorReporter.instance.report(
        'chatStreamProvider is null — chat backend not available',
        source: 'ChatStream',
        severity: ErrorSeverity.warning,
      );
      return;
    }
    _connected = provider.isConnected();
    _chatSub = provider.messages.listen(_onChatEvent);
  }

  void _subscribeControls() {
    final bus = widget.context.eventBus;

    debugPrint(
        '[ChatStream] subscribing: sendChannel=$_sendChannel inputId=$_inputId');

    // Listen for send button taps
    _sendSub = bus.subscribe(_sendChannel).listen((_) {
      debugPrint('[ChatStream] send button tapped on $_sendChannel');
      if (!mounted) return;
      _sendMessage();
    });

    // Listen for new session button
    _newSessionSub = bus.subscribe('chat.newSession').listen((_) {
      debugPrint('[ChatStream] new session requested');
      if (!mounted) return;
      _resetSession();
    });

    // Listen for system messages (dev notifications)
    _systemMsgSub = bus.subscribe('chat.systemMessage').listen((event) {
      if (!mounted) return;
      final text = (event.data['text'] as String?) ?? '';
      if (text.isEmpty) return;
      _messages.add({
        'role': 'system',
        'text': text,
        'isUser': false,
        'isAssistant': true,
        'isStreaming': false,
      });
      _scheduleRebuild();
    });

    // Listen for TextField input changes and submit
    final inputId = _inputId;
    if (inputId != null && inputId.isNotEmpty) {
      _changeSub = bus.subscribe('input.$inputId.changed').listen((event) {
        _currentInputText = (event.data['value'] as String?) ?? '';
      });
      _submitSub = bus.subscribe('input.$inputId.submitted').listen((event) {
        debugPrint(
            '[ChatStream] TextField submitted: ${event.data['value']}');
        if (!mounted) return;
        final text = (event.data['value'] as String?) ?? '';
        if (text.isNotEmpty) {
          _sendMessage(overrideText: text);
        }
      });
    }
  }

  void _resetSession() {
    final provider = widget.context.chatStreamProvider;
    provider?.resetSession();
    setState(() {
      _messages.clear();
      _isStreaming = false;
    });
  }

  void _sendMessage({String? overrideText}) {
    final text = (overrideText ?? _currentInputText).trim();
    debugPrint(
        '[ChatStream] _sendMessage text="$text" isStreaming=$_isStreaming');
    if (text.isEmpty || _isStreaming) return;

    final provider = widget.context.chatStreamProvider;
    if (provider == null) return;

    setState(() {
      _messages.add(_makeMessage(role: 'user', text: text));
      // Add a "thinking" bubble that shows while waiting for the first response
      _messages.add(_makeMessage(
        role: 'assistant',
        text: 'Thinking...',
        isStreaming: true,
      ));
      _isStreaming = true;
    });

    // Clear the TextField
    widget.context.eventBus.publish(
      _clearChannel,
      EventPayload(type: 'chat.clear', data: {}),
    );
    _currentInputText = '';

    // Send to the backend
    provider.send(text);
  }

  /// Schedule a single setState per frame instead of one per event.
  void _scheduleRebuild() {
    if (_rebuildScheduled || !mounted) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _onChatEvent(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    if (!mounted) return;

    switch (type) {
      case 'thinking':
        _ensureStreamingBubble();
        _scheduleRebuild();
        break;

      case 'text_delta':
        // Mutate in place — batched rebuild via _scheduleRebuild.
        final bubble = _ensureStreamingBubble();
        final delta = msg['text'] as String? ?? '';
        bubble['text'] = (bubble['text'] as String? ?? '') + delta;
        _scheduleRebuild();
        break;

      case 'assistant_message':
        _removeStreamingBubble();
        _messages.add(_makeMessage(
          role: 'assistant',
          text: msg['text'] as String? ?? '',
        ));
        _isStreaming = false;
        _scheduleRebuild();
        break;

      case 'tool_start':
        _removeStreamingBubble();
        _messages.add(_makeMessage(
          role: 'tool',
          text: '${msg['toolName']}...',
          isStreaming: true,
          toolName: msg['toolName'] as String?,
          toolId: msg['toolId'] as String?,
        ));
        _scheduleRebuild();
        break;

      case 'tool_end':
        final toolId = msg['toolId'] as String?;
        for (int i = _messages.length - 1; i >= 0; i--) {
          if (_messages[i]['role'] == 'tool' &&
              _messages[i]['toolId'] == toolId) {
            final name = _messages[i]['toolName'] ?? '';
            final isError = msg['isError'] == true;
            _messages[i]['text'] =
                isError ? '\u2717 $name' : '\u2713 $name';
            _messages[i]['isStreaming'] = false;
            break;
          }
        }
        // Add a "Thinking..." bubble to show the agent is still working
        if (_isStreaming) {
          _messages.add(_makeMessage(
            role: 'assistant',
            text: 'Thinking...',
            isStreaming: true,
          ));
        }
        _scheduleRebuild();
        break;

      case 'error':
        _removeStreamingBubble();
        _messages.add(_makeMessage(
          role: 'error',
          text: msg['text'] as String? ?? 'Unknown error',
        ));
        _isStreaming = false;
        _scheduleRebuild();
        break;

      case 'done':
        _removeStreamingBubble();
        _isStreaming = false;
        _scheduleRebuild();
        break;

      case 'stream_event':
        break;

      default:
        if (msg.containsKey('role') && msg.containsKey('text')) {
          _messages.add(_makeMessage(
            role: msg['role'] as String? ?? 'assistant',
            text: msg['text'] as String? ?? '',
          ));
          _scheduleRebuild();
        }
    }
  }

  Map<String, dynamic> _makeMessage({
    required String role,
    String text = '',
    bool isStreaming = false,
    String? toolName,
    String? toolId,
  }) {
    return {
      'role': role,
      'text': text,
      'isStreaming': isStreaming,
      'isUser': role == 'user',
      'isAssistant': role == 'assistant',
      'isTool': role == 'tool',
      'isError': role == 'error',
      if (toolName != null) 'toolName': toolName,
      if (toolId != null) 'toolId': toolId,
    };
  }

  Map<String, dynamic> _ensureStreamingBubble() {
    if (_messages.isNotEmpty &&
        _messages.last['role'] == 'assistant' &&
        _messages.last['isStreaming'] == true) {
      // Clear the "Thinking..." placeholder when real content arrives
      if (_messages.last['text'] == 'Thinking...') {
        _messages.last['text'] = '';
      }
      return _messages.last;
    }
    final bubble = _makeMessage(role: 'assistant', isStreaming: true);
    _messages.add(bubble);
    return bubble;
  }

  void _removeStreamingBubble() {
    if (_messages.isNotEmpty &&
        _messages.last['role'] == 'assistant' &&
        _messages.last['isStreaming'] == true) {
      _messages.removeLast();
    }
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _sendSub?.cancel();
    _submitSub?.cancel();
    _changeSub?.cancel();
    _newSessionSub?.cancel();
    _systemMsgSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Refresh connection status on each build (provider may reconnect).
    final provider = widget.context.chatStreamProvider;
    if (provider != null) {
      _connected = provider.isConnected();
    }

    final scope = <String, dynamic>{
      'messages': _messages,
      'isStreaming': _isStreaming,
      'isThinking': _isStreaming,
      'connected': _connected,
      'hasMessages': _messages.isNotEmpty,
    };

    final children = widget.node.children;
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) {
      return widget.childRenderer(children.first, scope);
    }
    // Stack children for mutually-exclusive Conditionals
    return Stack(
      fit: StackFit.expand,
      children:
          children.map((c) => widget.childRenderer(c, scope)).toList(),
    );
  }
}
