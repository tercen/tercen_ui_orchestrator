# Tercen Widget Library — Development Guide

This document is for developers building the **tercen_widget_catalog** — a Flutter package of complex, domain-aware widgets that work both standalone and inside the Tercen UI Orchestrator.

## 1. Project Setup

### 1.1 Create the widget library package

```bash
flutter create --template=package tercen_widget_catalog
cd tercen_widget_catalog
```

### 1.2 Dependencies

In `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # SDUI core types (EventBus, SduiNode, WidgetRegistry, etc.)
  # Import from the orchestrator until these are extracted to a shared package.
  tercen_ui_orchestrator:
    path: ../tercen_ui_orchestrator

  # Tercen API client — for widgets with built-in data calls
  sci_tercen_client:
    git:
      ref: 1.16.1
      url: https://github.com/tercen/sci_tercen_client
      path: sci_tercen_client
  sci_base:
    git:
      ref: 1.16.1
      url: https://github.com/tercen/sci_tercen_client
      path: sci_base
```

### 1.3 Authentication (for data-connected widgets)

Widgets that call Tercen services need a JWT token. During development:

1. Get a token from your Tercen instance (Profile → API Tokens, or `tercenctl context to-token --validity 30d`)
2. Pass it via `--dart-define=TERCEN_TOKEN=<jwt>` when running Flutter
3. Your standalone test harness (see section 6) creates a `ServiceFactory` from this token

### 1.4 Claude Code setup

If using Claude Code to assist development, create a `CLAUDE.md` in your widget library root with:

```markdown
This is a Flutter widget library for the Tercen SDUI system.
See ../tercen_ui_orchestrator/WIDGET_LIB_INSTRUCTIONS.md for full architecture docs.
Key imports from the orchestrator: EventBus, EventPayload, SduiNode, SduiRenderContext, WidgetRegistry, WidgetMetadata, PropSpec.
```

---

## 2. Architecture Overview

### 2.1 SDUI (Server-Driven UI)

The orchestrator renders widget trees from JSON. An AI agent (or any backend) composes JSON describing what to show. The renderer walks the tree, looks up each node's `type` in the `WidgetRegistry`, and calls the registered builder function.

```
JSON node: {"type": "ProjectList", "id": "pl-1", "props": {"limit": 20}}
  → WidgetRegistry.getBuilder("ProjectList")
  → builder(node, children, renderContext) → Flutter Widget
```

### 2.2 Key types you'll import

| Type | Location | Purpose |
|------|----------|---------|
| `SduiWidgetBuilder` | `sdui/registry/widget_registry.dart` | `Widget Function(SduiNode, List<Widget>, SduiRenderContext)` — the builder signature |
| `SduiNode` | `sdui/schema/sdui_node.dart` | The JSON node: `type`, `id`, `props`, `children`, `dataSource`, `actions`, `reactTo` |
| `SduiRenderContext` | `sdui/renderer/sdui_render_context.dart` | Shared context: `eventBus`, `templateResolver`, `serviceCaller` |
| `EventBus` | `sdui/event_bus/event_bus.dart` | Publish/subscribe with channel-based routing |
| `EventPayload` | `sdui/event_bus/event_payload.dart` | Event data: `type`, `sourceWidgetId`, `data` map, `timestamp` |
| `WidgetRegistry` | `sdui/registry/widget_registry.dart` | Register builder + metadata by type name |
| `WidgetMetadata` | `sdui/registry/widget_metadata.dart` | Describes a widget for the AI: props, gestures, emitted events |
| `PropSpec` | `sdui/registry/widget_metadata.dart` | Describes a single prop: type, required, default, description |
| `ServiceCaller` | `sdui/renderer/sdui_render_context.dart` | `Future<dynamic> Function(String service, String method, List<dynamic> args)` |

### 2.3 Widget tiers

- **Tier 1**: Layout primitives (Row, Column, Text, Card, ...) — already in the orchestrator
- **Tier 2**: Domain widgets (what you're building) — complex, may fetch data, emit events

---

## 3. Widget Contract

### 3.1 The builder function

Every widget is a function with this signature:

```dart
Widget buildProjectList(SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final limit = node.props['limit'] as int? ?? 20;
  final serviceCaller = ctx.serviceCaller;

  // Your widget implementation
  return ProjectListWidget(limit: limit, serviceCaller: serviceCaller);
}
```

The builder receives:
- `node` — the JSON node with resolved props (template bindings like `{{item.id}}` are already resolved)
- `children` — child widgets already rendered by the SDUI renderer
- `ctx` — shared context with EventBus, TemplateResolver, and ServiceCaller

### 3.2 Registration

Export a registration function from your library:

```dart
// lib/tercen_widget_catalog.dart

import 'package:tercen_ui_orchestrator/sdui/registry/widget_registry.dart';
import 'package:tercen_ui_orchestrator/sdui/registry/widget_metadata.dart';

void registerTercenWidgets(WidgetRegistry registry) {
  registry.register('ProjectList', buildProjectList,
    metadata: const WidgetMetadata(
      type: 'ProjectList',
      tier: 2,
      description: 'Displays a list of Tercen projects with selection support',
      props: {
        'limit': PropSpec(type: 'int', defaultValue: 20, description: 'Max items to show'),
        'showPublic': PropSpec(type: 'bool', defaultValue: true),
      },
      emittedEvents: ['system.selection.project'],
      acceptedActions: ['onTap', 'onDoubleTap'],
    ),
  );

  registry.register('WorkflowViewer', buildWorkflowViewer,
    metadata: const WidgetMetadata(
      type: 'WorkflowViewer',
      tier: 2,
      description: 'Displays workflow steps and their status',
      props: {
        'workflowId': PropSpec(type: 'string', required: true),
        'projectId': PropSpec(type: 'string', required: true),
      },
      emittedEvents: ['system.selection.workflow', 'system.selection.step'],
    ),
  );

  // ... more widgets
}
```

The orchestrator calls this at startup:

```dart
// In the orchestrator's SduiContext.create():
registerBuiltinWidgets(registry);     // Tier 1
registerTercenWidgets(registry);      // Tier 2 (your library)
```

### 3.3 Metadata matters

The `WidgetMetadata` fields are not just documentation — they feed the AI's discovery system:

- `description` — the AI reads this to decide which widget to use
- `props` — the AI knows what props are available and their types
- `emittedEvents` — the AI knows what events to expect (for wiring reactTo)
- `acceptedActions` — the AI knows what gestures the widget supports

**Important**: Fill these in accurately. The `discover_interactions` MCP tool will eventually generate its catalog from registered widget metadata. Inaccurate metadata means the AI composes broken widget trees.

---

## 4. EventBus — Communication System

### 4.1 How it works

The EventBus is a simple publish/subscribe system with channel-based routing. Every widget in the system shares the same EventBus instance (via `SduiRenderContext`).

```dart
// Publish
ctx.eventBus.publish('system.selection.project', EventPayload(
  type: 'onTap',
  sourceWidgetId: 'project-list-1',
  data: {'projectId': 'abc', 'projectName': 'My Project'},
));

// Subscribe to a specific channel
ctx.eventBus.subscribe('system.selection.project').listen((event) {
  final projectId = event.data['projectId'];
  // React to selection
});

// Subscribe to all channels matching a prefix
ctx.eventBus.subscribePrefix('system.selection.').listen((event) {
  // Receives events from system.selection.project, system.selection.workflow, etc.
});
```

### 4.2 Channel naming conventions

```
system.selection.<entity>    — User selected something (project, workflow, step, file)
system.layout.op             — Layout operations (addWindow, removeWindow, etc.)
system.data.<entity>         — Data changed (triggers refetch in listening widgets)
system.task.<taskId>         — Task progress/completion
widget.<widgetId>.<event>    — Widget-specific internal events
```

### 4.3 Within-widget events

For complex widgets with internal components (e.g., a table with sortable columns), use the `widget.<widgetId>.*` namespace:

```dart
// Table header publishes sort event
ctx.eventBus.publish('widget.${node.id}.sort', EventPayload(
  type: 'sort',
  sourceWidgetId: node.id,
  data: {'column': 'name', 'direction': 'asc'},
));

// Table body listens to sort events from its own widget
ctx.eventBus.subscribe('widget.${node.id}.sort').listen((event) {
  setState(() {
    _sortColumn = event.data['column'];
    _sortDirection = event.data['direction'];
  });
});
```

These events are scoped to the widget instance (via `node.id`) so multiple instances don't interfere.

### 4.4 Between-widget events

For cross-widget communication, use the `system.*` channels:

```dart
// ProjectList publishes selection
ctx.eventBus.publish('system.selection.project', EventPayload(
  type: 'onTap',
  sourceWidgetId: node.id,
  data: {'projectId': project.id, 'projectName': project.name},
));

// WorkflowViewer listens and reloads
ctx.eventBus.subscribe('system.selection.project').listen((event) {
  final projectId = event.data['projectId'];
  _loadWorkflows(projectId);
});
```

The orchestrator's server also listens to `system.selection.*` events and tracks them as user context — so the AI knows what's selected.

### 4.5 Event flow diagram

```
┌─────────────┐     system.selection.project      ┌──────────────────┐
│ ProjectList  │ ──────────────────────────────→   │ WorkflowViewer   │
│              │     {projectId, projectName}      │ (reloads on      │
│  onTap →     │                                   │  project change) │
│  publish()   │                                   │  subscribe()     │
└─────────────┘                                    └──────────────────┘
       │                                                    │
       │                                                    │
       ▼                                                    ▼
  ┌──────────────────────────────────────────────────────────────┐
  │                    EventBus (shared)                          │
  │                                                              │
  │  Channels:                                                   │
  │    system.selection.project  ← ProjectList publishes here    │
  │    system.selection.workflow ← WorkflowViewer publishes here │
  │    widget.pl-1.sort          ← internal to ProjectList       │
  └──────────────────────────────────────────────────────────────┘
       │
       ▼ (forwarded to server via WebSocket)
  ┌──────────────────┐
  │ Orchestrator      │
  │ Server            │
  │ (_userContext)    │
  └──────────────────┘
```

---

## 5. Data-Connected Widgets

### 5.1 Pattern: widget with built-in data fetching

For widgets that own their data call (as opposed to receiving data via `dataSource` on the JSON node):

```dart
class ProjectListWidget extends StatefulWidget {
  final int limit;
  final ServiceCaller? serviceCaller;
  final EventBus eventBus;
  final String nodeId;

  const ProjectListWidget({
    super.key,
    required this.limit,
    required this.eventBus,
    required this.nodeId,
    this.serviceCaller,
  });

  @override
  State<ProjectListWidget> createState() => _ProjectListWidgetState();
}

class _ProjectListWidgetState extends State<ProjectListWidget> {
  List<Map<String, dynamic>>? _projects;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (widget.serviceCaller == null) {
      setState(() => _error = 'Not authenticated');
      return;
    }

    try {
      final result = await widget.serviceCaller!(
        'projectService',
        'findByIsPublicAndLastModifiedDate',
        [[false, ''], [true, '\uf000'], widget.limit],
      );
      setState(() {
        _projects = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _onProjectTap(Map<String, dynamic> project) {
    widget.eventBus.publish(
      'system.selection.project',
      EventPayload(
        type: 'onTap',
        sourceWidgetId: widget.nodeId,
        data: {
          'projectId': project['id'],
          'projectName': project['name'],
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Text('Error: $_error');
    if (_projects == null) return const CircularProgressIndicator();

    return ListView.builder(
      itemCount: _projects!.length,
      itemBuilder: (context, index) {
        final project = _projects![index];
        return ListTile(
          title: Text(project['name'] ?? ''),
          subtitle: Text(project['description'] ?? ''),
          onTap: () => _onProjectTap(project),
        );
      },
    );
  }
}
```

The builder function wires the widget to the SDUI context:

```dart
Widget buildProjectList(SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return ProjectListWidget(
    limit: node.props['limit'] as int? ?? 20,
    serviceCaller: ctx.serviceCaller,
    eventBus: ctx.eventBus,
    nodeId: node.id,
  );
}
```

### 5.2 ServiceCaller vs direct ServiceFactory

Use `ServiceCaller` (the typedef from `SduiRenderContext`), not `ServiceFactory` directly. This keeps widgets decoupled from the Tercen client internals and makes them testable with mock callers.

```dart
// ServiceCaller signature:
typedef ServiceCaller = Future<dynamic> Function(String service, String method, List<dynamic> args);
```

If your widget needs very specific service access not covered by `ServiceCaller`, you can accept `ServiceFactory` as a prop, but prefer `ServiceCaller` when possible.

### 5.3 Graceful degradation

`serviceCaller` can be null (user not authenticated yet). Always handle this:

```dart
if (ctx.serviceCaller == null) {
  return const Text('Sign in to view projects');
}
```

---

## 6. Standalone Mode (Testing Outside the Orchestrator)

Every widget should work in a standalone Flutter app for development and testing.

### 6.1 Standalone test harness

Create `example/main.dart` in your widget library:

```dart
import 'package:flutter/material.dart';
import 'package:tercen_ui_orchestrator/sdui/event_bus/event_bus.dart';
import 'package:tercen_ui_orchestrator/sdui/renderer/sdui_render_context.dart';
import 'package:tercen_ui_orchestrator/sdui/renderer/template_resolver.dart';
import 'package:tercen_ui_orchestrator/sdui/schema/sdui_node.dart';
import 'package:tercen_widget_catalog/tercen_widget_catalog.dart';

// For data-connected widgets:
import 'package:sci_tercen_client/sci_client_service_factory.dart';
import 'package:tercen_ui_orchestrator/sdui/service/service_call_dispatcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create a minimal SDUI context
  final eventBus = EventBus();
  final templateResolver = TemplateResolver();

  // Optional: set up ServiceFactory for data-connected widgets
  ServiceCaller? serviceCaller;
  const token = String.fromEnvironment('TERCEN_TOKEN');
  if (token.isNotEmpty) {
    final factory = await createServiceFactoryForWebApp(token, 'http://127.0.0.1:5400/api/v1');
    final dispatcher = ServiceCallDispatcher(factory);
    serviceCaller = dispatcher.call;
  }

  final renderContext = SduiRenderContext(
    eventBus: eventBus,
    templateResolver: templateResolver,
    serviceCaller: serviceCaller,
  );

  // Debug: log all events
  eventBus.subscribePrefix('system.').listen((event) {
    debugPrint('[event] ${event.type} from ${event.sourceWidgetId}: ${event.data}');
  });

  runApp(MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: buildProjectList(
        SduiNode(type: 'ProjectList', id: 'test-pl', props: {'limit': 10}),
        [],
        renderContext,
      ),
    ),
  ));
}
```

Run with:
```bash
cd example
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 12889 \
  --dart-define=TERCEN_TOKEN=<your-jwt>
```

### 6.2 Testing between-widget events standalone

To test that two widgets communicate correctly:

```dart
// In your test harness, place both widgets side by side
Row(
  children: [
    Expanded(child: buildProjectList(
      SduiNode(type: 'ProjectList', id: 'pl-1', props: {}),
      [], renderContext,
    )),
    Expanded(child: buildWorkflowViewer(
      SduiNode(type: 'WorkflowViewer', id: 'wv-1', props: {}),
      [], renderContext,
    )),
  ],
)
```

Tap a project in the list → WorkflowViewer should react (because they share the same EventBus).

---

## 7. Integration with the Orchestrator

### 7.1 How the orchestrator consumes your library

The orchestrator adds your package as a dependency and calls your registration function at startup. No other integration is needed — the registry, renderer, and EventBus handle everything.

```dart
// In the orchestrator's SduiContext.create():
registerBuiltinWidgets(registry);
registerTercenWidgets(registry);  // ← your library
```

Once registered, the AI can compose your widgets in JSON:

```json
{"type": "ProjectList", "id": "pl-1", "props": {"limit": 20}}
```

### 7.2 How the AI discovers your widgets

The AI discovers available widgets through the `discover_interactions` and widget catalog MCP tools. Your `WidgetMetadata` is the source of truth:

- `description` → AI uses this to decide when to use the widget
- `props` → AI knows what to pass
- `emittedEvents` → AI knows what channels to wire `reactTo` to
- `acceptedActions` → AI knows what gestures are supported

### 7.3 JSON-only vs self-contained widgets

Your widgets can work in two modes:

**Mode A — JSON-composed (Tier 1 style):** The AI composes the full widget tree from primitives + `dataSource`. Your widget is a dumb renderer. This is how Tier 1 works today.

**Mode B — Self-contained (Tier 2):** The AI just says `{"type": "ProjectList", "props": {"limit": 20}}` and your widget handles everything internally: data fetching, rendering, internal events, selection publishing. The AI treats it as a black box.

Mode B is what you're building. The AI picks the widget and its top-level props; the widget owns everything inside.

---

## 8. Known Gaps and Workarounds

### 8.1 SDUI core types — extracted to `sdui` package

The EventBus, SduiNode, WidgetRegistry, behavior widgets, and renderer live in the `../sdui` package. Both the orchestrator and widget libraries depend on it. Import from `package:sdui/sdui.dart`.

### 8.2 Widget metadata → AI discovery pipeline (not yet automated)

The `WidgetMetadata.emittedEvents` and `acceptedActions` fields exist but are not yet read by the MCP discovery tools. The `discover_interactions` tool currently has a static catalog.

**Future**: The MCP server will dynamically generate its interaction catalog from registered widget metadata. For now, when you add a new widget with events, also update the static catalog in `server/bin/mcp_discover.dart` (`_discoverInteractions` function).

### 8.3 Type safety — ALWAYS use PropConverter and Map.from()

Two rules that apply **everywhere** in the SDUI codebase:

**Rule 1: Never cast `as int`, `as double`, `as String` on values from JSON, templates, or Tercen API responses.**
Use `PropConverter.to<T>()` from `package:sdui/sdui.dart`. It handles `int`, `num`, `String`, `null`, and cross-type coercion safely.

```dart
// WRONG — will throw on num, String, or null
final limit = args[2] as int;

// CORRECT
final limit = PropConverter.to<int>(args[2]) ?? 20;
```

**Rule 2: Never cast `as Map<String, dynamic>` on maps from `toJson()` or JSON deserialization.**
Tercen's `toJson()` returns `LinkedMap<dynamic, dynamic>`. JSON deserialization on web returns `_InternalLinkedHashMap<String, dynamic>` which also fails `as` casts in some contexts.

```dart
// WRONG — throws on LinkedMap<dynamic, dynamic>
final user = result as Map<String, dynamic>;

// CORRECT
final user = Map<String, dynamic>.from(result as Map);
```

These two rules prevent the most common runtime errors in the SDUI system. They apply to:
- `ServiceCallDispatcher` (service call args and results)
- `behavior_widgets.dart` (DataSource props, ForEach items)
- `builtin_widgets.dart` (widget props)
- Any new code that touches dynamic data

### 8.4 Service call patterns — two `find*` styles

Tercen services have two kinds of `find*` methods. The dispatcher auto-detects which to use based on the args:

**Pattern A: findStartKeys (range query)** — methods with `startKey, endKey` parameters.
Args: `[startKey, endKey, limit?, skip?, descending?]` where keys are arrays matching the view's index fields.
```dart
// findByIsPublicAndLastModifiedDate expects [isPublic: bool, lastModifiedDate: string]
serviceCaller('projectService', 'findByIsPublicAndLastModifiedDate',
  [[false, ''], [true, '\uf000'], 20]  // gets all projects (public + private)
);
```

**Pattern B: findKeys (key lookup)** — methods with `keys` parameter (a List).
Args: `[keysList]` — a single list element containing the keys to look up.
```dart
// findTeamByOwner expects keys: List (list of owner usernames)
serviceCaller('teamService', 'findTeamByOwner',
  [["owner-username"]]  // note: single list wrapping the keys
);
```

**How the dispatcher distinguishes:** The dispatcher uses a strict 3-step order: (1) `_tryBaseMethod` for `get`/`list`/direct `findStartKeys`/`findKeys`, (2) `_callSpecificMethod` for service-specific handlers, (3) `_tryGenericFind` as a last resort. The generic fallback uses `_findKeysViewName()` mapping for `findKeys` methods. See Section 9.1 for full details.

**Critical:** Always use the EXACT method name from the service factory (e.g., `findTeamByOwner`, NOT `findByOwner`). Use `discover_methods` to verify.

### 8.5 Using the MCP discovery server for catalog authoring

When an AI generates `catalog.json` templates, it MUST use exact Tercen API method names and correct argument patterns. The MCP discovery server provides this information.

The discovery server is **fully static** — method names and signatures come from the `sci_tercen_client` package source, not from a live Tercen instance. No token, no network, no running server needed.

**Option A: Via the orchestrator (automatic)**

When the orchestrator server is running, it spawns the MCP server for Claude Code automatically. Just ask Claude to `discover_methods("teamService")` etc. before writing DataSource nodes.

**Option B: Standalone (for catalog authoring without the orchestrator)**

```bash
# Run the MCP server directly — no token or Tercen instance required
cd tercen_ui_orchestrator/server
claude --mcp-config '{"mcpServers":{"tercen":{"type":"stdio","command":"dart","args":["run","bin/mcp_discover.dart"]}}}'
```

**What the AI MUST do when authoring catalog templates:**
1. Call `discover_methods(serviceName)` for every service used in a DataSource
2. Check the view type: `(startKeys)` vs `(keys)` — this determines the args format
3. Copy the EXACT method name (e.g., `findTeamByOwner`, not `findByOwner`)
4. Use `{{context.username}}` / `{{context.userId}}` for user-specific queries

### 8.6 Date fields are wrapped objects

Tercen dates look like `{"kind": "Date", "value": "2026-01-09T19:00:02.248Z"}`. Access the actual string via `.value`.

### 8.7 Object IDs are in the `id` field (not `_id`)

### 8.8 Theming — semantic tokens only

All styling must use semantic tokens from `tokens.json`. Never use raw hex colors, pixel font sizes, or numeric spacing in templates or widget code.

- **Colors**: Use M3 ColorScheme token names (`primary`, `onSurface`, `surfaceContainerHigh`, etc.)
- **Text styles**: Use M3 TextTheme slot names via `textStyle` prop (`bodySmall`, `labelMedium`, `titleLarge`, etc.)
- **Spacing**: Use token names (`xs`, `sm`, `md`, `lg`, `xl`, `xxl`) in padding/spacing props

See `SDUI_CATALOG_AUTHORING_GUIDE.md` Section 7 for the full token reference.

### 8.9 Catalog authoring for Tier 2 JSON template widgets

For Tier 2 widgets authored as JSON templates (not compiled Dart), see `SDUI_CATALOG_AUTHORING_GUIDE.md` for the complete reference including:
- All available primitive and interactive widgets
- Behavior widget composition patterns
- Data connection patterns (3 args formats)
- Theming tokens
- Working examples

---

## 9.1 Service call dispatcher architecture

The `ServiceCallDispatcher` routes DataSource calls to the correct Tercen API method. Understanding its dispatch order is critical when debugging data connection issues.

**Dispatch order (first match wins):**

1. **`_tryBaseMethod`** — handles `get`, `list`, `findStartKeys` (direct), `findKeys` (direct). These are universal CouchDB-style methods present on every service.

2. **`_callSpecificMethod`** — service-specific handlers with correct named parameters. For example, `findProjectObjectsByLastModifiedDate` is called with `startKey:`, `endKey:`, `limit:` named params. These handlers know the exact Dart method signature.

3. **`_tryGenericFind`** — fallback for `find*` methods not explicitly handled in step 2. Uses `_findKeysViewName()` mapping for `findKeys` methods (the view name may differ from the method name). For `findStartKeys` methods, the method name IS the view name.

**Why the order matters:** The generic fallback uses a heuristic (`args[0] is List` → `findKeys`) that is ambiguous — `findStartKeys` methods also take List args (the start key array). If the generic fallback ran first, it would misroute `findStartKeys` calls as `findKeys` calls. Specific handlers MUST run before the generic fallback.

**Debugging tip:** If a DataSource returns unexpected results or errors, check:
1. Is the method name exact? (Use `discover_methods` to verify.)
2. Is it a `findKeys` or `findStartKeys` method? (Check the view type in `discover_methods` output.)
3. Does `_findKeysViewName()` have a mapping for this method? (findKeys view names sometimes differ from method names.)

## 9.2 PromptRequired behavior widget

`PromptRequired` is a behavior widget for templates that need runtime configuration values the user must provide (or that may already exist in context).

**How it works:**
- Wrap a template subtree in a `PromptRequired` node with a `fields` prop
- Each field: `{name, label, default}` — name is the scope key, label is shown in the dialog, default is pre-filled
- If the value already exists in context or parent scope, the widget renders immediately (no prompt)
- If missing, a "Configure" button is shown; clicking it opens a dialog with defaults pre-filled
- Once submitted, resolved values are exposed in child scope under the field names

**Example from FileNavigator:**
```json
{
  "type": "PromptRequired",
  "id": "{{widgetId}}-prompt",
  "props": {
    "fields": [
      {"name": "projectId", "label": "Project ID", "default": "2076952ae523bb4d472e283b9e000121"}
    ]
  },
  "children": [...]
}
```

**When to use:** Any template widget that requires IDs or configuration that cannot be inferred from the current selection context. The pattern avoids hardcoding IDs in templates while still allowing seamless rendering when values are already available (e.g., from a previous selection event).

## 9. Checklist for Each New Widget

- [ ] Builder function with signature `Widget Function(SduiNode, List<Widget>, SduiRenderContext)`
- [ ] `WidgetMetadata` with accurate `description`, `props`, `emittedEvents`, `acceptedActions`
- [ ] Registered via `registerTercenWidgets()` (or similar exported function)
- [ ] Handles `serviceCaller == null` gracefully
- [ ] Uses `EventBus` for cross-widget events (not callbacks or global state)
- [ ] Uses `widget.<nodeId>.*` channels for internal events
- [ ] Uses `system.selection.*` channels for selection events
- [ ] Works standalone in the example harness
- [ ] Works inside the orchestrator (renders from JSON)
- [ ] Converts `toJson()` maps with `Map<String, dynamic>.from()`
