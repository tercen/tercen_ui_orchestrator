import 'dart:async';

import 'package:flutter/material.dart';
import '../../di/service_locator.dart';
import '../../domain/models/content_state.dart';
import '../../domain/models/home_models.dart';
import '../../domain/models/window_identity.dart';
import '../../domain/services/event_bus.dart';
import '../../domain/services/event_payload.dart';
import '../../domain/services/home_data_service.dart';
import '../../domain/services/window_channels.dart';

/// Central state provider for the Home Panel window.
///
/// Manages: user info, recent projects, activity, featured apps, search,
/// and EventBus communication.
class HomePanelProvider extends ChangeNotifier {
  final HomeDataService _dataService = serviceLocator<HomeDataService>();
  final EventBus _eventBus = serviceLocator<EventBus>();

  final WindowIdentity identity;
  final String windowId;

  // -- Content state --
  ContentState _contentState = ContentState.loading;
  ContentState get contentState => _contentState;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // -- User --
  HomeUser? _user;
  HomeUser? get user => _user;

  // -- Recent projects --
  List<RecentProject> _recentProjects = [];
  List<RecentProject> get recentProjects =>
      _isSearching ? _searchResults : _recentProjects;

  // -- Search --
  bool _isSearching = false;
  bool get isSearching => _isSearching;
  String _searchQuery = '';
  String get searchQuery => _searchQuery;
  List<RecentProject> _searchResults = [];

  // -- Activity --
  bool _activityLoading = true;
  bool get activityLoading => _activityLoading;
  List<ActivityEvent> _activities = [];
  List<ActivityEvent> get activities => _activities;

  // -- Featured apps --
  bool _appsLoading = true;
  bool get appsLoading => _appsLoading;
  List<FeaturedApp> _featuredApps = [];
  List<FeaturedApp> get featuredApps => _featuredApps;
  bool _hasMoreApps = true;
  bool get hasMoreApps => _hasMoreApps;
  bool _isLoadingMoreApps = false;
  bool get isLoadingMoreApps => _isLoadingMoreApps;

  // -- Help links --
  List<HelpLink> get helpLinks => _dataService.getHelpLinks();

  StreamSubscription<EventPayload>? _commandSubscription;

  HomePanelProvider({
    required this.identity,
    required this.windowId,
  }) {
    _commandSubscription = _eventBus
        .subscribe(WindowChannels.commandChannel(windowId))
        .listen(_handleCommand);
    _initialize();
  }

  // -- Greeting --

  String get greeting {
    final hour = DateTime.now().hour;
    final name = _user?.displayName ?? '';
    if (hour >= 5 && hour < 12) return 'Good morning, $name';
    if (hour >= 12 && hour < 17) return 'Good afternoon, $name';
    return 'Good evening, $name';
  }

  // -- Initialization --

  Future<void> _initialize() async {
    try {
      _user = await _dataService.getCurrentUser();
      _recentProjects =
          await _dataService.getRecentProjects(_user!.userId);
      _contentState = ContentState.active;
      notifyListeners();

      // Load secondary data independently
      _loadActivity();
      _loadApps();
    } catch (e) {
      _errorMessage = e.toString();
      _contentState = ContentState.error;
      notifyListeners();
    }
  }

  Future<void> _loadActivity() async {
    _activityLoading = true;
    notifyListeners();
    try {
      _activities =
          await _dataService.getRecentActivity(_user?.teams ?? []);
    } catch (e) {
      debugPrint('Error loading activity: $e');
    }
    _activityLoading = false;
    notifyListeners();
  }

  Future<void> _loadApps() async {
    _appsLoading = true;
    notifyListeners();
    try {
      _featuredApps = await _dataService.getFeaturedApps(offset: 0, limit: 6);
      _hasMoreApps = _featuredApps.length >= 6;
    } catch (e) {
      debugPrint('Error loading apps: $e');
    }
    _appsLoading = false;
    notifyListeners();
  }

  // -- Refresh --

  Future<void> refresh() async {
    _contentState = ContentState.loading;
    _errorMessage = null;
    _isSearching = false;
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
    await _initialize();
  }

  Future<void> retry() async {
    await refresh();
  }

  // -- Search --

  Future<void> searchProjects(String query) async {
    if (query.isEmpty) {
      clearSearch();
      return;
    }
    _isSearching = true;
    _searchQuery = query;
    notifyListeners();

    try {
      _searchResults = await _dataService.searchProjects(query);
    } catch (e) {
      debugPrint('Error searching projects: $e');
      _searchResults = [];
    }

    // Emit searchProjects intent to orchestrator
    _eventBus.publish(
      WindowChannels.windowIntent,
      EventPayload(
        type: 'searchProjects',
        sourceWidgetId: windowId,
        data: {
          'windowId': windowId,
          'query': query,
        },
      ),
    );
    debugPrint('[EventBus] searchProjects: $query');

    notifyListeners();
  }

  void clearSearch() {
    _isSearching = false;
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }

  // -- Infinite scroll for apps --

  Future<void> loadMoreApps() async {
    if (!_hasMoreApps || _isLoadingMoreApps) return;

    _isLoadingMoreApps = true;
    notifyListeners();

    try {
      final moreApps = await _dataService.getFeaturedApps(
        offset: _featuredApps.length,
        limit: 6,
      );
      _featuredApps.addAll(moreApps);
      _hasMoreApps = moreApps.length >= 6;
    } catch (e) {
      debugPrint('Error loading more apps: $e');
    }

    _isLoadingMoreApps = false;
    notifyListeners();
  }

  // -- EventBus actions --

  void openProject(RecentProject project) {
    debugPrint('[EventBus] openResource: project ${project.projectId}');
    _eventBus.publish(
      WindowChannels.windowIntent,
      EventPayload(
        type: 'openResource',
        sourceWidgetId: windowId,
        data: {
          'windowId': windowId,
          'resourceType': 'project',
          'resourceId': project.projectId,
        },
      ),
    );
  }

  void openActivityResource(ActivityEvent activity) {
    debugPrint(
        '[EventBus] openResource: ${activity.resourceType} ${activity.resourceId}');
    _eventBus.publish(
      WindowChannels.windowIntent,
      EventPayload(
        type: 'openResource',
        sourceWidgetId: windowId,
        data: {
          'windowId': windowId,
          'resourceType': activity.resourceType,
          'resourceId': activity.resourceId,
        },
      ),
    );
  }

  void createProject({
    required String name,
    String description = '',
    required String teamId,
    bool isPublic = false,
    String? gitUrl,
    String? gitBranch,
    String? gitCommit,
    String? gitTag,
    String? gitToken,
  }) {
    final isGit = gitUrl != null && gitUrl.isNotEmpty;
    final type = isGit ? 'cloneProjectFromGit' : 'createProject';
    debugPrint('[EventBus] $type: name=$name, team=$teamId, public=$isPublic'
        '${isGit ? ", git=$gitUrl, branch=$gitBranch" : ""}');
    _eventBus.publish(
      WindowChannels.windowIntent,
      EventPayload(
        type: type,
        sourceWidgetId: windowId,
        data: {
          'windowId': windowId,
          'name': name,
          'description': description,
          'teamId': teamId,
          'isPublic': isPublic,
          if (isGit) ...{
            'gitUrl': gitUrl,
            'gitBranch': gitBranch ?? 'main',
            if (gitCommit != null && gitCommit.isNotEmpty)
              'gitCommit': gitCommit,
            if (gitTag != null && gitTag.isNotEmpty)
              'gitTag': gitTag,
            if (gitToken != null && gitToken.isNotEmpty)
              'gitToken': gitToken,
          },
        },
      ),
    );
  }

  void openTeamManagement() {
    debugPrint('[EventBus] openTeamManagement requested');
    _eventBus.publish(
      WindowChannels.windowIntent,
      EventPayload(
        type: 'openTeamManagement',
        sourceWidgetId: windowId,
        data: {'windowId': windowId},
      ),
    );
  }

  void openAuditTrail() {
    debugPrint('[EventBus] openAuditTrail requested');
    _eventBus.publish(
      WindowChannels.windowIntent,
      EventPayload(
        type: 'openAuditTrail',
        sourceWidgetId: windowId,
        data: {'windowId': windowId},
      ),
    );
  }

  void openApp(FeaturedApp app) {
    debugPrint('[EventBus] openApp: ${app.appId} ${app.name}');
    _eventBus.publish(
      WindowChannels.windowIntent,
      EventPayload(
        type: 'openApp',
        sourceWidgetId: windowId,
        data: {
          'windowId': windowId,
          'appId': app.appId,
          'appName': app.name,
        },
      ),
    );
  }

  // -- Inbound commands --

  void _handleCommand(EventPayload payload) {
    switch (payload.type) {
      case 'focus':
      case 'blur':
        // Standard focus handling -- no-op for mock
        break;
    }
  }

  @override
  void dispose() {
    _commandSubscription?.cancel();
    super.dispose();
  }
}
