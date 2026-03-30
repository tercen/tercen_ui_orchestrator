# Formal Spec Pipeline — Status & Continuation Guide

## Goal

AI generates correct, renderable SDUI widgets with zero manual intervention. Five formal specs, one MCP server interface.

## What's Done (committed)

### Mock Orchestrator (`lib/mock/`)
Fully working. Run via JetBrains "Mock Orchestrator" config. See `docs/MOCK_ORCHESTRATOR.md`.

### Template Validator (`lib/sdui/validator/`)
Fully working. 7 rule categories. See `docs/SDUI_VALIDATOR.md`.

## What's Built But Not Committed (in working tree)

These are complete, tested, but not yet wired into the running system. They live in the working tree for the next session to integrate.

### 1. OpenAPI Spec Generator (`../sci/sci_api_gen/lib/src/openapi/`)
- `openapi_spec_generator.dart` — generates `tercen-api.openapi.json` from `ApiLibrary`
- `../sci/sci_api/bin/generate_openapi.dart` — entry point
- **Output**: 245 schemas, 195 paths, auto-generated from the same introspection as TS/Python/R generators
- **Status**: Works. Generates correct spec. Not in CI yet.
- **Next**: Add to CI pipeline alongside other generators. Decide where the output file lives.

### 2. SDUI Component Schema Generator (`lib/sdui/validator/schema_generator.dart`)
- Walks WidgetRegistry, emits `sdui-components.schema.json`
- **Output**: 65 components (54 Tier 1 + 11 Tier 2), tokens, bindings
- **Status**: Works via `flutter test test/sdui/validator/generate_schema_test.dart`
- **Next**: Decide if this runs in CI or on-demand. Output file location.

### 3. Event Spec Generator (`lib/sdui/validator/event_spec_generator.dart`)
- Extracts channels, payloads, intents from catalog
- **Output**: `sdui-events.json` — 17 channels, 11 intents, 3 intra-widget patterns
- **Status**: Works via `flutter test test/sdui/validator/generate_events_test.dart`
- **Next**: This is a seed — the event spec should eventually be maintained as source of truth (not generated from catalog).

### 4. Widget Archetypes (`lib/sdui/archetypes/`)
- 5 patterns: data-list, detail-view, dashboard-card, form, master-detail
- `archetype_expander.dart` — takes archetype + slots → complete widget JSON
- **Status**: Works. Tested via `test/sdui/archetypes/expander_test.dart`. Generated widget passes validator with 0 errors.
- **Next**: Wire into MCP server. Add more archetypes as needed.

### 5. Contract Bus (`lib/sdui/contracts/`)
- Typed event contracts replacing string-addressed pub/sub
- 8 built-in contracts: selection, navigation, dataChanged, command, notification, taskStatus, formSubmit, stateChange
- `ContractBus` sits on top of `EventBus` with field mapping + filtering
- **Status**: Works. 7 tests passing. NOT wired into the SDUI renderer yet.
- **Next** (the big integration work):
  - Add `produces`/`consumes` fields to `WidgetMetadata` (in `../sdui`)
  - Add `produces`/`consumes` to catalog widget metadata entries
  - Wire `ContractBus` into `SduiContext` alongside `EventBus`
  - Add contract-aware `Action` variant (or extend Action to support contracts)
  - Add contract-aware `DataSource.refreshOn` (subscribe by contract instead of channel)
  - Update archetypes to use contracts instead of channel names

### 6. SDUI Authoring MCP Server (`server/bin/mcp_sdui_author.dart`)
- 8 tools: find_data, suggest_widget, get_primitives, get_events, get_tokens, get_intents, list_archetypes, save_to_catalog
- Reads generated spec files, exposes task-oriented tools
- **Status**: Works standalone. Tested via stdin pipe.
- **Next**: Create run config. Register with Claude Code. Add `validate` and `preview` tools (need to call flutter test / mock orchestrator).

## Integration Order for Next Session

1. **Commit the OpenAPI generator** to sci repo (2 files, standalone)
2. **Wire ContractBus into SduiContext** — add to `SduiContext.create()`, make it available alongside EventBus
3. **Extend WidgetMetadata** in `../sdui` with `produces`/`consumes` fields
4. **Migrate one widget** (e.g., ProjectNavigator) to use contracts — proves the system works end-to-end
5. **Register MCP server** with Claude Code for testing
6. **Add generated specs to CI** — run generators on change

## Architecture Diagram

```
tercen-api.openapi.json          ← generated from sci_api_gen (data layer)
sdui-components.schema.json      ← generated from WidgetRegistry (UI layer)
sdui-events.json                 ← seeded from catalog (event channels)
sdui-contracts.json              ← contract registry (semantic event types)
tokens.json                      ← tercen-style repo (theme)
archetypes/*.dart                ← 5 widget patterns (recipes)

        ALL read by
            ↓

SDUI MCP Server (server/bin/mcp_sdui_author.dart)
  find_data → searches OpenAPI spec
  suggest_widget → archetype expander
  validate → template validator
  preview → mock orchestrator
  save_to_catalog → writes catalog.json
  get_primitives / get_events / get_tokens / get_intents

        Called by
            ↓

AI Agent (never reads specs directly)
```
