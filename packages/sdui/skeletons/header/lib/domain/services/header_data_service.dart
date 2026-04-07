import '../models/user_state.dart';

/// Abstract service providing user state and LLM connection status to the header.
abstract class HeaderDataService {
  /// Get the current user's state (display name, identity string, admin flag).
  UserState getUserState();

  /// Get the current LLM connection status.
  bool isLlmConnected();
}
