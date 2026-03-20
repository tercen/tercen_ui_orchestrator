# SDUI Widget Catalog — Authoring Guide for AI

This document explains how to create a `catalog.json` file for a new SDUI widget library project. The catalog is a JSON file that describes reusable UI components (widgets) that the SDUI renderer can instantiate at runtime.

---

## 1. What is a catalog?

A catalog is a JSON file containing an array of **widget definitions**. Each definition has:
- **metadata** — describes the widget (name, props, events) so AIs and tools can discover and use it
- **template** — the actual widget tree (a JSON tree of `SduiNode` objects) that gets expanded at render time

The renderer loads the catalog at startup. When it encounters a node like `{"type": "MyWidget", ...}`, it looks up the template, injects the caller's props, and renders the tree.

---

## 2. Catalog file structure

```json
{
  "widgets": [
    {
      "metadata": { ... },
      "template": { ... }
    },
    {
      "metadata": { ... },
      "template": { ... }
    }
  ]
}
```

---

## 3. Metadata schema

```json
{
  "type": "WidgetName",
  "tier": 2,
  "description": "Human-readable description of what this widget does",
  "props": {
    "propName": {
      "type": "string|int|number|bool|list|object",
      "required": true,
      "default": "defaultValue",
      "values": ["option1", "option2"],
      "description": "What this prop controls"
    }
  },
  "emittedEvents": ["channel.name"],
  "acceptedActions": ["onTap", "onDoubleTap"]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | yes | Unique widget name. PascalCase. This is what callers use in their JSON. |
| `tier` | int | no | Always `2` for catalog widgets. Tier 1 = built-in primitives. |
| `description` | string | yes | What the widget does. AIs read this to decide which widget to use. Be specific. |
| `props` | object | no | Map of prop name → PropSpec. Describes every configurable input. |
| `emittedEvents` | string[] | no | EventBus channels this widget publishes to. |
| `acceptedActions` | string[] | no | Gestures the widget supports (onTap, onDoubleTap, onLongPress, onSecondaryTap). |

### PropSpec fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | yes | One of: `string`, `int`, `number`, `bool`, `list`, `object` |
| `required` | bool | no | Default `false`. If `true`, caller must provide this prop. |
| `default` | any | no | Default value used when caller omits this prop. |
| `values` | string[] | no | Enumeration of allowed values (e.g., `["asc", "desc"]`). |
| `description` | string | no | What this prop controls. |

---

## 4. SduiNode schema (the template tree)

Every node in the template is an `SduiNode`:

```json
{
  "type": "WidgetType",
  "id": "unique-id",
  "props": { ... },
  "children": [ ... ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | yes | Widget type name (must be a registered primitive or behavior widget) |
| `id` | string | yes | Unique node ID. Use `{{widgetId}}-suffix` to avoid collisions across instances. |
| `props` | object | no | Key-value pairs passed to the widget builder |
| `children` | SduiNode[] | no | Child nodes rendered inside this widget |

### ID uniqueness rules

- Every node ID must be unique within the rendered tree
- Use `{{widgetId}}` (injected automatically from the caller's node ID) as a prefix: `"{{widgetId}}-ds"`, `"{{widgetId}}-lv"`
- Inside `ForEach`, use `{{item.id}}` or `{{_index}}` to differentiate per-iteration nodes: `"card-{{item.id}}"`
- The ForEach widget automatically appends `__0`, `__1`, etc. to all child IDs, but using item-specific IDs makes debugging easier

---

## 5. Template bindings (`{{...}}` expressions)

Templates are not static — they contain binding expressions that get resolved at render time.

### 5.1 Available binding variables

| Variable | Available when | Description |
|----------|---------------|-------------|
| `{{props.X}}` | Always (in template) | Caller-provided prop `X`, with metadata defaults applied |
| `{{widgetId}}` | Always (in template) | The `id` of the node that invoked this template |
| `{{context.username}}` | Always (after auth) | Current user's username (from JWT `data.u`) |
| `{{context.userId}}` | Always (after auth) | Current user's ID (from JWT) |
| `{{data}}` | Inside `DataSource` children | Data returned by the service call |
| `{{loading}}` | Inside `DataSource` children | `true` while fetch is in progress |
| `{{ready}}` | Inside `DataSource` children | `true` when data loaded successfully |
| `{{error}}` | Inside `DataSource` children | `true` if fetch failed |
| `{{errorMessage}}` | Inside `DataSource` children | Error message string |
| `{{item}}` | Inside `ForEach` children | Current iteration item (a Map) |
| `{{_index}}` | Inside `ForEach` children | Current iteration index (int) |
| `{{matched}}` | Inside `ReactTo` children | `true` if the latest event matched |
| `{{state}}` | Inside `StateHolder` children | Current mutable state (a Map) |
| `{{sorted}}` | Inside `Sort` children | The sorted list |
| `{{filtered}}` | Inside `Filter` children | The filtered list |

### 5.2 Dot-path navigation

Access nested fields with dots: `{{item.acl.owner}}`, `{{props.config.theme}}`

### 5.3 String interpolation vs raw value

- If the entire prop value is a single `{{...}}` expression, the raw type is preserved (list, map, int, bool)
- If mixed with text (`"Hello {{item.name}}"`), the result is a string

### 5.4 Examples

```json
"props": {
  "text": "{{item.name}}",
  "textStyle": "bodyMedium",
  "color": "onSurface"
}
```

```json
"props": {
  "items": "{{data}}",
  "text": "Project: {{item.name}} ({{item.description}})"
}
```

---

## 6. Available primitive widgets (Tier 1)

These are built into the renderer. Use them as building blocks in your templates.

### Layout

| Type | Props | Description |
|------|-------|-------------|
| `Row` | `mainAxisAlignment` (start\|end\|center\|spaceBetween\|spaceAround\|spaceEvenly), `crossAxisAlignment` (start\|end\|center\|stretch) | Horizontal layout |
| `Column` | `mainAxisAlignment`, `crossAxisAlignment` (same values as Row) | Vertical layout |
| `ListView` | `padding` (number or token) | Scrollable vertical list |
| `Grid` | `columns` (int, required, default 2), `spacing` (number or token, default 8) | Grid layout |
| `Expanded` | `flex` (int, default 1) | Fills available space in Row/Column |
| `Spacer` | `flex` (int, default 1) | Flexible space in Row/Column |
| `Center` | — | Centers its child |
| `Padding` | `padding` (number or token, required, default 8) | Adds uniform padding |
| `SizedBox` | `width` (number), `height` (number) | Fixed-size spacer |
| `Container` | `color` (string), `padding` (number or token), `width` (number), `height` (number) | Box with color/padding/size |

### Display

| Type | Props | Description |
|------|-------|-------------|
| `Text` | `text` (string, required), `textStyle` (string — M3 slot name), `color` (string), `fontSize` (number, fallback), `fontWeight` (string: bold\|w100–w900, fallback) | Text display. Prefer `textStyle` over `fontSize`/`fontWeight`. |
| `Icon` | `icon` (string, required — Material icon name), `size` (number, default 24), `color` (string) | Material icon |
| `Card` | `elevation` (number, default 1), `color` (string) | Material card |
| `LoadingIndicator` | `variant` (spinner\|linear\|skeleton), `width`, `height`, `color`, `text` | Loading spinner/bar/skeleton |
| `Placeholder` | `label` (string), `color` (string) | Placeholder for testing |
| `Divider` | `height` (number), `thickness` (number), `color` (string), `indent` (number) | Horizontal divider line |
| `Chip` | `label` (string, required), `color` (string), `avatar` (string) | Material chip label |
| `CircleAvatar` | `text` (string), `icon` (string), `radius` (number), `color` (string) | Circular avatar |
| `Image` | `src` (string, required — URL), `width` (number), `height` (number), `fit` (contain\|cover\|fill) | Network image |
| `Tooltip` | `message` (string, required) | Hover tooltip wrapper |
| `ProgressBar` | `value` (number, 0.0–1.0), `variant` (linear\|circular), `color` (string) | Progress indicator |

### Interactive

| Type | Props | Description |
|------|-------|-------------|
| `TextField` | `hint` (string), `maxLines` (int), `autofocus` (bool) | Text input. Publishes `input.<id>.changed` and `input.<id>.submitted`. |
| `ElevatedButton` | `text` (string, required), `channel` (string, required), `color` (string) | Raised button. Publishes to `channel` on tap. |
| `TextButton` | `text` (string, required), `channel` (string, required), `color` (string) | Flat text button. Publishes to `channel` on tap. |
| `IconButton` | `icon` (string, required), `channel` (string, required), `tooltip` (string), `size` (number), `color` (string) | Icon button. Publishes to `channel` on tap. |
| `Switch` | `value` (bool), `channel` (string) | Toggle switch. Publishes `input.<id>.changed` with `{value: bool}`. |
| `Checkbox` | `value` (bool), `channel` (string) | Checkbox. Publishes `input.<id>.changed` with `{value: bool}`. |
| `DropdownButton` | `items` (list of strings), `value` (string), `channel` (string) | Dropdown selector. Publishes `input.<id>.changed` with `{value: selected}`. |

---

## 7. Theming and styling

**CRITICAL RULE:** Never use raw hex colors (`#1E1E1E`), pixel font sizes (`16`), or numeric spacing values in templates. Use semantic tokens only.

### 7.1 Color tokens

Colors are semantic names from the Material 3 ColorScheme. Use these in any `color` prop:

| Token | Use for |
|-------|---------|
| `primary` | Primary actions, active states |
| `onPrimary` | Text/icons on primary-colored surfaces |
| `primaryContainer` | Selected item backgrounds, highlight |
| `onPrimaryContainer` | Text on primaryContainer |
| `secondary` | Secondary actions |
| `surface` | Default background |
| `surfaceContainerHigh` | Elevated surfaces (toolbars, panels) |
| `onSurface` | Primary text on surfaces |
| `onSurfaceVariant` | Secondary text, icons |
| `onSurfaceMuted` | Tertiary/disabled text |
| `outline` | Borders |
| `outlineVariant` | Subtle dividers |
| `error` | Error states |
| `onError` | Text on error surfaces |
| `errorContainer` | Error backgrounds |

All 45+ M3 ColorScheme tokens are supported. Hex (`#RRGGBB`) and named colors (`red`, `grey`) still work as fallback but **should not be used in catalog templates**.

### 7.2 Text styles

Use the `textStyle` prop on `Text` widgets instead of `fontSize`/`fontWeight`:

| Token | Typical use |
|-------|-------------|
| `displayLarge` / `displayMedium` / `displaySmall` | Hero text, splash screens |
| `headlineLarge` / `headlineMedium` / `headlineSmall` | Page titles |
| `titleLarge` / `titleMedium` / `titleSmall` | Section headings, card titles |
| `labelLarge` / `labelMedium` / `labelSmall` | Toolbar labels, buttons, captions |
| `bodyLarge` / `bodyMedium` / `bodySmall` | Body text, list items |

### 7.3 Spacing tokens

Use token names in any `padding` or spacing prop:

| Token | Value |
|-------|-------|
| `xs` | 4px |
| `sm` | 8px |
| `md` | 16px |
| `lg` | 24px |
| `xl` | 32px |
| `xxl` | 48px |

### 7.4 Examples — correct vs incorrect

```json
// WRONG — hardcoded styling
{"type": "Text", "id": "t1", "props": {"text": "Hello", "fontSize": 13, "fontWeight": "bold", "color": "#F59E0B"}}
{"type": "Container", "id": "c1", "props": {"color": "#1E1E1E", "padding": 8}}

// CORRECT — semantic tokens
{"type": "Text", "id": "t1", "props": {"text": "Hello", "textStyle": "labelMedium", "color": "onSurface"}}
{"type": "Container", "id": "c1", "props": {"color": "surfaceContainerHigh", "padding": "sm"}}
```

---

## 8. Behavior widgets

These add data fetching, iteration, interaction, and state management to your templates. They are the core composition primitives.

### 8.1 DataSource — fetch data from a service

```json
{
  "type": "DataSource",
  "id": "{{widgetId}}-ds",
  "props": {
    "service": "projectDocumentService",
    "method": "findProjectObjectsByLastModifiedDate",
    "args": [["{{projectId}}", ""], ["{{projectId}}", "\uf000"], 50]
  },
  "children": [ ... ]
}
```

- Calls `service.method(args...)` on mount
- Provides `{{data}}`, `{{loading}}`, `{{ready}}`, `{{error}}`, `{{errorMessage}}` to children
- Without children, shows a built-in spinner/error display
- Re-fetches if service/method/args change

**CRITICAL:** Method names must be exact. Always call `discover_methods(serviceName)` first and copy the exact method name. Even small typos (e.g., `findByOwner` vs `findTeamByOwner`) will cause errors.

#### Service call args — three patterns

The `args` format depends on the method type:

**Pattern 1: `get(id)`** — fetch a single object by ID:
```json
"args": ["the-object-id"]
```

**Pattern 2: `findStartKeys` (range query)** — methods with `startKey, endKey` parameters. Args: `[startKey, endKey, limit?, skip?, descending?]`. Keys are arrays matching the CouchDB view's index fields.
```json
"args": [["{{projectId}}", ""], ["{{projectId}}", "\uf000"], 50]
```
Use startKey `[false, ...]` and endKey `[true, "\uf000"]` for views with `isPublic` to include both public and private items.

**Pattern 3: `findKeys` (key lookup)** — methods with a `keys` parameter. Args: `[keysList]` — a SINGLE list containing the lookup keys.
```json
"args": [["{{context.userId}}"]]
```

**How to tell the difference:** Check `discover_methods` output:
- If the method signature says `(startKeys)` → Pattern 2 — args is `[startKey, endKey, limit]`
- If the method signature says `(keys)` → Pattern 3 — args is `[[key1, key2, ...]]`
- If the method is `get` → Pattern 1 — args is `[id]`

### 8.2 ForEach — iterate a list

```json
{
  "type": "ForEach",
  "id": "{{widgetId}}-fe",
  "props": {
    "items": "{{data}}"
  },
  "children": [ ... ]
}
```

- Renders children once per item in `items`
- Provides `{{item}}` (current map) and `{{_index}}` (int) to children
- If `items` is null (e.g., still loading), renders nothing (safe)
- If `items` is empty, shows "No data"

### 8.3 Action — make something clickable

```json
{
  "type": "Action",
  "id": "tap-{{item.id}}",
  "props": {
    "gesture": "onTap",
    "channel": "navigator.focusChanged",
    "payload": {
      "nodeId": "{{item.id}}",
      "nodeType": "{{item.kind}}",
      "nodeName": "{{item.name}}"
    }
  },
  "children": [ ... ]
}
```

- Wraps children in a gesture detector
- On gesture, publishes `payload` to EventBus on `channel`
- Supported gestures: `onTap`, `onDoubleTap`, `onLongPress`, `onSecondaryTap`
- Adds `_channel` key to the published payload automatically

### 8.4 ReactTo — respond to events

```json
{
  "type": "ReactTo",
  "id": "rt-{{item.id}}",
  "props": {
    "channel": "navigator.focusChanged",
    "match": {
      "nodeId": "{{item.id}}"
    },
    "overrideProps": {
      "color": "primaryContainer"
    },
    "mode": "latest"
  },
  "children": [ ... ]
}
```

- Subscribes to `channel` on the EventBus
- When an event arrives, compares `event.data` keys against `match` spec
- If matched: merges `overrideProps` into the immediate children's props
- Provides `{{matched}}` (bool) to children
- `mode: "latest"` (default) — tracks whether the latest event matched
- `mode: "toggle"` — flips matched on/off with each matching event

### 8.5 Conditional — show/hide

```json
{
  "type": "Conditional",
  "id": "{{widgetId}}-cond",
  "props": {
    "visible": "{{ready}}"
  },
  "children": [ ... ]
}
```

- Shows children when `visible` is truthy (`true`, `"true"`, non-zero number)
- Hides children (renders nothing) when falsy

### 8.6 PromptRequired — collect missing configuration values

```json
{
  "type": "PromptRequired",
  "id": "{{widgetId}}-prompt",
  "props": {
    "fields": [
      {"name": "projectId", "label": "Project ID", "default": "some-default-id"}
    ]
  },
  "children": [ ... ]
}
```

- Checks if each field's value already exists in context or parent scope
- If ALL values are present: renders children immediately (no prompt shown)
- If ANY values are missing: shows a "Configure" button; clicking it opens a dialog with defaults pre-filled
- Once submitted, resolved values are exposed in child scope by field name (e.g., `{{projectId}}`)

**When to use:** Wrap templates that require IDs or configuration that cannot be inferred from the current context. This avoids hardcoding IDs while still rendering seamlessly when values are available (e.g., from a prior selection event or parent scope).

### 8.7 StateHolder — mutable local state

```json
{
  "type": "StateHolder",
  "id": "{{widgetId}}-state",
  "props": {
    "initialState": { "count": 0, "expanded": false }
  },
  "children": [ ... ]
}
```

- Provides `{{state}}` to children (e.g., `{{state.count}}`, `{{state.expanded}}`)
- Listens on channel `state.<nodeId>.set` for mutations
- Mutation operations (sent via Action payload):
  - `{"op": "merge", "values": {"key": "newValue"}}` — merge keys
  - `{"op": "increment", "key": "count", "amount": 1}` — increment number
  - `{"op": "decrement", "key": "count", "amount": 1}` — decrement number
  - `{"op": "toggle", "key": "expanded"}` — flip boolean
  - `{"op": "reset"}` — restore to initialState
  - No `op` key — implicit merge of all non-underscore-prefixed keys

### 8.8 Sort — sort a list

```json
{
  "type": "Sort",
  "id": "{{widgetId}}-sort",
  "props": {
    "items": "{{data}}",
    "key": "name",
    "direction": "asc"
  },
  "children": [ ... ]
}
```

- Sorts `items` by `key` in `asc` or `desc` order
- Provides `{{sorted}}` to children

### 8.9 Filter — filter a list

```json
{
  "type": "Filter",
  "id": "{{widgetId}}-filter",
  "props": {
    "items": "{{data}}",
    "field": "name",
    "contains": "{{state.searchQuery}}"
  },
  "children": [ ... ]
}
```

- Case-insensitive substring match on `field`
- Provides `{{filtered}}` to children

---

## 9. Event channel conventions

```
system.selection.<entity>    — User selected something (project, workflow, step, file)
system.layout.op             — Layout operations (addWindow, removeWindow, etc.)
system.data.<entity>         — Data changed
system.task.<taskId>         — Task progress/completion
navigator.focusChanged       — File navigator selection
widget.<widgetId>.<event>    — Widget-specific internal events
state.<nodeId>.set           — StateHolder mutation channel
input.<nodeId>.changed       — Interactive widget value changed
input.<nodeId>.submitted     — TextField submitted
```

---

## 10. Composition patterns

### 10.1 Data list with selection highlighting

The most common pattern: fetch data, iterate, make items tappable, highlight the selected one.

```
DataSource  →  provides {{data}}
  └─ ListView
      └─ ForEach items={{data}}  →  provides {{item}}
          └─ Action onTap → publish selection
              └─ ReactTo selection channel, match={{item.id}}
                  └─ Card (gets overrideProps when selected)
                      └─ Text {{item.name}}
```

### 10.2 Conditional loading/error states

```
DataSource  →  provides {{loading}}, {{error}}, {{data}}
  ├─ Conditional visible={{loading}}
  │    └─ LoadingIndicator
  ├─ Conditional visible={{error}}
  │    └─ Text "Error: {{errorMessage}}"
  └─ Conditional visible={{ready}}
       └─ ForEach items={{data}}
            └─ ...
```

### 10.3 PromptRequired + DataSource

When a widget needs a runtime value (like a projectId) that may or may not be in context:

```
PromptRequired fields=[{name: "projectId", label: "Project ID", default: "..."}]
  └─ DataSource service="projectDocumentService" args=[["{{projectId}}", ...]]
       └─ ForEach ...
```

If `projectId` is already in scope (e.g., passed by a parent widget), the prompt is skipped entirely.

### 10.4 Stateful search/filter

```
StateHolder initialState={searchQuery: ""}
  ├─ Action onTap → publish to state.<nodeId>.set with query value
  └─ Filter items={{data}} field="name" contains={{state.searchQuery}}
      └─ ForEach items={{filtered}}
          └─ ...
```

### 10.5 Detail window on double-tap

Use the `system.layout.op` channel with `addWindow` operation:

```json
{
  "type": "Action",
  "id": "dbl-{{item.id}}",
  "props": {
    "gesture": "onDoubleTap",
    "channel": "system.layout.op",
    "payload": {
      "op": "addWindow",
      "id": "win-detail-{{item.id}}",
      "title": "{{item.name}}",
      "size": "medium",
      "align": "center",
      "content": {
        "type": "Column",
        "id": "detail-col-{{item.id}}",
        "children": [
          { "type": "Text", "id": "d-name-{{item.id}}", "props": { "text": "{{item.name}}", "textStyle": "titleMedium" } },
          { "type": "Text", "id": "d-desc-{{item.id}}", "props": { "text": "{{item.description}}", "textStyle": "bodySmall", "color": "onSurfaceVariant" } }
        ]
      }
    }
  },
  "children": [ ... ]
}
```

---

## 11. Tercen data connection reference

### 11.1 Available services

Use `discover_services()` to get the full list. Common ones:

| Service | Common methods |
|---------|---------------|
| `teamService` | `findTeamByOwner` (keys: userId) |
| `projectService` | `findByIsPublicAndLastModifiedDate` (startKeys) |
| `projectDocumentService` | `findProjectObjectsByLastModifiedDate`, `findProjectObjectsByFolderAndName` |
| `workflowService` | `get(id)` |
| `tableSchemaService` | `get(id)` |
| `fileService` | `get(id)` |
| `userService` | `get(id)`, `findUserByEmail` (keys) |

### 11.2 User context

The JWT token provides user identity, available in templates as:
- `{{context.username}}` — the Tercen username
- `{{context.userId}}` — the user's unique ID

Common pattern for user-specific queries:
```json
"args": [["{{context.userId}}"]]
```

### 11.3 Tercen API quirks

- **Dates** are wrapped objects: `{"kind": "Date", "value": "2026-01-09T19:00:02.248Z"}`. Access the actual string via `.value`.
- **Object IDs** are in the `id` field (not `_id`).
- **User = Team**: A Tercen user is itself a team. `findTeamByOwner` returns the user's teams.
- **findKeys view names differ from method names**: `findTeamByOwner` → view `teamByOwner`, `findUserByEmail` → view `userByEmail`. The dispatcher handles this mapping internally.

---

## 12. Complete example

Here is a full widget definition for a file navigator with PromptRequired, semantic theming, and proper data connection:

```json
{
  "widgets": [
    {
      "metadata": {
        "type": "FileNavigator",
        "tier": 2,
        "description": "File browser for a Tercen project. Lists project documents (files, schemas, workflows) with selection support.",
        "props": {
          "projectId": {
            "type": "string",
            "required": false,
            "description": "Project ID to browse. If omitted, prompts user."
          }
        },
        "emittedEvents": ["navigator.focusChanged"],
        "acceptedActions": ["onTap"]
      },
      "template": {
        "type": "PromptRequired",
        "id": "{{widgetId}}-prompt",
        "props": {
          "fields": [
            {"name": "projectId", "label": "Project ID", "default": "2076952ae523bb4d472e283b9e000121"}
          ]
        },
        "children": [{
          "type": "Column",
          "id": "{{widgetId}}-root",
          "props": {"crossAxisAlignment": "stretch"},
          "children": [
            {
              "type": "Container",
              "id": "{{widgetId}}-toolbar",
              "props": {"color": "surfaceContainerHigh", "padding": "sm"},
              "children": [{
                "type": "Row",
                "id": "{{widgetId}}-toolbar-row",
                "props": {"mainAxisAlignment": "spaceBetween"},
                "children": [
                  {"type": "Text", "id": "{{widgetId}}-title", "props": {"text": "Navigator", "textStyle": "labelMedium", "color": "onSurface"}},
                  {"type": "Text", "id": "{{widgetId}}-filter-label", "props": {"text": "All types", "textStyle": "labelSmall", "color": "onSurfaceMuted"}}
                ]
              }]
            },
            {
              "type": "Expanded",
              "id": "{{widgetId}}-body",
              "children": [{
                "type": "DataSource",
                "id": "{{widgetId}}-ds",
                "props": {
                  "service": "projectDocumentService",
                  "method": "findProjectObjectsByLastModifiedDate",
                  "args": [["{{projectId}}", ""], ["{{projectId}}", "\uf000"], 50]
                },
                "children": [
                  {
                    "type": "Conditional", "id": "{{widgetId}}-loading",
                    "props": {"visible": "{{loading}}"},
                    "children": [{"type": "Center", "id": "{{widgetId}}-spinner", "children": [{"type": "LoadingIndicator", "id": "{{widgetId}}-li", "props": {"variant": "skeleton", "text": "Loading…"}}]}]
                  },
                  {
                    "type": "Conditional", "id": "{{widgetId}}-error",
                    "props": {"visible": "{{error}}"},
                    "children": [{"type": "Center", "id": "{{widgetId}}-err-center", "children": [{"type": "Text", "id": "{{widgetId}}-err-text", "props": {"text": "Error: {{errorMessage}}", "color": "error"}}]}]
                  },
                  {
                    "type": "Conditional", "id": "{{widgetId}}-ready",
                    "props": {"visible": "{{ready}}"},
                    "children": [{
                      "type": "ListView", "id": "{{widgetId}}-lv", "props": {"padding": 4},
                      "children": [{
                        "type": "ForEach", "id": "{{widgetId}}-fe", "props": {"items": "{{data}}"},
                        "children": [{
                          "type": "Action", "id": "tap-{{item.id}}",
                          "props": {"gesture": "onTap", "channel": "navigator.focusChanged", "payload": {"nodeId": "{{item.id}}", "nodeType": "{{item.kind}}", "nodeName": "{{item.name}}"}},
                          "children": [{
                            "type": "ReactTo", "id": "rt-{{item.id}}",
                            "props": {"channel": "navigator.focusChanged", "match": {"nodeId": "{{item.id}}"}, "overrideProps": {"color": "primaryContainer"}},
                            "children": [{
                              "type": "Padding", "id": "pad-{{item.id}}", "props": {"padding": "sm"},
                              "children": [{
                                "type": "Row", "id": "row-{{item.id}}",
                                "children": [
                                  {"type": "Icon", "id": "icon-{{item.id}}", "props": {"icon": "description", "size": 16, "color": "onSurfaceVariant"}},
                                  {"type": "SizedBox", "id": "gap-{{item.id}}", "props": {"width": 8}},
                                  {"type": "Expanded", "id": "exp-{{item.id}}", "children": [{"type": "Text", "id": "name-{{item.id}}", "props": {"text": "{{item.name}}", "textStyle": "bodySmall"}}]},
                                  {"type": "Text", "id": "kind-{{item.id}}", "props": {"text": "{{item.kind}}", "textStyle": "labelSmall", "color": "onSurfaceMuted"}}
                                ]
                              }]
                            }]
                          }]
                        }]
                      }]
                    }]
                  }
                ]
              }]
            }
          ]
        }]
      }
    }
  ]
}
```

---

## 13. Checklist for a new catalog widget

1. **Choose a unique `type` name** — PascalCase, descriptive (e.g., `WorkflowViewer`, `DataTableExplorer`)
2. **Write the metadata** — accurate `description`, all `props` with types/defaults, `emittedEvents`, `acceptedActions`
3. **Build the template tree** — compose from primitives (Section 6) and behavior widgets (Section 8)
4. **Use semantic tokens only** — `textStyle` not `fontSize`, color tokens not hex, spacing tokens not pixel values (Section 7)
5. **Use `{{widgetId}}-suffix` for all IDs** — prevents collisions when multiple instances exist
6. **Use `{{item.X}}` IDs inside ForEach** — makes per-item nodes unique
7. **Test binding expressions** — ensure `{{props.X}}` refs match metadata prop names
8. **Wire events correctly** — Action publishes, ReactTo subscribes on the same channel with matching keys
9. **Handle loading states** — DataSource provides `{{loading}}`/`{{ready}}`/`{{error}}`, use Conditional to show appropriate UI
10. **Wrap with PromptRequired** if the widget needs IDs that may not be in context
11. **Verify service methods** — call `discover_methods(serviceName)` and use EXACT method names
12. **Use correct args pattern** — check if the method uses `startKeys` (range) or `keys` (lookup) format
13. **Validate the JSON** — must parse cleanly; every node needs `type` and `id`

---

## 14. Common mistakes

| Mistake | Fix |
|---------|-----|
| Duplicate node IDs | Use `{{widgetId}}` prefix and `{{item.id}}` suffixes |
| Binding `{{data}}` outside DataSource | Only available inside DataSource children |
| Binding `{{item}}` outside ForEach | Only available inside ForEach children |
| Using `{{item.X}}` in node IDs without ForEach | These won't resolve — use `{{widgetId}}-X` instead |
| Missing `channel` on Action | Required — Action won't publish without it |
| ReactTo `match` keys don't align with Action `payload` keys | The keys in `match` must exactly match the keys in the Action's `payload` |
| Forgetting `"required": true` on essential props | Caller might omit them, causing broken rendering |
| Using non-existent widget type | Check Section 6 and 8 for available types |
| Hardcoded hex colors (`#1E1E1E`) | Use semantic tokens (`surfaceContainerHigh`) |
| Raw `fontSize` / `fontWeight` | Use `textStyle` with M3 slot name (`bodySmall`, `labelMedium`) |
| Guessing service method names | Always call `discover_methods` first and copy exact names |
| Wrong args format for findKeys | `findKeys` methods: `args: [["key1"]]` (list inside list). `findStartKeys`: `args: [[start], [end], limit]` |
| Using `{{context.username}}` for key lookups | Some views index by userId, not username. Check `discover_methods` output. |
| Hardcoding object IDs in templates | Use `PromptRequired` with a default, or bind from context/scope |
