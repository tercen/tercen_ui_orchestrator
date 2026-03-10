import 'dart:async';

import 'package:flutter/material.dart';

import '../../main.dart';
import '../../services/orchestrator_client.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[];
  StreamSubscription<Map<String, dynamic>>? _chatSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatSub ??=
        OrchestratorClientScope.of(context).chatMessages.listen((msg) {
      setState(() {
        _messages.add(_ChatMessage(
          role: msg['role'] as String? ?? 'assistant',
          text: msg['text'] as String? ?? '',
        ));
      });
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
    });
    _controller.clear();

    // Send to server via WebSocket
    OrchestratorClientScope.of(context).sendChat(text);
  }

  void _triggerWidget() {
    setState(() {
      _messages.add(
        _ChatMessage(role: 'user', text: 'Open project list'),
      );
    });
    OrchestratorClientScope.of(context).sendChat('open project list');
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF252525),
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
          const Icon(Icons.terminal, color: Colors.white54, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Claude Code',
            style: TextStyle(
              color: Colors.white70,
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
                color: connected ? Colors.green : Colors.red,
              );
            },
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _triggerWidget,
            icon: const Icon(Icons.widgets_outlined, size: 16),
            label: const Text('Open Widget'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
              textStyle: const TextStyle(fontSize: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'Ask Claude to do something...',
          style: TextStyle(color: Colors.white24, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isUser ? Icons.person : Icons.smart_toy,
            color: isUser ? Colors.blue : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg.text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
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
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Message Claude...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send, color: Colors.blue),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String text;

  _ChatMessage({required this.role, required this.text});
}
