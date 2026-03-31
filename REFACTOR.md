# Refactor Summary — 2026-03-31

Major architectural refactor of the SDUI system. All changes committed and pushed across sdui, orchestrator, sci, and tercen_ui_widgets repos.

## 1. StateManager replaces ReactTo, Interaction, StateHolder

**What changed:** Three behavior widgets (ReactTo, Interaction, StateHolder) removed from the sdui package. Replaced by a single `StateManager` (ChangeNotifier) per template widget.

**Where:**
- `sdui/lib/src/state/state_manager.dart` — NEW: StateManager, StateConfig, SelectionConfig, StateManagerScope
- `sdui/lib/src/registry/behavior_widgets.dart` — ReactTo, Interaction, StateHolder registrations and classes removed
- `sdui/lib/src/registry/widget_metadata.dart` — added `stateConfig` field, parsed from `metadata.state` in catalog JSON
- `sdui/lib/src/renderer/sdui_render_context.dart` — added `stateManager` field (set during render pass)

**How it works:**
- Selection config declared in widget metadata: `{selection: {channel, matchField, payloadField}, publishTo: [...]}`
- `matchField` = field on the data item (e.g., `"id"`)
- `payloadField` = field in the event payload (e.g., `"nodeId"`) — bridges semantic mapping
- Action widget reads StateManager at tap time via `findAncestorWidgetOfExactType` (no rebuild dependency)
- ForEach checks `ctx.stateManager.isSelected(itemMap)` inline during render — no per-item listeners
- Selection highlight applied via DecoratedBox with `theme.colors.primaryContainer`

## 2. ComponentHost — per-template rebuild boundary

**What changed:** Every template widget expansion creates a `_ComponentHost` StatefulWidget that owns the StateManager and isolates rebuilds.

**Where:** `sdui/lib/src/renderer/sdui_renderer.dart`

**How it works:**
- `_renderTemplate` returns a `_ComponentHost` instead of a raw widget tree
- ComponentHost listens to StateManager, calls `setState` on change
- `build()` re-renders the template via `widget.renderer.render()`
- DataSource inside keeps cached data (doesn't refetch on selection change)
- Nested components are independent — parent rebuild doesn't force child rebuild

## 3. SkeletonTheme — semantic text roles

**What changed:** All hardcoded token names in archetypes replaced with semantic roles.

**Where:** `lib/sdui/archetypes/skeleton_theme.dart` — NEW

**Roles:** prominent, primary, secondary, muted, action, section. Each maps to a textStyle + color token pair. Archetypes reference `SkeletonTheme.primary.textStyle` instead of `'bodySmall'`.

## 4. Schema generator reads tokens.json

**What changed:** Token definitions in the generated schema come from `tokens.json` (single source of truth), not hardcoded lists.

**Where:** `lib/sdui/validator/schema_generator.dart` — accepts `tokensJson` parameter, extracts color/textStyle/spacing/radius names from it. Adds `roles` section documenting semantic roles.

## 5. catalog.json migrated to formal spec

**What changed:** All 11 widgets rebuilt. 7 fresh from SkeletonTheme + archetypes, 4 copied (ChatBox, HomePanel, MainHeader, TaskMonitor) with StateHolder stripped.

**Where:** `tercen_ui_widgets/catalog.json`

**Key changes:**
- No ReactTo, Interaction, StateHolder, PromptRequired in any template
- ProjectNavigator has `metadata.state` config for selection
- HomePanel: StateHolder removed, DashboardCard pagination temporarily disabled
- Zero raw hex colors, font sizes, or numeric padding in fresh widgets

## 6. ServiceCallDispatcher — spec-driven mappings

**What changed:** Service names, view types, and findKeys view names generated from OpenAPI spec instead of hardcoded.

**Where:**
- `lib/sdui/service/generated_service_map.dart` — NEW: serviceNames, viewTypes, findKeysViewNames (from tercen-api.openapi.json)
- `lib/sdui/service/service_call_dispatcher.dart` — uses `spec.serviceNames`, `spec.viewTypes`, `spec.findKeysViewNames`

## 7. Agent MCP — spec-driven, no hardcoded knowledge

**What changed:** Agent's SDUI MCP server rewritten to read from generated spec files. Hardcoded knowledge files deleted.

**Where:**
- `sci/tercen_agent/src/sdui_server.ts` — rewritten: reads sdui-components.schema.json, sdui-events.json, tercen-api.openapi.json
- `sci/tercen_agent/src/sdui_knowledge.ts` — DELETED
- `sci/tercen_agent/src/service_catalog.ts` — DELETED
- `sci/tercen_agent/src/main.ts` — system prompt updated

**Tools:** find_data, get_primitives, get_events, get_tokens, get_roles, get_intents, get_bindings, render_widget

## 8. render_widget — mandatory validation loop

**What changed:** Agent must use `render_widget` tool instead of outputting raw JSON layout ops. The tool validates all widget types against the component schema before outputting the layout op.

**Where:** `sci/tercen_agent/src/sdui_server.ts` (render_widget function)

**How it works:**
1. Agent calls `render_widget({id, title, content: {...}})`
2. Tool walks content tree, checks every type against `sdui-components.schema.json`
3. Unknown types → returns error listing them, agent retries
4. All valid → outputs JSON code block, Flutter client extracts and renders
5. Client-side validator in WindowManager provides double protection

## 9. Runtime validation in WindowManager

**What changed:** `addWindow` validates content tree against WidgetRegistry before creating window. Unknown types cause rejection with error reported via ErrorReporter.

**Where:** `sdui/lib/src/window/window_manager.dart`

## 10. Other fixes

- **Theme tokens 404 fixed** — mock used `main` branch, tercen-style repo uses `master`
- **Runtime theme fetch removed** — `main.dart` no longer fetches tokens from server, uses compiled defaults
- **`history` icon added** to icon map
- **Event inspector copy button** — mock event inspector has copy-to-clipboard per event
- **Docker image rebuilt** — includes spec files in `/operator/specs/`, updated system prompt

## Generated spec files

| File | Location | Source |
|------|----------|--------|
| `tercen-api.openapi.json` | repo root / Docker `/operator/specs/` | `sci/sci_api/bin/generate_openapi.dart` |
| `sdui-components.schema.json` | repo root / Docker `/operator/specs/` | `flutter test test/sdui/validator/generate_schema_test.dart` |
| `sdui-events.json` | repo root / Docker `/operator/specs/` | `flutter test test/sdui/validator/generate_events_test.dart` |

## Known issues remaining

- Selection highlight has ~50ms delay in ComponentHost architecture (full template re-render on setState)
- ContractBus built but not wired into renderer
- HomePanel DashboardCard pagination disabled (was StateHolder-dependent)
- Agent still may generate ReactTo if it ignores the strict rules — render_widget catches it, but costs a turn
