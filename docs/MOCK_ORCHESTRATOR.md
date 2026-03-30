# Mock Orchestrator — SDUI Widget Test Harness

Renders catalog widgets in isolation with mock data, no Tercen backend required.

## Quick Start

1. Select **"Mock Orchestrator"** from the JetBrains run configurations dropdown
2. Hit play — opens Chrome at `127.0.0.1:12889`
3. The widget specified in `MOCK_WIDGET` dart-define renders in a floating window

## What It Does

- Loads `catalog.json` from GitHub (same source as production)
- Loads `tokens.json` from `tercen-style` repo (same theme as production)
- Renders widgets via the real `WindowManager` (same floating window chrome)
- Uses `MockServiceCaller` instead of real Tercen API
- Provides an event inspector and service call log

## UI Layout

```
┌──────────────────────────────────────────────────┐
│ [Widget ▼]  Scenario: [Normal] [Empty] [...] ... │
├─────────────────────────────┬────────────────────┤
│                             │ Events / Svc Calls │
│   Widget under test         │                    │
│   (floating window)         │ Event log          │
│                             │ Event injector     │
│                             │ Service call log   │
└─────────────────────────────┴────────────────────┘
```

## Features

### Widget Selector
Dropdown lists all Tier 2 catalog widgets. Widgets that need real backends (ChatBox → ChatStream, TaskMonitor → TaskStream) show a warning icon and banner.

### Scenario Switching
- **Normal** — 5 items with plausible data
- **Single** — 1 item
- **Empty** — 0 items (tests empty state)
- **Many** — 50 items (tests scrolling)
- **Error** — throws exception (tests error state)

Each click rebuilds the widget from scratch, triggering DataSource refetch.

### PromptRequired Bypass
Widget config values (e.g., `projectId`) are auto-seeded from template defaults. No "Configure" popup in mock mode.

### Event Inspector
- **Events tab** — live log of all EventBus events with channel, payload, timestamp
- **Inject tab** — send custom events to the widget. Quick-send buttons pre-filled from the widget's known channels (extracted from metadata + template).

### Service Call Log
Shows every `MockServiceCaller` invocation: service, method, args, timestamp.

## How MockServiceCaller Works

The mock is **method-agnostic**. It maps service names to model types:

```
projectService → Project
projectDocumentService → ProjectDocument
workflowService → Workflow
teamService → Team
...
```

Any method (`findByX`, `findByY`, `list`, `get`) on a service returns instances of that model. Method signatures are irrelevant — adding new methods to the real client requires zero mock changes.

The only explicit overrides are composite methods (`getWorkflowGraph`, `getStepTables`) that return non-standard shapes (~7 methods).

## Changing the Default Widget

Edit the run config's dart-define: `MOCK_WIDGET=WorkflowViewer`

Or duplicate the run config for different widgets.

## Files

```
lib/mock/
  main_mock.dart           — entry point
  mock_shell.dart          — UI shell
  mock_service_caller.dart — ServiceCaller implementation
  event_inspector.dart     — event log + injector
.run/
  Mock Orchestrator.run.xml — JetBrains run config
```
