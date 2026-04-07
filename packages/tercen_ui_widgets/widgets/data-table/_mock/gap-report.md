# Data Table — SDUI Gap Report

**Widget:** Data Table (Window 5)
**Spec version:** 1.0
**Generated:** 2026-03-31
**Source:** data-table-spec.md, active_state.dart, window_toolbar.dart, mock_data_service.dart

---

## How to read this table

| Column | Meaning |
|--------|---------|
| **Element** | Named UI element from the spec or Dart implementation |
| **SDUI Primitive** | The catalog.json primitive that would render this element |
| **Gap Type** | `exists` — primitive already in catalog / `extend` — primitive exists but needs new props / `new` — new primitive required |
| **Notes** | What needs to be done to close the gap |

---

## Gap Table

| # | Element | SDUI Primitive | Gap Type | Notes |
|---|---------|---------------|----------|-------|
| 1 | **Window toolbar** (48px, ghost buttons, spacer, trailing widgets) | `WindowToolbar` | exists | Already part of skeleton-window pattern. Left actions + spacer + trailing actions layout is standard. |
| 2 | **Ghost icon toolbar button** (32×32, 8px radius, hover state, focus ring) | `ToolbarIconButton` | exists | Implemented in window_toolbar.dart. SDUI must support `variant: ghost \| primary \| secondary` and `icon` prop. |
| 3 | **Labeled toolbar button** (icon + text, 32px height) | `ToolbarLabeledButton` | exists | Used for Save/Discard in annotation mode. Needs `label` prop alongside `icon`. |
| 4 | **Toolbar search field** (collapse-to-icon, match count, prev/next navigation) | `ToolbarSearchField` | extend | Spec §5.2. Primitive likely exists in skeleton; needs `matchCount` and `onNavigate` props to support in-widget search rather than global search. |
| 5 | **Go-to-row input** (number text field, 28px height, Enter triggers scroll) | `ToolbarNumberInput` | new | No equivalent primitive. Needs: `type: number`, `placeholder`, `onSubmit` action, `min`/`max` validation, error flash on out-of-range. |
| 6 | **Sort progress indicator** (2px LinearProgressIndicator, indeterminate, primary colour) | `LinearProgressBar` | new | No thin progress bar primitive in catalog. Full-width, 2px height, indeterminate animation, `color: primary`. Shown only during sort. |
| 7 | **Table grid — header row** (fixed, 36px, horizontally scrollable with data) | `DataTableHeader` | new | No table-specific header primitive. Needs: `columns[]` prop, sticky top, horizontal scroll sync with body, `onSort` action per column. |
| 8 | **Column header cell** (column name, type badge, sort arrow, click-to-sort, tooltip) | `DataTableHeaderCell` | new | Child of `DataTableHeader`. Needs: `columnName`, `columnType`, `sortState: asc \| desc \| none`, `onSort` action, hover state, tooltip. |
| 9 | **Row number column** (fixed 56px, non-scrolling, 0-based index, muted style) | `DataTableRowIndex` | new | Frozen first column. Not sortable, not editable. Style: `color: onSurfaceMuted`. Width fixed at 56px per spec. |
| 10 | **Data row** (32px height, even/odd alternating bg, hover highlight, virtualised) | `DataTableRow` | new | Fixed row height. Background: even=`surface`, odd=`surfaceContainerLow`. Hover: `primaryFixed`. Virtualised rendering (only visible rows). |
| 11 | **Data cell** (text, numeric right-aligned, tooltip on hover, ellipsis overflow) | `DataTableCell` | new | Needs: `value`, `type` (string vs numeric → alignment), `overflow: ellipsis`, `tooltip: colName: value`, 140px width. |
| 12 | **Search match highlight** (amber tint on matched cells) | `DataTableCell` | extend | Add `highlighted: match \| focused` prop to `DataTableCell`. `match` → `rgba(amber, 0.25)`, `focused` → `rgba(amber, 0.55)`. Uses `warning`/`warningContainer` token palette. |
| 13 | **Edited cell highlight** (blue tint, annotation mode only) | `DataTableCell` | extend | Add `editState: edited` prop. Background: `rgba(primary, 0.12)`. Only active when `annotationMode: true`. |
| 14 | **Go-to-row highlight** (amber bg, brief animation, clears after ~1.5s) | `DataTableRow` | extend | Add `highlighted: gotoTarget` prop. Background: `rgba(warningContainer, 0.65)`. Auto-clears — needs a timer or one-shot animation. |
| 15 | **Inline cell editor** (text input within cell, annotation mode) | `DataTableCellEditor` | new | Full-width input inside a data cell. Spec §10.2. `border: 2px primary`, `borderRadius: sm`, confirm on Enter/blur, cancel on Escape. Appears only in `annotationMode: true`. |
| 16 | **Info popover** (table metadata, column list, copy-ID button) | `InfoCard` or `OverlayPanel` | new | Spec §8. Anchored to Info toolbar button. Contains: name, ID (with copy button), kind, row count, column count, scrollable column list. No equivalent primitive — needs a positioned overlay container. |
| 17 | **Metadata field row** (key: value pair inside popover) | `KeyValueRow` | new | Reusable label-value layout used inside the Info popover. May be generalisable to other popovers across widgets. |
| 18 | **Column list in popover** (scrollable, full name, type label, no truncation) | `ColumnList` | new | Child component of the Info popover. Spec §8.2. Alternating row background. Each row: column name + type string. |
| 19 | **Copy-to-clipboard button** (icon-only, inline with ID field, "Copied" toast) | `ClipboardCopyButton` | new | Spec §8.3. 20×20 icon button adjacent to the ID value. On copy: shows brief "Copied" success toast. Reusable across widgets. |
| 20 | **Loading body state** (centred spinner + "Loading table…" label) | `LoadingState` | exists | Standard skeleton-window body state. Spinner size: 28px (matches `window.avatarSize`). Label: `bodyMedium`. |
| 21 | **Empty body state** (centred icon + title + subtitle) | `EmptyState` | exists | Standard skeleton-window body state. Icon: `fa-table` (solid). Title: `headlineSmall`. Subtitle: `bodyMedium`, `onSurfaceMuted`. |
| 22 | **Error body state** (centred icon + message + Retry button) | `ErrorState` | exists | Standard skeleton-window body state. Icon: `fa-triangle-exclamation`. Error message string prop. Retry is a Primary button. |
| 23 | **Active body state** (toolbar + grid) | `ActiveState` | exists | Container: toolbar at top (fixed), table grid below (fills remaining height). Layout is `Column` in Flutter / `flex-direction: column` in CSS. |
| 24 | **Annotation mode toolbar indicator** (Annotate button in primary variant) | `ToolbarIconButton` | extend | Add `active: bool` prop to `ToolbarIconButton`. When `active: true`, render as `variant: primary`. Spec §5.3. |
| 25 | **Save annotations button** (labeled, floppy-disk icon, edit count in label, disabled when 0 edits) | `ToolbarLabeledButton` | extend | Needs `disabled` prop and dynamic `label` (e.g. "Save (3)" with count injected from state). |
| 26 | **Discard changes button** (labeled, xmark icon, shows in annotation mode only) | `ToolbarLabeledButton` | exists | Standard labeled button, `icon: xmark`, conditionally visible via `visible` binding. |
| 27 | **Annotation mode banner** (info strip below toolbar, edit count badge) | `AnnotationBanner` | new | Full-width strip between toolbar and table grid. Background: `primaryFixed`. Contains: icon, text, edit-count badge. Only shown in annotation mode. No equivalent primitive. |
| 28 | **Edit count badge** (pill showing "N edits") | `Badge` | extend | Rounded pill with count. Background: `primaryContainer`, text: `onPrimaryContainer`. Needs `variant: primary` on a generic `Badge` primitive. |
| 29 | **Discard confirm dialog** ("Discard N unsaved changes?") | `ConfirmDialog` | new | Modal dialog with title, body text, Cancel (ghost) + Discard (error/danger) buttons. Spec §10.5. No danger-variant confirm dialog exists in catalog. |
| 30 | **CSV download progress** (Download button loading state, disabled during export) | `ToolbarIconButton` | extend | Add `loading: bool` prop — shows spinner icon, disables button. Auto-resets on completion. |
| 31 | **Toast notification** ("Annotations saved", "Copied", "Downloaded") | `Toast` | extend | Short-lived notification. Spec §8.3. Likely exists; needs `duration` prop and `variant: success` for save, neutral for copy. |
| 32 | **Type badge** (short type label inside header cell: str / dbl / int32) | `TypeBadge` | new | Small pill inside column header. Background: `surfaceContainer`. Text: `onSurfaceMuted`. Content abbreviated from full type string. Not in catalog. |
| 33 | **Horizontal scroll sync** (header scrolls with body horizontally) | _(layout behaviour)_ | new | Not a visual primitive — a scroll-link constraint. Requires platform-level coordination between header and body `ScrollController`s. Must be specified in the widget's layout contract, not in catalog.json. |
| 34 | **Virtual scroll / infinite load** (load-more on scroll-to-bottom) | _(platform behaviour)_ | new | Requires `onScrollEnd` trigger and `loadPage(offset, limit)` action. Not expressible as a single SDUI primitive — needs a `DataTableSource` service binding or streaming data primitive. |
| 35 | **Sort state (triple-state toggle)** (asc → desc → none per column) | _(state behaviour)_ | extend | Sort state drives header cell appearance and data ordering. Needs `sortColumn` and `sortDirection` in `DataTableProvider` state shape and corresponding SDUI state bindings. |

---

## Summary by gap type

| Gap Type | Count | Elements |
|----------|-------|---------|
| `exists` | 6 | WindowToolbar, ToolbarIconButton, ToolbarLabeledButton, LoadingState, EmptyState, ErrorState, ActiveState |
| `extend` | 10 | ToolbarSearchField, DataTableCell (search highlight), DataTableCell (edit highlight), DataTableRow (goto highlight), ToolbarIconButton (active variant), ToolbarLabeledButton (disabled+count), Badge, ClipboardCopyButton (→ Toast), CSVDownload loading state, Sort state binding |
| `new` | 17 | ToolbarNumberInput, LinearProgressBar, DataTableHeader, DataTableHeaderCell, DataTableRowIndex, DataTableRow, DataTableCell, DataTableCellEditor, InfoCard/OverlayPanel, KeyValueRow, ColumnList, ClipboardCopyButton, AnnotationBanner, ConfirmDialog, TypeBadge, HScrollSync (layout constraint), VirtualScroll/InfiniteLoad |

---

## Priority order for implementation

### P0 — Blocking (cannot show Active state without these)

1. `DataTableHeader` + `DataTableHeaderCell` — column headers with sort
2. `DataTableRow` + `DataTableCell` — data rendering
3. `DataTableRowIndex` — frozen row-number column
4. `LinearProgressBar` — sort feedback

### P1 — Core features (functional for review)

5. `ToolbarNumberInput` — go-to-row
6. `ToolbarSearchField` extensions — match count, prev/next
7. Search + edit highlight props on `DataTableCell`
8. `DataTableCellEditor` — annotation mode editing

### P2 — Metadata and UX polish

9. `InfoCard` / `OverlayPanel` + `KeyValueRow` + `ColumnList` + `ClipboardCopyButton`
10. `AnnotationBanner` + `ConfirmDialog`
11. `TypeBadge`
12. `Toast` extension (duration, variant)

### P3 — Platform / data layer

13. Virtual scroll / infinite load — requires `DataTableSource` service binding
14. Horizontal scroll sync — platform layout constraint
15. Sort state SDUI binding

---

## Token compliance notes

All colour values in the Dart mock use deleted tokens (see `tokens.meta.json` `deletedTokens`).
The HTML mock uses only approved tokens. Mapping:

| Dart (deleted) | Approved replacement |
|---------------|---------------------|
| `panelBackground` | `surfaceContainerLow` |
| `surfaceElevated` | `surfaceContainerHigh` |
| `borderSubtle` | `outlineVariant` |
| `textPrimary` | `onSurface` |
| `textMuted` | `onSurfaceMuted` |
| `primaryBg` | `primaryFixed` |
| `primaryDarker` | `onPrimaryContainer` |
| `primarySurface` | `primaryContainer` |

Search highlight amber colours (`0x40FBBF24` / `0x40F59E0B`) are not named tokens.
Recommended token approach: derive from `warning` and `warningContainer` with opacity, or add
`searchHighlight` and `searchFocusHighlight` as named Tercen extension tokens.

The window identity colour `#F59E0B` (amber/warning yellow for the Data tab) is listed in
`approvedTypeColors` in `tokens.meta.json` — approved for use.
