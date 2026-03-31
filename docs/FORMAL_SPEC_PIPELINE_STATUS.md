# Formal Spec Pipeline — Status

## Goal

AI generates correct, renderable SDUI widgets with zero manual intervention. Specs are the single source of truth. No hardcoded knowledge.

## Architecture

```
tokens.json (tercen-style)          ← design values (single source of truth)
       ↓
SkeletonTheme (archetypes)          ← semantic roles → token names
       ↓
sdui-components.schema.json         ← generated from WidgetRegistry + tokens.json
sdui-events.json                    ← generated from catalog metadata
tercen-api.openapi.json             ← generated from sci_api_gen

       ALL read by
            ↓

Agent SDUI MCP Server (tercen_agent/src/sdui_server.ts)
  find_data       → searches OpenAPI spec
  get_primitives  → widget types, props, rules
  get_roles       → semantic text roles
  get_tokens      → color, textStyle, spacing, radius
  get_events      → EventBus channels, intents
  get_bindings    → template expression syntax

       Called by
            ↓

AI Agent (never reads specs directly)
```

## Component Status

### Committed & Working

| Component | Location | Status |
|-----------|----------|--------|
| **StateManager** | `sdui/lib/src/state/state_manager.dart` | Per-widget state, ComponentHost rebuild boundary |
| **ComponentHost** | `sdui/lib/src/renderer/sdui_renderer.dart` | Every template = isolated rebuild unit |
| **SkeletonTheme** | `lib/sdui/archetypes/skeleton_theme.dart` | 6 semantic text roles, layout constants |
| **Archetypes** | `lib/sdui/archetypes/` | 5 patterns (data-list, detail-view, dashboard-card, form, master-detail) |
| **Schema generator** | `lib/sdui/validator/schema_generator.dart` | Reads tokens.json, 66 components |
| **Event spec generator** | `lib/sdui/validator/event_spec_generator.dart` | 17 channels, 11 intents |
| **OpenAPI generator** | `sci/sci_api_gen/` | 246 schemas, 22 services |
| **Template validator** | `lib/sdui/validator/template_validator.dart` | 7 rule categories |
| **Mock orchestrator** | `lib/mock/` | Renders widgets with mock data, event inspector |
| **Agent MCP server** | `sci/tercen_agent/src/sdui_server.ts` | Spec-driven, no hardcoded knowledge |
| **catalog.json** | `tercen_ui_widgets/catalog.json` | Migrated to formal spec architecture |
| **Contract bus** | `lib/sdui/contracts/` | Typed event contracts (not yet wired to renderer) |
| **MCP SDUI Author** | `server/bin/mcp_sdui_author.dart` | Dev-mode authoring server (8 tools) |

### Removed

| Component | Reason |
|-----------|--------|
| **ReactTo** | Replaced by StateManager selection |
| **Interaction** | Replaced by StateManager |
| **StateHolder** | Replaced by StateManager |
| **PromptRequired** | Props come from intent system |
| **sdui_knowledge.ts** | Replaced by spec files |
| **service_catalog.ts** | Replaced by OpenAPI spec |

### State Config (metadata.state)

Selection state declared in widget metadata, not template tree:

```json
{
  "metadata": {
    "type": "ProjectNavigator",
    "state": {
      "selection": {
        "channel": "navigator.focusChanged",
        "matchField": "id",
        "payloadField": "nodeId"
      },
      "publishTo": ["navigator.focusChanged"]
    }
  }
}
```

- `matchField`: field on the data item ("id")
- `payloadField`: field in the event payload ("nodeId")
- StateManager bridges the semantic mapping

### Semantic Roles (SkeletonTheme)

| Role | textStyle | color | Used for |
|------|-----------|-------|----------|
| prominent | titleMedium | onSurface | Widget titles |
| primary | bodySmall | onSurface | Main item text |
| secondary | labelSmall | onSurfaceMuted | Supporting text |
| muted | labelSmall | onSurfaceDisabled | Timestamps |
| action | labelMedium | primary | Clickable labels |
| section | labelMedium | onSurface | Section headers |

## Running the Generators

```bash
# OpenAPI spec
cd ../sci/sci_api && dart bin/generate_openapi.dart

# SDUI component schema (reads tokens.json)
flutter test test/sdui/validator/generate_schema_test.dart

# Event spec
flutter test test/sdui/validator/generate_events_test.dart

# Regenerate catalog.json from formal specs
flutter test test/sdui/archetypes/expander_test.dart

# Validate catalog
flutter test test/sdui/validator/validate_catalog_test.dart
```

## Building the Agent Docker Image

```bash
cd ../sci
docker build -f Dockerfile_tercen_agent -t ghcr.io/tercen/tercen_agent:latest .
docker push ghcr.io/tercen/tercen_agent:latest
```

The image bundles:
- tercenctl (compiled from Dart)
- Agent TypeScript code
- Spec files in `/operator/specs/`
- `.mcp.json` with two servers: `tercen` (tercenctl) + `sdui` (spec reader)

## Next Steps

1. **Wire ContractBus into renderer** — typed event contracts replacing string channels
2. **Add constraint rules to validator** — listener topology, rebuild cardinality, tree depth
3. **Performance test** — tap on 50-item list must complete in <16ms
4. **CI integration** — run generators on change, validate catalog on PR
