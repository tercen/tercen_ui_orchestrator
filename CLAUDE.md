# Tercen UI Orchestrator (Monorepo)

This is the monorepo for the Tercen web UI. It contains the Flutter orchestrator app, the SDUI rendering engine, and the widget catalog.

## Repository Structure

```
lib/                          Orchestrator app (Flutter web)
packages/
  sdui/                       SDUI rendering engine (theme, primitives, renderer, window manager)
  tercen_ui_widgets/          Widget catalog + widget project specs/mocks
    catalog.json              Widget catalog — THE source of truth for all widgets
    widgets/                  Individual widget projects (specs, mocks, fixtures)
    _references/              Shared design references (global-rules.md, window-design.md)
```

## Key Files

| File | Role |
|------|------|
| `packages/tercen_ui_widgets/catalog.json` | Widget catalog consumed at runtime |
| `packages/sdui/lib/src/theme/sdui_theme.dart` | Token master — all design values defined here |
| `packages/sdui/lib/src/registry/builtin_widgets.dart` | Primitive widget builders + metadata |
| `packages/sdui/lib/src/registry/behavior_widgets.dart` | Behavior widget builders + metadata |
| `packages/sdui/lib/src/renderer/sdui_renderer.dart` | 3-tier render: scope -> builder -> template |
| `packages/sdui/lib/src/window/window_manager.dart` | Window lifecycle + pane layout |
| `lib/main.dart` | Orchestrator bootstrap, auth, catalog loading, event listeners |
| `lib/sdui/service/service_call_dispatcher.dart` | Backend API bridge for DataSource widgets |
| `orchestrator.config.json` | Points at the catalog fetch URL |

## SDUI Bridge Chain

```
SduiTheme.dart          -> defines token values (MASTER)
  | fromJson()          -> parses all token groups from JSON config
  | toMaterialTheme()   -> maps tokens into Flutter ThemeData (backstop)
builtin_widgets.dart    -> primitive builders consume ctx.theme tokens
behavior_widgets.dart   -> behavior builders consume ctx.theme tokens
  | WidgetMetadata      -> declares props (skills read this to generate catalog.json)
widget_registry.dart    -> loadCatalog() loads catalog.json templates
sdui_renderer.dart      -> render() resolves templates -> primitives -> Flutter widgets
```

Every link must stay aligned. Run `/bridge-check` after changes to any file in this chain.

## SDUI Invariants

1. **Every token class field must be parseable from JSON.** If a token class has a field, its fromJson must read it.
2. **Every prop read by a builder must be declared in WidgetMetadata.** Undocumented props are invisible to catalog authors.
3. **Every prop declared in WidgetMetadata must be read by the builder.** Phantom props cause confusion.
4. **Builders must use ctx.theme tokens, not hardcoded values.** No bare pixel sizes, durations, or colors.
5. **Removed primitives must not appear in skills.** ReactTo, StateHolder, Interaction are removed (replaced by StateManager).

## Widget Development Pipeline

1. **Spec** — functional specification (`/phase-1-spec`)
2. **Mock** — HTML wireframe + styled rendering + gap evaluation (`/phase-2-mock`)
3. **Reconcile** — diff mock against spec, produce design-decisions.md (`/phase-3-reconcile`)
4. **Primitives** — fill gaps in sdui package / tokens (`/phase-3-primitives`)
5. **Catalog** — author catalog.json entry (`/phase-4-catalog`)
6. **Review** — validation and sign-off (`/phase-5-review`)

## Sibling Packages (outside this repo)

| What | Where | Authority |
|------|-------|-----------|
| Approval flags, component specs | `../tercen-style/tokens.meta.json` | Approval gate |
| Theme values export (generated) | `../tercen-style/theme-export.json` | Downstream |
| CSS tokens (INCOMPLETE) | `../tercen-style/dist/tercen-tokens.css` | Convenience only |
| Tercen API client | `../sci_tercen_client/` | API layer |

## Token Hierarchy

```
SduiTheme.dart (packages/sdui/)       <- MASTER
  -> theme-export.json (tercen-style)  <- generated, includes all tokens
    -> tercen-tokens.css (tercen-style) <- generated, INCOMPLETE subset
  -> tokens.meta.json (tercen-style)   <- approval gate
```

When values conflict, **SduiTheme.dart wins**.

## Key Constraints

- FontAwesome 6 Solid is the only icon library
- Material Design baseline for structural properties
- Tercen branding applies to colours only
- All chrome must be theme-aware (light and dark)
- Max one PrimaryButton per view
- Spacing uses 8px grid tokens only (xs=4, sm=8, md=16, lg=24, xl=32, xxl=48)
- Only 36 approved colour tokens may appear in catalog.json template color props
- `typeColor` in widget metadata uses approved hex values from tokens.meta.json
- catalog.json must never be round-tripped through json.load/json.dump — edit by hand only
