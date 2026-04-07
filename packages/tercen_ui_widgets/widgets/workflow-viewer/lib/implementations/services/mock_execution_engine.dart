import 'dart:async';
import 'dart:math';

import '../../domain/models/workflow_models.dart';
import '../../domain/services/event_bus.dart';
import '../../domain/services/event_payload.dart';
import '../../domain/services/workflow_channels.dart';

/// Simulates realistic Tercen workflow execution by walking the DAG
/// and publishing [WorkflowChannels.stepStateChanged] events on timers.
///
/// In production the server pushes these events over the WebSocket;
/// this engine replaces that for Phase 2 mock mode.
class MockExecutionEngine {
  final EventBus _eventBus;
  final String _sourceWidgetId;
  final Random _rng = Random();

  /// Active timers for cancellation on stop/dispose.
  final List<Timer> _timers = [];

  /// Track which steps have completed in the current run.
  final Set<String> _completedSteps = {};

  /// Counter for failure injection (1 in 5 runs).
  int _runCount = 0;

  MockExecutionEngine({
    required EventBus eventBus,
    required String sourceWidgetId,
  })  : _eventBus = eventBus,
        _sourceWidgetId = sourceWidgetId;

  // ── Public API ──

  /// Run the entire workflow: cascade through the DAG from entry points.
  void runWorkflow(WorkflowModel workflow) {
    _cancelAllTimers();
    _completedSteps.clear();
    _runCount++;

    // Determine if this run should have a failure (1 in 5 runs, skip first)
    final shouldFail = _runCount > 1 && _runCount % 5 == 0;
    String? failStepId;
    if (shouldFail) {
      // Pick a random non-entry step to fail
      final candidates = workflow.steps
          .where((s) =>
              s.kind != StepKind.tableStep &&
              s.kind != StepKind.inStep &&
              s.kind != StepKind.workflow)
          .toList();
      if (candidates.isNotEmpty) {
        failStepId = candidates[_rng.nextInt(candidates.length)].id;
      }
    }

    // Set all non-workflow steps to pending immediately
    for (final step in workflow.steps) {
      if (step.kind == StepKind.workflow) continue;
      _publishState(step.id, StepState.pending);
    }

    // Build adjacency: parent → children
    final childMap = <String, List<String>>{};
    final parentMap = <String, List<String>>{};
    for (final link in workflow.links) {
      childMap.putIfAbsent(link.outputStepId, () => []).add(link.inputStepId);
      parentMap.putIfAbsent(link.inputStepId, () => []).add(link.outputStepId);
    }

    // Find entry points (steps with no parents, excluding workflow root)
    final entryPoints = workflow.steps
        .where((s) =>
            s.kind != StepKind.workflow &&
            (!parentMap.containsKey(s.id) || parentMap[s.id]!.isEmpty))
        .toList();

    // Start entry points after a short delay (simulates server acknowledgement)
    _scheduleTimer(Duration(milliseconds: _jitter(200, 500)), () {
      for (final entry in entryPoints) {
        _startStep(entry.id, workflow, childMap, parentMap, failStepId);
      }
    });
  }

  /// Run a single step (and then cascade to its children).
  void runStep(String stepId, WorkflowModel workflow) {
    _cancelAllTimers();
    _completedSteps.clear();

    final childMap = <String, List<String>>{};
    final parentMap = <String, List<String>>{};
    for (final link in workflow.links) {
      childMap.putIfAbsent(link.outputStepId, () => []).add(link.inputStepId);
      parentMap.putIfAbsent(link.inputStepId, () => []).add(link.outputStepId);
    }

    // Mark the step and all its downstream as pending
    _markDownstreamPending(stepId, childMap);

    _scheduleTimer(Duration(milliseconds: _jitter(200, 400)), () {
      _startStep(stepId, workflow, childMap, parentMap, null);
    });
  }

  /// Stop the entire workflow: cancel all running/pending steps.
  void stopWorkflow(WorkflowModel workflow) {
    _cancelAllTimers();

    // Cancel all running/pending steps with a short staggered delay
    for (final step in workflow.steps) {
      if (step.state == StepState.running ||
          step.state == StepState.runningDependent ||
          step.state == StepState.pending) {
        _scheduleTimer(Duration(milliseconds: _jitter(50, 200)), () {
          _publishState(step.id, StepState.canceled);
        });
      }
    }
  }

  /// Stop a single step and its downstream dependents.
  void stopStep(String stepId, WorkflowModel workflow) {
    _cancelAllTimers();

    final childMap = <String, List<String>>{};
    for (final link in workflow.links) {
      childMap.putIfAbsent(link.outputStepId, () => []).add(link.inputStepId);
    }

    _publishState(stepId, StepState.canceled);
    _cancelDownstream(stepId, childMap, workflow);
  }

  /// Reset entire workflow: all steps → init.
  void resetWorkflow(WorkflowModel workflow) {
    _cancelAllTimers();
    _completedSteps.clear();

    for (final step in workflow.steps) {
      if (step.kind == StepKind.workflow) continue;
      _publishState(step.id, StepState.init);
    }
  }

  /// Reset a single step and its downstream dependents → init.
  void resetStep(String stepId, WorkflowModel workflow) {
    _cancelAllTimers();

    final childMap = <String, List<String>>{};
    for (final link in workflow.links) {
      childMap.putIfAbsent(link.outputStepId, () => []).add(link.inputStepId);
    }

    _publishState(stepId, StepState.init);
    _resetDownstream(stepId, childMap);
  }

  /// Cancel all pending timers (e.g., on dispose).
  void dispose() {
    _cancelAllTimers();
  }

  // ── Internal ──

  void _startStep(
    String stepId,
    WorkflowModel workflow,
    Map<String, List<String>> childMap,
    Map<String, List<String>> parentMap,
    String? failStepId,
  ) {
    _publishState(stepId, StepState.running);

    // Determine execution duration based on step kind
    final step = workflow.steps.firstWhere((s) => s.id == stepId,
        orElse: () => workflow.steps.first);
    final durationMs = _stepDuration(step.kind);

    _scheduleTimer(Duration(milliseconds: durationMs), () {
      // Check if this step should fail
      if (stepId == failStepId) {
        _publishState(stepId, StepState.failed);
        // Cancel all downstream
        _cancelDownstream(stepId, childMap, workflow);
        return;
      }

      _publishState(stepId, StepState.done);
      _completedSteps.add(stepId);

      // Cascade: start children whose ALL parents are done
      final children = childMap[stepId] ?? [];
      for (final childId in children) {
        final parents = parentMap[childId] ?? [];
        final allParentsDone =
            parents.every((p) => _completedSteps.contains(p));
        if (allParentsDone) {
          // Stagger child starts slightly
          _scheduleTimer(Duration(milliseconds: _jitter(100, 300)), () {
            _startStep(childId, workflow, childMap, parentMap, failStepId);
          });
        }
      }
    });
  }

  void _markDownstreamPending(
      String stepId, Map<String, List<String>> childMap) {
    _publishState(stepId, StepState.pending);
    for (final childId in childMap[stepId] ?? []) {
      _markDownstreamPending(childId, childMap);
    }
  }

  void _cancelDownstream(String stepId, Map<String, List<String>> childMap,
      WorkflowModel workflow) {
    for (final childId in childMap[stepId] ?? []) {
      final child = workflow.steps.firstWhere((s) => s.id == childId,
          orElse: () => workflow.steps.first);
      if (child.state == StepState.running ||
          child.state == StepState.runningDependent ||
          child.state == StepState.pending) {
        _scheduleTimer(Duration(milliseconds: _jitter(50, 150)), () {
          _publishState(childId, StepState.canceled);
        });
        _cancelDownstream(childId, childMap, workflow);
      }
    }
  }

  void _resetDownstream(String stepId, Map<String, List<String>> childMap) {
    for (final childId in childMap[stepId] ?? []) {
      _publishState(childId, StepState.init);
      _resetDownstream(childId, childMap);
    }
  }

  /// Duration for step execution based on kind.
  int _stepDuration(StepKind kind) {
    switch (kind) {
      case StepKind.tableStep:
      case StepKind.inStep:
        return _jitter(500, 1200); // Fast: just loading data
      case StepKind.viewStep:
      case StepKind.outStep:
      case StepKind.exportStep:
        return _jitter(400, 800); // Fast: rendering/output
      case StepKind.joinStep:
      case StepKind.meltStep:
        return _jitter(800, 2000); // Medium: data transformation
      case StepKind.dataStep:
        return _jitter(1500, 4000); // Slow: computation
      case StepKind.groupStep:
      case StepKind.wizardStep:
        return _jitter(1000, 2500); // Medium
      case StepKind.workflow:
        return 0;
    }
  }

  int _jitter(int minMs, int maxMs) {
    return minMs + _rng.nextInt(maxMs - minMs + 1);
  }

  void _publishState(String stepId, StepState state) {
    _eventBus.publish(
      WorkflowChannels.stepStateChanged,
      EventPayload(
        type: 'stepStateChanged',
        sourceWidgetId: _sourceWidgetId,
        data: {
          'stepId': stepId,
          'newState': state.name,
        },
      ),
    );
  }

  void _scheduleTimer(Duration delay, void Function() callback) {
    final timer = Timer(delay, callback);
    _timers.add(timer);
  }

  void _cancelAllTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }
}
