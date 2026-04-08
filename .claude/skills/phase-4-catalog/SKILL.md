---
name: phase-4-catalog
description: Phase 4 — Translate a Phase 2 HTML mock widget (header or window) into an SDUI catalog.json template. Performs primitive gap analysis, creates missing SDUI primitives, and authors the catalog entry with real data connections.
argument-hint: "[path to Phase 2 mock widget]"
disable-model-invocation: true
---

**READ-ONLY. Do NOT modify.**

Translate Phase 2 mock into SDUI catalog.json template. Mock is a visual reference — output is a JSON entry in `catalog.json` rendered by the orchestrator.

Determine widget kind from `skeleton.yaml`. Load kind-specific guide:

| Kind | Guide |
|------|-------|
| header | `integrate-header.md` |
| window | `integrate-window.md` |

## Rules

1. Mock is a visual reference, not code to port. Rebuild UI from SDUI primitives.
2. Semantic tokens only: M3 ColorScheme tokens (`primary`, `onSurface`, `surfaceContainerHigh`), TextTheme slots (`bodySmall`, `labelMedium`), spacing tokens (`xs`, `sm`, `md`, `lg`). No hex colors, pixel font sizes, numeric spacing.
3. Every node needs unique `id`: `{{widgetId}}-suffix`. Inside `ForEach`: `{{item.id}}`/`{{_index}}` suffixes.
4. Use `{{context.username}}`/`{{context.userId}}` for user-specific data.
5. Call `discover_methods(serviceName)` before writing any DataSource node. Use exact method names.
6. Output is catalog.json only. Do NOT modify files in the `sdui` repo. Primitive gaps are reported, not fixed here.

## Strict error policy

**Do NOT silently work around gaps. Do NOT fall back to unapproved behaviour.**

If any of the following occur, **STOP and report the error**. Do not continue authoring the catalog entry:

- A required SDUI primitive does not exist (e.g. no TreeView, no icon-only primary button)
- A primitive exists but is missing a required prop (e.g. IconButton has no `variant` prop)
- A token value is needed but not in the approved set in `tokens.meta.json`
- A DataSource method cannot be confirmed against the actual Tercen API
- The mock requires behaviour that no existing primitive supports

Log each blocker to `_issues/session-log.md` with tag `[BLOCKED]` and the specific gap. Then present the blocker list to the user before proceeding. The user will either:
- Direct you to proceed with a known limitation (document it in the catalog entry as a `_comment`)
- Schedule the fix in the SDUI repo first

**Never use a primitive that renders differently from what the mock shows.** If `IconButton` renders as a ghost icon but the mock shows a filled primary button, that is a blocker — not a "close enough" match.

## Inputs (read in this order)

1. **Design decisions** — `packages/tercen_ui_widgets/widgets/{name}/_mock/design-decisions.md` — AUTHORITATIVE overrides to the spec. Read FIRST. If a decision says "Removed: X", do not add X.
2. **Functional spec** — `packages/tercen_ui_widgets/widgets/{name}/{name}-spec.md` — original spec, overridden by design decisions
3. **SduiTheme (MASTER)** — `packages/sdui/lib/src/theme/sdui_theme.dart` — single source of truth for all token values. Read this to understand correct button sizes, toolbar dimensions, border widths, spacing, colours.
4. **SDUI primitives** — `packages/sdui/lib/src/registry/builtin_widgets.dart` and `behavior_widgets.dart` — read BOTH the registration metadata AND the builder implementation (`_build*` functions) to understand what each primitive actually renders.
5. **Approval gate** — `../tercen-style/tokens.meta.json` — only approved tokens may appear in catalog.json
6. **Phase 2 HTML mock** — `packages/tercen_ui_widgets/widgets/{name}/_mock/styled.html` — visual reference
7. **Existing catalog** — `catalog.json` — format and existing entries

## Step 1: Inventory the mock

For each visual element and interaction, record:

| Mock element | Description | SDUI primitive needed |
|---|---|---|

Also record: data sources (services/methods), events (EventBus channels), state (mutable state).

## Step 2: Gap analysis

Read available primitives — BOTH registration AND implementation:
1. `packages/sdui/lib/src/registry/builtin_widgets.dart` — read `registry.register(...)` calls for prop specs, AND read the corresponding `_build*()` functions to understand what the primitive actually renders. A primitive may accept a prop but ignore it, or render differently from what its name suggests.
2. `packages/sdui/lib/src/registry/behavior_widgets.dart` — same: registration + implementation
3. `packages/sdui/lib/src/theme/sdui_theme.dart` — check which theme tokens the builder functions actually use (e.g. does `_buildIconButton` read `ctx.theme.window.toolbarButtonSize`?)
4. Existing `catalog.json` — check for reusable Tier 2 templates

For each mock element, verify:
- Does a primitive exist with the right type name?
- Does the builder function produce the correct visual output (colours, sizes, borders)?
- Does it read the correct theme tokens?

If a primitive exists by name but renders wrong (e.g. `IconButton` exists but renders as ghost when primary is needed), that is a **GAP**, not a match. Apply the strict error policy.

## Step 3: Report primitive gaps

**Do NOT modify files in the `packages/sdui/` package.** Primitive fixes happen in a separate SDUI session.

For each gap found in Step 2, write a gap report entry to `packages/tercen_ui_widgets/widgets/{name}/_mock/sdui-gaps.md`:

```markdown
# SDUI Primitive Gaps — {Widget Name}

## GAP: {primitive name} — {short description}

**Mock needs:** {what the mock shows}
**SDUI has:** {what the primitive actually renders}
**Missing:** {specific prop, variant, or behaviour}
**Suggested fix:** {what needs to change in builtin_widgets.dart}
**Blocking:** {which catalog.json nodes are affected}
```

Present the gap list to the user. Do NOT proceed to Step 4 until the user either:
- Confirms the SDUI gaps will be fixed in a separate session and directs you to proceed with `_comment` annotations on affected nodes
- Tells you to stop and wait for the SDUI fixes

## Step 4: Author catalog.json entry

### Metadata
```json
{
  "metadata": {
    "type": "WidgetName", "tier": 2,
    "description": "From functional spec",
    "props": { }, "emittedEvents": [ ], "acceptedActions": [ ],
    "handlesIntent": [ ]
  },
  "template": { }
}
```
- Props: only caller-facing props, not internal state
- `handlesIntent`: define if widget opens in response to intent; usually empty for headers

### Template tree primitives
- **Layout**: `Row`, `Column`, `Container`, `Expanded`, `SizedBox`, `Padding`, `Spacer`
- **Display**: `Text`, `Icon`, `CircleAvatar`, `Divider`, `Image`, `Chip`, `Tooltip`
- **Interactive**: `ElevatedButton`, `TextButton`, `IconButton`, `PopupMenu`, `TextField`, `Switch`, `Checkbox`, `DropdownButton`
- **Behavior**: `DataSource`, `ForEach`, `Action`, `Conditional`, `Sort`, `Filter`, `PromptRequired`

### Data connections

Replace mock data with `DataSource` nodes:

| Pattern | Args example |
|---------|-------------|
| `get(id)` | `["the-object-id"]` |
| `findStartKeys` (range) | `[["{{projectId}}", ""], ["{{projectId}}", "\uf000"], 50]` |
| `findKeys` (key lookup) | `[["{{context.userId}}"]]` |

### State management

State is managed by StateManager (per-widget, outside the tree). Configure via `stateConfig` in widget metadata:
```json
"stateConfig": {
  "selectionKey": "selectedId",
  "multiSelect": false
}
```
StateManager handles selection state automatically — ForEach highlights selected items. Actions inside a StateManager-backed component delegate to the StateManager before publishing to EventBus.

### Event wiring
- Mock `eventBus.publish(channel, payload)` -> `Action` node with `channel`/`payload`
- Mock `eventBus.subscribe(channel)` -> `DataSource` with `refreshOn` channel, or `Conditional` with scope bindings

## Step 5: Insert into catalog.json

1. Read `packages/tercen_ui_widgets/catalog.json`
2. Add new entry to `widgets` array
3. If home widget: add/update `home` section
4. Validate JSON parses cleanly
5. No duplicate widget `type` names

Home config for auto-display widgets:
```json
{ "home": { "windows": [{ "type": "WidgetName", "id": "home-widgetname",
    "size": "medium", "align": "center", "title": "Window Title" }] } }
```
Headers render in shell's header slot, not as floating windows — see kind-specific guide.

## Step 6: Validate

1. JSON validity — must parse without error
2. Node ID uniqueness — no duplicates
3. Binding correctness — `{{...}}` must reference in-scope variables:
   - `{{props.X}}` — template root only
   - `{{data}}`, `{{loading}}`, `{{ready}}`, `{{error}}` — inside `DataSource` only
   - `{{item}}`, `{{_index}}` — inside `ForEach` only
   - `{{state}}` — inside components with `stateConfig` in metadata
   - `{{context.username}}`, `{{context.userId}}`, `{{widgetId}}` — always available
4. Semantic tokens only
5. Cross-check DataSource `method` against `discover_methods` output
6. Every node `type` must be registered Tier 1 primitive or Tier 2 template

## Step 7: Clean up

1. Phase 2 mock directory retained as visual reference
2. New primitives: verify `dart analyze` passes
3. Update `_issues/session-log.md` with primitives created and gaps encountered
4. Present completed catalog entry for review

## Diagnostic: rendering issues

1. Browser console for SDUI renderer errors
2. Verify catalog loaded: `[catalog] Auto-loaded N widget(s)` in console
3. Check node IDs for duplicates
4. Check DataSource errors (wrong method names, wrong args)
5. Check scope (`{{data}}` outside DataSource? `{{item}}` outside ForEach?)
6. Check primitive registered in `registerBuiltinWidgets()`
