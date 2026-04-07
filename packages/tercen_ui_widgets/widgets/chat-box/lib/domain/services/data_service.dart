import '../models/chat_session.dart';

/// Abstract data service for the Chat Box.
/// Phase 2: Mock implementation returns placeholder session data.
/// Phase 3: Real implementation queries Tercen API.
abstract class DataService {
  /// Load all available chat sessions.
  Future<List<ChatSession>> loadData();
}
