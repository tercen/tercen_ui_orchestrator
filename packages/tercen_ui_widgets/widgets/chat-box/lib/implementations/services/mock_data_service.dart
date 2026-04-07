import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_session.dart';
import '../../domain/services/data_service.dart';

/// Mock data service for skeleton-window compatibility.
/// Returns pre-built chat sessions with realistic conversation data.
class MockDataService implements DataService {
  @override
  Future<List<ChatSession>> loadData() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();

    return [
      ChatSession(
        id: 'session-1',
        title: 'Workflow setup help',
        createdAt: now.subtract(const Duration(hours: 2)),
        lastMessageAt: now.subtract(const Duration(hours: 1)),
        messages: [
          ChatMessage(
            id: 'msg-1-1',
            role: MessageRole.user,
            content: 'How do I create a new workflow?',
            timestamp: now.subtract(const Duration(hours: 2)),
          ),
          ChatMessage(
            id: 'msg-1-2',
            role: MessageRole.assistant,
            content: 'To create a new workflow, use the **New Workflow** button in the project view.',
            timestamp: now.subtract(const Duration(hours: 1, minutes: 59)),
          ),
        ],
      ),
      ChatSession(
        id: 'session-2',
        title: 'Data import question',
        createdAt: now.subtract(const Duration(days: 1)),
        lastMessageAt: now.subtract(const Duration(days: 1)),
        messages: [
          ChatMessage(
            id: 'msg-2-1',
            role: MessageRole.user,
            content: 'What file formats are supported for import?',
            timestamp: now.subtract(const Duration(days: 1)),
          ),
          ChatMessage(
            id: 'msg-2-2',
            role: MessageRole.assistant,
            content: 'Tercen supports **CSV**, **TSV**, and **Excel** files for data import.',
            timestamp: now.subtract(const Duration(days: 1)),
          ),
        ],
      ),
      ChatSession(
        id: 'session-3',
        title: 'Error troubleshooting',
        createdAt: now.subtract(const Duration(days: 3)),
        lastMessageAt: now.subtract(const Duration(days: 3)),
        messages: [
          ChatMessage(
            id: 'msg-3-1',
            role: MessageRole.user,
            content: 'My step is failing with a timeout error.',
            timestamp: now.subtract(const Duration(days: 3)),
          ),
          ChatMessage(
            id: 'msg-3-2',
            role: MessageRole.assistant,
            content: 'Timeout errors typically occur when the data volume exceeds the step\'s configured limit. Try increasing the timeout in the step settings.',
            timestamp: now.subtract(const Duration(days: 3)),
          ),
        ],
      ),
    ];
  }
}
