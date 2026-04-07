# Window Widget — Design Summary

> Reference for window widget skills. This document will expand as the window design matures.

---

## What Is a Window Widget?

A **feature window** that runs inside the Tercen UI Orchestrator frame. It provides:

1. Contextual information for both user and LLM during chat interactions
2. Interactive controls that instruct the LLM to perform Tercen functions
3. A display layer for Tercen data, navigation, and workflow context

Unlike panel and runner widgets, window widgets do not operate standalone — they are embedded within the orchestrator and communicate via message passing.

---

## Layout

Single-panel window with toolbar, body, and body state management.

```
┌─ Window Toolbar ────────────────────────────────┐
│  [Tab icon] [Title]              [Actions]       │
├─────────────────────────────────────────────────┤
│                                                  │
│  Window Body                                     │
│  (state-driven: loading / empty / active / error)│
│                                                  │
└─────────────────────────────────────────────────┘
```

---

## Skeleton Reference

Skeleton at `skeletons/window/`. Key files:

| File | Purpose |
|------|---------|
| `lib/presentation/widgets/window_shell.dart` | Window frame and layout |
| `lib/presentation/widgets/window_toolbar.dart` | Toolbar with tabs and actions |
| `lib/presentation/widgets/window_body.dart` | Body state switching |
| `lib/presentation/widgets/body_states/*.dart` | Loading, empty, active, error states |
| `lib/domain/services/event_bus.dart` | Message passing with orchestrator |
| `lib/domain/models/window_identity.dart` | Window identity and configuration |
| `lib/domain/models/content_state.dart` | Content state management |

---

## Toolbar Conventions

All toolbar buttons use primary accent styling (no ghost/secondary distinction). This ensures visual consistency across the toolbar.

- **Button size:** 36px (`WindowConstants.toolbarButtonSize` = `AppSpacing.controlHeight`)
- **Icon size:** 16px (`WindowConstants.toolbarButtonIconSize`)
- **Border radius:** 8px (`WindowConstants.toolbarButtonRadius` = `AppSpacing.radiusMd`)
- **Gap between buttons:** 8px (`WindowConstants.toolbarGap` = `AppSpacing.sm`)
- **Toolbar height:** 48px (`WindowConstants.toolbarHeight` = `AppSpacing.headerHeight`)
- **Minimum widget width:** 240px (`WindowConstants.minWidgetWidth`)
- **Hover transition:** 150ms ease via `AnimatedContainer`
- **Disabled buttons:** `onPressed: null`, muted icon colour, no hover effect

### Toolbar layout

```
[Button] [Button] [Button] ...  [Trailing widgets (search, filter)]
```

Action buttons flow left-to-right. Non-button controls (search field, dropdowns) go in the trailing slot, pushed right by a Spacer.

### Reusable search field

The skeleton provides `ToolbarSearchField` — a responsive text field for toolbars:

- Collapses to 36px (icon only) when narrow, expands up to configurable max width
- FontAwesome magnifying glass prefix, xmark clear button
- Accepts `onChanged` and optional `onClear` callbacks
- See `lib/presentation/widgets/toolbar_search_field.dart`

---

## Icon Conventions

All widgets use **FontAwesome 6** icons (`font_awesome_flutter` package), not Material Icons. This aligns with the Tercen style guide.

### Icon colours

Icons must use theme palette tokens only — no custom hex colours.

| Context | Light | Dark |
|---------|-------|------|
| Navigation/structural | `AppColors.primary` | `AppColorsDark.primary` |
| Files/documents | `AppColors.neutral700` | `AppColorsDark.neutral300` |
| Data/tables | `AppColors.warning` | `AppColorsDark.warning` |
| Workflows/pipelines | `AppColors.info` | `AppColorsDark.info` |
| Muted/secondary | `AppColors.neutral500` | `AppColorsDark.neutral400` |

---

## Content Area Conventions

### Text overflow

Any item name in a list, tree, or table must use `Flexible` + `TextOverflow.ellipsis` + `maxLines: 1`. Never allow text to wrap or overflow.

### Inline indicators

Status badges, chips, and icons displayed after an item name should:

- Use `Flexible` (not `Expanded`) on the name text
- Flow inline after the name with `AppSpacing.sm` padding
- NOT be pushed to the right edge with a `Spacer`

### Toolbar text styling

Text within toolbar controls (filter labels, search placeholder) must use `AppTextStyles.body` consistently.

### Toolbar control tooltips

All toolbar controls must have a `Tooltip`. For filter/dropdown controls, use "Filter" as the tooltip message. For action buttons, use the action name (e.g. "Upload", "Download").

**Important:** For `PopupMenuButton`, pass the tooltip via the widget's own `tooltip` parameter — do NOT wrap it in a separate `Tooltip` widget. `PopupMenuButton` has an internal gesture detector that blocks external `Tooltip` widgets from receiving hover events.

---

## Pane — The Tab Container

Window widgets run inside a **pane**. The pane is the draggable tab container managed by the orchestrator. Widget authors do NOT build pane chrome — it is provided by the framework.

**Terminology:** Frame (overall UI) > Workspace > Pane(s) > Tab(s) > Window widget content

**Design reference:** `skeletons/pane/` in the SDUI repo.

### What the pane provides (widget does NOT implement)

- **Tab strip** (32px): color square, title, close button per tab
- **Container**: straight corners (0px radius), `borderSubtle` border
- **Focus state**: primary accent bar on active tab when pane is focused
- **Drag/resize**: handled by the orchestrator's window manager

### What the widget provides (via its template)

- **Toolbar**: via `WindowShell` with `toolbarActions`
- **Body states**: loading, empty, active, error
- **Content**: all internal layout and styling
- **Identity**: `typeColor` (hex, for tab color square) and initial `label` (for tab title)
- **Dynamic title updates**: publish `{type: 'setTitle', title: '...'}` on `window.{id}.command`

### Widget metadata requirements for pane integration

Each widget must declare in its metadata:

| Field | Purpose | Example |
|-------|---------|---------|
| `typeColor` | Hex color for the 8px tab color square | `#1E40AF` |
| `handlesIntent[].windowTitle` | Initial tab title (supports `{{param}}` interpolation) | `"Workflow: {{name}}"` |
| `handlesIntent[].windowSize` | Initial pane size preset | `"large"`, `"column"` |

### Styling rules

- **No window-level chrome** in widget templates (no outer border, shadow, or title bar)
- **No rounded corners on outermost container** (pane has 0px radius)
- **Internal components** may use `borderRadius` (cards, inputs, etc.)
- **`elevation`** on internal components is acceptable but keep it subtle (1-2, not 3+)

---

## Design Details (Pending)

Key areas still to document:

- Orchestrator communication protocol (postMessage events)
- LLM instruction interface
- Content type registry
- Navigation integration
- Theme synchronization with parent frame
