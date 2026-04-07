import '../models/audit_event.dart';
import '../models/audit_scope.dart';

/// Abstract service for fetching audit events.
///
/// Phase 2: MockAuditDataService returns static data.
/// Phase 3: RealAuditDataService queries ActivityService + TaskService.
abstract class AuditDataService {
  /// Fetch a page of events for the given scope.
  /// [offset] is the number of events already loaded.
  /// [limit] is the page size.
  /// Returns a list of events and whether more are available.
  Future<AuditPageResult> fetchEvents({
    required AuditScope scope,
    int offset = 0,
    int limit = 50,
  });

  /// Get available scopes for the scope selector.
  Future<List<AuditScope>> getAvailableScopes();
}

/// Result of a paginated event fetch.
class AuditPageResult {
  final List<AuditEvent> events;
  final bool hasMore;

  const AuditPageResult({
    required this.events,
    this.hasMore = false,
  });
}
