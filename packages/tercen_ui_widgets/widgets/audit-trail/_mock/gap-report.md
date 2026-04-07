# Audit Trail — HTML Mock Gap Report

Source: extracted from `widgets/audit-trail/lib/` Dart mock (Phase 2).
Date: 2026-03-31

---

## 1. What the mock covers

The styled.html covers the **active body state** with realistic data from `MockAuditDataService`:

- Mock tab bar: teal identity dot, "MOCK" badge, light/dark theme toggle.
- Toolbar: Columns, Sort, Export CSV, Search field, Send to Chat (primary filled).
- Event table: 7 default visible columns (Date, Type, User, Action, Target, Team, Project), resizable column handles, filter icons on each header, checkbox column with select-all.
- Event type chips for all 7 types: create, update, delete, run, complete, fail, cancel — each using the correct colour token pair (background = `*-container`, foreground = `color-*`).
- Row states: default, hover, single-selected (`primary-container`), multi-selected (`primary-fixed`).
- Target column renders as an underlined link (`color-link`).
- Infinite-scroll hint row at the bottom.
- Detail panel: full metadata layout for the selected event, with sub-layouts for Activity (Properties section) vs Task (Task Timing + error box) events. Three demo events are wired to row clicks: cancel, fail (with error box), delete, update.
- Dark theme: toggled via `data-theme="dark"` on `<html>`, all colours resolve through CSS custom properties.

---

## 2. Gaps — functionality not present in the HTML mock

| # | Gap | Dart location | Notes |
|---|-----|---------------|-------|
| G1 | **Columns visibility popup** | `AuditToolbar._ColumnsMenu` | 17 columns with checkboxes, "Show All / Reset to Defaults" toggle. Not rendered in HTML — static column set only. |
| G2 | **Column filter popup (value list)** | `EventList._showColumnFilter` / `ColumnFilterPopup` | Checkbox list of unique column values, positioned under header cell. |
| G3 | **Date-range filter popup** | `EventList._showDateRangeFilter` / `DateRangeFilterPopup` | Date inputs for columns flagged `isDate` (Date, Created, Run Date). |
| G4 | **Resizable columns (drag)** | `_ResizableHeader.onHorizontalDragUpdate` | Handle is rendered but drag behaviour is not implemented in HTML. |
| G5 | **Horizontal scrollbar** | `EventList` `SingleChildScrollView` | Needed when total column width exceeds viewport. |
| G6 | **Keyboard navigation** | `AuditTrailProvider.handleKeyEvent` | Up/Down arrows, Enter (navigate to target), Escape (clear search / selection), Ctrl+A (select all). |
| G7 | **Shift+click range selection** | `AuditTrailProvider.shiftSelect` | Multi-row selection via Shift+click. |
| G8 | **Ctrl+click multi-select** | `AuditTrailProvider.toggleMultiSelect` | Individual row toggle; header checkbox select-all/clear-all. |
| G9 | **Send-to-Chat confirmation state** | `AuditToolbar._sendConfirmation` | Button icon flips to `fa-check` for 2 s after send; snackbar. |
| G10 | **Export CSV download** | `AuditToolbar._handleExportCsv` | Browser `<a download>` trigger; exports visible columns for filtered/selected rows. |
| G11 | **Scope selector** | `AuditTrailProvider.setScope` | Three scopes (project, user, team). Currently implied by static data; no UI control shown. |
| G12 | **Empty body state** | `EmptyState` | Centred `fa-clipboard-list` icon + "No events found" message. |
| G13 | **Loading body state** | `LoadingState` | Centred spinner with "Loading audit trail..." text. |
| G14 | **Error body state** | `ErrorState` | Centred error icon + message + "Retry" button. |
| G15 | **"No events match filters" inline state** | `EventList._buildEmptyFilters` | Shown inside the table area when filters produce zero rows. |
| G16 | **Load-more spinner** | `EventList._buildLoadingMore` | `CircularProgressIndicator` row appended at end of list during pagination fetch. |
| G17 | **Auto-fit column widths** | `AuditTrailProvider._autoFitColumnWidths` | TextPainter-based width measurement on data load. Not applicable to HTML. |
| G18 | **EventBus integration** | `AuditTrailProvider._handleCommand` / `_publishFocusChanged` | Commands: `openAuditTrail`, `setAuditFilter`, `setAuditDateRange`, `setAuditColumns`, `setAuditSearch`, `setAuditSort`. Intents: `focusChanged`, `sendAuditContext`, `openProject`, `openWorkflow`, `navigateToStep`, `openDocument`. |
| G19 | **Navigate-to-target double-click** | `_EventRow.onDoubleTap` | Double-click on row navigates to target object via EventBus. |
| G20 | **App snackbar** | `AppSnackbar` (success/error) | Appears for Send to Chat and Export CSV confirmations. |

---

## 3. Design decisions confirmed from Dart source

- **Window identity colour**: `#0D9488` (Teal) — hardcoded in `main.dart`.
- **Active body layout**: full-width `EventList` only (no explicit side-by-side split in `_buildActiveContent`). The `DetailPanel` is rendered in the HTML as an adjacent pane for mock purposes, but the Dart code places it inline within `EventList` scroll context.
- **Toolbar layout**: all buttons left-aligned (no spacer before trailing group). Search field is 220 px wide; Send to Chat follows immediately.
- **Column defaults**: 7 visible by default — date (130 px), type (84 px), user (110 px), action (160 px), target (140 px), team (110 px), project (140 px). 10 hidden columns available.
- **Sort default**: newest first (`_newestFirst = true`), uses `displayDate` (falls back to `timestamp` if no `completedDate` in details).
- **Chip colours**: use `color-*-container` for background and `color-*` for foreground — not custom hex values. See `event_type_chip.dart`.

---

## 4. Token compliance notes

All colours in the HTML mocks are expressed as CSS custom properties sourced from `tercen-tokens.css`. No hard-coded hex values appear in rule declarations (the `#0D9488` identity dot is an intentional exception matching the window's immutable `typeColor`). FontAwesome 6 Solid is used for all icons.
