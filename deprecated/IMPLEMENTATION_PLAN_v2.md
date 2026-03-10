# Tercen UI Orchestrator — SDUI Architecture Plan (v2)

## Changelog

| Version | Date       | Notes |
|---------|------------|-------|
| v2      | 2026-03-09 | Added: Floating window model, layout operations grammar (addWindow, removeWindow, etc.), content operations (addChild, updateProps, etc.), wiring operations, widget interaction metadata format, three interaction levels, system EventBus channels, standard window sizes/alignments, batch operations. User buttons and AI use same operations. |
| v1      | 2026-03-09 | Added AI Chat Widget section: architecture, LLM abstraction reuse from sci, backend-proxied auth, conversation stream rendering, MCP tool integration. Chat is an SDUI widget (always in default layout, repositionable). |
| v0      | 2026-03-09 | Initial draft. SDUI architecture, unified EventBus, widget catalog with deferred loading, 5-phase implementation plan. |

## Context

Tercen is an AI-driven data analysis platform where users interact through prompts to AI agents. The current orchestrator hosts webapps in iframes with postMessage communication. This doesn't scale well for:
- Multiple instances of the same widget (e.g., several plot viewers)
- AI-composed dashboards and dynamic layouts
- Tight widget-to-widget interactions (drag-and-drop across panels)

We're refactoring to a **Server-Driven UI (SDUI)** architecture: a single Flutter web app where all panels are Flutter widgets described by JSON schemas. AI agents compose widget trees from a catalog of Flutter primitives + Tercen domain widgets.

The **AI chat widget** is the primary user interface — users drive all analysis through conversation with AI agents that operate Tercen via MCP tools.

## Architecture Decisions

1. **No iframes** — single Flutter app, all UI as widgets
2. **Unified EventBus** — single API, transparent routing (local for UI events, backend via sci event system for data/task events)
3. **Widget catalog as separate Dart package** — deferred loading, plus test/example widgets in orchestrator
4. **Two-tier registry** — Flutter primitives (Row, Column, Text...) + Tercen domain widgets (PlotViewer, TreeView...)
5. **AI composes widget trees** via JSON schema — layout, props, inter-widget wiring, annotations
6. **Data always from Tercen** — AI operates Tercen via MCP tools, widgets react to state changes
7. **AI can compose from Flutter's full widget catalog** — not just domain widgets, but layout primitives too
8. **LLM calls proxied through Tercen backend** — API keys never reach the browser; full audit trail, rate limiting, data governance
9. **AI chat is an SDUI widget** — registered in catalog, always in default layout, repositionable/resizable but not removable
10. **Floating window model** — all widgets live in draggable/resizable floating windows with standard sizes and alignments
11. **Operations grammar** — AI and user buttons both emit layout operations (addWindow, removeWindow, addWiring, etc.) to `system.layout.op`; single mechanism for all layout changes

## Floating Window Model

All widgets live inside **floating windows** — draggable, resizable containers rendered in a `Stack`. Both AI and user buttons create/manage windows using the same operations grammar.

A floating window contains an **SDUI content tree** — which can be a single widget or a composed layout (Row, Column, Grid with multiple widgets inside).

### Standard Window Sizes (relative to viewport)

| Size | Width | Height |
|------|-------|--------|
| `small` | 30% | 40% |
| `medium` | 40% | 50% |
| `large` | 60% | 70% |
| `column` | 30% | 100% |
| `row` | 100% | 40% |
| `full` | 100% | 100% |

### Standard Alignments

| Alignment | Position |
|-----------|----------|
| `topLeft` | snaps to top-left |
| `topRight` | snaps to top-right |
| `bottomLeft` | snaps to bottom-left |
| `bottomRight` | snaps to bottom-right |
| `center` | centered |
| `left` | left edge, vertically centered |
| `right` | right edge, vertically centered |
| `top` | top edge, horizontally centered |
| `bottom` | bottom edge, horizontally centered |

After initial placement, users can freely drag to reposition and resize.

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

- `type` (string, required) — registry lookup key (Flutter primitive or Tercen domain widget)
- `id` (string, required) — unique within the window, used for wiring
- `props` (map, optional) — widget-specific config, supports `{{context.x}}` templates
- `children` (list, optional) — child nodes (for layout widgets like Row, Column, Grid)
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

### Content Operations (modify content inside a window)

| Operation | Description | Required Fields |
|-----------|-------------|-----------------|
| `updateContent` | Replace entire content tree of a window | `windowId`, `content` |
| `addChild` | Add a widget node to a parent node | `parentId`, `content`, `index?` |
| `removeChild` | Remove a widget node | `nodeId` |
| `updateProps` | Change props on an existing node | `nodeId`, `props` |

### Wiring Operations

| Operation | Description | Required Fields |
|-----------|-------------|-----------------|
| `addWiring` | Connect widget A's event to widget B's action | `source`, `target`, `transform?` |
| `removeWiring` | Disconnect a wiring | `wiringId` or `source`+`target` |

### Batch Operations

Multiple operations in a single message (atomic):

```json
{
  "ops": [
    {"op": "addWindow", "id": "win-1", "size": "column", "align": "left",
     "content": {"type": "ProjectNav", "id": "pnav-1"}},
    {"op": "addWindow", "id": "win-2", "size": "column", "align": "right",
     "content": {"type": "ProjectNav", "id": "pnav-2"}},
    {"op": "addWiring",
     "source": {"widgetId": "pnav-1", "event": "drag-item"},
     "target": {"widgetId": "pnav-2", "action": "drop-accept"}}
  ]
}
```

### Examples

**User clicks "Open Project Navigator" button:**
```json
{"op": "addWindow", "id": "win-pnav", "size": "column", "align": "left",
 "content": {"type": "ProjectNav", "id": "project-nav-1", "props": {"teamId": "{{context.teamId}}"}}}
```

**AI creates a 5x5 image grid:**
```json
{"op": "addWindow", "id": "win-grid", "size": "large", "align": "center",
 "content": {
   "type": "Grid", "id": "img-grid", "props": {"columns": 5},
   "children": [
     {"type": "ImageRenderer", "id": "img-1", "props": {"uri": "/api/image/1"}},
     {"type": "ImageRenderer", "id": "img-2", "props": {"uri": "/api/image/2"}},
     "... (25 total)"
   ]
 }}
```

**AI creates two side-by-side plots with cross-highlighting:**
```json
{"ops": [
  {"op": "addWindow", "id": "win-plots", "size": "large", "align": "center",
   "content": {
     "type": "Row", "id": "plot-row",
     "children": [
       {"type": "PlotViewer", "id": "plot-1", "props": {"stepId": "abc"}},
       {"type": "PlotViewer", "id": "plot-2", "props": {"stepId": "def"}}
     ]
   }},
  {"op": "addWiring",
   "source": {"widgetId": "plot-1", "event": "item-selected"},
   "target": {"widgetId": "plot-2", "action": "highlight"},
   "transform": "payload.itemId"},
  {"op": "addWiring",
   "source": {"widgetId": "plot-2", "event": "item-selected"},
   "target": {"widgetId": "plot-1", "action": "highlight"},
   "transform": "payload.itemId"}
]}
```

## Widget Interaction Metadata

Each widget declares its interaction surface in `WidgetMetadata`. The AI queries this to know what's available and what wiring is possible.

```json
{
  "type": "PlotViewer",
  "tier": 2,
  "description": "Interactive plot viewer for Tercen computation steps",
  "props": {
    "stepId": {"type": "string", "required": true},
    "chartType": {"type": "enum", "values": ["scatter", "bar", "heatmap"], "default": "scatter"}
  },
  "events": {
    "item-selected": {"payload": {"itemId": "string", "itemType": "string"}},
    "zoom-changed": {"payload": {"xRange": "[number, number]", "yRange": "[number, number]"}},
    "drag-item": {"payload": {"itemId": "string", "data": "any"}}
  },
  "actions": {
    "setStepId": {"params": {"stepId": "string"}},
    "highlight": {"params": {"itemIds": "string[]"}},
    "drop-accept": {"params": {"itemId": "string", "data": "any"}},
    "resetZoom": {"params": {}}
  },
  "gestures": ["clickable", "draggable", "zoomable"]
}
```

## Interaction Levels

### Level 1: Internal (no schema involvement)
Widget handles its own gestures — scrolling a list, clicking a button, text editing. Built into widget code.

### Level 2: Widget-to-Widget (wiring in operations)
AI or user defines these connections via `addWiring` operations:
```json
{"op": "addWiring",
 "source": {"widgetId": "plot-1", "event": "item-selected"},
 "target": {"widgetId": "table-1", "action": "highlight"},
 "transform": "payload.itemId"}
```
Compiled into EventBus subscriptions at runtime:
- Source publishes: `eventBus.publish('widget.plot-1.item-selected', payload)`
- Wiring bridges to: `eventBus.publish('widget.table-1.highlight', transformed)`
- Target listens: `eventBus.subscribe('widget.table-1.highlight', handler)`

### Level 3: Widget-to-System (fixed EventBus channels)
Well-known channels, no per-layout wiring needed. Widgets subscribe automatically.

| Channel | Purpose | Direction |
|---------|---------|-----------|
| `system.theme.*` | Theme changes | Broadcast |
| `system.layout.*` | Layout mutations (operations) | Widget/AI → Orchestrator |
| `system.ai.*` | AI chat events, tool execution | Bidirectional |
| `system.data.*` | Tercen data updates | Backend → Widgets |
| `system.task.*` | Task progress/state | Backend → Widgets |
| `system.auth.*` | Auth state changes | System → All |

The `system.layout.*` channel is how both AI and user buttons submit operations — they publish an operation payload to `system.layout.op`, and the orchestrator's window manager applies it.

## AI Chat Widget

### Overview

The chat widget is the primary user interface. Users prompt AI agents that operate Tercen via MCP tools. The AI drives workflows, creates plots, queries data — widgets react to the resulting state changes.

### Architecture

```
┌─────────────────────────────────────────────────┐
│  Flutter Chat Widget (SDUI)                     │
│  ├── Text input + send button                   │
│  ├── Message list (scrollable)                  │
│  │   ├── UserPrompt bubbles                     │
│  │   ├── Answer bubbles (markdown rendered)     │
│  │   ├── Thinking blocks (collapsible)          │
│  │   ├── Tool call indicators (expandable)      │
│  │   └── Error messages                         │
│  └── Model selector (dropdown)                  │
└──────────────────┬──────────────────────────────┘
                   │ Conversation.messageStream
                   │ (Dart broadcast stream)
┌──────────────────┴──────────────────────────────┐
│  MCPClient (from sci_mcp_client)                │
│  ├── McpClientAnthropic                         │
│  └── McpClientOpenai                            │
│  Manages: tool loop, message history, tokens    │
└──────────────────┬──────────────────────────────┘
                   │ HTTP (proxied)
┌──────────────────┴──────────────────────────────┐
│  Tercen Backend (proxy)                         │
│  ├── /_anthropic  → Anthropic API               │
│  ├── /_openrouter → OpenRouter (GPT, Grok,      │
│  │                  DeepSeek, Gemini)            │
│  └── MCP Server (Tercen tools)                  │
└─────────────────────────────────────────────────┘
```

### Reuse from sci

The sci codebase already provides the full LLM client layer. Key components to reuse:

**`sci_mcp_client` package** (add as dependency):
- `MCPClient` abstract base + `McpClientAnthropic` + `McpClientOpenai` — multi-provider factory
- `Conversation<T>` — message history, `messageStream` (broadcast), `actionStream`
- Sealed message types: `UserPrompt`, `Answer`, `Thinking`, `ErrorMessage`, `Debug`
- `ToolHandler` + `ToolContext` — tool execution with Tercen service access
- `McpLLM` model definitions with `Value<McpLLM>` for reactive model switching

**What sci handles (no need to rebuild):**
- LLM API calls (Anthropic + OpenAI/OpenRouter)
- Tool execution loop (LLM requests tool → execute → return result → LLM continues)
- Message history management and context window tracking
- Token counting (input/output per request)
- Provider-specific auth headers and message formats
- Cache control (Anthropic prompt caching)

### What We Build (Flutter Chat UI)

The chat widget consumes `Conversation.messageStream` and renders it:

```
lib/sdui/widgets/ai_chat/
  ai_chat_widget.dart         # Main widget: input + message list + model selector
  chat_message_list.dart      # Scrollable message list
  chat_bubble.dart            # Individual message rendering (user/assistant/thinking/tool/error)
  chat_input.dart             # Text field + send button + keyboard shortcuts
  model_selector.dart         # Dropdown for McpLLM switching
  tool_call_indicator.dart    # Expandable tool call display (name, input, output)
  markdown_renderer.dart      # Markdown rendering for AI responses
```

**Key behaviors:**
- Listens to `Conversation.messageStream` — renders each `Message` variant
- `UserPrompt` → right-aligned user bubble
- `Answer` → left-aligned assistant bubble with markdown rendering
- `Thinking` → collapsible thinking block (shows Claude's reasoning)
- `Debug` → hidden by default, toggle-able for developers
- `ErrorMessage` → error styled bubble
- Tool calls shown inline as expandable cards (tool name, status, input/output)
- Model selector uses `Value<McpLLM>` — switching model mid-conversation supported

**EventBus integration:**
- Chat publishes to `ai.tool-executed` when a tool completes (other widgets can react)
- Chat publishes to `ai.layout-compose` when AI decides to modify the layout
- Chat subscribes to `ui.chat-focus` for programmatic focus (e.g., from keyboard shortcut)

### Auth Flow

```
1. User logs into Tercen (existing auth)
2. Tercen JWT token available in orchestrator context
3. MCPClient created with: MCPClient.from(tercenBaseUri, jwtToken, serviceFactory, llmModel)
4. Client sends requests to Tercen backend (/_anthropic, /_openrouter)
5. Backend proxies to LLM API with its own API keys
6. API keys never reach the browser
```

**Regulatory benefits:**
- Full audit trail server-side (every prompt, response, tool call logged)
- Rate limiting per user/team
- Data governance — sensitive data filtered before reaching LLM
- Key rotation in one place (server config)
- Compliance-friendly (GDPR, HIPAA)

### LLM Provider Support

Already supported via sci (no additional work):

| Provider | Client | Route | Models |
|----------|--------|-------|--------|
| Anthropic | `McpClientAnthropic` | `/_anthropic` | Claude 3.5 Sonnet, Claude 4, etc. |
| OpenAI | `McpClientOpenai` | `/_openrouter` | GPT-4.1 |
| DeepSeek | `McpClientOpenai` | `/_openrouter` | DeepSeek Chat v3 |
| Grok | `McpClientOpenai` | `/_openrouter` | Grok 3 |
| Gemini | `McpClientOpenai` | `/_openrouter` | Gemini 2.5 Pro |

Adding a new provider = adding an entry to `McpLLM.llms` list + ensuring the backend proxy route exists.

## Implementation Phases

### Phase 1: Core SDUI Infrastructure

Create the SDUI engine alongside existing code (no breaking changes yet).

**New files:**
```
lib/sdui/
  schema/
    sdui_node.dart            # SduiNode, SduiAnnotation
    layout_operation.dart     # LayoutOperation sealed class (all op types)
  registry/
    widget_registry.dart      # WidgetRegistry with SduiWidgetBuilder typedef
    widget_metadata.dart      # WidgetMetadata, PropSpec (for AI catalog queries)
    builtin_widgets.dart      # Tier 1: Row, Column, Container, Text, ListView, Grid, etc.
    test_widgets.dart         # Built-in example widgets for testing
  renderer/
    sdui_renderer.dart        # Recursive JSON → widget tree renderer
    sdui_render_context.dart  # WidgetRegistry + EventBus + template values
    wiring_scope.dart         # InheritedWidget providing EventBus to subtree
    template_resolver.dart    # {{context.x}} resolution
    error_boundary.dart       # Per-node error catching with fallback UI
  window/
    window_manager.dart       # State management for open windows + operation handler
    floating_window.dart      # Draggable/resizable window widget
    window_state.dart         # WindowState model (position, size, z-index, content, wiring)
    window_chrome.dart        # Title bar, close/minimize buttons, resize handles
  event_bus/
    event_bus.dart            # Unified API: publish/subscribe
    event_payload.dart        # EventPayload {type, sourceWidgetId, data, timestamp}
    channel_registry.dart     # Maps channel patterns to transport (local vs backend)
    local_event_transport.dart    # In-process Dart StreamControllers
    backend_event_transport.dart  # Bridges to sci EventService via WebSocket
```

**Key types:**
- `SduiWidgetBuilder = Widget Function(SduiNode, List<Widget> children, SduiRenderContext)`
- `WidgetRegistry.register(type, builder, metadata)` / `.getBuilder(type)` / `.catalog`
- `EventBus.publish(channel, payload)` / `.subscribe(channel, handler)`
- `ChannelRegistry` defaults: `ui.*`, `theme.*`, `layout.*` → local; `data.*`, `task.*`, `ai.*` → backend

**Reuse from existing code:**
- `lib/core/theme/` — entire theme system (AppTheme, AppColors, AppSpacing, etc.) — no changes
- `lib/presentation/widgets/splitter.dart` — register as SDUI widget
- `lib/presentation/providers/theme_provider.dart` — adapt to publish on EventBus instead of MessageRouter
- `lib/presentation/providers/splash_provider.dart` — reuse with minor adaptation

### Phase 2: AI Chat Widget

Build the chat UI and integrate with sci's LLM client layer.

**New dependency in pubspec.yaml:**
- `sci_mcp_client` (path dependency to `../sci/sci_mcp_client`)

**New files:**
```
lib/sdui/widgets/ai_chat/
  ai_chat_widget.dart         # Main SDUI-registered widget
  chat_message_list.dart      # Scrollable message list
  chat_bubble.dart            # Message rendering per type
  chat_input.dart             # Text input + send
  model_selector.dart         # LLM model dropdown
  tool_call_indicator.dart    # Expandable tool call cards
  markdown_renderer.dart      # Markdown in AI responses
```

**Register in widget catalog:**
```dart
registry.register('AiChat', aiChatBuilder, metadata: WidgetMetadata(
  type: 'AiChat',
  description: 'AI conversation interface with MCP tool integration',
  tier: 2,
  props: { 'collapsed': PropSpec(type: 'bool', defaultValue: false) },
  emittedEvents: ['tool-executed', 'layout-compose'],
  acceptedActions: ['focus', 'setContext'],
));
```

### Phase 3: Port Remaining Widgets to SDUI

Convert each "webapp" from an iframe-hosted app to a registered Flutter widget.

**Order** (least to most coupled):
1. Toolbar
2. TaskManager
3. ProjectNav
4. StepViewer / PlotViewer

For each: create a `SduiWidgetBuilder` function, register it, define `WidgetMetadata` (props, events, actions), replace postMessage with EventBus calls.

### Phase 4: Replace Workbench with Window Manager

- `OrchestratorScreen` renders `WindowManager` (Stack of FloatingWindows) instead of `Workbench`
- Default startup emits a batch of `addWindow` operations to create initial layout (AiChat, toolbar, etc.)
- User buttons in toolbar emit `addWindow` operations to `system.layout.op`
- AI emits the same operations through the chat → EventBus

**Remove:**
- `lib/services/message_router.dart` → replaced by EventBus
- `lib/services/webapp_registry.dart` → replaced by WidgetRegistry
- `lib/domain/models/message_envelope.dart`, `webapp_registration.dart`, `webapp_instance.dart`
- `lib/presentation/widgets/webapp_iframe.dart`, `panel_host.dart`
- `lib/presentation/widgets/workbench.dart` → replaced by WindowManager + FloatingWindows
- `lib/presentation/providers/webapp_provider.dart` → logic into EventBus + WindowManager
- `lib/presentation/providers/layout_provider.dart` → replaced by WindowManager

### Phase 5: AI Layout Composition (MCP Tools)

Expose the operations grammar and widget catalog as MCP tools so the AI can compose layouts:

```
lib/sdui/ai/
  widget_catalog_tool.dart    # MCP tool: AI queries available widgets + their metadata (props, events, actions)
  layout_op_tool.dart         # MCP tool: AI submits layout operations (addWindow, addWiring, etc.)
  annotate_tool.dart          # MCP tool: AI adds annotations to existing widget nodes
```

The `layout_op_tool` accepts the same JSON operations grammar defined above. The AI sends ops → tool publishes to `system.layout.op` → WindowManager applies them.

### Phase 6: Extract Widget Catalog Package

Move domain widgets to `tercen_widget_catalog` (separate repo). Orchestrator imports via deferred loading:

```dart
import 'package:tercen_widget_catalog/tercen_widget_catalog.dart' deferred as catalog;

Future<void> registerTercenWidgets(WidgetRegistry registry) async {
  await catalog.loadLibrary();
  catalog.registerAll(registry);
}
```

## Window Manager

The orchestrator maintains a `WindowManager` that:
- Holds the list of open `FloatingWindow` instances (id, position, size, z-index, content tree, wiring)
- Listens to `system.layout.op` on the EventBus for incoming operations
- Applies operations (add/remove/move/resize/focus/minimize/restore windows, content mutations, wiring changes)
- Notifies the UI to rebuild via `ChangeNotifier`
- Persists window state to localStorage for session recovery

```
lib/sdui/
  window/
    window_manager.dart        # State management for open windows
    floating_window.dart       # Draggable/resizable window widget
    window_state.dart          # WindowState model (position, size, z-index, content, wiring)
    window_chrome.dart         # Title bar, close/minimize buttons, resize handles
    operation_handler.dart     # Parses and applies layout operations
```

## Verification

1. **Phase 1:** Unit tests for SduiNode.fromJson/toJson, WidgetRegistry register/lookup, SduiRenderer with builtin widgets, EventBus local publish/subscribe, template resolution
2. **Phase 2:** Chat widget renders conversation stream; send message → receive AI response with tool calls; model switching works; tool call indicators expand/collapse
3. **Phase 3:** Each ported widget renders correctly in isolation via test layout JSON
4. **Phase 4:** Default startup operations produce working layout with floating windows; drag/resize/minimize/restore work; user buttons and AI both create windows via same operations channel
5. **Phase 5:** AI can query widget catalog and compose a layout that renders correctly
6. **Phase 6:** `flutter build web` with deferred loading produces working app; widget catalog loads on demand

## Start Point

Begin with **Phase 1** — create the `lib/sdui/` directory with schema types, widget registry, renderer, and EventBus. Then **Phase 2** — the AI chat widget, since it's the primary user interface and validates the SDUI + EventBus architecture end-to-end.
