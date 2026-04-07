# SDUI Primitive Gaps -- Audit Trail

Generated: 2026-04-02
Updated: 2026-04-02
Source: Flutter mock conversion to catalog.json

**Policy:** No silent workarounds. Each gap is tagged with `_unimplemented: "TAG: description"` in the catalog JSON so the orchestrator debugger encounters explicit markers rather than dead UI. Fake/misleading UI elements (non-functional checkboxes, unconnected search fields) are removed or clearly tagged.

---

## GAP-1: Chip -- no per-item colour mapping

**Mock needs:** Event type chips with distinct bg/fg colour pairs per type (create=success/successContainer, delete=error/errorContainer, update=info/infoContainer, cancel=warning/warningContainer)
**SDUI has:** Chip primitive with single `color` prop, applies alpha automatically. No foreground colour control.
**Missing:** `fgColor`/`bgColor` props on Chip, or a Conditional-based colour switch on `{{item.eventType}}`
**Suggested fix:** Add `fgColor` prop to Chip, or add a `colorMap` prop that maps values to colour tokens
**Blocking:** `type-{{item.id}}` chip in event list rows, `{{widgetId}}-detail-type-chip` in detail panel
**Catalog tag:** `_unimplemented: "CHIP_COLOR_MAP"` on both list and detail Chip nodes. No fallback colour applied — chip renders unstyled.

## GAP-2: PopupMenu -- no checkbox items

**Mock needs:** Column visibility popup with 17 checkbox items, "Show All / Reset to Defaults" toggle
**SDUI has:** PopupMenu with `{value, label, icon?, divider?}` items -- single-select, no checkboxes
**Missing:** `multiSelect: true` prop or `checkbox: true` per item
**Suggested fix:** Add `selectionMode: "multi"` to PopupMenu, items gain `checked` state
**Blocking:** `{{widgetId}}-btn-columns` toolbar button
**Catalog tag:** `_unimplemented: "POPUP_MULTI_SELECT"` on PopupMenu node. Items list is present for reference but popup is single-select only.

## GAP-3: Date range filter -- no date picker primitive

**Mock needs:** DateRangeFilterPopup with From/To date+time inputs, positioned under column header
**SDUI has:** No date picker or date input primitive registered
**Missing:** Entire DatePicker/DateRangeInput primitive
**Suggested fix:** Register `DateRangeInput` primitive in builtin_widgets.dart
**Blocking:** Column header filters on Date, Created, Run Date columns
**Catalog tag:** None — feature entirely omitted from template. No date filter UI present.

## GAP-4: Resizable columns -- not expressible in SDUI

**Mock needs:** Drag handles between column headers to resize widths (40-600px range)
**SDUI has:** No resizable column or drag-resize primitive
**Missing:** Column resize behaviour on Row children
**Suggested fix:** Platform-level enhancement -- not a primitive gap
**Blocking:** None (cosmetic, columns use Expanded with flex ratios instead)
**Catalog tag:** None — acceptable fallback. Columns use fixed flex ratios via Expanded wrappers. Functional but not resizable.

## GAP-5: CSV export -- no file download primitive

**Mock needs:** Export button triggers browser file download (CSV blob)
**SDUI has:** Action primitive publishes to EventBus channel, but no file-download handler
**Missing:** Orchestrator action handler for CSV export
**Suggested fix:** Orchestrator registers handler for `audit.*.exportCsv` channel
**Blocking:** `{{widgetId}}-btn-export` toolbar button action
**Catalog tag:** `_unimplemented: "CSV_EXPORT"` on IconButton. Channel fires but nothing handles it.

## GAP-6: Toast/snackbar -- no notification primitive

**Mock needs:** Success snackbar after "Send to Chat" and "Export CSV" actions (2s auto-dismiss)
**SDUI has:** No toast/snackbar/notification primitive
**Missing:** Entire Toast/Snackbar primitive
**Suggested fix:** Register `Toast` primitive or handle as orchestrator-level feedback
**Blocking:** User feedback for send-to-chat and export actions
**Catalog tag:** Covered by `_unimplemented: "SEND_TO_CHAT"` on the send button. No separate toast node — user gets no feedback.

## GAP-7: Multi-select with Shift/Ctrl click

**Mock needs:** Ctrl+click toggles individual row, Shift+click selects range, header checkbox selects all
**SDUI has:** StateManager with `selectionKey` and `multiSelect`, ForEach auto-highlights selected. No modifier-key detection.
**Missing:** Modifier-key-aware selection in ForEach/Action
**Suggested fix:** Platform-level enhancement -- ForEach could detect Ctrl/Shift on tap
**Blocking:** Multi-select checkboxes and range selection in event list
**Catalog tag:** `_unimplemented: "MULTI_SELECT_HEADER"` on header row. Fake checkboxes removed from both header and per-row — they rendered but did nothing. Single-click selection via Action + StateManager still works.

## GAP-8: Infinite scroll / load more

**Mock needs:** ListView with scroll-to-bottom pagination trigger, loading spinner at end of list
**SDUI has:** ListView with ForEach, but no pagination/load-more behaviour
**Missing:** `onEndReached` prop or pagination-aware DataSource
**Suggested fix:** Add `loadMore` channel prop to DataSource that fires when ForEach reaches end
**Blocking:** Large audit logs require pagination
**Catalog tag:** `_unimplemented: "PAGINATION"` on main DataSource. Only first page (200 items) loads. Large audit logs silently truncated.

## GAP-9: Conditional equality check

**Mock needs:** Show task timing section only when `data.source == "task"` (string equality)
**SDUI has:** Conditional `visible` prop checks truthiness, not string equality
**Missing:** Expression evaluation in Conditional (e.g., `"visible": "{{data.source}} == 'task'"`)
**Suggested fix:** Support simple equality expressions in Conditional, or add `equals` prop
**Blocking:** `{{widgetId}}-detail-task-cond` -- task timing section visibility
**Catalog tag:** `_unimplemented: "CONDITIONAL_EQUALITY"` on Conditional node. Uses `{{data.isTask}}` which does NOT exist on the API response — will fail at runtime.

## GAP-10: Search field -- filter binding

**Mock needs:** TextField search input that filters the ForEach items (debounced, case-insensitive)
**SDUI has:** TextField publishes to `input.<id>.changed`, Filter behaviour primitive exists
**Missing:** Wiring between TextField and Filter is unclear -- may already work via Filter primitive
**Suggested fix:** Verify Filter primitive subscribes to TextField channel automatically
**Blocking:** `{{widgetId}}-search` toolbar field filtering the event list
**Catalog tag:** `_unimplemented: "SEARCH_FILTER"` on TextField. Field renders and accepts input but typing does nothing — no Filter primitive wired to ForEach.

---

## Summary

| Priority | Count | Description |
|----------|-------|-------------|
| P1 (Core UX — will fail visibly) | 4 | GAP-1 (chip colours), GAP-8 (pagination), GAP-9 (conditional equality), GAP-10 (search filter) |
| P2 (Features — channel fires but no handler) | 3 | GAP-5 (CSV export), GAP-6 (toast), GAP-7 (multi-select) |
| P3 (Enhancements) | 3 | GAP-2 (popup checkboxes), GAP-3 (date filter), GAP-4 (resizable columns) |

All gaps tagged with `_unimplemented: "TAG"` in audit-trail-catalog.json. No silent workarounds — the debugger will encounter explicit markers on every unimplemented feature.
