import '../models/home_models.dart';

/// Abstract data service for the Home Panel.
///
/// Phase 2: implemented by MockHomeDataService.
/// Phase 3: implemented by TercenHomeDataService.
abstract class HomeDataService {
  /// Get the current user profile.
  Future<HomeUser> getCurrentUser();

  /// Get recent projects for the user.
  Future<List<RecentProject>> getRecentProjects(String userId);

  /// Search projects by query string.
  Future<List<RecentProject>> searchProjects(String query, {int limit = 10});

  /// Get recent activity across user's teams.
  Future<List<ActivityEvent>> getRecentActivity(List<String> teamIds);

  /// Get featured apps with pagination.
  Future<List<FeaturedApp>> getFeaturedApps({int offset = 0, int limit = 6});

  /// Get help and documentation links.
  List<HelpLink> getHelpLinks();
}
