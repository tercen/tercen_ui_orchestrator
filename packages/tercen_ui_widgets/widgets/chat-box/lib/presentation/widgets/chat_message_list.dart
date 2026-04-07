import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/chat_provider.dart';
import 'chat_message_bubble.dart';
import 'thinking_indicator.dart';

/// Vertically scrollable message list with auto-scroll behaviour.
///
/// Auto-scrolls to bottom when new messages arrive, unless the user
/// has manually scrolled up to review earlier messages.
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({super.key});

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final ScrollController _scrollController = ScrollController();
  bool _userScrolledUp = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    // Consider "at bottom" if within 50px of the end
    _userScrolledUp = (maxScroll - currentScroll) > 50;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final messages = provider.messages;
    final isSending = provider.isSending;

    // Auto-scroll when new messages arrive
    if (messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      if (!_userScrolledUp) {
        _scrollToBottom();
      }
    }

    // Also scroll when sending indicator appears/disappears
    if (isSending && !_userScrolledUp) {
      _scrollToBottom();
    }

    if (messages.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: messages.length + (isSending ? 1 : 0),
      itemBuilder: (context, index) {
        // Thinking indicator at the end
        if (index == messages.length && isSending) {
          return const ThinkingIndicator();
        }

        final message = messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ChatMessageBubble(message: message, messageIndex: index),
        );
      },
    );
  }
}
