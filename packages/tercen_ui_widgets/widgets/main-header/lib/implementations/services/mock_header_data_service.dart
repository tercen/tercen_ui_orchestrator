import '../../domain/models/user_state.dart';
import '../../domain/services/header_data_service.dart';

/// Mock implementation returning hardcoded user data for Phase 2 development.
class MockHeaderDataService implements HeaderDataService {
  @override
  UserState getUserState() {
    return const UserState(
      displayName: 'Martin',
      identityString: 'martin.english',
      isAdmin: true,
    );
  }

  @override
  bool isLlmConnected() {
    return true;
  }
}
