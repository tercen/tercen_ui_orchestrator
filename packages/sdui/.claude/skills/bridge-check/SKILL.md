---
name: bridge-check
description: Validate alignment between SduiTheme tokens, primitive builders, metadata, and downstream skill guides. Run after any change to sdui_theme.dart, builtin_widgets.dart, behavior_widgets.dart, or the phase-4/phase-5 skills in tercen_ui_widgets.
argument-hint: ""
---

# Bridge Alignment Check

Validates that the critical file chain is aligned and no bridges are broken.

## Files to read

1. `/home/martin/tercen/sdui/lib/src/theme/sdui_theme.dart`
2. `/home/martin/tercen/sdui/lib/src/registry/builtin_widgets.dart`
3. `/home/martin/tercen/sdui/lib/src/registry/behavior_widgets.dart`
4. `/home/martin/tercen/sdui/lib/src/registry/widget_registry.dart` (loadCatalog method)
5. `/home/martin/tercen/tercen_ui_widgets/.claude/skills/phase-4-catalog/SKILL.md`
6. `/home/martin/tercen/tercen_ui_widgets/.claude/skills/phase-4-catalog/integrate-window.md`
7. `/home/martin/tercen/tercen_ui_widgets/.claude/skills/phase-4-catalog/integrate-header.md`
8. `/home/martin/tercen/tercen_ui_widgets/.claude/skills/phase-5-review/checks-catalog.md`

## Check 1: Theme → fromJson bridge

For every token class in `sdui_theme.dart` (`Sdui*Tokens`):

1. List all `final` fields in the class
2. Verify a `fromJson` factory exists
3. Verify every field is read in `fromJson` (via `_doubleFromJson`, `_intFromJson`, `_colorFromJson`)
4. Verify `SduiTheme.fromJson` calls that factory (not `const` constructor)

**FAIL** if any field is not parsed, any factory is missing, or `SduiTheme.fromJson` uses a hardcoded `const` constructor for a token group.

## Check 2: Theme → toMaterialTheme bridge

Verify `toMaterialTheme()` maps:
- `colors` → `ColorScheme` fields
- `button` → `elevatedButtonTheme`, `outlinedButtonTheme`, `textButtonTheme`
- `iconSize` → `iconTheme`, `iconButtonTheme`
- `radius` → used in button shapes and input decoration
- `spacing` → used in input decoration contentPadding
- `textStyles` → `textTheme`

**FAIL** if a token group used by Flutter widgets is not mapped.

## Check 3: Builder → Theme token bridge

For every `_build*` function in `builtin_widgets.dart`:

1. Search for hardcoded numeric literals in sizing/spacing/radius/border positions
2. Cross-reference against theme tokens that should be used:
   - Icon sizes: must use `ctx.theme.iconSize.*`, not bare numbers
   - Border radius: must use `ctx.theme.radius.*` or `ctx.theme.window.toolbar*`, not `BorderRadius.circular(8)`
   - Border widths: must use `ctx.theme.lineWeight.*` or `ctx.theme.window.toolbarButtonBorderWidth`
   - Spacing/padding: must use `ctx.theme.spacing.*`
   - Heights: must use `ctx.theme.window.*` or `ctx.theme.controlHeight.*`
   - Durations: must use `ctx.theme.animation.*`
   - Opacity/alpha: must use `ctx.theme.opacity.*`

**FAIL** if a builder hardcodes a value where a theme token exists for that purpose. Note: layout-only widgets (Row, Column, Expanded, SizedBox, Spacer, Center) are exempt.

## Check 4: Builder ↔ Metadata prop alignment

For every `registry.register(...)` and `registry.registerScope(...)` call:

1. Extract all prop names from `WidgetMetadata.props`
2. Extract all prop names read by the builder (`node.props['xxx']` or `widget.node.props['xxx']`)
3. **FAIL: Undocumented prop** — builder reads a prop not in metadata
4. **FAIL: Phantom prop** — metadata declares a prop the builder never reads
5. **FAIL: Wrong type** — metadata type doesn't match how builder converts the prop

## Check 5: Removed primitives not referenced

Scan skill files and guides for references to removed/deprecated widgets:

- `ReactTo` — removed, replaced by StateManager + ForEach selection
- `StateHolder` — removed, replaced by StateManager
- `Interaction` — removed, replaced by StateManager

Check these files:
- `phase-4-catalog/SKILL.md`
- `phase-4-catalog/integrate-window.md`
- `phase-4-catalog/integrate-header.md`
- `phase-5-review/checks-catalog.md`

**FAIL** if any removed widget name appears in skill instructions, example templates, or checklists.

## Check 6: Skill guide ↔ primitive capability alignment

For every primitive name mentioned in `phase-4-catalog/SKILL.md` line 137 (template tree primitives list):

1. Verify it is registered in `builtin_widgets.dart` or `behavior_widgets.dart`
2. Verify the usage examples in `integrate-window.md` use props that exist in metadata

For every prop used in example templates in `integrate-window.md`:

1. Verify the prop exists in the primitive's WidgetMetadata
2. Verify the prop name and type match

**FAIL** if a skill guide references a primitive that doesn't exist, or uses props that don't exist.

## Check 7: dart analyze

Run `cd /home/martin/tercen/sdui && dart analyze lib/`. **FAIL** if any errors (warnings/infos are noted but not failures).

## Output

Produce a report:

```markdown
# Bridge Alignment Report

**Date:** [date]
**Status:** [ALIGNED / MISALIGNED]

## Results

| Check | Status | Issues |
|-------|--------|--------|
| 1. Theme → fromJson | PASS/FAIL | [details] |
| 2. Theme → toMaterialTheme | PASS/FAIL | [details] |
| 3. Builder → Theme tokens | PASS/FAIL | [N hardcoded values found] |
| 4. Builder ↔ Metadata | PASS/FAIL | [N undocumented, N phantom] |
| 5. Removed primitives | PASS/FAIL | [N stale references] |
| 6. Skill ↔ Primitives | PASS/FAIL | [N mismatches] |
| 7. dart analyze | PASS/FAIL | [N errors] |

## Failures

[For each FAIL, list specific file, line, what's wrong, and what the fix should be]
```

Save report to `/home/martin/tercen/sdui/_local/bridge-report.md`.

## Rules

1. **Read only.** This skill checks alignment — it does NOT fix anything. Report findings.
2. Be specific — cite file paths, line numbers, exact hardcoded values, exact missing props.
3. Check ALL widgets, not a sample. Systematic, exhaustive.
4. False positives are worse than false negatives. Only FAIL when it's genuinely broken.
