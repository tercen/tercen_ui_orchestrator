# Team Manager — SDUI Gap Report

**Date:** 2026-04-14
**Spec:** `team-manager-spec.md` v1.0.0

---

## Summary

| Need | Status | Solution |
|------|--------|----------|
| 1. Master-detail accordion (single-expand) | **RESOLVED** | New `Accordion` behavior primitive wrapping Material `ExpansionPanelList.radio` |
| 2. Team row (chevron, name, badge, count) | COMPOSITION | Icon + Text + Badge + Text in Row |
| 3. Member row (name, dropdown, remove) | COMPOSITION | Text + DropdownButton + IconButton in Row |
| 4. Add member row (input, dropdown, add) | COMPOSITION | TextField + DropdownButton + IconButton in Row |
| 5. Inline error message | COMPOSITION | Alert (variant=error) + Conditional |
| 6. Sort dropdown (toolbar) | COMPOSITION | DropdownButton + Sort behavior widget |
| 7. Create Team dialog | COMPOSITION | FormDialog + TextField + PrimaryButton + GhostButton |
| 8. Delete Team confirmation dialog | COMPOSITION | FormDialog + Text + DangerButton + GhostButton |
| 9. Empty state | COMPOSITION | Conditional + Column + Icon + Text |
| 10. Loading state | AVAILABLE | DataSource integration / LoadingIndicator |
| 11. Error state | AVAILABLE | DataSource integration / Conditional + Icon + Text + Button |

---

## Gap 1: Accordion (single-expand mutual exclusion) — RESOLVED

**Category:** Primitive Gap (new behavior primitive)

**Resolution:** New `Accordion` behavior widget registered in `behavior_widgets.dart`, wrapping Material `ExpansionPanelList.radio`. This provides:
- Built-in single-expand constraint (only one panel open at a time)
- Material Design animation and styling
- `canTapOnHeader: true` for full-row click support
- EventBus integration via `expandChannel` and `collapseChannel`
- Scope variables: `{{item}}`, `{{index}}`, `{{expanded}}`, `{{activePanelId}}`
- Two template children: first = header row, second = body content
- Themeable `dividerColor` and configurable `elevation`

**Props:**
| Prop | Type | Required | Description |
|------|------|----------|-------------|
| items | list | yes | Data items to iterate |
| itemVariable | string | no | Scope variable name (default: "item") |
| panelIdKey | string | yes | Key in each item for the unique panel ID |
| expandChannel | string | no | EventBus channel for expand events |
| collapseChannel | string | no | EventBus channel for collapse events |
| elevation | number | no | Panel elevation (default: 0) |
| dividerColor | string | no | Color token or hex for divider |

---

## Composition Patterns (no code changes needed)

### Team row layout
```
Row
  Icon (chevron-right, rotates when expanded)
  Text (team name, flex, ellipsis)
  Badge (privilege: Owner/Admin/ReadWrite/Read)
  Text (member count)
```

### Member row layout
```
Row
  Text (username, flex, ellipsis)
  DropdownButton (privilege: Admin/ReadWrite/Read)
  IconButton (xmark, remove)
```

### Add member row
```
Row
  TextField (username or email, flex)
  DropdownButton (privilege, default ReadWrite)
  IconButton (plus, add)
```

### Body states
- **Loading:** DataSource wraps content; shows LoadingIndicator automatically
- **Empty:** Conditional (visible when team list empty) → Column → Icon + Text + Text
- **Error:** DataSource error state or Conditional → Column → Icon + Text + PrimaryButton (Retry)
- **Active:** ForEach → Collapsible team rows (wrapped in Accordion)

### Dialogs
- **Create Team:** FormDialog → Column → TextField (name) + Row (PrimaryButton + GhostButton)
- **Delete Team:** FormDialog → Column → Text (confirmation) + Row (DangerButton + GhostButton)
