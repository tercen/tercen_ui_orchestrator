# SDUI — Server-Driven UI Engine

This package is the runtime engine that renders widgets from JSON (catalog.json). It owns the theme, the primitive builders, the renderer, and the window manager.

## Critical Files (the bridge chain)

```
SduiTheme.dart          → defines token values (MASTER)
  ↓ fromJson()          → parses all token groups from JSON config
  ↓ toMaterialTheme()   → maps tokens into Flutter ThemeData (backstop)
builtin_widgets.dart    → primitive builders consume ctx.theme tokens
behavior_widgets.dart   → behavior builders consume ctx.theme tokens
  ↓ WidgetMetadata      → declares props (skill reads this to generate catalog.json)
widget_registry.dart    → loadCatalog() loads catalog.json templates
sdui_renderer.dart      → render() resolves templates → primitives → Flutter widgets
```

Every link in this chain must stay aligned. A token added to SduiTheme but not wired in fromJson is dead. A prop read by a builder but missing from metadata is invisible to catalog authors. A primitive that hardcodes values instead of reading theme tokens breaks theming.

## Invariants — never break these

1. **Every token class field must be parseable from JSON.** If `SduiWindowTokens` has a field, `SduiWindowTokens.fromJson` must read it, and `SduiTheme.fromJson` must call that factory.

2. **Every prop read by a builder must be declared in WidgetMetadata.** The skill that generates catalog.json reads metadata to know what props exist. Undocumented props are invisible.

3. **Every prop declared in WidgetMetadata must be read by the builder.** Declared-but-ignored props cause the skill to set values that have no effect.

4. **Builders must use ctx.theme tokens, not hardcoded values.** Toolbar buttons use `ctx.theme.window.toolbarButtonSize`, not `36`. Dividers use `ctx.theme.lineWeight.subtle`, not `1`. Icon sizes use `ctx.theme.iconSize.md`, not `24`. Animation durations use `ctx.theme.animation.fast`, not `Duration(milliseconds: 150)`.

5. **toMaterialTheme() must map all token groups that Flutter widgets consume.** This is the backstop for any widget that reads `Theme.of(context)`.

6. **Removed primitives must not appear in skill guides.** ReactTo and StateHolder are removed (replaced by StateManager). Any skill/guide referencing them will produce broken catalog.json.

## Token groups in SduiTheme

All 16 must have `fromJson` factories and be wired in `SduiTheme.fromJson`:

| Group | Class | Status |
|-------|-------|--------|
| colors | SduiColorTokens | wired |
| spacing | SduiSpacingTokens | wired |
| textStyles | SduiTextStyleTokens | wired |
| elevation | SduiElevationTokens | wired |
| radius | SduiRadiusTokens | wired |
| lineWeight | SduiLineWeightTokens | wired |
| panel | SduiPanelTokens | wired |
| controlHeight | SduiControlHeightTokens | wired |
| window | SduiWindowTokens | wired |
| opacity | SduiOpacityTokens | wired |
| animation | SduiAnimationTokens | wired |
| dataTable | SduiDataTableTokens | wired |
| internalTab | SduiInternalTabTokens | wired |
| button | SduiButtonTokens | wired |
| iconSize | SduiIconSizeTokens | wired |
| fontFamily | String | wired |

## Key file locations

| File | Role |
|------|------|
| `lib/src/theme/sdui_theme.dart` | Token master — all values defined here |
| `lib/src/registry/builtin_widgets.dart` | Primitive builders + metadata |
| `lib/src/registry/behavior_widgets.dart` | Behavior builders + metadata |
| `lib/src/registry/widget_registry.dart` | Registry + catalog loader |
| `lib/src/renderer/sdui_renderer.dart` | 3-tier render: scope → builder → template |
| `lib/src/window/window_manager.dart` | Window lifecycle + validation |
| `lib/src/renderer/sdui_render_context.dart` | Context flowing to all builders |

## Sibling repos

| Repo | Relationship |
|------|-------------|
| `tercen_ui_widgets` | Produces catalog.json — consumes our primitives + metadata |
| `tercen_ui_orchestrator` | Hosts the SDUI engine — calls SduiContext.create, loads catalog |
| `tercen-style` | Approval gate (tokens.meta.json) + visual reference |
