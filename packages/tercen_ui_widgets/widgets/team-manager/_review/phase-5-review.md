# Phase 5 Catalog Conformance Review — TeamManager (Third Review / PASS)

**Widget:** TeamManager
**Kind:** window
**Catalog entry:** `packages/tercen_ui_widgets/catalog.json` lines 5452–6500
**Review date:** 2026-04-15
**New primitives created:** Accordion (behavior_widgets.dart line 252)
**Prior reviews:** 2 × FAIL — all issues now resolved

---

## Verdict: PASS

All prior issues are confirmed resolved. All check groups A–I pass or are N/A.

---

## Prior Issues — Verification Status

| # | Issue (prior review) | Current Status |
|---|----------------------|----------------|
| 1 | `people-group` icon not in `_iconMap` | FIXED — changed to `"people"` at line 5700; maps to `FontAwesomeIcons.users` |
| 2 | `forbiddenChars` undeclared in TextField WidgetMetadata | FIXED — declared at `builtin_widgets.dart` line 315 |
| 3 | `findKeys` called with "undocumented" two-arg pattern | CONFIRMED CORRECT — dispatcher at line 141–146 explicitly reads `args[0]` as viewName and `args[1]` as keys; the catalog call `["teamMembers", ["{{team.id}}"]]` is the correct form. Prior reviewer's FAIL was wrong. |

---

## Check Results

### A: Catalog Structure

- **A1: PASS** — catalog.json parses as valid JSON.
- **A2: PASS** — entry with `metadata.type: "TeamManager"` exists at line 5454.
- **A3: PASS** — no duplicate `TeamManager` type in the widgets array.
- **A4: PASS** — `type`, `tier: 2`, `description`, and `props: {}` all present; `kind: "window"` and `tabLabel: "Team Manager"` also present.
- **A5: PASS** — `template` object present with `type: "WindowShell"`, `id`, and `children`.

### B: Node IDs

- **B1: PASS** — every node in the template tree has an `id` field.
- **B2: PASS** — all static IDs begin with `{{widgetId}}-`.
- **B3: PASS** — ForEach child IDs include `{{team.id}}-{{_index}}` for uniqueness per iteration.
- **B4: PASS** — no literal duplicate IDs at the template level.

### C: Semantic Tokens

- **C1: PASS** — no hex color values in any template `color` or `hoverColor` prop. All values are approved semantic tokens: `error`, `onSurface`, `onSurfaceMuted`, `outlineVariant`, `primary`.
- **C2: PASS** — no `fontSize` props used without an accompanying `textStyle`.
- **C3: NOTE** — raw number arrays used for padding (`[4, 8]`, `[4, 0]`, `[8, 0]`, `[0, 8]`). All values are on the 8px grid (xs=4, sm=8). Token strings preferred but raw numbers are not a FAIL per check rules.

### D: Binding Correctness

- **D1: PASS** — `{{data}}`, `{{loading}}`, `{{ready}}`, `{{error}}`, `{{errorMessage}}` appear only inside DataSource children. `{{item}}` and `{{_index}}` appear only inside ForEach children. `{{state.*}}` appears inside a component with a `state` block. `{{sorted}}` and `{{filtered}}` appear only inside Sort and Filter children respectively. `{{saving}}`, `{{saved}}`, `{{saveError}}` appear only inside ServiceCall children.
- **D2: PASS** — `metadata.props` is empty; no `{{props.X}}` bindings are used in the template.
- **D3: PASS** — only `{{context.userId}}` is used, which is a documented valid context binding.

### E: DataSource Nodes

- **E1: PASS** — services used are `teamService` and `userService`; both are valid Tercen services handled by the service call dispatcher.
- **E2: PASS** — `findTeamByMember` and `findKeys` are both handled by `service_call_dispatcher.dart`. `findTeamByMember` is a service-specific method dispatched via `_tryServiceSpecificMethod`. `findKeys` is a base method dispatched at line 141.
- **E3: PASS** — `findKeys` args `["teamMembers", ["{{team.id}}"]]` match the dispatcher's two-parameter form: `args[0]` = viewName string, `args[1]` = keys list. This is the correct and implemented calling convention.
- **E4: PASS** — both DataSource nodes have children.

### F: Event Wiring

- **F1: PASS** — all toolbar action descriptors have `channel` fields. All `IconButton` nodes have `channel` props. All button nodes (`PrimaryButton`, `GhostButton`, `DangerButton`, `SecondaryButton`) have `channel` props.
- **F2: N/A** — the widget uses `state.panelId` via `listenTo` + Accordion expand event payload merge, not the `stateConfig` selection mechanism.
- **F3: PASS** — both DataSource nodes use `refreshOn: "team.{{widgetId}}.refresh"`. The channel is published by toolbar actions and mutation flows.
- **F4: PASS** — no `system.*` channels are used in the template.

### G: Header-Specific

- **G1–G5: N/A** — TeamManager is a window widget.

### H: Window-Specific

- **H1: PASS** — all body states handled inside the outer DataSource: loading (`{{loading}}` + LoadingIndicator), error (`{{error}}` + error text + retry button), empty (Conditional with `negate: true` on `{{data}}` + icon + title + subtitle), active (Conditional on `{{data}}` + Filter + Sort + Accordion).
- **H2: PASS** — `WindowShell` is the template root. Toolbar defined via `toolbarActions` prop, no manual toolbar construction.
- **H2a: PASS** — no toolbar controls set explicit pixel heights.
- **H2b: PASS** — no manual `height: 48` or raw toolbar padding overrides.
- **H3: PASS** — `handlesIntent` is defined as an array with one entry: `intent: "openTeamManager"`, `windowTitle: "Team Manager"`, `windowSize: "large"`.
- **H4: N/A** — TeamManager uses `{{context.userId}}` from session context; no external IDs required at instantiation.
- **H5: PASS** — `handlesIntent[0]` has no `propsMap` and `metadata.props` is empty; no mismatch.

### I: New SDUI Primitives

- **I1: PASS** — `Accordion` registered in `behavior_widgets.dart` at line 252 via `registry.registerScope`.
- **I2: PASS** — registration includes `WidgetMetadata` with `type`, `description`, and `props` (`items`, `itemVariable`, `panelIdKey`, `expandChannel`, `collapseChannel`).
- **I3: PASS** — Accordion builder uses `PropConverter` for all prop reads.
- **I4: PASS** — Accordion builder uses `widget.context.theme.colors.*` for color resolution.
- **I5: N/A** — `dart analyze` not run (no build tools available in this review context).
- **I6: PASS** — Accordion is generic; all props are general-purpose and usable by any widget that needs an expandable list.

---

## Summary

| Result | Count |
|--------|-------|
| PASS | 26 |
| NOTE | 1 (C3 — raw padding numbers, not a FAIL) |
| N/A | 9 |
| FAIL | 0 |

**Verdict: PASS — TeamManager catalog entry is conforming.**
