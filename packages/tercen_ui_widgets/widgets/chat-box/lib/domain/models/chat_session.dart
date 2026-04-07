import 'chat_message.dart';

/// A chat session groups a sequence of messages into a named conversation.
class ChatSession {
  final String id;
  String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  DateTime lastMessageAt;

  ChatSession({
    required this.id,
    required this.title,
    List<ChatMessage>? messages,
    required this.createdAt,
    DateTime? lastMessageAt,
  })  : messages = messages ?? [],
        lastMessageAt = lastMessageAt ?? createdAt;
}
