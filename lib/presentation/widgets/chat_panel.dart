import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sdui/sdui.dart';

import '../../main.dart';
import '../../services/orchestrator_client.dart';

/// SDUI builder function for the ChatPanel Tier 1 primitive.
/// Registered in main.dart after SduiContext creation.
Widget buildChatPanel(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return const ChatPanel();
}

/// Metadata for the ChatPanel primitive — used by AI for discovery.
const chatPanelMetadata = WidgetMetadata(
  type: 'ChatPanel',
  tier: 1,
  description:
      'Interactive chat panel for conversing with Claude Code. Connects to the orchestrator WebSocket for streaming responses.',
  props: {},
  emittedEvents: ['chat.message.sent'],
  acceptedActions: [],
);

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];
  StreamSubscription<Map<String, dynamic>>? _chatSub;
  bool _isStreaming = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatSub ??=
        OrchestratorClientScope.of(context).chatMessages.listen(_onEvent);
  }

  void _onEvent(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;

    setState(() {
      switch (type) {
        case 'thinking':
          _ensureStreamingBubble();
          break;

        case 'text_delta':
          final bubble = _ensureStreamingBubble();
          bubble.textBuffer.write(msg['text'] as String? ?? '');
          break;

        case 'assistant_message':
          _removeStreamingBubble();
          _messages.add(_ChatMessage(
            role: 'assistant',
            text: msg['text'] as String? ?? '',
          ));
          _isStreaming = false;
          break;

        case 'tool_start':
          _removeStreamingBubble();
          _messages.add(_ChatMessage(
            role: 'tool',
            text: '\u{1F527} ${msg['toolName']}...',
            isStreaming: true,
            toolName: msg['toolName'] as String?,
            toolId: msg['toolId'] as String?,
          ));
          break;

        case 'tool_end':
          final toolId = msg['toolId'] as String?;
          for (int i = _messages.length - 1; i >= 0; i--) {
            if (_messages[i].role == 'tool' && _messages[i].toolId == toolId) {
              final name = _messages[i].toolName ?? '';
              final isError = msg['isError'] == true;
              _messages[i]
                ..textBuffer.clear()
                ..textBuffer.write(isError ? '\u2717 $name' : '\u2713 $name')
                ..isStreaming = false;
              break;
            }
          }
          break;

        case 'error':
          _removeStreamingBubble();
          _messages.add(_ChatMessage(
            role: 'error',
            text: msg['text'] as String? ?? 'Unknown error',
          ));
          _isStreaming = false;
          break;

        case 'done':
          _removeStreamingBubble();
          _isStreaming = false;
          break;

        case 'stream_event':
          return;

        default:
          if (msg.containsKey('role') && msg.containsKey('text')) {
            _messages.add(_ChatMessage(
              role: msg['role'] as String? ?? 'assistant',
              text: msg['text'] as String? ?? '',
            ));
          }
      }
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  _ChatMessage _ensureStreamingBubble() {
    if (_messages.isNotEmpty &&
        _messages.last.role == 'assistant' &&
        _messages.last.isStreaming) {
      return _messages.last;
    }
    final bubble = _ChatMessage(role: 'assistant', isStreaming: true);
    _messages.add(bubble);
    return bubble;
  }

  void _removeStreamingBubble() {
    if (_messages.isNotEmpty &&
        _messages.last.role == 'assistant' &&
        _messages.last.isStreaming) {
      _messages.removeLast();
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || _isStreaming) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _messages.add(_ChatMessage(role: 'assistant', isStreaming: true));
      _isStreaming = true;
    });
    _controller.clear();
    _scrollToBottom();

    OrchestratorClientScope.of(context).sendChat(text);
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1, thickness: 1),
          Expanded(child: _buildMessageList()),
          const Divider(height: 1, thickness: 1),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final client = OrchestratorClientScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.terminal,
              color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 8),
          Text(
            'Claude Code',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          ListenableBuilder(
            listenable: client,
            builder: (context, _) {
              final connected =
                  client.state == WsConnectionState.connected;
              return Icon(
                Icons.circle,
                size: 8,
                color: connected
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.error,
              );
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'Ask Claude to do something...',
          style:
              TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    final isTool = msg.role == 'tool';
    final isError = msg.role == 'error';

    final IconData icon;
    final Color iconColor;

    final colorScheme = Theme.of(context).colorScheme;
    if (isUser) {
      icon = Icons.person;
      iconColor = colorScheme.primary;
    } else if (isTool) {
      icon = Icons.build;
      iconColor = Colors.amber;
    } else if (isError) {
      icon = Icons.error_outline;
      iconColor = colorScheme.error;
    } else {
      icon = Icons.smart_toy;
      iconColor = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.displayText,
                  style: TextStyle(
                    color: isError
                        ? colorScheme.error
                        : (isTool
                            ? Colors.amber.shade200
                            : colorScheme.onSurface),
                    fontSize: 14,
                    fontFamily: isTool ? 'monospace' : null,
                  ),
                ),
                if (msg.isStreaming)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14),
              decoration: InputDecoration(
                hintText: _isStreaming
                    ? 'Claude is thinking...'
                    : 'Message Claude...',
                hintStyle: TextStyle(color: Theme.of(context).hintColor),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              enabled: !_isStreaming,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isStreaming ? null : _sendMessage,
            icon: Icon(
              Icons.send,
              color: _isStreaming
                  ? Theme.of(context).hintColor
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final StringBuffer textBuffer;
  bool isStreaming;
  final String? toolName;
  final String? toolId;

  _ChatMessage({
    required this.role,
    String? text,
    this.isStreaming = false,
    this.toolName,
    this.toolId,
  }) : textBuffer = StringBuffer(text ?? '');

  String get displayText => textBuffer.toString();
}
