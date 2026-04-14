import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sci_tercen_client/sci_client_service_factory.dart' as tercen;
import 'package:sdui/sdui.dart';

/// Polls for running tasks, subscribes to event channels for live progress,
/// and exposes an aggregated task stream for the TaskStream scope builder.
class TaskMonitorService {
  final EventBus eventBus;
  final String username;

  Timer? _pollTimer;
  bool _loading = false;

  /// Tasks currently tracked (running or recently seen).
  final Map<String, TaskEntry> _tracked = {};

  /// Recently completed tasks (most recent first, max 20).
  final List<TaskEntry> _recent = [];

  /// Event channel subscriptions keyed by channelId.
  final Map<String, StreamSubscription> _channelSubs = {};

  /// Deduplication for event processing.
  final Set<String> _processedEventIds = {};

  /// Name caches to avoid re-fetching.
  final Map<String, String> _workflowNameCache = {};
  final Map<String, String> _projectNameCache = {};

  /// Broadcast stream of task snapshots.
  final _taskStream =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  static const _pollInterval = Duration(seconds: 5);
  static const _maxRecent = 20;
  static const _maxCacheSize = 200;
  static const _maxEventIds = 1000;

  TaskMonitorService({required this.eventBus, required this.username});

  Stream<List<Map<String, dynamic>>> get tasks => _taskStream.stream;

  bool get hasRunning =>
      _tracked.values.any((t) => !t.status.isFinal);

  /// Start polling. Call after auth when ServiceFactory is available.
  void start() {
    _loadRecent();
    _poll();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
    debugPrint('[task-monitor] Started (polling every ${_pollInterval.inSeconds}s)');
  }

  /// Seed the recent list with completed task activities via activityService.
  Future<void> _loadRecent() async {
    final factory = _factory;
    if (factory == null) return;

    try {
      if (username.isEmpty) {
        debugPrint('[task-monitor] No username — skipping recent load');
        return;
      }

      // Use the same API as HomePanel's Recent Activity card.
      final svc = factory.activityService;
      final activities = await svc.findStartKeys(
        'findByUserAndDate',
        startKey: [username, ''],
        endKey: [username, '\uf000'],
        limit: 100,
        descending: true,
      );

      debugPrint('[task-monitor] findByUserAndDate returned ${activities.length} activities');

      // Build recent entries from all activity types.
      int loaded = 0;
      for (final activity in activities) {
        if (loaded >= _maxRecent) break;
        final json = activity.toJson();
        final type = (json['type'] ?? '') as String;
        final objectKind = (json['objectKind'] ?? '') as String;
        final objectName = _extractProperty(json, 'name') ?? objectKind;
        final projectName = (json['projectName'] ?? '') as String;
        final dateMap = json['date'] as Map?;
        final dateValue = dateMap?['value'] as String? ?? '';
        final actDate = DateTime.tryParse(dateValue) ?? DateTime.now();

        final status = switch (type) {
          'delete' => TaskStatus.failed,
          _ => TaskStatus.done,
        };

        final verb = switch (type) {
          'create' => 'Created',
          'update' => 'Updated',
          'delete' => 'Deleted',
          'run' => 'Ran',
          'complete' => 'Completed',
          'fail' => 'Failed',
          'cancel' => 'Cancelled',
          _ => type,
        };

        _recent.add(TaskEntry(
          taskId: json['id'] as String? ?? '',
          channelId: '',
          workflowId: '',
          workflowName: objectName,
          projectName: projectName,
          stepName: '',
          taskType: '$verb $objectKind',
          status: status,
          startedAt: actDate,
          completedAt: actDate,
        ));
        loaded++;
      }

      if (_recent.isNotEmpty) {
        debugPrint('[task-monitor] Loaded ${_recent.length} recent task(s)');
        _notify();
      } else {
        debugPrint('[task-monitor] No task activities found for $username');
      }
    } catch (e, st) {
      debugPrint('[task-monitor] Failed to load recent tasks: $e');
      debugPrint('[task-monitor] $st');
    }
  }

  /// Extract a value from the activity properties list by key.
  static String? _extractProperty(Map json, String key) {
    final props = json['properties'];
    if (props is List) {
      for (final p in props) {
        if (p is Map && p['key'] == key) return p['value'] as String?;
      }
    }
    return null;
  }

  sci.ServiceFactory? get _factory {
    final f = tercen.ServiceFactory.CURRENT;
    return f is sci.ServiceFactory ? f : null;
  }

  Future<void> _poll() async {
    if (_loading) return;
    final factory = _factory;
    if (factory == null) return;

    _loading = true;
    try {
      final rawTasks = await factory.taskService.getTasks([]);

      // Filter for workflow and computation tasks, exclude init/final states
      final activeTasks = rawTasks.where((t) =>
          (t.kind == 'RunWorkflowTask' || t.kind == 'RunComputationTask') &&
          !t.state.isFinal &&
          t.state.kind != 'InitState').toList();

      if (activeTasks.isNotEmpty || _tracked.isNotEmpty) {
        debugPrint('[task-monitor] Poll: ${activeTasks.length} active, '
            '${_tracked.length} tracked, ${_recent.length} recent');
      }

      final activeIds = <String>{};

      for (final task in activeTasks) {
        activeIds.add(task.id);

        if (_tracked.containsKey(task.id)) {
          // Update state of existing tracked task
          _tracked[task.id] = _tracked[task.id]!.copyWith(
            status: _mapStatus(task.state.kind),
          );
        } else {
          // New task — resolve names and subscribe to events
          final entry = await _buildEntry(factory, task);
          _tracked[task.id] = entry;
          _subscribeToChannel(factory, task.channelId, task.id);
        }
      }

      // Tasks that disappeared from active list
      final disappeared = _tracked.keys
          .where((id) => !activeIds.contains(id))
          .toList();
      for (final id in disappeared) {
        final entry = _tracked.remove(id);
        if (entry != null && !entry.status.isFinal) {
          // Infer completion — it was running but is no longer in getTasks
          _addToRecent(entry.copyWith(
            status: TaskStatus.done,
            completedAt: DateTime.now(),
          ));
        }
      }

      _notify();
    } catch (e) {
      debugPrint('[task-monitor] Poll failed: $e');
    } finally {
      _loading = false;
    }
  }

  Future<TaskEntry> _buildEntry(
      sci.ServiceFactory factory, sci.Task task) async {
    String workflowId = '';
    String workflowName = '';
    String projectName = '';
    String projectId = '';

    debugPrint('[task-monitor] Building entry for ${task.id} '
        'kind=${task.kind} runtimeType=${task.runtimeType} '
        'state=${task.state.kind}');

    // Access projectId from ProjectTask (common parent for both task types)
    if (task is sci.ProjectTask) {
      projectId = task.projectId;
      projectName = await _resolveProjectName(factory, projectId);
    }

    if (task is sci.RunWorkflowTask) {
      workflowId = task.workflowId;
      workflowName = await _resolveWorkflowName(factory, task.workflowId);
    }

    debugPrint('[task-monitor] Entry: wf="$workflowName" proj="$projectName" '
        'wfId=$workflowId projId=$projectId');

    return TaskEntry(
      taskId: task.id,
      channelId: task.channelId,
      workflowId: workflowId,
      workflowName: workflowName,
      projectName: projectName,
      stepName: '',
      taskType: task.kind == 'RunWorkflowTask' ? 'Workflow' : 'Computing',
      status: _mapStatus(task.state.kind),
      startedAt: DateTime.tryParse(task.lastModifiedDate.value) ?? DateTime.now(),
    );
  }

  void _subscribeToChannel(
      sci.ServiceFactory factory, String channelId, String taskId) {
    if (_channelSubs.containsKey(channelId)) return;
    if (channelId.isEmpty) return;

    debugPrint('[task-monitor] Subscribing to channel $channelId (task $taskId)');

    final sub = factory.eventService.channel(channelId).listen(
      (event) {
        if (event is sci.TaskStateEvent) {
          _handleTaskStateEvent(event, channelId);
        }
      },
      onError: (e) {
        debugPrint('[task-monitor] Channel $channelId error: $e');
      },
      onDone: () {
        debugPrint('[task-monitor] Channel $channelId closed');
        _channelSubs.remove(channelId)?.cancel();
      },
    );

    _channelSubs[channelId] = sub;
  }

  void _handleTaskStateEvent(sci.TaskStateEvent event, String channelId) {
    final eventKey = '${event.id}_${event.date.value}_${event.state.kind}';
    if (_processedEventIds.contains(eventKey)) return;
    _processedEventIds.add(eventKey);

    // Bound the dedup set
    if (_processedEventIds.length > _maxEventIds) {
      final toRemove = _processedEventIds.take(
          _processedEventIds.length - _maxEventIds + 100).toList();
      _processedEventIds.removeAll(toRemove);
    }

    final taskId = event.taskId;
    final entry = _tracked[taskId];
    if (entry == null) return;

    final newStatus = _mapStatus(event.state.kind);

    // Extract step name from event metadata
    String? stepName;
    try {
      final stepIdMeta = event.meta.firstWhere(
        (m) => m.key == 'step.id',
        orElse: () => sci.Pair(),
      );
      if (stepIdMeta.value.isNotEmpty) {
        // Use step.id as fallback name; we'd need the workflow to get the real name
        stepName = stepIdMeta.value;
      }
    } catch (_) {}

    if (newStatus.isFinal) {
      // Task completed — move to recent
      _tracked.remove(taskId);
      _addToRecent(entry.copyWith(
        status: newStatus,
        stepName: stepName ?? entry.stepName,
        completedAt: DateTime.now(),
      ));

      // Clean up channel subscription
      _channelSubs[channelId]?.cancel();
      _channelSubs.remove(channelId);

      // Publish completion event
      String? failReason;
      if (event.state is sci.FailedState) {
        final fs = event.state as sci.FailedState;
        failReason = fs.reason.isNotEmpty ? fs.reason : fs.error;
      }

      eventBus.publish(
        'system.task.completed',
        EventPayload(
          type: 'task.completed',
          sourceWidgetId: 'task-monitor-service',
          data: {
            'taskId': taskId,
            'workflowId': entry.workflowId,
            'status': newStatus.name,
            if (failReason != null) 'reason': failReason,
          },
        ),
      );

      debugPrint('[task-monitor] Task $taskId → ${newStatus.name}'
          '${failReason != null ? " ($failReason)" : ""}');
    } else {
      // Partial update
      _tracked[taskId] = entry.copyWith(
        status: newStatus,
        stepName: stepName ?? entry.stepName,
      );
    }

    _notify();
  }

  void _addToRecent(TaskEntry entry) {
    _recent.insert(0, entry);
    if (_recent.length > _maxRecent) {
      _recent.removeRange(_maxRecent, _recent.length);
    }
  }

  /// Find a tracked (running) task ID for a given workflowId.
  String? findTaskForWorkflow(String workflowId) {
    for (final entry in _tracked.values) {
      if (entry.workflowId == workflowId && !entry.status.isFinal) {
        return entry.taskId;
      }
    }
    return null;
  }

  /// Cancel a running task.
  Future<void> cancelTask(String taskId) async {
    final factory = _factory;
    if (factory == null) return;

    try {
      await factory.taskService.cancelTask(taskId);
      debugPrint('[task-monitor] Cancelled task $taskId');
      // The event stream will deliver CancelledState — no manual state update needed
    } catch (e) {
      debugPrint('[task-monitor] Cancel failed for $taskId: $e');
    }
  }

  /// Build the snapshot list and push to the stream.
  void _notify() {
    final now = DateTime.now();
    final all = <Map<String, dynamic>>[];

    // Running tasks first
    for (final entry in _tracked.values) {
      all.add(entry.toMap(now));
    }

    // Then recent (already sorted newest first)
    for (final entry in _recent) {
      all.add(entry.toMap(now));
    }

    _taskStream.add(all);
  }

  Future<String> _resolveWorkflowName(
      sci.ServiceFactory factory, String workflowId) async {
    if (workflowId.isEmpty) return '';
    if (_workflowNameCache.containsKey(workflowId)) {
      return _workflowNameCache[workflowId]!;
    }
    try {
      final wf = await factory.workflowService.get(workflowId);
      final name = wf.name;
      _boundedPut(_workflowNameCache, workflowId, name);
      return name;
    } catch (e) {
      debugPrint('[task-monitor] Failed to resolve workflow $workflowId: $e');
      return workflowId;
    }
  }

  Future<String> _resolveProjectName(
      sci.ServiceFactory factory, String projectId) async {
    if (projectId.isEmpty) return '';
    if (_projectNameCache.containsKey(projectId)) {
      return _projectNameCache[projectId]!;
    }
    try {
      final proj = await factory.projectService.get(projectId);
      final name = proj.name;
      _boundedPut(_projectNameCache, projectId, name);
      return name;
    } catch (e) {
      debugPrint('[task-monitor] Failed to resolve project $projectId: $e');
      return projectId;
    }
  }

  void _boundedPut(Map<String, String> cache, String key, String value) {
    if (cache.length >= _maxCacheSize) {
      cache.remove(cache.keys.first);
    }
    cache[key] = value;
  }

  static TaskStatus _mapStatus(String stateKind) {
    return switch (stateKind) {
      'PendingState' => TaskStatus.pending,
      'RunningState' => TaskStatus.running,
      'RunningDependentState' => TaskStatus.runningDependent,
      'DoneState' => TaskStatus.done,
      'FailedState' => TaskStatus.failed,
      'CanceledState' => TaskStatus.cancelled,
      _ => TaskStatus.pending,
    };
  }

  void dispose() {
    _pollTimer?.cancel();
    for (final sub in _channelSubs.values) {
      sub.cancel();
    }
    _channelSubs.clear();
    _processedEventIds.clear();
    _taskStream.close();
    debugPrint('[task-monitor] Disposed');
  }
}

// -- Data model --

enum TaskStatus {
  pending,
  running,
  runningDependent,
  done,
  failed,
  cancelled;

  bool get isFinal => this == done || this == failed || this == cancelled;
}

class TaskEntry {
  final String taskId;
  final String channelId;
  final String workflowId;
  final String workflowName;
  final String projectName;
  final String stepName;
  final String taskType;
  final TaskStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;

  const TaskEntry({
    required this.taskId,
    required this.channelId,
    required this.workflowId,
    required this.workflowName,
    required this.projectName,
    required this.stepName,
    required this.taskType,
    required this.status,
    required this.startedAt,
    this.completedAt,
  });

  TaskEntry copyWith({
    String? stepName,
    TaskStatus? status,
    DateTime? completedAt,
  }) {
    return TaskEntry(
      taskId: taskId,
      channelId: channelId,
      workflowId: workflowId,
      workflowName: workflowName,
      projectName: projectName,
      stepName: stepName ?? this.stepName,
      taskType: taskType,
      status: status ?? this.status,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap(DateTime now) {
    final elapsed = (completedAt ?? now).difference(startedAt);
    return {
      'taskId': taskId,
      'workflowId': workflowId,
      'workflowName': workflowName,
      'projectName': projectName,
      'stepName': stepName,
      'taskType': taskType,
      'status': status.name,
      'isFinal': status.isFinal,
      'isRunning': status == TaskStatus.running,
      'isPending': status == TaskStatus.pending,
      'isDone': status == TaskStatus.done,
      'isFailed': status == TaskStatus.failed,
      'isCancelled': status == TaskStatus.cancelled,
      'elapsed': _formatDuration(elapsed),
      'startedAt': startedAt.toIso8601String(),
      if (completedAt != null)
        'completedAt': completedAt!.toIso8601String(),
    };
  }

  static String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }
}
