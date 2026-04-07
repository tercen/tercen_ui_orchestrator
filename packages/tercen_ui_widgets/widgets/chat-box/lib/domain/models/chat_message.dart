/// A single message in a chat conversation.
class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

/// The role of a chat message sender.
enum MessageRole {
  user,
  assistant,
}
