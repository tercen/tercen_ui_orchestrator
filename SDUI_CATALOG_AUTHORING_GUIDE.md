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
  "fontSize": 16,
  "color": "{{props.textColor}}"
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
| `ListView` | `padding` (number) | Scrollable vertical list |
| `Grid` | `columns` (int, required, default 2), `spacing` (number, default 8) | Grid layout |
| `Expanded` | `flex` (int, default 1) | Fills available space in Row/Column |
| `Center` | — | Centers its child |
| `Padding` | `padding` (number, required, default 8) | Adds uniform padding |
| `SizedBox` | `width` (number), `height` (number) | Fixed-size spacer |
| `Container` | `color` (string), `padding` (number), `width` (number), `height` (number) | Box with color/padding/size |

### Display

| Type | Props | Description |
|------|-------|-------------|
| `Text` | `text` (string, required), `fontSize` (number, default 14), `color` (string), `fontWeight` (string: bold\|w100–w900) | Text display |
| `Card` | `elevation` (number, default 1), `color` (string) | Material card |
| `LoadingIndicator` | `variant` (spinner\|linear\|skeleton), `width`, `height`, `color`, `text` | Loading spinner/bar/skeleton |
| `Placeholder` | `label` (string), `color` (string) | Placeholder for testing |

### Color values

Colors can be:
- Hex: `"#1565C0"` (6-digit, no alpha)
- Named: `"red"`, `"blue"`, `"green"`, `"orange"`, `"purple"`, `"white"`, `"black"`, `"grey"`

---

## 7. Behavior widgets

These add data fetching, iteration, interaction, and state management to your templates. They are the core composition primitives.

### 7.1 DataSource — fetch data from a service

```json
{
  "type": "DataSource",
  "id": "{{widgetId}}-ds",
  "props": {
    "service": "projectService",
    "method": "findByIsPublicAndLastModifiedDate",
    "args": [[false, ""], [true, ""], "{{props.limit}}"]
  },
  "children": [ ... ]
}
```

- Calls `service.method(args...)` on mount
- Provides `{{data}}`, `{{loading}}`, `{{ready}}`, `{{error}}`, `{{errorMessage}}` to children
- Without children, shows a built-in spinner/error display
- Re-fetches if service/method/args change

### 7.2 ForEach — iterate a list

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

### 7.3 Action — make something clickable

```json
{
  "type": "Action",
  "id": "tap-{{item.id}}",
  "props": {
    "gesture": "onTap",
    "channel": "system.selection.project",
    "payload": {
      "projectId": "{{item.id}}",
      "projectName": "{{item.name}}"
    }
  },
  "children": [ ... ]
}
```

- Wraps children in a gesture detector
- On gesture, publishes `payload` to EventBus on `channel`
- Supported gestures: `onTap`, `onDoubleTap`, `onLongPress`, `onSecondaryTap`
- Adds `_channel` key to the published payload automatically

### 7.4 ReactTo — respond to events

```json
{
  "type": "ReactTo",
  "id": "rt-{{item.id}}",
  "props": {
    "channel": "system.selection.project",
    "match": {
      "projectId": "{{item.id}}"
    },
    "overrideProps": {
      "elevation": 4,
      "color": "#1565C0"
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

### 7.5 Conditional — show/hide

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

### 7.6 StateHolder — mutable local state

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

### 7.7 Sort — sort a list

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

### 7.8 Filter — filter a list

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

## 8. Event channel conventions

```
system.selection.<entity>    — User selected something (project, workflow, step, file)
system.layout.op             — Layout operations (addWindow, removeWindow, etc.)
system.data.<entity>         — Data changed
system.task.<taskId>         — Task progress/completion
widget.<widgetId>.<event>    — Widget-specific internal events
state.<nodeId>.set           — StateHolder mutation channel
```

---

## 9. Composition patterns

### 9.1 Data list with selection highlighting

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

### 9.2 Conditional loading/error states

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

### 9.3 Stateful search/filter

```
StateHolder initialState={searchQuery: ""}
  ├─ Action onTap → publish to state.<nodeId>.set with query value
  └─ Filter items={{data}} field="name" contains={{state.searchQuery}}
      └─ ForEach items={{filtered}}
          └─ ...
```

### 9.4 Detail window on double-tap

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
          { "type": "Text", "id": "d-name-{{item.id}}", "props": { "text": "{{item.name}}", "fontSize": 20, "fontWeight": "bold" } },
          { "type": "Text", "id": "d-desc-{{item.id}}", "props": { "text": "{{item.description}}", "color": "grey" } }
        ]
      }
    }
  },
  "children": [ ... ]
}
```

---

## 10. Complete example

Here is a full widget definition for a project list with selection and detail navigation:

```json
{
  "widgets": [
    {
      "metadata": {
        "type": "ProjectNavigator",
        "tier": 2,
        "description": "Scrollable list of Tercen projects with selection and detail navigation. Fetches projects from projectService and displays name, description, and owner.",
        "props": {
          "limit": {
            "type": "int",
            "required": false,
            "default": 20,
            "description": "Maximum number of projects to load"
          }
        },
        "emittedEvents": ["system.selection.project"],
        "acceptedActions": ["onTap", "onDoubleTap"]
      },
      "template": {
        "type": "DataSource",
        "id": "{{widgetId}}-ds",
        "props": {
          "service": "projectService",
          "method": "findByIsPublicAndLastModifiedDate",
          "args": [[false, ""], [true, ""], "{{props.limit}}"]
        },
        "children": [
          {
            "type": "ListView",
            "id": "{{widgetId}}-lv",
            "props": { "padding": 8 },
            "children": [
              {
                "type": "ForEach",
                "id": "{{widgetId}}-fe",
                "props": { "items": "{{data}}" },
                "children": [
                  {
                    "type": "Action",
                    "id": "tap-{{item.id}}",
                    "props": {
                      "gesture": "onTap",
                      "channel": "system.selection.project",
                      "payload": {
                        "projectId": "{{item.id}}",
                        "projectName": "{{item.name}}"
                      }
                    },
                    "children": [
                      {
                        "type": "ReactTo",
                        "id": "rt-{{item.id}}",
                        "props": {
                          "channel": "system.selection.project",
                          "match": { "projectId": "{{item.id}}" },
                          "overrideProps": { "elevation": 4, "color": "#1565C0" }
                        },
                        "children": [
                          {
                            "type": "Card",
                            "id": "card-{{item.id}}",
                            "props": { "elevation": 1, "color": "#1E1E1E" },
                            "children": [
                              {
                                "type": "Padding",
                                "id": "pad-{{item.id}}",
                                "props": { "padding": 14 },
                                "children": [
                                  {
                                    "type": "Column",
                                    "id": "col-{{item.id}}",
                                    "props": { "crossAxisAlignment": "start" },
                                    "children": [
                                      { "type": "Text", "id": "name-{{item.id}}", "props": { "text": "{{item.name}}", "fontSize": 16, "fontWeight": "bold" } },
                                      { "type": "SizedBox", "id": "sb-{{item.id}}", "props": { "height": 4 } },
                                      { "type": "Text", "id": "desc-{{item.id}}", "props": { "text": "{{item.description}}", "fontSize": 13, "color": "grey" } },
                                      { "type": "SizedBox", "id": "sb2-{{item.id}}", "props": { "height": 4 } },
                                      { "type": "Text", "id": "owner-{{item.id}}", "props": { "text": "Owner: {{item.acl.owner}}", "fontSize": 12, "color": "#888888" } }
                                    ]
                                  }
                                ]
                              }
                            ]
                          }
                        ]
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }
    }
  ]
}
```

---

## 11. Checklist for a new catalog widget

1. **Choose a unique `type` name** — PascalCase, descriptive (e.g., `WorkflowViewer`, `DataTableExplorer`)
2. **Write the metadata** — accurate `description`, all `props` with types/defaults, `emittedEvents`, `acceptedActions`
3. **Build the template tree** — compose from primitives (Section 6) and behavior widgets (Section 7)
4. **Use `{{widgetId}}-suffix` for all IDs** — prevents collisions when multiple instances exist
5. **Use `{{item.X}}` IDs inside ForEach** — makes per-item nodes unique
6. **Test binding expressions** — ensure `{{props.X}}` refs match metadata prop names
7. **Wire events correctly** — Action publishes, ReactTo subscribes on the same channel with matching keys
8. **Handle loading states** — DataSource provides `{{loading}}`/`{{ready}}`/`{{error}}`, use Conditional to show appropriate UI
9. **Validate the JSON** — must parse cleanly; every node needs `type` and `id`

---

## 12. Common mistakes

| Mistake | Fix |
|---------|-----|
| Duplicate node IDs | Use `{{widgetId}}` prefix and `{{item.id}}` suffixes |
| Binding `{{data}}` outside DataSource | Only available inside DataSource children |
| Binding `{{item}}` outside ForEach | Only available inside ForEach children |
| Using `{{item.X}}` in node IDs without ForEach | These won't resolve — use `{{widgetId}}-X` instead |
| Missing `channel` on Action | Required — Action won't publish without it |
| ReactTo `match` keys don't align with Action `payload` keys | The keys in `match` must exactly match the keys in the Action's `payload` |
| Forgetting `"required": true` on essential props | Caller might omit them, causing broken rendering |
| Using non-existent widget type | Check Section 6 and 7 for available types |
