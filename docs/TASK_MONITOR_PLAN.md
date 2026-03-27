# Task Monitor — Implementation Plan

## Goal

Build a Task Monitor system that shows all running/recent tasks to the user,
provides live progress updates, and closes the agent feedback loop (agent says
"run this workflow" → user sees progress → results appear automatically).

## Reference Implementation

The existing task manager in `kumo_analysis_webapp_operator` (`lib/screens/task_manager_screen_new.dart`) serves as the reference. Key learnings and known issues from that implementation are called out below.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  Tercen Backend                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │ taskService   │  │ eventService │  │workflowService│ │
│  │ .getTasks()   │  │ .channel()   │  │ .get()        │ │
│  │ .create()     │  │              │  │               │ │
│  │ .runTask()    │  │              │  │               │ │
│  │ .cancelTask() │  │              │  │               │ │
│  └──────┬───────┘  └──────┬───────┘  └───────┬───────┘ │
└─────────┼─────────────────┼───────────────────┼─────────┘
          │                 │                   │
          ▼                 ▼                   ▼
┌─────────────────────────────────────────────────────────┐
│  Orchestrator (lib/services/task_monitor_service.dart)   │
│                                                         │
│  TaskMonitorService                                     │
│  ├── polls getTasks() every N seconds                   │
│  ├── subscribes eventService.channel(channelId) per task│
│  ├── resolves workflow/project/step names               │
│  ├── aggregates into a single task state stream         │
│  ├── emits completion intents (auto-open results)       │
│  └── exposes taskStreamProvider for SDUI                │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│  SDUI Layer                                             │
│                                                         │
│  taskStreamProvider on SduiRenderContext                 │
│       │                                                 │
│       ▼                                                 │
│  TaskStream (scope builder, Tier 1)                     │
│  ├── exposes: {{tasks}}, {{activeCount}}, {{hasRunning}}│
│  └── children render via ForEach + Conditional          │
│       │                                                 │
│       ▼                                                 │
│  TaskMonitor (catalog widget, Tier 2 JSON template)     │
│  ├── Running tasks section (grouped by workflow)        │
│  ├── Recent completed section                           │
│  └── Cancel button, open results action                 │
└─────────────────────────────────────────────────────────┘
```

---

## Phase 1: TaskMonitorService (Dart, orchestrator)

**File:** `lib/services/task_monitor_service.dart`

### Responsibilities

1. **Poll for running tasks** — call `taskService.getTasks(['RunWorkflowTask', 'RunComputationTask'])` on a timer
2. **Subscribe to event channels** — per-task real-time progress via `eventService.channel(channelId)`
3. **Resolve display names** — workflow name, project name, step name
4. **Aggregate state** — maintain a single `List<TaskEntry>` that the UI can bind to
5. **Emit completion events** — publish to EventBus when a task finishes so result windows can auto-open
6. **Cancel tasks** — expose `cancelTask(taskId)` for the cancel button

### Data Model

```dart
class TaskEntry {
  final String taskId;
  final String channelId;
  final String workflowId;
  final String workflowName;
  final String projectName;
  final String stepName;       // Resolved from workflow.steps
  final String taskType;       // 'Workflow' | 'Computing'
  final TaskStatus status;     // enum: pending, running, runningDependent, done, failed, cancelled
  final DateTime startedAt;
  final DateTime? completedAt;
  final Duration elapsed;

  TaskEntry copyWith({...});
}

enum TaskStatus { pending, running, runningDependent, done, failed, cancelled }
```

### Polling Strategy

```
┌─────────────────────────────────────────────────┐
│ Timer fires every 5 seconds                     │
│                                                 │
│  1. if (_loading) return;  // prevent overlap   │
│  2. _loading = true                             │
│  3. rawTasks = getTasks([...])                  │
│  4. for each new task not in _tracked:          │
│       - resolve workflow/project/step names     │
│       - subscribe to eventService.channel()     │
│       - add to _tracked                         │
│  5. for each _tracked task not in rawTasks:     │
│       - if status was non-final: mark as done   │
│       - move to _recent (keep last 20)          │
│  6. _loading = false                            │
│  7. notify listeners                            │
└─────────────────────────────────────────────────┘
```

**Improvements over kumo reference:**
- `_loading` guard prevents concurrent polls (kumo doesn't do this → overlapping fetches)
- Disappeared tasks are moved to `_recent` instead of silently dropped
- `_processedEventIds` and `_stepNameCache` are bounded (LRU or max-size) to prevent memory leaks

### Event Subscription (per task)

```
eventService.channel(channelId).listen((event) {
  if event is TaskStateEvent:
    1. Deduplicate: skip if eventKey in _processedEventIds
    2. Extract step.id from event.meta (if present)
       → resolve step name from workflow.steps
       → update TaskEntry.stepName
    3. Update TaskEntry.status from event.state.kind
    4. If event.state.isFinal:
       a. Move task to _recent list
       b. Cancel this channel subscription
       c. Emit completion event to EventBus:
          → type: 'task.completed'
          → data: {taskId, workflowId, status, ...}
       d. Trigger a full poll (_loadData) to catch
          any cascading tasks
    5. Notify listeners (triggers UI rebuild)
});
```

### Step Name Resolution (4-strategy approach from kumo)

Step name resolution is non-trivial because the task-to-step mapping is not
always immediately available. The kumo reference uses 4 strategies in order:

1. **Match by taskId** — `workflow.steps.firstWhere(s => s.state.taskId == task.id)`
2. **Find unmatched running step** — look for steps not in final/init state that aren't matched to other tasks
3. **Query past events** — `eventService.findByChannelAndDate()` to find events with `step.id` metadata
4. **Fallback** — generic label ("Pending step...", "Computing step...")

### Name Caching

- `_workflowNameCache`: `Map<String, String>` (workflowId → name)
- `_projectNameCache`: `Map<String, String>` (projectId → name)
- `_stepNameCache`: `Map<String, String>` (taskId → stepName)
- All bounded to 200 entries max; evict oldest on overflow
- Avoids re-fetching the same workflow/project on every poll

### Completion Events

When a task reaches a final state, the service publishes to the EventBus:

```dart
eventBus.publish('system.task.completed', EventPayload(
  type: 'task.completed',
  sourceWidgetId: 'task-monitor-service',
  data: {
    'taskId': entry.taskId,
    'workflowId': entry.workflowId,
    'status': entry.status.name,  // 'done' | 'failed' | 'cancelled'
  },
));
```

This can be consumed by:
- The orchestrator (to auto-open result windows)
- The agent (to know workflow finished)
- Any SDUI widget via ReactTo

### Cancellation

```dart
Future<void> cancelTask(String taskId) async {
  final entry = _tracked[taskId];
  if (entry == null) return;

  await factory.taskService.cancelTask(taskId);

  // If it's a RunWorkflowTask, optionally delete the workflow too
  // (kumo does this — discuss with Thiago if we want the same behavior)

  // The event stream will deliver the CancelledState event,
  // which triggers the normal final-state handling above.
  // No need to manually update state here.
}
```

### Lifecycle

```dart
class TaskMonitorService {
  Timer? _pollTimer;
  final Map<String, StreamSubscription> _channelSubs = {};
  final Map<String, TaskEntry> _tracked = {};
  final List<TaskEntry> _recent = [];  // last 20 completed
  bool _loading = false;

  void start() {
    _poll();  // immediate first load
    _pollTimer = Timer.periodic(Duration(seconds: 5), (_) => _poll());
  }

  void dispose() {
    _pollTimer?.cancel();
    for (final sub in _channelSubs.values) sub.cancel();
    _channelSubs.clear();
  }
}
```

---

## Phase 2: TaskStream Scope Builder (Tier 1, orchestrator)

**File:** `lib/sdui/widgets/task_stream.dart`

Follows the exact same pattern as `ChatStream`:
- Registered in `main.dart` via `registry.registerScope('TaskStream', buildTaskStream)`
- Bridges `taskStreamProvider` from `SduiRenderContext` into SDUI scope variables
- Listens to a stream of task updates, maintains `_tasks` list in state

### Provider typedef (in sdui package)

```dart
typedef TaskStreamProvider = ({
  Stream<List<TaskEntry>> tasks,     // aggregated task list stream
  void Function(String taskId) cancel, // cancel a task
  bool Function() hasRunning,         // any tasks running?
});
```

Added to `SduiRenderContext` alongside `chatStreamProvider`.

### Scope variables exposed to children

| Variable | Type | Description |
|----------|------|-------------|
| `{{tasks}}` | `List<Map>` | All tracked tasks (running + recent) |
| `{{runningTasks}}` | `List<Map>` | Only non-final tasks |
| `{{recentTasks}}` | `List<Map>` | Completed/failed/cancelled |
| `{{activeCount}}` | `int` | Number of running tasks |
| `{{hasRunning}}` | `bool` | Any tasks running? |

Each task in the list is a Map with keys matching `TaskEntry` fields:
`taskId`, `workflowName`, `projectName`, `stepName`, `taskType`,
`status`, `elapsed`, `startedAt`, `completedAt`.

---

## Phase 3: TaskMonitor Catalog Widget (Tier 2, JSON template)

**File:** `tercen_ui_widgets/catalog.json` (new entry)

### Template Structure

```
TaskMonitor (PromptRequired wrapper)
└── Column
    ├── Container (toolbar)
    │   └── Row: title "Task Monitor" + refresh button + active count badge
    │
    ├── Conditional (hasRunning)
    │   └── ForEach over {{runningTasks}}
    │       └── Card
    │           └── Row
    │               ├── Column: workflow name, step name, project name
    │               ├── ProgressBar (indeterminate) or status badge
    │               ├── Text: elapsed time
    │               └── IconButton: cancel (publishes task.cancel)
    │
    ├── Divider
    │
    └── Conditional (recentTasks not empty)
        └── ForEach over {{recentTasks}}
            └── Card
                └── Row
                    ├── Icon: checkmark (done) or error (failed)
                    ├── Column: workflow name, step name
                    ├── Text: completed time
                    └── IconButton: open results (publishes intent)
```

### Catalog Metadata

```json
{
  "type": "TaskMonitor",
  "tier": 2,
  "description": "Live task monitor showing running and recent tasks with progress updates. Subscribes to Tercen event service for real-time status. Cancel running tasks, view completed results.",
  "props": {},
  "emittedEvents": ["task.cancel", "system.intent"],
  "acceptedActions": ["openTaskMonitor"],
  "handlesIntent": [
    {
      "intent": "openTaskMonitor",
      "windowTitle": "Task Monitor",
      "windowSize": "medium",
      "windowAlign": "right"
    }
  ]
}
```

### Header Integration

Wire the existing `taskManager` header intent (already in MainHeader dropdown):

```dart
// In main.dart _listenHeaderIntents():
case 'taskManager':
  _sduiContext.eventBus.publish('system.intent', EventPayload(
    type: 'openTaskMonitor',
    sourceWidgetId: 'header',
    data: {'intent': 'openTaskMonitor'},
  ));
```

---

## Phase 4: Agent Workflow Feedback Loop

### Agent emits intent instead of blocking tercenctl call

Currently the agent calls `mcp__tercen__run_workflow` which blocks until
completion. Instead, the agent should emit an intent:

```json
{
  "op": "addWindow",
  "id": "task-monitor",
  "content": { "type": "TaskMonitor" },
  "size": "medium",
  "align": "right"
}
```

Or emit a `runWorkflow` intent that the orchestrator handles:

```dart
// In main.dart, subscribe to system.intent for 'runWorkflow':
case 'runWorkflow':
  final workflowId = event.data['workflowId'] as String;
  _taskMonitorService.runWorkflow(workflowId);
  // Opens TaskMonitor if not already open
```

The `TaskMonitorService.runWorkflow()` method:
1. Creates `RunWorkflowTask` with the workflowId
2. Calls `taskService.create(task)` → gets channelId
3. Subscribes to event channel
4. Calls `taskService.runTask(task.id)`
5. Task appears in TaskMonitor automatically

The agent can then move on (doesn't burn turns waiting). When the task
completes, `task.completed` event fires, and the orchestrator auto-opens
result windows.

### Auto-opening results on completion

```dart
// In main.dart, subscribe to task.completed:
_sduiContext.eventBus.subscribe('system.task.completed').listen((event) {
  final status = event.data['status'];
  final workflowId = event.data['workflowId'];
  if (status == 'done' && workflowId != null) {
    // Fetch generated files for the workflow
    // For each image → emit openStepImages intent
    // For each table → emit openStepTables intent
  }
});
```

---

## Implementation Order

### Step 1: TaskMonitorService
- `lib/services/task_monitor_service.dart`
- Polling, event subscription, name resolution, aggregation
- Unit-testable without UI
- **No UI changes yet** — just the service

### Step 2: TaskStream scope builder + provider wiring
- `lib/sdui/widgets/task_stream.dart`
- `TaskStreamProvider` typedef in sdui package
- Wire in `main.dart` (create service after auth, inject provider)

### Step 3: TaskMonitor catalog widget
- JSON template in `catalog.json`
- Header intent wiring (`taskManager` → `openTaskMonitor`)
- Cancel button wiring (EventBus → service)

### Step 4: Agent workflow intent
- New `runWorkflow` intent handler in orchestrator
- `TaskMonitorService.runWorkflow()` method
- Auto-open results on completion

### Step 5: Polish
- Elapsed time auto-updating (timer in TaskStream)
- Error states and retry
- Bounded caches and memory cleanup
- Recent tasks persistence (optional — survive page reload)

---

## Known Pitfalls (from kumo analysis)

| Issue | Kumo behavior | Our fix |
|-------|---------------|---------|
| Concurrent polls | No guard → overlapping fetches | `_loading` flag prevents overlap |
| Memory leaks | `_processedEventIds` and `_taskStepNames` grow unbounded | Bounded maps, cleared on dispose |
| Step name resolution | 4-strategy cascade, expensive | Cache aggressively, resolve lazily |
| Disappeared tasks | Silently dropped from list | Move to `_recent` with inferred completion |
| Event dedup key | `{id}_{date}_{state}` — fragile if events reorder | Same approach but bounded set |
| Workflow fetch per poll | Fetches workflow object for every task every poll | Cache workflow/project names |
| No concurrent load cancel | Old fetches can overwrite newer data | Sequence counter: discard stale results |

---

## Dependencies

- **sdui package**: Add `TaskStreamProvider` typedef to `SduiRenderContext`
- **orchestrator**: New service + scope builder + main.dart wiring
- **tercen_ui_widgets**: New catalog entry
- **No backend changes required** for Phase 1-3 (uses existing task/event APIs)
