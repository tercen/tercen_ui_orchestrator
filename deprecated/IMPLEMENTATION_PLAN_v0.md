# Tercen UI Orchestrator — SDUI Architecture Plan (v0)

## Changelog

| Version | Date       | Notes |
|---------|------------|-------|
| v0      | 2026-03-09 | Initial draft. SDUI architecture, unified EventBus, widget catalog with deferred loading, 5-phase implementation plan. Needs iteration on: schema details, wiring model, EventBus transport bridge, AI composition interface. |

## Context

Tercen is an AI-driven data analysis platform where users interact through prompts to AI agents. The current orchestrator hosts webapps in iframes with postMessage communication. This doesn't scale well for:
- Multiple instances of the same widget (e.g., several plot viewers)
- AI-composed dashboards and dynamic layouts
- Tight widget-to-widget interactions (drag-and-drop across panels)

We're refactoring to a **Server-Driven UI (SDUI)** architecture: a single Flutter web app where all panels are Flutter widgets described by JSON schemas. AI agents compose widget trees from a catalog of Flutter primitives + Tercen domain widgets.

## Architecture Decisions

1. **No iframes** — single Flutter app, all UI as widgets
2. **Unified EventBus** — single API, transparent routing (local for UI events, backend via sci event system for data/task events)
3. **Widget catalog as separate Dart package** — deferred loading, plus test/example widgets in orchestrator
4. **Two-tier registry** — Flutter primitives (Row, Column, Text...) + Tercen domain widgets (PlotViewer, TreeView...)
5. **AI composes widget trees** via JSON schema — layout, props, inter-widget wiring, annotations
6. **Data always from Tercen** — AI operates Tercen via MCP tools, widgets react to state changes
7. **AI can compose from Flutter's full widget catalog** — not just domain widgets, but layout primitives too

## SDUI JSON Schema

```json
{
  "id": "layout-main",
  "version": 1,
  "root": {
    "type": "Row",
    "id": "main-row",
    "children": [
      {
        "type": "ProjectNav",
        "id": "project-nav-1",
        "props": { "width": 280, "teamId": "{{context.teamId}}" }
      },
      {
        "type": "PlotViewer",
        "id": "plot-1",
        "props": { "stepId": "{{context.selectedStepId}}" },
        "annotations": [{ "text": "Volcano plot — DE genes", "position": "top-right" }]
      }
    ]
  },
  "wiring": [
    {
      "source": { "widgetId": "project-nav-1", "event": "step-selected" },
      "target": { "widgetId": "plot-1", "action": "setStepId" },
      "transform": "payload.stepId"
    }
  ]
}
```

Every node: `type` (registry key), `id` (unique, used in wiring), `props` (config with `{{context.x}}` templates), `children`, optional `annotations`.

## Implementation Phases

### Phase 1: Core SDUI Infrastructure

Create the SDUI engine alongside existing code (no breaking changes yet).

**New files:**
```
lib/sdui/
  schema/
    sdui_node.dart            # SduiNode, SduiLayout, SduiWiring, SduiAnnotation
  registry/
    widget_registry.dart      # WidgetRegistry with SduiWidgetBuilder typedef
    widget_metadata.dart      # WidgetMetadata, PropSpec (for AI catalog queries)
    builtin_widgets.dart      # Tier 1: Row, Column, Container, Text, ListView, etc.
    test_widgets.dart         # Built-in example widgets for testing
  renderer/
    sdui_renderer.dart        # Recursive JSON → widget tree renderer
    sdui_render_context.dart  # WidgetRegistry + EventBus + template values
    wiring_scope.dart         # InheritedWidget providing EventBus to subtree
    template_resolver.dart    # {{context.x}} resolution
    error_boundary.dart       # Per-node error catching with fallback UI
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

### Phase 2: Port Existing Widgets to SDUI

Convert each "webapp" from an iframe-hosted app to a registered Flutter widget.

**Order** (least to most coupled):
1. Toolbar
2. AiChat
3. TaskManager
4. ProjectNav
5. StepViewer / PlotViewer

For each: create a `SduiWidgetBuilder` function, register it, define `WidgetMetadata` (props, events, actions), replace postMessage with EventBus calls.

### Phase 3: Replace Workbench with SDUI Renderer

- `OrchestratorScreen` renders `SduiRenderer(layout: defaultLayout)` instead of `Workbench`
- Default layout JSON reproduces the current workbench structure
- `LayoutProvider` drives mutations to the SDUI layout (tool strip open/close, resize, etc.)

**Remove:**
- `lib/services/message_router.dart` → replaced by EventBus
- `lib/services/webapp_registry.dart` → replaced by WidgetRegistry
- `lib/domain/models/message_envelope.dart`, `webapp_registration.dart`, `webapp_instance.dart`
- `lib/presentation/widgets/webapp_iframe.dart`, `panel_host.dart`
- `lib/presentation/providers/webapp_provider.dart` → logic into EventBus + RenderContext

### Phase 4: AI Layout Composition

```
lib/sdui/ai/
  layout_composer.dart        # AI tool output → SduiLayout
  widget_catalog_tool.dart    # MCP tool exposing registry catalog to AI
  compose_layout_tool.dart    # MCP tool: AI sends SDUI JSON → orchestrator renders
  annotate_tool.dart          # MCP tool: add annotations to widget nodes
```

### Phase 5: Extract Widget Catalog Package

Move domain widgets to `tercen_widget_catalog` (separate repo). Orchestrator imports via deferred loading:

```dart
import 'package:tercen_widget_catalog/tercen_widget_catalog.dart' deferred as catalog;

Future<void> registerTercenWidgets(WidgetRegistry registry) async {
  await catalog.loadLibrary();
  catalog.registerAll(registry);
}
```

## Inter-Widget Wiring

Declared in schema, compiled at render time into EventBus subscriptions:
- Widgets publish: `eventBus.publish('widget.${node.id}.step-selected', payload)`
- Widgets listen: `eventBus.subscribe('widget.${node.id}.setStepId', handler)`
- Wiring entries bridge source events to target actions, with optional `transform` (dot-path extraction)

## Verification

1. **Phase 1:** Unit tests for SduiNode.fromJson/toJson, WidgetRegistry register/lookup, SduiRenderer with builtin widgets, EventBus local publish/subscribe, template resolution
2. **Phase 2:** Each ported widget renders correctly in isolation via test layout JSON
3. **Phase 3:** Default SDUI layout matches current workbench visually; all interactions work (tool strip toggle, splitter resize, bottom panel, theme switch)
4. **Phase 4:** AI can query widget catalog and compose a layout that renders correctly
5. **Phase 5:** `flutter build web` with deferred loading produces working app; widget catalog loads on demand

## Start Point

Begin with **Phase 1** — create the `lib/sdui/` directory with schema types, widget registry, renderer, and EventBus. This is additive (no existing code changes) and enables everything that follows.
