# Phase 3 Review — Catalog Widget (Header / Window)

Checklist for reviewing a catalog.json integration. Replaces the standard Phase 3 checks (Groups A–M) which apply to standalone Flutter apps.

---

## Inputs

- **catalog.json** — the widget catalog containing the new/updated entry
- **Phase 2 mock** — the standalone Flutter app used as visual reference
- **Functional spec** — the Phase 1 output document
- **SDUI package** — `/home/martin/tercen/sdui/` (if new primitives were created)

---

## Workflow

1. Read the functional spec. Identify widget kind (header/window) from Section header or skeleton.yaml.
2. Read `catalog.json`. Locate the new widget entry by `metadata.type`.
3. If new SDUI primitives were created, read the relevant files in the sdui package.
4. Run all applicable check groups below.
5. Produce the conformance report and save to `_local/phase-3-conformance-report.md` in the widget project directory.

---

## Check Group A: Catalog Structure

### A1: Valid JSON

`catalog.json` must parse without errors. Use `python3 -c "import json; json.load(open('catalog.json'))"` or equivalent.

### A2: Widget entry exists

The `widgets` array must contain an entry with `metadata.type` matching the expected widget name.

### A3: No duplicate types

No two entries in `widgets` may share the same `metadata.type`.

### A4: Metadata complete

The widget entry must have:
- `metadata.type` (string, PascalCase)
- `metadata.tier` (must be `2`)
- `metadata.description` (non-empty string)
- `metadata.props` (object — may be empty if widget takes no props)

### A5: Template exists

The widget entry must have a `template` object with at least `type`, `id`, and either `children` or `props`.

---

## Check Group B: Node IDs

### B1: All nodes have IDs

Every node in the template tree must have an `id` field. Glob the JSON for nodes missing `id`.

### B2: IDs use widgetId prefix

All IDs in the template (outside ForEach) must use `{{widgetId}}-suffix` pattern. Bare IDs without `{{widgetId}}` prefix will collide across instances.

### B3: ForEach child IDs use item identifiers

Inside `ForEach` children, IDs must include `{{item.id}}` or `{{_index}}` to be unique per iteration. IDs using only `{{widgetId}}-suffix` inside ForEach will produce duplicates.

### B4: No literal duplicate IDs

Scan the template for any two nodes with the exact same `id` string (before template resolution). Two nodes with `id: "{{widgetId}}-toolbar"` is fine (same template, different instances). Two nodes with `id: "toolbar"` is a FAIL.

---

## Check Group C: Semantic Tokens

### C1: No hex colors

Scan all `color` props in the template. No value should match `#[0-9a-fA-F]{3,8}`. All colors must be semantic tokens (`primary`, `onSurface`, `surfaceContainerHigh`, etc.).

### C2: No pixel font sizes

Scan all `fontSize` props. If present alongside a `textStyle` prop, note but do not FAIL (textStyle takes precedence). If `fontSize` is used WITHOUT `textStyle`, FAIL — should use `textStyle` token instead.

### C3: No numeric spacing in tokens

Scan `padding` props. Raw numbers are acceptable (the renderer converts them). But prefer token names (`xs`, `sm`, `md`, `lg`, `xl`, `xxl`) over raw numbers. Note if raw numbers are used but do not FAIL.

---

## Check Group D: Binding Correctness

### D1: No out-of-scope bindings

Check that:
- `{{data}}`, `{{loading}}`, `{{ready}}`, `{{error}}`, `{{errorMessage}}` appear only inside `DataSource` children
- `{{item}}`, `{{_index}}` appear only inside `ForEach` children
- `{{state}}` appears only inside components with `stateConfig` in metadata
- `{{sorted}}` appears only inside `Sort` children
- `{{filtered}}` appears only inside `Filter` children

### D2: Props bindings match metadata

Every `{{props.X}}` reference must correspond to a prop `X` defined in `metadata.props`.

### D3: Context bindings are valid

`{{context.username}}` and `{{context.userId}}` are always valid. Any other `{{context.X}}` binding must be documented — FAIL if undocumented.

---

## Check Group E: DataSource Nodes

### E1: Service names are valid

Every DataSource `service` prop must name a real Tercen service. Common valid services: `teamService`, `projectService`, `projectDocumentService`, `workflowService`, `tableSchemaService`, `fileService`, `userService`.

### E2: Method names are exact

Every DataSource `method` prop must be an exact method name from the service. Verify against `discover_methods` output or the `sci_tercen_client` source. Common mistake: `findByOwner` vs `findTeamByOwner`.

### E3: Args pattern matches method type

Check args format:
- `get` methods: args is `["id-string"]`
- `findStartKeys` methods: args is `[[startKey], [endKey], limit]`
- `findKeys` methods: args is `[["key1", "key2"]]` (list inside list)

Mismatched patterns (e.g., findKeys args on a findStartKeys method) are a FAIL.

### E4: No DataSource without children

A DataSource node without children will render a default spinner/error. If intentional, note. If the DataSource should feed data to sibling nodes, FAIL — data is only available to children.

---

## Check Group F: Event Wiring

### F1: Action nodes have channel

Every `Action` node must have a `channel` prop. Missing channel means the action publishes nowhere.

### F2: StateManager selection wiring

If the widget uses `stateConfig` for selection, verify that `Action` nodes publish payloads containing the correct item identifiers so StateManager can track selection. ForEach auto-highlights selected items.

### F3: DataSource refreshOn alignment

If a `DataSource` uses `refreshOn`, verify that the channel it listens on is actually published by an `Action` or other event source in the template.

### F4: Standard event channels

If the widget publishes to `system.*` channels, verify they follow conventions:
- `system.selection.<entity>` for selections
- `system.intent` for intent-based navigation
- `system.layout.op` for window operations

---

## Check Group G: Header-Specific (N/A for window)

### G1: Fixed height

Header template root must specify a fixed `height` (typically 36).

### G2: No DataSource required

Header should not have DataSource nodes unless it genuinely needs live data beyond user context. `{{context.username}}` and `{{context.userId}}` don't need a DataSource.

### G3: No loading/error states

Headers render immediately — no Conditional nodes for loading/error unless there's a DataSource.

### G4: No handlesIntent

Header metadata should NOT have `handlesIntent` — headers are always visible, not opened via intents.

### G5: Home section

`catalog.json` should have a `home.header` entry (or equivalent) pointing to this widget.

---

## Check Group H: Window-Specific (N/A for header)

### H1: Four body states

Template must handle all four body states using `Conditional` nodes:
- Loading: `visible: "{{loading}}"` with `LoadingIndicator`
- Error: `visible: "{{error}}"` with error message display
- Ready: `visible: "{{ready}}"` with active content

Empty state can be handled by ForEach's built-in "No data" or a separate Conditional.

### H2: Toolbar present

Template should have a toolbar row at the top (before the body content). May be omitted only if the spec explicitly says "no toolbar".

### H3: handlesIntent defined

If the spec says this window opens in response to intents, `metadata.handlesIntent` must be defined with correct `propsMap`.

### H4: PromptRequired for configurable values

If the widget needs IDs (projectId, workflowId) that may not be in context, the template must be wrapped in `PromptRequired`.

### H5: Intent propsMap matches widget props

Every key in `handlesIntent[].propsMap` values must correspond to a prop in `metadata.props` or a `PromptRequired` field name.

---

## Check Group I: New SDUI Primitives (N/A if no primitives were created)

### I1: Registered in builtin_widgets.dart

New primitive must be registered via `registry.register()` inside `registerBuiltinWidgets()`.

### I2: Has WidgetMetadata

Registration must include a `metadata` parameter with `type`, `description`, and `props`.

### I3: Uses PropConverter

Builder function must use `PropConverter.to<T>()` for numeric/bool conversions, not raw `as int`/`as double`.

### I4: Uses theme.resolveColor

Builder function must use `ctx.theme.resolveColor()` for color props, not hardcoded hex values.

### I5: dart analyze passes

Run `cd /home/martin/tercen/sdui && dart analyze`. No errors allowed. Warnings noted but not FAIL.

### I6: Generic and reusable

The primitive should be usable by other widgets, not specific to one template. Check that the prop names and behavior are general-purpose.

---

## Conformance Report Format

```markdown
# Phase 3 Catalog Conformance Report

**Widget:** [widget type from metadata]
**Kind:** [header / window]
**Spec:** [spec filename]
**Date:** [review date]
**New primitives created:** [list or "none"]

## Summary

| Result | Count |
|--------|-------|
| PASS | [n] |
| FAIL | [n] |
| N/A | [n] |
| **Total** | [n] |

**Verdict:** [CONFORMING / NON-CONFORMING]

---

## Results

### A: Catalog Structure
- A1: [PASS/FAIL] — Valid JSON [detail if FAIL]
- A2: [PASS/FAIL] — Widget entry exists [detail if FAIL]
- A3: [PASS/FAIL] — No duplicate types [detail if FAIL]
- A4: [PASS/FAIL] — Metadata complete [detail if FAIL]
- A5: [PASS/FAIL] — Template exists [detail if FAIL]

### B: Node IDs
- B1: [PASS/FAIL] — All nodes have IDs [detail if FAIL]
- B2: [PASS/FAIL] — IDs use widgetId prefix [detail if FAIL]
- B3: [PASS/FAIL/N/A] — ForEach child IDs use item identifiers [detail if FAIL]
- B4: [PASS/FAIL] — No literal duplicate IDs [detail if FAIL]

### C: Semantic Tokens
- C1: [PASS/FAIL] — No hex colors [detail if FAIL]
- C2: [PASS/FAIL] — No pixel font sizes without textStyle [detail if FAIL]
- C3: [PASS/NOTE] — Spacing tokens preferred [detail if NOTE]

### D: Binding Correctness
- D1: [PASS/FAIL] — No out-of-scope bindings [detail if FAIL]
- D2: [PASS/FAIL] — Props bindings match metadata [detail if FAIL]
- D3: [PASS/FAIL] — Context bindings valid [detail if FAIL]

### E: DataSource Nodes (N/A if no DataSource)
- E1: [PASS/FAIL/N/A] — Service names valid [detail if FAIL]
- E2: [PASS/FAIL/N/A] — Method names exact [detail if FAIL]
- E3: [PASS/FAIL/N/A] — Args pattern correct [detail if FAIL]
- E4: [PASS/FAIL/N/A] — DataSource has children [detail if FAIL]

### F: Event Wiring
- F1: [PASS/FAIL/N/A] — Action nodes have channel [detail if FAIL]
- F2: [PASS/FAIL/N/A] — StateManager selection wiring correct [detail if FAIL]
- F3: [PASS/FAIL/N/A] — DataSource refreshOn alignment [detail if FAIL]
- F4: [PASS/FAIL/N/A] — Standard event channels [detail if FAIL]

### G: Header-Specific (N/A for window)
- G1: [PASS/FAIL/N/A] — Fixed height [detail if FAIL]
- G2: [PASS/FAIL/N/A] — No unnecessary DataSource [detail if FAIL]
- G3: [PASS/FAIL/N/A] — No loading/error states [detail if FAIL]
- G4: [PASS/FAIL/N/A] — No handlesIntent [detail if FAIL]
- G5: [PASS/FAIL/N/A] — Home section [detail if FAIL]

### H: Window-Specific (N/A for header)
- H1: [PASS/FAIL/N/A] — Four body states [detail if FAIL]
- H2: [PASS/FAIL/N/A] — Toolbar present [detail if FAIL]
- H3: [PASS/FAIL/N/A] — handlesIntent defined [detail if FAIL]
- H4: [PASS/FAIL/N/A] — PromptRequired for configurable values [detail if FAIL]
- H5: [PASS/FAIL/N/A] — Intent propsMap matches props [detail if FAIL]

### I: New SDUI Primitives (N/A if none created)
- I1: [PASS/FAIL/N/A] — Registered in builtin_widgets.dart [detail if FAIL]
- I2: [PASS/FAIL/N/A] — Has WidgetMetadata [detail if FAIL]
- I3: [PASS/FAIL/N/A] — Uses PropConverter [detail if FAIL]
- I4: [PASS/FAIL/N/A] — Uses theme.resolveColor [detail if FAIL]
- I5: [PASS/FAIL/N/A] — dart analyze passes [detail if FAIL]
- I6: [PASS/FAIL/N/A] — Generic and reusable [detail if FAIL]

---

## Failures Detail

[For each FAIL, provide:]

### [Check ID]: [Check name]
**File:** [file path]
**Line:** [line number if applicable]
**Expected:** [what should be there]
**Found:** [what was found]
**Spec Reference:** [which spec section this relates to, if applicable]
```

---

## Rules

1. **Read the spec first.** Understand widget kind and expected behavior before starting checks.
2. **Report only.** Never edit catalog.json or sdui package files.
3. **Only check what this skill defines.** Do not add opinions about template design or alternative approaches.
4. **All failures are equal.** Every check is PASS or FAIL. N/A only when the skill explicitly allows it.
5. **Cite file paths and line numbers in failures.**
