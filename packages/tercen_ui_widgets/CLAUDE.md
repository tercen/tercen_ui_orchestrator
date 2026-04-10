# Tercen UI Widgets

This repo produces **JSON catalog entries** for SDUI widgets (window and header kinds). The output is `catalog.json` — no compiled Flutter apps.

## What this repo contains

- `catalog.json` — the widget catalogue consumed by the orchestrator
- `widgets/` — 10 widget projects (all window or header kind)
- `.claude/agents/` — catalog-integrator, spec-writer, mock-builder, reviewer
- `.claude/skills/` — phase 1-3 skills for the widget development pipeline
- `_references/` — window-design.md, global-rules.md

## What this repo does NOT contain

- Standalone Flutter apps — those are in `tercen_flutter_apps`
- Panel/runner skeletons — those are in `tercen_flutter_apps`
- Window/header skeletons — authoritative copies are in `sdui/skeletons/`
- Style guide or design tokens — those are in `tercen-style`

## Phase Pipeline

1. **Spec** — functional specification (`phase-1-spec`)
2. **Primitives** — fill gaps in sdui package / tokens (`phase-3-primitives`)
3. **Catalog** — author catalog.json entry, test in mock shell (`phase-4-catalog`)
4. **Review** — validation and sign-off (`phase-5-review`)

## Sibling packages (read directly, no copies)

| What | Where | Authority |
|------|-------|-----------|
| **SduiTheme (MASTER for all token values)** | `packages/sdui/lib/src/theme/sdui_theme.dart` | **Single source of truth** |
| SDUI primitives source | `packages/sdui/lib/src/registry/builtin_widgets.dart` | |
| Behaviour primitives source | `packages/sdui/lib/src/registry/behavior_widgets.dart` | |
| Approval flags, component specs, rules | `../tercen-style/tokens.meta.json` | Approval gate |
| Theme values export (generated from SduiTheme) | `../tercen-style/theme-export.json` | Downstream |
| CSS tokens (INCOMPLETE — missing toolbar/window) | `../tercen-style/dist/tercen-tokens.css` | Convenience only |
| Visual style guide (for human review) | `../tercen-style/dist/style-guide.html` | |

### Token hierarchy

```
SduiTheme.dart (sdui repo)          ← MASTER — all token values defined here
  → theme-export.json (tercen-style) ← generated, includes all tokens
    → tercen-tokens.css (tercen-style) ← generated, INCOMPLETE subset
    → style-guide.html (tercen-style)  ← visual reference
  → tokens.meta.json (tercen-style)  ← approval gate (which tokens agents may use)
```

When values conflict between sources, **SduiTheme.dart wins**.

## Colour governance

- **SduiTheme.dart** is the runtime master for all colour values
- **tokens.meta.json** controls which colours are approved for use in catalog.json
- Only 36 approved colour tokens may appear in catalog.json template `color` props
- `typeColor` in widget metadata uses approved hex values from the `approvedTypeColors` list
- Raw hex values, `grey`, and legacy token names (panelBg, sectionHeaderBg, primaryHover, etc.) are forbidden in templates
- See `PITFALLS.md` for the full list of deleted token names and their replacements

## Key constraints

- FontAwesome 6 Solid is the only icon library — no custom icon fonts
- Material Design is the baseline for structural properties (radius, elevation, spacing)
- Tercen branding applies to colours only
- All chrome must be theme-aware (light and dark)
- Max one PrimaryButton per view
- Spacing must use the 8px grid tokens only (xs=4, sm=8, md=16, lg=24, xl=32, xxl=48)
