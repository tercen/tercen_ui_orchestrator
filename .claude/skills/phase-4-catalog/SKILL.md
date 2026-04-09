---
name: phase-4-catalog
description: Author an SDUI catalog.json template for a widget. Performs primitive gap analysis, creates the catalog entry with real data connections, and tests in the mock shell.
argument-hint: "[widget name or path to functional spec]"
disable-model-invocation: true
---

**READ-ONLY. Do NOT modify.**

Author the catalog.json template for a widget. The functional spec is the input. Test the result in the mock shell (`flutter run -t lib/mock/main_mock.dart`).

Determine widget kind from the spec. Load kind-specific guide:

| Kind | Guide |
|------|-------|
| header | `integrate-header.md` |
| window | `integrate-window.md` |

## Rules

1. Build UI from SDUI primitives — not from any mock or existing Flutter code.
2. Semantic tokens only: M3 ColorScheme tokens (`primary`, `onSurface`, `surfaceContainerHigh`), TextTheme slots (`bodySmall`, `labelMedium`), spacing tokens (`xs`, `sm`, `md`, `lg`). No hex colors, pixel font sizes, numeric spacing.
3. Every node needs unique `id`: `{{widgetId}}-suffix`. Inside `ForEach`: `{{item.id}}`/`{{_index}}` suffixes.
4. Use `{{context.username}}`/`{{context.userId}}` for user-specific data.
5. Call `discover_methods(serviceName)` before writing any DataSource node. Use exact method names.
6. Output is catalog.json only. Do NOT modify files in `packages/sdui/`. Primitive gaps are reported, not fixed here.
7. **Never round-trip catalog.json through json.load/json.dump.** Edit by hand only. `\uf000` sentinels and Unicode escapes must be preserved.

## Strict error policy

**Do NOT silently work around gaps. Do NOT fall back to unapproved behaviour.**

If any of the following occur, **STOP and report the error**:

- A required SDUI primitive does not exist
- A primitive exists but is missing a required prop
- A token value is needed but not in the approved set in `../tercen-style/tokens.meta.json`
- A DataSource method cannot be confirmed against the actual Tercen API
- The spec requires behaviour that no existing primitive supports

Log each blocker with tag `[BLOCKED]` and present the list to the user before proceeding.

## Inputs (read in this order)

1. **Functional spec** — `packages/tercen_ui_widgets/widgets/{name}/{name}-spec.md`
2. **SduiTheme (MASTER)** — `packages/sdui/lib/src/theme/sdui_theme.dart` — single source of truth for all token values
3. **SDUI primitives** — `packages/sdui/lib/src/registry/builtin_widgets.dart` and `behavior_widgets.dart` — read BOTH registration metadata AND builder implementation
4. **Approval gate** — `../tercen-style/tokens.meta.json` — only approved tokens may appear in catalog.json
5. **Existing catalog** — `packages/tercen_ui_widgets/catalog.json` — format and existing entries

## Step 1: Inventory the spec

For each visual element and interaction in the spec, record:

| Spec element | Description | SDUI primitive needed |
|---|---|---|

Also record: data sources (services/methods), events (EventBus channels), state (mutable state).

## Step 2: Gap analysis

Read available primitives — BOTH registration AND implementation:
1. `packages/sdui/lib/src/registry/builtin_widgets.dart` — read `registry.register(...)` calls AND `_build*()` functions
2. `packages/sdui/lib/src/registry/behavior_widgets.dart` — same
3. `packages/sdui/lib/src/theme/sdui_theme.dart` — check which theme tokens builders actually use
4. Existing `packages/tercen_ui_widgets/catalog.json` — check for reusable Tier 2 templates

For each spec element, verify the primitive exists and renders correctly. Apply strict error policy for gaps.

## Step 3: Report primitive gaps

**Do NOT modify files in `packages/sdui/`.** Primitive fixes happen in a separate session.

Write gap report to `packages/tercen_ui_widgets/widgets/{name}/_mock/sdui-gaps.md`. Present to user before proceeding.

## Step 4: Author catalog.json entry

### Metadata
```json
{
  "metadata": {
    "type": "WidgetName", "kind": "window", "tier": 2,
    "typeColor": "#hex", "tabLabel": "Label",
    "description": "From functional spec",
    "props": { }, "emittedEvents": [ ],
    "handlesIntent": [ ]
  },
  "template": { }
}
```

### Template root: WindowShell

All window widgets MUST use `WindowShell` as the template root. WindowShell provides:
- Standard 48px toolbar (height from `theme.window.toolbarHeight`)
- Toolbar buttons via `toolbarActions` prop (all rendered at 32px = `theme.window.toolbarButtonSize`)
- Body area for content children

```json
{
  "type": "WindowShell",
  "id": "{{widgetId}}-root",
  "props": {
    "toolbarActions": [
      { "icon": "play", "label": "Run All", "channel": "workflow.run", "isPrimary": true },
      { "icon": "search", "isSearch": true }
    ]
  },
  "children": [ /* body content */ ]
}
```

Do NOT build toolbars manually with `Container` + `Row` + buttons. All toolbar controls are 32px height — no exceptions, no manual overrides.

### Template tree primitives
- **Layout**: `Row`, `Column`, `Container`, `Expanded`, `SizedBox`, `Padding`, `Spacer`
- **Display**: `Text`, `Icon`, `CircleAvatar`, `Divider`, `Image`, `Chip`, `Tooltip`
- **Interactive**: `PrimaryButton`, `SecondaryButton`, `IconButton`, `PopupMenu`, `TextField`, `Switch`, `Checkbox`, `DropdownButton`
- **Behavior**: `DataSource`, `ForEach`, `Action`, `Conditional`, `Sort`, `Filter`, `EventScope`
- **Shell**: `WindowShell` (template root for all window widgets)

### Data connections

Replace spec data with `DataSource` nodes:

| Pattern | Args example |
|---------|-------------|
| `get(id)` | `["the-object-id"]` |
| `findStartKeys` (range) | `[["{{projectId}}", ""], ["{{projectId}}", "\uf000"], 50]` |

### State management

State via StateManager (per-widget, outside tree). Configure via `stateConfig` in metadata.

### Event wiring
- Publish: `Action` node with `channel`/`payload`
- Subscribe: `DataSource` with `refreshOn`, or `EventScope` for scope injection

## Step 5: Insert into catalog.json

1. Read `packages/tercen_ui_widgets/catalog.json`
2. Add new entry to `widgets` array — edit by hand, preserve `\uf000` sentinels
3. If home widget: add/update `home` section
4. Validate JSON parses cleanly
5. No duplicate widget `type` names

## Step 6: Test in mock shell

Run the mock shell to verify the widget renders correctly:

```bash
cd /home/martin/tercen/tercen_ui_orchestrator
flutter run -t lib/mock/main_mock.dart -d web-server --web-port 12889 --dart-define=MOCK_WIDGET=WidgetName
```

Verify:
1. Widget renders without layout errors
2. Loading/error/ready states display correctly
3. DataSource calls appear in the Service Calls tab
4. Events fire correctly in the Events tab
5. Theme tokens render correctly (colours, spacing, typography)

## Step 7: Validate

1. JSON validity — must parse without error
2. Node ID uniqueness — no duplicates
3. Binding correctness — `{{...}}` must reference in-scope variables
4. Semantic tokens only
5. Cross-check DataSource `method` against `discover_methods` output
6. Every node `type` must be a registered primitive or template
