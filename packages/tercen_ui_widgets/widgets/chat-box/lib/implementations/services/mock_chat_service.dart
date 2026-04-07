import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_session.dart';
import '../../domain/models/focus_context.dart';
import '../../domain/services/chat_service.dart';
import 'mock_data.dart';

/// Mock chat service that returns canned conversations.
///
/// Responses are returned after a brief simulated delay
/// to exercise the sending indicator state.
class MockChatService implements ChatService {
  final List<ChatSession> _sessions = [];
  final Map<String, List<String>> _cannedResponses = {};
  final Map<String, int> _responseIndex = {};

  MockChatService() {
    _sessions.addAll(MockData.buildSessions());
    _buildCannedResponses();
  }

  void _buildCannedResponses() {
    // Session 1 follow-up responses
    _cannedResponses['session-1'] = [
      '''Great question! To add a **UMAP dimensionality reduction** step after clustering, you would:

1. Select the PhenoGraph output step
2. Add a new DataStep with the UMAP operator

```yaml
step:
  type: DataStep
  operator: UMAP
  parameters:
    n_neighbors: 15
    min_dist: 0.1
    metric: euclidean
  input:
    - source: PhenoGraph.clusters
```

The UMAP step will automatically inherit the clustering assignments as metadata.''',
    ];

    // Session 2 follow-up responses
    _cannedResponses['session-2'] = [
      '''The column mapping looks correct. Here is a summary of your import:

| Status | Count |
|--------|-------|
| Mapped | 12 |
| Skipped | 2 |
| Errors | 0 |

All channels are now available in the data table. You can verify by opening the **Data Viewer** and checking the column headers.''',
    ];

    // Session 3 follow-up responses
    _cannedResponses['session-3'] = [
      '''Glad to hear it is working now! A few tips to prevent this in the future:

- Always check the **operator version** matches your data format
- Use the `--validate` flag when running batch operations
- Monitor the **Audit Trail** (Window 7) for early warning signs

Let me know if you need anything else.''',
    ];
  }

  @override
  Future<ChatMessage> sendMessage({
    required String sessionId,
    required String messageText,
    FocusContext? focusContext,
  }) async {
    // Simulate LLM response delay (10s for mock to show thinking animation)
    await Future.delayed(const Duration(seconds: 10));

    // Pick a canned response or generate a default one
    String responseText;
    final responses = _cannedResponses[sessionId];
    final idx = _responseIndex[sessionId] ?? 0;

    if (responses != null && idx < responses.length) {
      responseText = responses[idx];
      _responseIndex[sessionId] = idx + 1;
    } else {
      responseText =
          'I understand you are asking about "$messageText". '
          'This is a mock response. In production, this would be a real LLM reply '
          'with context from the **${focusContext?.nodeName ?? 'current view'}**.';
    }

    return ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.assistant,
      content: responseText,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<ChatSession> loadSession(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => throw Exception('Session not found: $sessionId'),
    );
  }

  @override
  Future<List<ChatSession>> listSessions() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final sorted = List<ChatSession>.from(_sessions)
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return sorted;
  }

  @override
  Future<ChatSession> createSession() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final session = ChatSession(
      id: 'session-${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Chat',
      createdAt: DateTime.now(),
    );
    _sessions.add(session);
    return session;
  }
}
