# Widget Developer Guide — Real Tercen Integration

This guide is for developers building widgets that run inside the Tercen UI Orchestrator and connect to real data on **stage.tercen.com**.

---

## How widgets work

Widgets are **JSON templates** in `catalog.json`. They compose Tier 1 primitives that the SDUI renderer already knows how to render. There is no compiled Dart from the widget library running inside the orchestrator.

A template is a tree of nodes. Data fetching happens through `DataSource` nodes, which call the Tercen API automatically when the orchestrator is authenticated.

**The templates don't change between mock and real mode** — the orchestrator's auth state is what changes. With a valid JWT token, `DataSource` calls go to the real Tercen instance.

---

## What you need

### 1. JWT token for stage.tercen.com

```bash
# Option A: Tercen CLI
tercenctl context to-token --validity 30d

# Option B: Tercen UI → Profile → API Tokens → Create
```

### 2. The orchestrator running

```bash
# Terminal 1: server
cd tercen_ui_orchestrator/server
dart run bin/server.dart

# Terminal 2: Flutter app
cd tercen_ui_orchestrator
flutter run -d chrome \
  --dart-define=SERVER_URL=ws://127.0.0.1:8080 \
  --dart-define=TERCEN_TOKEN=<jwt> \
  --web-hostname 127.0.0.1 \
  --web-port 12888
```

The orchestrator reads `orchestrator.config.json` for the widget library URL and auto-loads `catalog.json` on startup. The home config in `catalog.json` opens the default windows.

### 3. API discovery

Use the MCP discovery server to find exact method names before writing templates:

```bash
cd tercen_ui_orchestrator/server
claude --mcp-config '{"mcpServers":{"tercen":{"type":"stdio","command":"dart","args":["run","bin/mcp_discover.dart"]}}}'
```

Then ask:
- `discover_services()` — list all services
- `discover_methods("tableSchemaService")` — exact method signatures

**Always use exact method names.** `findByOwner` vs `findTeamByOwner` will fail silently.

---

## Available Tier 1 primitives

These are the building blocks your templates compose:

| Category | Widgets |
|----------|---------|
| Layout | `Row`, `Column`, `Container`, `Expanded`, `SizedBox`, `Center`, `Spacer`, `ListView`, `Grid`, `Card`, `Padding` |
| Display | `Text`, `SelectableText`, `Icon`, `Divider`, `Chip`, `CircleAvatar`, `Image`, `Tooltip`, `ProgressBar`, `Placeholder`, `LoadingIndicator` |
| Interactive | `TextField`, `ElevatedButton`, `TextButton`, `IconButton`, `Switch`, `Checkbox`, `DropdownButton` |
| Behaviour | `DataSource`, `ForEach`, `Action`, `ReactTo`, `Conditional`, `PromptRequired`, `StateHolder`, `Sort`, `Filter` |
| Domain | `DataTable`, `DirectedGraph`, `ImageViewer`, `TabbedImageViewer`, `TabbedDataTable` |
| Orchestrator | `ChatPanel` — chat interface with Claude Code streaming |

The domain primitives handle the complex rendering (scroll-synced grids, graph layouts, image zoom/pan). Your templates compose these — the hard UI work is already done.

---

## Available API methods

These are the methods your `DataSource` nodes can call. If you need a method not listed here, the orchestrator dev adds it to the `ServiceCallDispatcher`.

### tableSchemaService

| Method | Args | Returns |
|--------|------|---------|
| `select` | `[schemaId, columnNames, offset, limit]` | `{nRows, columns: [{name, type, values}]}` — **column-major** |
| `selectCSV` | `[schemaId, columnNames, offset, limit, separator?, quote?, encoding?]` | `{csv: String, schemaId}` — defaults: `,`, `true`, `utf-8` |
| `getStepImages` | `[workflowId, stepId]` | `{stepName, images: [{schemaId, filename, mimetype, url}]}` |

### fileService

| Method | Args | Returns |
|--------|------|---------|
| `download` | `[fileDocumentId]` | `{content: String, fileId}` — UTF-8 text only |
| `downloadUrl` | `[fileDocumentId]` | `{url: String, fileId}` — authenticated URL for any file type. Use with `ImageViewer` or `Image`. |

### operatorContext (write data back)

Saves data back to Tercen. Requires a `taskId` (CubeQueryTask or RunWebAppTask).

| Method | Args | Returns |
|--------|------|---------|
| `saveTable` | `[taskId, columns]` | `{success: bool, taskId}` |
| `saveTables` | `[taskId, tablesList]` | `{success: bool, taskId}` |

Column format:
```json
[taskId, [
  {"name": ".ri", "type": "int32", "values": [0, 1, 2]},
  {"name": ".ci", "type": "int32", "values": [0, 0, 0]},
  {"name": "corrected", "type": "double", "values": [1.5, 2.3, 0.8]}
]]
```

Column types: `int32`, `double` (or `float64`), `string`.

### Generic methods (all services)

| Method | Args | Notes |
|--------|------|-------|
| `get` | `[id]` | Single object by ID |
| `list` | `[ids]` | Batch get |
| `findStartKeys` variants | `[startKey, endKey, limit?, skip?, descending?]` | Range query — method name varies per service |
| `findKeys` variants | `[keys]` | Key lookup — method name varies per service |

Service-specific handlers exist for: `projectService`, `teamService`, `workflowService`, `userService`, `projectDocumentService`, `operatorService`. Use `discover_methods()` to find exact signatures.

---

## Writing a template

### Structure

Every entry in `catalog.json` has `metadata` + `template`:

```json
{
  "metadata": {
    "type": "MyWidget",
    "tier": 2,
    "description": "What it does — the AI reads this to decide when to use it",
    "props": {
      "projectId": {"type": "string", "required": false, "description": "Project ID"}
    },
    "emittedEvents": ["system.selection.project"],
    "acceptedActions": ["onTap"],
    "handlesIntent": [
      {
        "intent": "openProject",
        "propsMap": {"projectId": "projectId"},
        "windowTitle": "Project: {{projectName}}",
        "windowSize": "large"
      }
    ]
  },
  "template": {
    "type": "PromptRequired",
    "id": "{{widgetId}}-prompt",
    "props": {
      "fields": [{"name": "projectId", "label": "Project ID", "default": ""}]
    },
    "children": [...]
  }
}
```

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
    {"type": "Conditional", "props": {"visible": "{{loading}}"}, "children": [
      {"type": "Center", "id": "...", "children": [
        {"type": "LoadingIndicator", "id": "...", "props": {"text": "Loading..."}}
      ]}
    ]},
    {"type": "Conditional", "props": {"visible": "{{error}}"}, "children": [
      {"type": "Text", "id": "...", "props": {"text": "{{errorMessage}}", "color": "error"}}
    ]},
    {"type": "Conditional", "props": {"visible": "{{ready}}"}, "children": [
      ...actual content using {{data}}...
    ]}
  ]
}
```

`DataSource` exposes to children:
- `{{data}}` — API response
- `{{loading}}` — true while fetching
- `{{error}}` — true if call failed
- `{{errorMessage}}` — error text
- `{{ready}}` — data is available

### Template bindings

- `{{props.myProp}}` — caller's props (from metadata defaults or explicit values)
- `{{widgetId}}` — the caller's node ID (use for unique child IDs)
- `{{context.username}}` / `{{context.userId}}` — logged-in user
- `{{data}}` — from parent `DataSource`
- `{{item}}` / `{{_index}}` — from parent `ForEach`

### Rules

1. **Use exact method names.** Verify with `discover_methods()`.
2. **Match arg format.** `(startKeys)` = `[startKey, endKey, limit]`. `(keys)` = `[keysList]`.
3. **Use `PromptRequired`** for IDs the user must provide (projectId, workflowId).
4. **All child IDs must be unique.** Use `{{widgetId}}-suffix` pattern.

---

## Home configuration

`catalog.json` can include a `"home"` key that defines which windows open on startup:

```json
{
  "widgets": [ ... ],
  "home": {
    "windows": [
      {"type": "ChatPanel", "id": "chat-1", "size": "column", "align": "right", "title": "Claude Code"},
      {"type": "WorkflowViewer", "id": "wv-1", "size": "medium", "align": "center", "props": {}}
    ]
  }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | Widget type (must be registered) |
| `id` | No | Window ID (auto-generated if omitted) |
| `size` | No | `small` (30%x40%), `medium` (40%x50%), `large` (60%x70%), `column` (30%x100%), `row` (100%x40%), `full` (100%x100%) |
| `align` | No | Initial position: `center`, `left`, `right`, `top`, `bottom` |
| `title` | No | Window title bar text |
| `props` | No | Props passed to the widget |

Home windows open after the catalog loads. Widgets with `handlesIntent` in their metadata can open secondary windows when the user interacts (e.g., clicking a project opens a WorkflowViewer).

---

## Widget priority

| Widget | Status | What to do |
|--------|--------|------------|
| **workflow-viewer** | Template exists | Verify `getWorkflowGraph` works with real data |
| **data-table** | Template exists | Verify `TabbedDataTable` handles column-major data. CSV export via `selectCSV`. |
| **file-navigator** | Template needed | Use `projectDocumentService` methods. Check if `ForEach` + layout is sufficient or if a tree primitive is needed. |
| **home-panel** | Template needed | Multiple `DataSource` nodes for projects, user info. `Grid`/`Card` layout. |
| **png-viewer** | Template needed | `fileService.downloadUrl` → `ImageViewer` |
| **audit-trail** | Template needed | Use `discover_methods('activityService')` first |
| **document-editor** | Template needed | `fileService.download` for text, `downloadUrl` for binary |
| **chat-box** | Built-in | `ChatPanel` is a Tier 1 primitive. Add to home config. |
| **main-header** | Template needed | Static branding: `Row` + `Image`/`Icon` + `Text` |

---

## Testing

After updating `catalog.json`:

1. Push to the widget library repo (or commit locally if using a local path)
2. Restart the orchestrator server (it re-fetches the catalog on startup)
3. The Flutter app auto-loads the catalog after auth
4. Home windows open automatically

Verify in browser console:
- `[catalog] Auto-loaded N widget(s)` — catalog loaded
- `[home] Opening N home window(s)` — home config applied
- `[SduiRenderer] >>> expanding template "WorkflowViewer"` — templates rendering
- `[DataSource]` logs — API calls executing

---

## Common pitfalls

| Problem | Fix |
|---------|-----|
| `DataSource` returns unexpected results | Verify method name is exact. Check `findStartKeys` vs `findKeys` arg format. |
| Template shows nothing | Check browser console for `[SduiRenderer] UNKNOWN type` — widget type not registered |
| Data loads in mock but not real mode | Check orchestrator has `TERCEN_TOKEN` set. Look for `[auth]` logs. |
| `select()` data looks wrong | It's column-major: each column has a `values` array. `TabbedDataTable` handles this. |
| Images don't load | Use `downloadUrl` (returns authenticated URL), not `download` (returns text). |
| `findStartKeys` vs `findKeys` | `discover_methods` output shows `(startKeys)` or `(keys)` — use matching arg format |
