/// User profile for the Home Panel.
class HomeUser {
  final String userId;
  final String displayName;
  final List<String> teams;

  const HomeUser({
    required this.userId,
    required this.displayName,
    required this.teams,
  });
}

/// A recent project entry.
class RecentProject {
  final String projectId;
  final String name;
  final String owner;
  final String lastModified;

  const RecentProject({
    required this.projectId,
    required this.name,
    required this.owner,
    required this.lastModified,
  });
}

/// An activity event entry.
class ActivityEvent {
  final String id;
  final String type;
  final String objectName;
  final String resourceType;
  final String resourceId;
  final String date;
  final String team;
  final String user;
  final String projectName;
  final String projectId;

  const ActivityEvent({
    required this.id,
    required this.type,
    required this.objectName,
    required this.resourceType,
    required this.resourceId,
    required this.date,
    required this.team,
    required this.user,
    required this.projectName,
    required this.projectId,
  });
}

/// A featured app entry.
class FeaturedApp {
  final String appId;
  final String name;
  final String description;

  const FeaturedApp({
    required this.appId,
    required this.name,
    required this.description,
  });
}

/// A help/documentation link.
class HelpLink {
  final String label;
  final String url;

  const HelpLink({
    required this.label,
    required this.url,
  });
}
