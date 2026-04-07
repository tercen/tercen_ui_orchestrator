import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/focus_context.dart';

/// Abstract chat service interface.
///
/// Phase 2: Mock implementation returns canned responses.
/// Phase 3: Real implementation communicates with the LLM API.
abstract class ChatService {
  /// Send a message to the LLM and receive the assistant's response.
  Future<ChatMessage> sendMessage({
    required String sessionId,
    required String messageText,
    FocusContext? focusContext,
  });

  /// Load a session by ID with all its messages.
  Future<ChatSession> loadSession(String sessionId);

  /// List all sessions, ordered by most recent activity.
  Future<List<ChatSession>> listSessions();

  /// Create a new empty session.
  Future<ChatSession> createSession();
}
