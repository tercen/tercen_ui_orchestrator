---
name: phase-2-mock
description: Build an HTML mock from a Phase 1 functional spec. Three steps — wireframe, styled rendering, gap evaluation. Produces HTML files in widgets/{name}/_mock/ using Material CSS + Tercen tokens.
argument-hint: "[path to functional spec]"
disable-model-invocation: true
---

**READ-ONLY. Do NOT modify. Log gaps to `_issues/session-log.md` and continue.**

## Inputs

1. **Functional spec** — `widgets/{name}/{name}-spec.md`
2. **SduiTheme (MASTER)** — `packages/sdui/lib/src/theme/sdui_theme.dart` — the single source of truth for all token values. Read this FIRST for colours, spacing, typography, button tokens, toolbar tokens, window tokens, and icon sizes.
3. **Approval flags** — `../tercen-style/tokens.meta.json` — controls which tokens are approved for use
4. **Tercen tokens CSS** — `../tercen-style/dist/tercen-tokens.css` — convenience CSS subset. WARNING: this file is INCOMPLETE — it is missing toolbar, window, and some button tokens. Always cross-check values against SduiTheme.dart.
5. **Primitive metadata** — `../tercen-style/theme-export.json` (primitives array)

## Output Directory

`widgets/{name}/_mock/`

## Step 1 — Wireframe (`wireframe.html`)

HTML/CSS layout skeleton with minimal styling (grey boxes, placeholder text).
- Shows feature placement, content areas, control types from spec
- Annotate elements with `data-function` attribute or visible label
- Use semantic HTML: `<header>`, `<main>`, `<aside>`, `<section>`, `<article>`
- Include top note: "Wireframe — layout and features only, no styling"
- Goal: agree feature set and spatial layout with user

## Step 2 — Styled Rendering (`styled.html`)

Copy wireframe structure, apply Tercen design system.

### Embedding tokens
Read `../tercen-style/dist/tercen-tokens.css` and embed in `<style>` tag in `<head>`. Do NOT use `<link>` (relative path won't resolve cross-repo).

**IMPORTANT**: `tercen-tokens.css` is incomplete. After embedding it, read `SduiTheme.dart` and add any missing tokens as additional CSS variables. Key sections to check:
- `SduiButtonTokens` — button padding, border radius, outlined border width
- `SduiWindowTokens` — toolbar height, toolbar button size/icon size/radius/border width, toolbar gap
- `SduiIconSize` — icon sizes sm/md/lg

### Theme application
- Font: `--font-family` CSS variable
- Colours: approved tokens only (check `tokens.meta.json` where `approved: true`)
- Spacing/border-radius: token CSS variables
- **Button/toolbar values: from SduiTheme.dart** — do not guess or hardcode

### Controls
- Reference `tokens.meta.json` components section for control specs
- Buttons: correct padding, border-radius, colours per variant (primary, secondary, ghost)
- Inputs: outline borders, correct focus states

### Theme toggle
Include light/dark toggle in the **convenience bar** (see below), not as an in-widget control.

### Convenience bar (standard for all mocks)
Every styled.html MUST include a convenience bar at the top of the page. This is a **development-only frame** — it represents the orchestrator's tab strip and pane chrome, which the widget does NOT own. The widget itself has no border, no tab, and no frame.

The convenience bar MUST contain:
1. **Tab mock** — coloured type dot + widget name (matches the orchestrator tab appearance)
2. **State switcher** — buttons: Active, Loading, Empty, Error. Switches the body state.
3. **Theme toggle** — light/dark mode button using `[data-theme]` selectors from tokens CSS.

The convenience bar MUST be visually distinct from the widget (dark background, small text) so it cannot be confused with actual widget UI. Mark it with a comment: `<!-- CONVENIENCE BAR — Dev only, not part of widget -->`.

**Do NOT include** in the widget area:
- Floating action buttons for theme toggle
- Toast notification demo dots
- Any other dev controls that are not part of the widget spec

### EventBus modelling
If the spec defines EventBus events, model them in the mock:
- **Bottom log bar** — monospace strip showing the last emitted event channel + payload
- **Toast notification** — appears briefly when an event fires that has no visible UI change (e.g. focusChanged, openViewer, downloadFile). Shows the channel name and payload so reviewers can verify wiring.

## Step 3 — Gap Evaluation (`gap-report.md`)

Check each UI element against primitives in `../tercen-style/theme-export.json`.

| Category | Description |
|----------|-------------|
| Primitive gap | Needs X, doesn't exist in SDUI |
| Variant gap | Needs X variant of Y, Y exists but lacks variant |
| Prop gap | Needs prop Z on primitive Y |
| Composition question | Achievable with existing primitives via pattern P? |
| Style gap | Needs token not in approved set |

Output: markdown with categorised table. Each row: element name, gap category, description, proposed resolution. If no gaps: "All elements map to existing SDUI primitives."

## Mock Data

Static JSON fixtures in `widgets/{name}/_fixtures/`.
- Realistic data (real-looking names, timestamps, IDs), not from live API
- All four states: loading, empty, active, error

## Rules

- Only approved colour tokens (check `tokens.meta.json`)
- Only approved text styles from `theme-export.json`
- FontAwesome 6 Solid for icons — CDN: `https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css`
- No real API connections, no EventBus wiring
- HTML is a design artifact, not code to port

## Checklist

- [ ] wireframe.html created and reviewed with user
- [ ] styled.html with Tercen theme applied
- [ ] Controls match style guide specs
- [ ] Mock data fixtures with realistic data
- [ ] All 4 states represented (loading, empty, active, error)
- [ ] gap-report.md produced
- [ ] Only approved colour tokens used
- [ ] FontAwesome 6 Solid icons only
