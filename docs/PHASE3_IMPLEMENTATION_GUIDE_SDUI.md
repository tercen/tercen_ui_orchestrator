# Phase 3 — Real Tercen Integration Guide (SDUI Native)

> **Status:** Enriched with verified answers from codebase analysis. Remaining gaps requiring development are marked with **[GAP]**.

---

## How It Works

Widgets run in the orchestrator as **JSON templates** defined in `catalog.json`. They compose Tier 1 primitives (`DataSource`, `ForEach`, `DataTable`, `DirectedGraph`, etc.) that the SDUI renderer already knows how to render. Data fetching happens through `DataSource` behavior widgets which call the Tercen API via `ServiceCaller`.

**There is no compiled Dart code from `tercen_ui_widgets` running inside the orchestrator.** The standalone Flutter apps in `widgets/` are for development/testing outside the orchestrator. Inside the orchestrator, everything is driven by `catalog.json`.

### What Phase 3 means

The templates already reference real Tercen API methods (e.g., `workflowService.getWorkflowGraph`, `tableSchemaService.select`). When the orchestrator has a valid JWT token, `ServiceCaller` is set on the render context and `DataSource` calls go to the real Tercen instance. **The templates don't change between mock and real mode** — the `ServiceCaller` is what changes.

Phase 3 work is:

1. **Verify `catalog.json` entries** use correct API method names and argument patterns
2. **Ensure `ServiceCallDispatcher` supports all needed methods** — add any that are missing
3. **Test with a real JWT token** against stage.tercen.com
4. **Address the 3 remaining gaps** (see below)

---

## Architecture Summary

| Layer | What | Where |
|-------|------|-------|
| **Tier 1 primitives** | 41 compiled Dart widgets (layout, display, interactive, behavior, domain-specific) | `sdui` package — already registered |
| **Tier 2 templates** | JSON compositions of Tier 1 primitives | `tercen_ui_widgets/catalog.json` — loaded via `loadCatalog()` |
| **ServiceCallDispatcher** | Routes `DataSource` service calls to real Tercen API | `tercen_ui_orchestrator/lib/sdui/service/service_call_dispatcher.dart` |
| **Standalone apps** | Full Flutter apps for dev/testing outside orchestrator | `tercen_ui_widgets/widgets/<name>/` |

### Available Tier 1 primitives

| Category | Widgets |
|----------|---------|
| Layout | `Row`, `Column`, `Container`, `Expanded`, `SizedBox`, `Center`, `Spacer`, `ListView`, `Grid`, `Card`, `Padding` |
| Display | `Text`, `SelectableText`, `Icon`, `Divider`, `Chip`, `CircleAvatar`, `Image`, `Tooltip`, `ProgressBar`, `Placeholder`, `LoadingIndicator` |
| Interactive | `TextField`, `ElevatedButton`, `TextButton`, `IconButton`, `Switch`, `Checkbox`, `DropdownButton` |
| Behavior | `DataSource`, `ForEach`, `Action`, `ReactTo`, `Conditional`, `PromptRequired`, `StateHolder`, `Sort`, `Filter` |
| Domain-specific | `DataTable`, `DirectedGraph`, `ImageViewer`, `TabbedImageViewer`, `TabbedDataTable` |

The domain-specific primitives handle complex rendering (scroll-synced grids, graph layouts, tabbed image viewers). Templates compose these — the hard UI work is already done in compiled Dart.

### How catalog loading works

1. User clicks "Load Library" in orchestrator toolbar (or server loads on startup)
2. Server fetches `catalog.json` from GitHub repo → serves via `GET /api/widget-catalog`
3. Client calls `registry.loadCatalog(catalog)` → registers each entry as a template
4. When AI emits `{"type": "WorkflowViewer", ...}`, the renderer expands the template and recursively renders the Tier 1 primitives
5. `DataSource` nodes call `ServiceCaller` → `ServiceCallDispatcher` → real Tercen API

---

## Prerequisites

### 1. Get a JWT token for stage.tercen.com

```bash
# Option A: Tercen CLI
tercenctl context to-token --validity 30d

# Option B: Tercen UI
# Profile → API Tokens → Create
```

The JWT contains the API endpoint in its `iss` claim. The orchestrator extracts this automatically.

### 2. Repos cloned side by side

```
Documents/GitHub/
├── sdui/                          # SDUI framework
├── tercen_ui_orchestrator/        # Orchestrator app
├── tercen_ui_widgets/             # Widget templates + standalone apps
└── sci_tercen_client/             # (optional) For browsing API source
```

---

## Verified ServiceCallDispatcher Methods

These are the **exact methods currently implemented** that `DataSource` nodes in templates can call. Only these work via `ServiceCaller`:

### tableSchemaService

| Method | Args | Returns |
|--------|------|---------|
| `select` | `[schemaId, columnNames: List<String>, offset: int, limit: int]` | `{nRows: int, columns: [{name, type, values}]}` — **column-major** |
| `selectCSV` | `[schemaId, columnNames, offset, limit, separator?, quote?, encoding?]` | `{csv: String, schemaId: String}` — defaults: `,`, `true`, `utf-8` |
| `getStepImages` | `[workflowId, stepId]` | `{stepName, images: [{schemaId, filename, mimetype, url}]}` |

> **Column-major data:** `select()` returns columns where each has a `values` array. The Tier 1 `DataTable` and `TabbedDataTable` primitives must handle this format internally. If they expect row-major, a transpose is needed inside the primitive — not in the template.

### fileService

| Method | Args | Returns |
|--------|------|---------|
| `download` | `[fileDocumentId]` | `{content: String, fileId: String}` — **UTF-8 text only** |
| `downloadUrl` | `[fileDocumentId]` | `{url: String, fileId: String}` — authenticated URL for any file type (images, ZIPs, etc.). Pass to `ImageViewer`'s `url` prop or `Image`'s `src` prop. |

### Generic methods (all services)

| Method | Args | Notes |
|--------|------|-------|
| `get` | `[id]` | Single object by ID |
| `list` | `[ids: List<String>]` | Batch get |
| `findStartKeys` variants | `[startKey, endKey, limit?, skip?, descending?]` | Range query — method name varies per service |
| `findKeys` variants | `[keys: List]` | Key lookup — method name varies per service |

### Service-specific handlers

Exist for: `projectService`, `teamService`, `workflowService`, `userService`, `projectDocumentService`, `operatorService`.

Use `discover_methods('<serviceName>')` via the MCP server to get exact method signatures and argument patterns.

---

## Catalog Template Authoring

### Data flow pattern

Every data-connected template follows this pattern:

```json
{
  "type": "DataSource",
  "id": "{{widgetId}}-ds",
  "props": {
    "service": "workflowService",
    "method": "getWorkflowGraph",
    "args": ["{{workflowId}}"]
  },
  "children": [
    {"type": "Conditional", "props": {"visible": "{{loading}}"}, "children": [...]},
    {"type": "Conditional", "props": {"visible": "{{error}}"}, "children": [...]},
    {"type": "Conditional", "props": {"visible": "{{ready}}"}, "children": [
      ...actual content using {{data}}...
    ]}
  ]
}
```

`DataSource` exposes these scope variables to children:
- `{{data}}` — the resolved API response
- `{{loading}}` — true while fetching
- `{{error}}` — true if call failed
- `{{errorMessage}}` — error description
- `{{ready}}` — true when data is available (`!loading && !error`)

### Critical rules for templates

1. **Use exact method names.** `findTeamByOwner` not `findByOwner`. Use `discover_methods()` to verify.
2. **Match the `findStartKeys` vs `findKeys` arg format.** Check `discover_methods` output: `(startKeys)` = range query args, `(keys)` = key list args.
3. **Use `{{context.username}}` / `{{context.userId}}`** for user-specific queries.
4. **Use `PromptRequired`** when a template needs runtime IDs (projectId, workflowId) that may or may not be in scope from a previous selection.

### Widget-specific template notes

**WorkflowViewer** — already in `catalog.json`, uses `DataSource(workflowService.getWorkflowGraph)` → `DirectedGraph`. Verify the method exists in the dispatcher.

**DataTableViewer** — already in `catalog.json`, uses `DataSource(tableSchemaService.select)` → `TabbedDataTable`. Verify the `TabbedDataTable` Tier 1 primitive handles column-major data correctly.

**file-navigator** — needs a template that composes `DataSource(projectDocumentService.findProjectObjectsByLastModifiedDate)` → tree display. Check if a tree/list Tier 1 primitive exists or if `ForEach` + nested layout is sufficient.

**home-panel** — compose with multiple `DataSource` nodes for projects, user info, activity. Use `Grid`/`Card` layout.

**png-viewer** — use `DataSource(fileService.downloadUrl)` to get an authenticated URL, pass to `ImageViewer`'s `url` prop.

**chat-box** — talks to orchestrator WebSocket, not Tercen API. Read `orchestrator_client.dart` and `chat_panel.dart` for protocol. May be redundant with the built-in chat panel.

**audit-trail** — use `discover_methods('activityService')` and `discover_methods('taskService')` to find exact methods before authoring the template.

**main-header** — static branding. Simple template with `Row`, `Image`/`Icon`, `Text`.

---

## Gaps — Features That Need Development

### ~~GAP 1: Binary file download~~ — RESOLVED

`fileService.downloadUrl` now returns an authenticated URL that works for any file type. `ImageViewer` and `Image` primitives already accept URL strings. No base64 encoding needed.

### ~~GAP 2: CSV export via ServiceCaller~~ — RESOLVED

`tableSchemaService.selectCSV` is now wired in the dispatcher. Returns `{csv: String, schemaId: String}`. Defaults: separator `,`, quote `true`, encoding `utf-8`.

### GAP 3: Annotation save API (Blocks: data-table cell editing)

**Problem:** The data-table mock has `saveAnnotations(sourceTableId, projectId, edits)`. No corresponding method was found in `tableSchemaService` or elsewhere in `sci_tercen_client`.

**Needs investigation:**
- Does Tercen have a table annotation/edit API?
- Is this handled through a different service?
- Does this feature need to be deferred?

**Owner:** Both (needs API investigation first)

---

## Standalone Mode (Testing Outside the Orchestrator)

The standalone Flutter apps in `widgets/` can also be connected to real Tercen data for development and testing. This is separate from the orchestrator integration.

### Auth bootstrap (confirmed working)

`createServiceFactoryForWebApp()` from `package:sci_tercen_client/sci_service_factory_web.dart`:

```dart
Future<ServiceFactory> createServiceFactoryForWebApp({
  String? tercenToken,   // Falls back to dart-define TERCEN_TOKEN
  String? serviceUri,    // Falls back to dart-define SERVICE_URI
})
```

### Update main.dart

```dart
import 'package:sci_tercen_client/sci_service_factory_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: true);

  if (useMocks) {
    setupServiceLocator(useMocks: true);
  } else {
    try {
      final factory = await createServiceFactoryForWebApp();
      final taskId = Uri.base.queryParameters['taskId'];
      final projectId = Uri.base.queryParameters['projectId'];
      setupServiceLocator(useMocks: false, factory: factory, taskId: taskId, projectId: projectId);
    } catch (e) {
      print('Tercen init failed: $e — falling back to mocks');
      setupServiceLocator(useMocks: true);
    }
  }
  // ... rest unchanged
}
```

### Run standalone with real data

```bash
flutter run -d chrome \
  --dart-define=USE_MOCKS=false \
  --dart-define=TERCEN_TOKEN=<jwt> \
  --dart-define=SERVICE_URI=https://stage.tercen.com \
  --web-hostname 127.0.0.1 \
  --web-port 12889
```

> `SERVICE_URI` is the base URL (e.g., `https://stage.tercen.com`), not the API path.

### Implement real services per widget

Create `lib/implementations/services/real_<name>_service.dart` using `ServiceFactory`:

```dart
class RealDataService implements DataService {
  final ServiceFactory factory;
  RealDataService({required this.factory, this.projectId});

  @override
  Future<TableSchema> getSchema(String tableId) async {
    final schema = await factory.tableSchemaService.get(tableId);
    return TableSchema(id: schema.id, name: schema.name ?? '', ...);
  }
}
```

### Critical rules for service implementations

1. **Never `as Map<String, dynamic>`** — use `Map<String, dynamic>.from(result as Map)`
2. **Never `as int`/`as double`** — use `(value as num?)?.toInt() ?? 0`
3. **Tercen dates are wrapped:** `{"kind": "Date", "value": "2026-01-09T..."}`  — access via `(field as Map)['value']`
4. **Object IDs use `id` field** (not `_id`)

### EventBus for standalone mode

Each widget has local `EventBus` and `EventPayload` classes. These are **NOT compatible** with the SDUI version:

| Behavior | SDUI (`package:sdui`) | Widget (local copy) |
|----------|----------------------|---------------------|
| `publish()` to non-existent channel | Auto-creates channel, event delivered | **Silently drops event** |
| `subscribePrefix()` | Tracks prefix subs, auto-wires new channels | **One-shot only**, misses later channels |

If the standalone apps also need correct EventBus behavior, replace local copies with `package:sdui` imports:

```dart
// Replace: import '../domain/services/event_bus.dart';
// With:    import 'package:sdui/sdui.dart' show EventBus, EventPayload;
```

### Dependencies for standalone mode

Update each widget's `pubspec.yaml` to align versions:

```yaml
dependencies:
  sdui:
    path: ../../../sdui
  sci_tercen_client:
    git:
      ref: 1.16.1    # Match orchestrator version (widgets currently use 1.12.0)
      url: https://github.com/tercen/sci_tercen_client
      path: sci_tercen_client
```

---

## Testing Inside the Orchestrator

1. Start the orchestrator server:
   ```bash
   cd tercen_ui_orchestrator/server
   dart run bin/server.dart
   ```

2. Start the orchestrator Flutter app:
   ```bash
   cd tercen_ui_orchestrator
   flutter run -d chrome \
     --dart-define=SERVER_URL=ws://127.0.0.1:8080 \
     --dart-define=TERCEN_TOKEN=<jwt> \
     --web-hostname 127.0.0.1 \
     --web-port 12888
   ```

3. Load the widget library via toolbar "Load Library" → provide the `tercen_ui_widgets` GitHub repo URL

4. Ask the AI to show a widget: "Show me a data table for table XYZ"

5. Verify in browser console:
   - `[WidgetRegistry] loadCatalog: N widget(s)` — templates loaded
   - `[SduiRenderer] >>> expanding template "WorkflowViewer"` — template rendering
   - `[DataSource]` logs — API calls executing

---

## API Discovery

Use the MCP discovery server to find exact method names before authoring templates:

```bash
cd tercen_ui_orchestrator/server
dart run bin/mcp_discover.dart
```

Or in Claude Code:
```bash
claude --mcp-config '{"mcpServers":{"tercen":{"type":"stdio","command":"dart","args":["run","bin/mcp_discover.dart"]}}}'
```

Then ask:
- `discover_services()` — list all services
- `discover_methods("tableSchemaService")` — exact method signatures

**Always use exact method names.** `findByOwner` vs `findTeamByOwner` will fail silently.

---

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| `LinkedMap` cast failures | Always `Map<String, dynamic>.from(result as Map)` |
| `type 'int' is not a subtype of type 'double'` | Use `(value as num?)?.toDouble()` |
| Date fields returning a Map instead of String | Access `.value` key: `(date as Map)['value']` |
| Template shows "Not authenticated" | Check that orchestrator has a valid `TERCEN_TOKEN` and `ServiceCaller` is set |
| `DataSource` returns unexpected results | Verify method name is exact. Check `findStartKeys` vs `findKeys` arg format. |
| Orchestrator can't find widget type | Verify type name in `catalog.json` metadata matches what AI emits |
| `findStartKeys` vs `findKeys` confusion | Check `discover_methods` output: `(startKeys)` = range query, `(keys)` = key list |
| `select()` returns column-major data | Tier 1 `DataTable`/`TabbedDataTable` must handle this — verify they do |
| `build/` removed from git | **NEVER** add `build/` to `.gitignore`. Tercen serves from `build/web/` in git. |

---

## Checklist

### Orchestrator mode (catalog templates)

- [ ] Verify each `catalog.json` entry uses correct Tercen API method names
- [ ] Verify argument patterns match `findStartKeys` vs `findKeys` format
- [ ] Ensure all referenced methods exist in `ServiceCallDispatcher`
- [ ] Test with real JWT token against stage.tercen.com
- [ ] Address GAP 1 (binary download) for png-viewer
- [ ] Address GAP 2 (CSV export) for data-table
- [ ] Investigate GAP 3 (annotation save) for data-table

### Standalone mode (Flutter apps)

- [ ] Create `real_<name>_service.dart` per widget
- [ ] Update `service_locator.dart` to accept `ServiceFactory`
- [ ] Update `main.dart` for `USE_MOCKS=false` with JWT auth
- [ ] Replace local EventBus with `package:sdui` imports
- [ ] Align `sci_tercen_client` to `ref: 1.16.1`
- [ ] Test standalone against stage.tercen.com
- [ ] Run `flutter build web` and commit `build/`

---

## Widget Priority

| Priority | Widget | Orchestrator readiness | Notes |
|----------|--------|------------------------|-------|
| 1 | **workflow-viewer** | Template exists in catalog.json | Verify `getWorkflowGraph` dispatcher method exists |
| 2 | **data-table** | Template exists in catalog.json | Verify `TabbedDataTable` handles column-major data. CSV export needs GAP 2. |
| 3 | **file-navigator** | Template needed | Author template using `projectDocumentService` |
| 4 | **home-panel** | Template needed | Author template using `projectService`, `userService` |
| 5 | **png-viewer** | Template needed | Use `fileService.downloadUrl` → `ImageViewer` |
| 6 | **audit-trail** | Template needed | Need `discover_methods` for activity/task services first |
| 7 | **document-editor** | Template needed | Text files work now; binary files need GAP 1 |
| 8 | **chat-box** | N/A | Uses orchestrator WebSocket — may be redundant with built-in chat |
| 9 | **main-header** | Template needed | Static — trivial to author |
