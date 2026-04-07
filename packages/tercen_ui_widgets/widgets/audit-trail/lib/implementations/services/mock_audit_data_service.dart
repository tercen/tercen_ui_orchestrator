import '../../domain/models/audit_event.dart';
import '../../domain/models/audit_scope.dart';
import '../../domain/services/audit_data_service.dart';

/// Mock implementation with realistic audit event data.
///
/// Data is based on real Activity records from stage.tercen.com.
/// All mock data is contained in this single file for easy Phase 3 replacement.
class MockAuditDataService implements AuditDataService {
  static final List<AuditScope> _scopes = [
    const AuditScope(
      scopeType: ScopeType.project,
      scopeId: 'proj-std-op-test',
      scopeLabel: 'Standard Operator Test Workflow',
    ),
    const AuditScope(
      scopeType: ScopeType.user,
      scopeId: 'martin.english',
      scopeLabel: 'martin.english',
    ),
    const AuditScope(
      scopeType: ScopeType.team,
      scopeId: 'Team10Dec2025',
      scopeLabel: 'Team10Dec2025',
    ),
  ];

  static final List<AuditEvent> _allEvents = _buildMockEvents();

  @override
  Future<List<AuditScope>> getAvailableScopes() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(_scopes);
  }

  @override
  Future<AuditPageResult> fetchEvents({
    required AuditScope scope,
    int offset = 0,
    int limit = 50,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    // Filter events by scope
    final filtered = _allEvents.where((e) {
      switch (scope.scopeType) {
        case ScopeType.user:
          return e.userId == scope.scopeId;
        case ScopeType.team:
          return e.teamId == scope.scopeId;
        case ScopeType.project:
          return e.projectId == scope.scopeId;
      }
    }).toList();

    // Sort newest first
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final end = (offset + limit).clamp(0, filtered.length);
    final page = filtered.sublist(offset.clamp(0, filtered.length), end);
    final hasMore = end < filtered.length;

    return AuditPageResult(events: page, hasMore: hasMore);
  }

  static List<AuditEvent> _buildMockEvents() {
    final events = <AuditEvent>[];
    var idx = 0;

    // --- Activity events (create/update/delete) ---

    // Project creates
    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 3, 4, 12, 9, 14),
      eventType: 'create',
      objectKind: 'Project',
      userId: 'admin',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'proj-std-op-test',
      targetName: 'Standard Operator Test Workflow',
      details: {
        'id': 'proj-std-op-test-abc123def456',
        'name': 'Standard Operator Test Workflow',
      },
    ));

    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 2, 15, 9, 30, 0),
      eventType: 'create',
      objectKind: 'Project',
      userId: 'martin.english',
      teamId: 'MartinLibrary',
      projectId: 'proj-immuno-v3',
      projectName: 'immunophenotyping_v3_webapp_operator',
      targetId: 'proj-immuno-v3',
      targetName: 'immunophenotyping_v3_webapp_operator',
      details: {
        'id': 'proj-immuno-v3-789ghi012jkl',
        'name': 'immunophenotyping_v3_webapp_operator',
      },
    ));

    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 1, 20, 15, 45, 22),
      eventType: 'create',
      objectKind: 'Project',
      userId: 'admin',
      teamId: 'TestTeam10Dec2025',
      projectId: 'proj-project1',
      projectName: 'Project1',
      targetId: 'proj-project1',
      targetName: 'Project1',
      details: {
        'id': 'proj-project1-345mno678pqr',
        'name': 'Project1',
      },
    ));

    // Workflow creates
    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 3, 4, 14, 20, 24),
      eventType: 'create',
      objectKind: 'Workflow',
      userId: 'admin',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'wf-crabs-001',
      targetName: 'Crabs Workflow',
      details: {
        'id': 'ec1e482ae7f2fdc0a1580c5e32215049',
        'name': 'Crabs Workflow',
      },
    ));

    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 3, 4, 14, 20, 30),
      eventType: 'create',
      objectKind: 'Workflow',
      userId: 'admin',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'wf-analysis-002',
      targetName: 'Analysis Pipeline',
      details: {
        'id': 'wf-analysis-002-abc123',
        'name': 'Analysis Pipeline',
      },
    ));

    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 2, 15, 10, 0, 0),
      eventType: 'create',
      objectKind: 'Workflow',
      userId: 'martin.english',
      teamId: 'MartinLibrary',
      projectId: 'proj-immuno-v3',
      projectName: 'immunophenotyping_v3_webapp_operator',
      targetId: 'wf-flow-immuno-001',
      targetName: 'Flow Immunophenotyping - PhenoGraph',
      details: {
        'id': 'wf-flow-immuno-001-xyz789',
        'name': 'Flow Immunophenotyping - PhenoGraph',
      },
    ));

    // Workflow updates
    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 2, 26, 12, 57, 0),
      eventType: 'update',
      objectKind: 'Workflow',
      userId: 'faris.naji',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'wf-crabs-001',
      targetName: 'Crabs Workflow',
      details: {
        'id': 'ec1e482ae7f2fdc0a1580c5e32215049',
        'name': 'Crabs Workflow',
      },
    ));

    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 2, 26, 12, 56, 0),
      eventType: 'update',
      objectKind: 'Workflow',
      userId: 'faris.naji',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'wf-analysis-002',
      targetName: 'Analysis Pipeline',
      details: {
        'id': 'wf-analysis-002-abc123',
        'name': 'Analysis Pipeline',
      },
    ));

    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 3, 10, 8, 15, 0),
      eventType: 'update',
      objectKind: 'Workflow',
      userId: 'martin.english',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'wf-crabs-001',
      targetName: 'Crabs Workflow',
      details: {
        'id': 'ec1e482ae7f2fdc0a1580c5e32215049',
        'name': 'Crabs Workflow',
      },
    ));

    // TableSchema creates
    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 3, 4, 14, 20, 20),
      eventType: 'create',
      objectKind: 'TableSchema',
      userId: 'admin',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'ts-crabs-data-001',
      targetName: 'Crabs Data',
      details: {
        'id': 'ts-crabs-data-001-abc123',
        'name': 'Crabs Data',
      },
    ));

    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 2, 20, 11, 0, 0),
      eventType: 'create',
      objectKind: 'TableSchema',
      userId: 'martin.english',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'ts-kinase-data-002',
      targetName: 'raw_kinase_data',
      details: {
        'id': 'ts-kinase-data-002-def456',
        'name': 'raw_kinase_data',
      },
    ));

    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 3, 12, 16, 30, 0),
      eventType: 'create',
      objectKind: 'TableSchema',
      userId: 'admin',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'ts-results-003',
      targetName: 'analysis_results_v2',
      details: {
        'id': 'ts-results-003-ghi789',
        'name': 'analysis_results_v2',
      },
    ));

    // FileDocument creates
    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 3, 5, 9, 0, 0),
      eventType: 'create',
      objectKind: 'FileDocument',
      userId: 'martin.english',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'fd-report-001',
      targetName: 'experiment_report.md',
      details: {
        'id': 'fd-report-001-jkl012',
        'name': 'experiment_report.md',
      },
    ));

    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 3, 6, 14, 22, 0),
      eventType: 'create',
      objectKind: 'FileDocument',
      userId: 'admin',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'fd-config-002',
      targetName: 'pipeline_config.json',
      details: {
        'id': 'fd-config-002-mno345',
        'name': 'pipeline_config.json',
      },
    ));

    // FileDocument delete
    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 3, 15, 10, 30, 0),
      eventType: 'delete',
      objectKind: 'FileDocument',
      userId: 'admin',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'fd-old-draft-003',
      targetName: 'old_draft_report.md',
      details: {
        'id': 'fd-old-draft-003-pqr678',
        'name': 'old_draft_report.md',
      },
    ));

    // FolderDocument creates
    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 3, 3, 16, 0, 0),
      eventType: 'create',
      objectKind: 'FolderDocument',
      userId: 'admin',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'fld-results-001',
      targetName: 'Results',
      details: {
        'id': 'fld-results-001-stu901',
        'name': 'Results',
      },
    ));

    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 3, 3, 16, 5, 0),
      eventType: 'create',
      objectKind: 'FolderDocument',
      userId: 'admin',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'fld-data-002',
      targetName: 'Data',
      details: {
        'id': 'fld-data-002-vwx234',
        'name': 'Data',
      },
    ));

    // WebAppOperator create
    events.add(AuditEvent(
      id: 'act-${++idx}',
      source: EventSource.activity,
      timestamp: DateTime(2026, 3, 8, 11, 0, 0),
      eventType: 'create',
      objectKind: 'WebAppOperator',
      userId: 'martin.english',
      teamId: 'MartinLibrary',
      projectId: 'proj-immuno-v3',
      projectName: 'immunophenotyping_v3_webapp_operator',
      targetId: 'wao-immuno-001',
      targetName: 'Immunophenotyping Viewer',
      details: {
        'id': 'wao-immuno-001-yza567',
        'name': 'Immunophenotyping Viewer',
      },
    ));

    // --- Task events (run/complete/fail/cancel) ---

    // Task completions
    events.add(AuditEvent(
      id: 'task-${++idx}',
      source: EventSource.task,
      timestamp: DateTime(2026, 3, 10, 9, 0, 0),
      eventType: 'run',
      objectKind: 'Task',
      userId: 'admin',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'step-mean-001',
      targetName: 'Mean Operator',
      details: {
        'state': 'RunningState',
        'createdDate': '2026-03-10T08:59:50Z',
        'runDate': '2026-03-10T09:00:00Z',
      },
    ));

    events.add(AuditEvent(
      id: 'task-${++idx}',
      source: EventSource.task,
      timestamp: DateTime(2026, 3, 10, 9, 2, 34),
      eventType: 'complete',
      objectKind: 'Task',
      userId: 'admin',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'step-mean-001',
      targetName: 'Mean Operator',
      details: {
        'state': 'DoneState',
        'createdDate': '2026-03-10T08:59:50Z',
        'runDate': '2026-03-10T09:00:00Z',
        'completedDate': '2026-03-10T09:02:34Z',
        'duration': '154.0',
      },
    ));

    events.add(AuditEvent(
      id: 'task-${++idx}',
      source: EventSource.task,
      timestamp: DateTime(2026, 3, 11, 14, 15, 0),
      eventType: 'run',
      objectKind: 'Task',
      userId: 'faris.naji',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'step-pca-002',
      targetName: 'PCA Operator',
      details: {
        'state': 'RunningState',
        'createdDate': '2026-03-11T14:14:50Z',
        'runDate': '2026-03-11T14:15:00Z',
      },
    ));

    events.add(AuditEvent(
      id: 'task-${++idx}',
      source: EventSource.task,
      timestamp: DateTime(2026, 3, 11, 14, 18, 12),
      eventType: 'complete',
      objectKind: 'Task',
      userId: 'faris.naji',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'step-pca-002',
      targetName: 'PCA Operator',
      details: {
        'state': 'DoneState',
        'createdDate': '2026-03-11T14:14:50Z',
        'runDate': '2026-03-11T14:15:00Z',
        'completedDate': '2026-03-11T14:18:12Z',
        'duration': '192.0',
      },
    ));

    events.add(AuditEvent(
      id: 'task-${++idx}',
      source: EventSource.task,
      timestamp: DateTime(2026, 3, 12, 17, 0, 45),
      eventType: 'complete',
      objectKind: 'Task',
      userId: 'admin',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'step-boxplot-003',
      targetName: 'Boxplot Operator',
      details: {
        'state': 'DoneState',
        'createdDate': '2026-03-12T16:58:00Z',
        'runDate': '2026-03-12T16:58:10Z',
        'completedDate': '2026-03-12T17:00:45Z',
        'duration': '155.0',
      },
    ));

    // Task failures
    events.add(AuditEvent(
      id: 'task-${++idx}',
      source: EventSource.task,
      timestamp: DateTime(2026, 3, 13, 10, 5, 0),
      eventType: 'fail',
      objectKind: 'Task',
      userId: 'martin.english',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'step-heatmap-004',
      targetName: 'Heatmap Operator',
      details: {
        'state': 'FailedState',
        'createdDate': '2026-03-13T10:00:00Z',
        'runDate': '2026-03-13T10:00:10Z',
        'completedDate': '2026-03-13T10:05:00Z',
        'duration': '290.0',
        'error': 'OutOfMemoryError: insufficient memory for data matrix (2.1GB required, 1.5GB available)',
      },
    ));

    events.add(AuditEvent(
      id: 'task-${++idx}',
      source: EventSource.task,
      timestamp: DateTime(2026, 3, 14, 16, 20, 0),
      eventType: 'fail',
      objectKind: 'Task',
      userId: 'admin',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'step-cluster-005',
      targetName: 'Clustering Operator',
      details: {
        'state': 'FailedState',
        'createdDate': '2026-03-14T16:15:00Z',
        'runDate': '2026-03-14T16:15:05Z',
        'completedDate': '2026-03-14T16:20:00Z',
        'duration': '295.0',
        'error': 'RuntimeError: convergence not reached after 1000 iterations',
      },
    ));

    // Task cancel
    events.add(AuditEvent(
      id: 'task-${++idx}',
      source: EventSource.task,
      timestamp: DateTime(2026, 3, 16, 11, 0, 0),
      eventType: 'cancel',
      objectKind: 'Task',
      userId: 'faris.naji',
      teamId: 'Team10Dec2025',
      projectId: 'proj-std-op-test',
      projectName: 'Standard Operator Test Workflow',
      targetId: 'step-pca-002',
      targetName: 'PCA Operator',
      details: {
        'state': 'CanceledState',
        'createdDate': '2026-03-16T10:55:00Z',
        'runDate': '2026-03-16T10:55:10Z',
        'completedDate': '2026-03-16T11:00:00Z',
        'duration': '290.0',
      },
    ));

    return events;
  }
}
