# Tercen UI Orchestrator — SDUI Architecture Plan

## Changelog

| Version | Date       | Notes |
|---------|------------|-------|
| v4      | 2026-03-10 | Reflects actual implementation: Phase 1 done, Claude CLI integration working (stream-json), WebSocket round-trip with reconnection, streaming chat UI. Added: domain widget data wiring via ServiceFactory, dynamic widget catalog generation for AI system prompt, two-stage AI approach (CLI now, REST API later). Reorganized phases to match reality. |
| v3      | 2026-03-09 | Addressed review: removed widget-to-widget wiring (all comms via EventBus), added structured error responses for AI ops, clarified widget data loading via ServiceFactory + IDs, clarified backend transport (uses existing EventService.channel()), added get_layout_state_tool for AI awareness, removed responsive/mobile scope (web only). |
| v2.1    | 2026-03-09 | Added: Full bootstrap flow (token → ServiceFactory → MCPClient → Conversation), MCP tool categories (7), tool result → widget update propagation (dual path: messageStream + EventBus), grammar docs as AI reference/skill. |
| v2      | 2026-03-09 | Added: Floating window model, layout operations grammar, content operations, widget interaction metadata, system EventBus channels, standard window sizes/alignments, batch operations. |
| v1      | 2026-03-09 | Added AI Chat Widget section: architecture, LLM abstraction reuse from sci, backend-proxied auth, conversation stream rendering, MCP tool integration. |
| v0      | 2026-03-09 | Initial draft. SDUI architecture, unified EventBus, widget catalog with deferred loading, 5-phase implementation plan. |

## Context

Tercen is an AI-driven data analysis platform where users interact through prompts to AI agents. The current orchestrator hosts webapps in iframes with postMessage communication. This doesn't scale well for:
- Multiple instances of the same widget (e.g., several plot viewers)
- AI-composed dashboards and dynamic layouts
- Tight widget-to-widget interactions (drag-and-drop across panels)

We're refactoring to a **Server-Driven UI (SDUI)** architecture: a single Flutter web app where all panels are Flutter widgets described by JSON schemas. AI agents compose widget trees from a catalog of Flutter primitives + Tercen domain widgets.

## Architecture Decisions

1. **No iframes** — single Flutter app, all UI as widgets
2. **Unified EventBus** — single API, transparent routing (local for UI events, backend via sci event system for data/task events)
3. **Two-tier registry** — Tier 1: Flutter primitives (Row, Column, Text...) + Tier 2: Tercen domain widgets (ProjectList, WorkflowViewer...)
4. **AI composes widget trees** via JSON schema — can use both primitives and domain widgets
5. **Domain widgets are opaque to the AI** — AI picks type + props; widget handles data fetching/rendering internally
6. **Widgets load data via ServiceFactory** — props provide IDs, widgets fetch from Tercen internally via `sci_tercen_client`
7. **Floating window model** — all widgets live in draggable/resizable floating windows with standard sizes and alignments
8. **Operations grammar** — AI and user buttons both emit layout operations (addWindow, removeWindow, updateContent, etc.) to `system.layout.op`
9. **No direct widget-to-widget wiring** — all communication via EventBus channels; drag-and-drop uses Flutter's native gesture system
10. **Structured error responses** for AI-facing operations — JSON with success/error so AI can read and act
11. **WidgetMetadata is the single source of truth** — the AI system prompt is generated dynamically from the registry catalog
12. **Two-stage AI integration** — Stage 1: Claude Code CLI (`-p --output-format stream-json`); Stage 2: REST API via `sci_mcp_client`
13. **ServiceFactory is nullable in SduiRenderContext** — app works without auth (chat, Tier-1 widgets); domain widgets degrade gracefully

## Current State (What's Built)

### Phase 1: SDUI Infrastructure — DONE

All files compile clean (`flutter analyze` — no issues).

**Schema** (`lib/sdui/schema/`)
- `sdui_node.dart` — `SduiNode` + `SduiAnnotation`, JSON serialization, `copyWith`
- `layout_operation.dart` — Sealed class, 11 operations (7 window + 4 content), batch support

**Registry** (`lib/sdui/registry/`)
- `widget_metadata.dart` — `WidgetMetadata` + `PropSpec` for AI catalog queries
- `widget_registry.dart` — `WidgetRegistry` with register/lookup/catalog, `SduiWidgetBuilder` typedef
- `builtin_widgets.dart` — 12 Tier-1 widgets: Row, Column, Container, Text, Expanded, SizedBox, Center, ListView, Grid, Card, Padding, Placeholder

**Renderer** (`lib/sdui/renderer/`)
- `template_resolver.dart` — Resolves `{{context.x}}` templates in props
- `sdui_render_context.dart` — Shared context (EventBus + TemplateResolver)
- `sdui_renderer.dart` — Recursive JSON→widget tree with template resolution + error boundaries
- `error_boundary.dart` — Per-node error catching with red fallback UI

**Window Manager** (`lib/sdui/window/`)
- `window_state.dart` — `WindowState`, `WindowSize` (6 presets), `WindowAlignment` (9 presets)
- `window_chrome.dart` — Title bar with minimize/close, dark themed
- `floating_window.dart` — Draggable + resizable window with chrome
- `window_manager.dart` — ChangeNotifier, applies all 11 layout operations, structured JSON error responses, listens to `system.layout.op` on EventBus

**Integration** (`lib/sdui/`)
- `sdui_context.dart` — `SduiContext` factory (creates EventBus + Registry + WindowManager) + `SduiScope` InheritedWidget

### WebSocket Round-Trip — DONE

- `lib/services/orchestrator_client.dart` — Connects to `/ws/chat` and `/ws/ui`, bridges UI commands to EventBus, auto-reconnect with exponential backoff, connection state as `ChangeNotifier`
- `lib/main.dart` — `OrchestratorClientScope` InheritedWidget
- `server/bin/server.dart` — Shelf server with WebSocket handlers

### Claude CLI Integration — DONE

The server spawns `claude -p` as a subprocess for each user message:

```
User message → /ws/chat → Server
  → spawn: claude -p "<message>" --output-format stream-json --verbose
           --strict-mcp-config --mcp-config '{"mcpServers": {}}'
           --system-prompt <SDUI grammar>
  → close stdin (required — claude hangs without this)
  → parse stdout line-by-line (newline-delimited JSON)
  → forward events to /ws/chat: text_delta, tool_start, tool_end, assistant_message
  → extract JSON code blocks with layout ops → dispatch to /ws/ui
  → kill process on "result" event (workaround for stream-json hang bug)
```

**Known issues with Claude CLI subprocess:**
- Must close stdin immediately or claude hangs waiting for input
- Must use `--strict-mcp-config --mcp-config '{"mcpServers": {}}'` to avoid hanging on MCP server connections
- stream-json never exits cleanly after completion — must kill process on `result` event
- Must strip `CLAUDECODE`, `CLAUDE_CODE_SSE_PORT`, `CLAUDE_CODE_ENTRYPOINT` env vars

**Chat panel** (`lib/presentation/widgets/chat_panel.dart`):
- Handles streaming text deltas (live typing effect with spinner)
- Tool call indicators
- Error display
- Connection status dot (green/red)
- Input disabled during streaming

**Server tracks current layout state:**
- Maintains `_currentWindows` map (id → full layout op JSON)
- Injects `<current_layout>` block into each prompt so Claude knows what windows exist
- Claude can use `updateContent` to modify existing windows, `removeWindow` to close them

## SDUI Node Schema

Every node in a content tree:

```json
{
  "type": "PlotViewer",
  "id": "plot-1",
  "props": { "stepId": "{{context.selectedStepId}}" },
  "children": [],
  "annotations": [{ "text": "Volcano plot — DE genes", "position": "top-right" }]
}
```

- `type` (string, required) — registry lookup key
- `id` (string, required) — unique within the window
- `props` (map, optional) — widget-specific config, supports `{{context.x}}` templates
- `children` (list, optional) — child nodes (for layout widgets)
- `annotations` (list, optional) — AI-generated annotations overlay

## Layout Operations Grammar

Both AI and user buttons emit operations. The orchestrator applies them to the current window state.

### Window Operations

| Operation | Description | Required Fields |
|-----------|-------------|-----------------|
| `addWindow` | Create a floating window with SDUI content | `id`, `content`, `size`, `align` |
| `removeWindow` | Close and destroy a window | `windowId` |
| `moveWindow` | Reposition a window | `windowId`, `align` (or `x`/`y`) |
| `resizeWindow` | Change window size | `windowId`, `size` (or `width`/`height`) |
| `focusWindow` | Bring window to front | `windowId` |
| `minimizeWindow` | Collapse window to a tab/icon | `windowId` |
| `restoreWindow` | Restore minimized window | `windowId` |

### Content Operations

| Operation | Description | Required Fields |
|-----------|-------------|-----------------|
| `updateContent` | Replace entire content tree of a window | `windowId`, `content` |
| `addChild` | Add a widget node to a parent node | `parentId`, `content`, `index?` |
| `removeChild` | Remove a widget node | `nodeId` |
| `updateProps` | Change props on an existing node | `nodeId`, `props` |

### Standard Sizes / Alignments

| Size | Width | Height |
|------|-------|--------|
| `small` | 30% | 40% |
| `medium` | 40% | 50% |
| `large` | 60% | 70% |
| `column` | 30% | 100% |
| `row` | 100% | 40% |
| `full` | 100% | 100% |

Alignments: `topLeft`, `topRight`, `bottomLeft`, `bottomRight`, `center`, `left`, `right`, `top`, `bottom`

## Widget Tiers

### Tier 1: Layout Primitives

Stateless builders. AI composes them freely into any structure. They render whatever props and children they receive.

Registered in `builtin_widgets.dart`: Row, Column, Container, Text, Expanded, SizedBox, Center, ListView, Grid, Card, Padding, Placeholder.

### Tier 2: Generic Data Widgets

Generic widgets that render data from any Tercen service. The AI tells them **which service to call and how to display the result**. The widget handles the execution, loading states, and rendering.

**How they work:**
```
AI calls discover_services tool → gets list of services and methods
AI decides which service/method to call for the user's request
AI emits: {"type": "DataTable", "props": {"service": "projectService", "method": "explore", "args": ["all", 0, 20], "columns": ["name", "created"]}}
  ↓
SDUI renderer looks up "DataTable" in WidgetRegistry
  ↓
DataTable widget reads renderContext.serviceFactory
  ↓
Dispatches: serviceFactory.projectService.explore("all", 0, 20)
  ↓
Manages loading → error → data states internally
  ↓
Renders a table with the specified columns
```

**Key insight:** The AI is the brain that maps user intent to service calls. The widget is a generic renderer. This means:
- We build a small set of generic data widgets (DataTable, DataList, DataTree) instead of dozens of domain-specific ones
- The AI discovers available services via an MCP tool — no hardcoded service lists in the system prompt
- Adding a new service to Tercen automatically makes it available to the AI

### Generic Data Widget Types

| Widget | Purpose | Key Props |
|--------|---------|-----------|
| `DataTable` | Tabular data display | service, method, args, columns, sortBy |
| `DataList` | Scrollable list of items | service, method, args, titleField, subtitleField |
| `DataTree` | Hierarchical tree view | service, method, args, labelField, childrenField |
| `DataDetail` | Single object detail view | service, method, args, fields |

All share the same pattern: receive service+method+args in props, call ServiceFactory, render the result using the display config.

### Service Discovery via MCP Tool

Instead of listing all services in the system prompt (which wastes context), the AI discovers services on-demand via an MCP tool exposed to Claude Code:

```
Claude receives user message: "show me my projects"
  ↓
Claude calls discover_services() tool
  ↓
MCP server returns: list of services with their methods and signatures
  ↓
Claude picks projectService.explore("all", 0, 20)
  ↓
Claude emits JSON: {"type": "DataTable", "props": {"service": "projectService", "method": "explore", "args": ["all", 0, 20], "columns": ["name", "created"]}}
  ↓
Widget renders the data
```

The MCP server (`server/bin/mcp_discover.dart`) exposes:
- `discover_services()` — returns all service names
- `discover_methods(service)` — returns methods for a specific service with parameter signatures

This is a stdio MCP server (JSON-RPC 2.0 over stdin/stdout) configured via `--mcp-config` when spawning Claude.

## ServiceFactory Integration

### ServiceFactory Overview

From `sci_tercen_client`, the ServiceFactory provides 20 services. All services share a base CRUD interface:

**Base methods (all services):**
```
get(id) → T
list(ids) → List<T>
create(object) → T
update(object) → String (rev)
delete(id, rev)
findStartKeys(viewName, {startKey, endKey, limit, skip, descending}) → List<T>
findKeys(viewName, {keys}) → List<T>
```

**Services:** projectService, workflowService, userService, teamService, fileService, taskService, tableSchemaService, operatorService, eventService, documentService, folderService, queryService, activityService, persistentService, workerService, cranLibraryService, lockService, garbageCollectorService, subscriptionPlanService, patchRecordService

**Key service-specific methods:**
| Service | Extra Methods |
|---------|---------------|
| projectService | `explore(category, start, limit)`, `recentProjects(userId)`, `cloneProject(...)`, `profiles(id)` |
| workflowService | `getCubeQuery(workflowId, stepId)`, `copyApp(...)` |
| fileService | `upload(file, bytes)`, `download(id)`, `listZipContents(id)` |
| tableSchemaService | `select(tableId, columns, offset, limit)`, `uploadTable(...)` |
| taskService | `runTask(id)`, `cancelTask(id)`, `waitDone(id)`, `getWorkers(...)`, `getTasks(...)` |
| queryService | `jq(expression, limit)` — universal data query via jq syntax |
| eventService | `channel(name)` → Stream, `sendChannel(name, evt)` |
| documentService | `search(query, limit)`, `getLibrary(...)`, `getTercenOperatorLibrary(...)` |
| userService | `connect(user, pass)`, `createToken(...)`, `profiles(id)` |
| teamService | `profiles(id)`, `findTeamByOwner(...)` |

### Bootstrap Flow

```
1. Orchestrator starts → renders immediately (chat works, Tier-1 widgets render)
2. Read JWT token:
   - Dev: String.fromEnvironment('TERCEN_TOKEN')
   - Prod: window.localStorage['authorization']
3. Create ServiceFactory (async):
   - createServiceFactoryForWebApp(tercenToken, serviceUri)
   - Uses HttpAuthClient to inject JWT on all requests
   - Sets ServiceFactory.CURRENT singleton
4. Inject into SDUI:
   - sduiContext.setServiceFactory(factory)
   - Sets templateResolver values (userId, teamId, etc.)
   - Domain widgets now have access → they fetch data and render
```

**Key:** ServiceFactory is nullable in SduiRenderContext. The app is usable before auth completes (chat + Tier-1 widgets work). Domain widgets show a "not authenticated" fallback until ServiceFactory is available.

### SduiRenderContext (extended)

```dart
class SduiRenderContext {
  final EventBus eventBus;
  final TemplateResolver templateResolver;
  final ServiceFactory? serviceFactory;  // null until auth completes
}
```

## Widget Communication

All widget communication goes through the **EventBus**. No direct widget-to-widget wiring.

### EventBus Channels

| Channel | Purpose | Direction |
|---------|---------|-----------|
| `system.theme.*` | Theme changes | Broadcast |
| `system.layout.op` | Layout operations | Widget/AI → WindowManager |
| `system.ai.*` | AI chat events, tool execution | Bidirectional |
| `system.data.*` | Tercen data updates | Backend → Widgets |
| `system.task.*` | Task progress/state | Backend → Widgets |
| `system.auth.*` | Auth state changes | System → All |

### Widget Data Loading

Domain widgets load data through `ServiceFactory`, not through the EventBus. Props provide the IDs needed:

```
Widget receives props: { "stepId": "abc", "workflowId": "def" }
  ↓
Widget reads renderContext.serviceFactory
  ↓
Calls factory.workflowService.get(workflowId), factory.tableSchemaService.select(...)
  ↓
Data loaded via REST/WebSocket + TSON encoding
  ↓
Widget renders
```

The EventBus carries **notifications** (data changed, task completed). Widgets react by re-fetching via ServiceFactory.

## AI Service Discovery via MCP

### Problem

The AI needs to know what Tercen services and methods are available so it can compose the right widget props (`service`, `method`, `args`). Hardcoding this in the system prompt wastes context and goes out of sync.

### Solution: Lightweight MCP Server

A small Dart MCP server (`server/bin/mcp_discover.dart`) runs as a stdio subprocess alongside Claude. It implements JSON-RPC 2.0 over stdin/stdout and exposes discovery tools:

**Tools:**
- `discover_services()` — returns list of all service names with descriptions
- `discover_methods(service)` — returns all methods for a specific service with full parameter signatures and return types

**Configuration:** Passed to Claude via `--mcp-config`:
```json
{
  "mcpServers": {
    "tercen": {
      "type": "stdio",
      "command": "dart",
      "args": ["run", "server/bin/mcp_discover.dart"]
    }
  }
}
```

**The service catalog is generated from the actual `sci_tercen_client` service definitions** — not hardcoded. When a new service or method is added to Tercen, the MCP server automatically exposes it.

The system prompt stays lean — it only describes the SDUI widget types and layout grammar. Service discovery happens via tool calls, keeping context clean.

## AI Integration

### Stage 1: Claude Code CLI + MCP Discovery (Current)

Each user message spawns a `claude -p` subprocess with a lightweight MCP server for service discovery. Stateless per-message (no conversation history). The server injects current layout state into each prompt.

```
User types message → /ws/chat
  → Server prepends <current_layout> with existing windows
  → Spawns: claude -p "<prompt>" --output-format stream-json --verbose
            --mcp-config '{"mcpServers":{"tercen":{"type":"stdio","command":"dart","args":["run","server/bin/mcp_discover.dart"]}}}'
            --system-prompt <SDUI grammar + widget types>
  → Claude may call discover_services / discover_methods tools
  → Streams text deltas to chat panel
  → Extracts JSON code blocks with layout ops → dispatches to /ws/ui
  → Kills process on result event
```

**Limitations of Stage 1:**
- No conversation history (each message is independent)
- Claude can discover services but can't execute queries yet (UI widgets will do that)
- No model selection

### Stage 2: REST API via sci_mcp_client (Future)

Replace CLI subprocess with `MCPClient` from `sci_mcp_client`. This enables:
- Conversation history and context
- MCP tool access (Claude can call Tercen tools to get real data before composing UI)
- Model selection (Anthropic, OpenAI, DeepSeek, etc.)
- Token tracking and rate limiting
- Proper auth via Tercen backend proxy

```
User types message → MCPClient.sendMessage(prompt)
  → MCPClient calls LLM API (proxied through Tercen backend)
  → LLM may call MCP tools (layout_op_tool, widget_catalog_tool, Tercen data tools)
  → Tool results flow back to LLM → LLM continues
  → Conversation.messageStream → Chat UI renders
  → Layout ops dispatched via EventBus
```

**Key reuse from sci:**
- `sci_mcp_client`: MCPClient, Conversation, message types, tool handlers
- `sci_operations`: Tercen tool registry (7 categories)
- `sci_tercen_client`: ServiceFactory, all services

## Implementation Phases

### Phase 1: Core SDUI Infrastructure — DONE

Schema types, widget registry, renderer, EventBus, window manager, floating windows.

### Phase 2: WebSocket + Claude CLI Chat — DONE

WebSocket round-trip, Claude CLI subprocess integration, streaming chat UI, layout state tracking.

### Phase 3: MCP Service Discovery + Generic Data Widgets — NEXT

Build the MCP discovery server and generic data widgets that can render any service call.

**Step 3a: MCP Discovery Server**
- Create: `server/bin/mcp_discover.dart` — stdio MCP server (JSON-RPC 2.0)
  - `discover_services()` tool — returns all service names with descriptions
  - `discover_methods(service)` tool — returns method signatures for a service
  - Service catalog generated from `sci_tercen_client` service definitions
- Modify: `server/bin/server.dart` — pass MCP config to Claude spawn instead of empty `{}`

**Step 3b: ServiceFactory in SDUI**
- Modify: `pubspec.yaml` — add `sci_tercen_client` path dependency
- Modify: `lib/sdui/renderer/sdui_render_context.dart` — add `ServiceFactory?` field
- Modify: `lib/sdui/sdui_context.dart` — add `setServiceFactory()` for late injection
- Modify: `lib/main.dart` — bootstrap auth, call `createServiceFactoryForWebApp()`, inject into SduiContext

**Step 3c: Generic Data Widgets**
- Create: `lib/sdui/registry/data_widgets/data_table_widget.dart` — generic table widget
- Create: `lib/sdui/registry/data_widgets/data_list_widget.dart` — generic list widget
- Create: `lib/sdui/registry/data_widgets.dart` — `registerDataWidgets()` function
- Each widget: reads `service`+`method`+`args` from props → calls ServiceFactory → renders result

**Verification:**
1. `dart analyze server/bin/mcp_discover.dart` — no errors
2. `flutter analyze` — no errors
3. Start server → Claude has access to `discover_services` / `discover_methods` tools
4. Ask Claude "show me my projects" → Claude calls discover_services → picks projectService.explore → emits DataTable widget → widget renders with real data
5. Tier-1 widgets still work as before

### Phase 4: AI Chat Widget (SDUI-registered)

Replace the current placeholder ChatPanel with a proper SDUI-registered AiChat widget. Register in catalog so the AI can reference it.

### Phase 5: Port Domain Widgets

Build additional domain widgets, each following the Phase 3 pattern:

**Order** (least to most coupled):
1. TeamList
2. FileList
3. TaskList
4. WorkflowViewer
5. OperatorBrowser
6. StepViewer / PlotViewer

### Phase 6: REST API Integration (sci_mcp_client)

Replace Claude CLI with `MCPClient` from `sci_mcp_client`:
- Add `sci_mcp_client` dependency
- Create `MCPClient.from(...)` with Tercen tools
- `Conversation.messageStream` drives the chat UI
- Layout operations become MCP tools (`layout_op_tool`, `widget_catalog_tool`, `get_layout_state_tool`)

### Phase 7: Extract Widget Catalog Package

Move domain widgets to `tercen_widget_catalog` (separate repo) with deferred loading.

## To Run

### Development (Stage 1: CLI)

```bash
# Terminal 1: Server
cd server && dart run bin/server.dart

# Terminal 2: Flutter (without Tercen auth — Tier-1 only)
flutter run -d chrome --dart-define=SERVER_URL=ws://localhost:8080

# Terminal 2: Flutter (with Tercen auth — domain widgets work)
flutter run -d chrome \
  --dart-define=SERVER_URL=ws://localhost:8080 \
  --dart-define=TERCEN_TOKEN=<jwt> \
  --dart-define=SERVICE_URI=https://tercen.com/api/v1
```

### Production

```bash
flutter build web
cd server && dart run bin/server.dart  # serves Flutter build + WebSocket
# Open http://localhost:8080
```