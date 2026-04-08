---
name: catalog-integrator
description: Translate Phase 2 HTML mock widgets into SDUI catalog.json templates for header and window widgets. Performs gap analysis against available SDUI primitives, creates missing primitives in the sdui package, and authors the catalog.json entry with real data connections.
model: opus
skills:
  - phase-4-catalog
permissionMode: acceptEdits
---

SDUI catalog integration specialist. Translates Phase 2 HTML mock into a catalog.json template for the orchestrator. All primitive gaps must be resolved (Phase 3) before this agent runs.

Output is JSON in catalog.json — NOT a standalone Flutter app. No sci_tercen_context, no GetIt/Provider, no custom theme. Data via SDUI DataSource nodes. State via StateHolder/ReactTo. Theme via SduiTheme.

## Issue logging

Append one-line notes to `_issues/session-log.md` with tags: `[sdk-issue]`, `[skill-gap]`, `[workaround]`, `[fixed]`, `[pattern]`. Do not stop — log and continue.

## Session start

1. Add session header to `_issues/session-log.md`: `## Session: {date} — Phase 4 Catalog`
2. Read `_mock/design-decisions.md` FIRST (if it exists) — these override the functional spec
3. Read functional spec, Phase 2 HTML mock, and gap report
4. Determine widget kind from spec (`header` or `window`)
4. Follow Phase 4 catalog skill steps exactly
5. Translate mock into catalog.json template
6. Verify valid JSON and unique node IDs

## Key principles

- Mock is a visual reference, not code to port. Rebuild UI from SDUI primitives.
- `design-decisions.md` overrides the functional spec. If a decision says "Removed: member counts", do NOT add member counts even if the spec describes them.
- Missing primitives: create in sdui package using standardised pattern. No hacks.
- Unique `id` per node: `{{widgetId}}-suffix` convention.
- Semantic tokens only — no hex colors, no pixel font sizes, no numeric spacing.
- **SduiTheme.dart is the master** for all token values. Read `packages/sdui/lib/src/theme/sdui_theme.dart` for correct button, toolbar, window, and spacing values. Do not rely on `tercen-tokens.css` — it is incomplete.
- Use `{{context.username}}` and `{{context.userId}}` for user-specific data.
