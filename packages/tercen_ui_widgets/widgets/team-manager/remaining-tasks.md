# TeamManager — Remaining Tasks

**Date:** 2026-04-15
**Status:** Accordion rows with member controls working. Mutations and dialogs not yet wired.

---

## What's Working

- Teams button on HomePanel opens TeamManager in same pane
- Team list loads via `findKeys("teamByOwner", [userId])`
- Accordion expand/collapse per team (Collapsible primitive)
- Members load inside expanded team via `findTeamMembers(teamId)` (enriched with privilege from ACL)
- Privilege dropdown per member showing actual role (Owner/Admin/ReadWrite/Read)
- Remove member button (X) with red hover state
- Add member row: text field + privilege dropdown + add button (layout aligned to 24+8+200+8+150+4+32 grid)
- Toolbar with "Create Team" button (not yet wired)
- Loading/error/empty body states
- New Project dialog git toggle fixed (ReactTo → EventScope)

## Engine Changes Made

| File | Change | Why |
|------|--------|-----|
| `builtin_widgets.dart` | TextField `maxLines` defaults to 1 when absent | Fixes TextField blowing out Row layouts |
| `builtin_widgets.dart` | `hoverColor` prop + `_HoverIconButton` on IconButton | Destructive hover style on remove buttons |
| `behavior_widgets.dart` | `refreshChannel` prop on ServiceCall | Triggers DataSource refresh after mutations |
| `service_call_dispatcher.dart` | `userService.setTeamPrivilege` method | Calls API to add/remove/change member privilege |
| `service_call_dispatcher.dart` | `userService.findTeamMembers` method | Fetches members enriched with privilege from team ACL |
| `service_call_dispatcher.dart` | `import sci_tercen_model` | Needed for Principal/Privilege model classes |
| `main.dart` | ReactTo → EventScope in New Project dialog | Fixes "unknown widget ReactTo" error |

## Known Bugs

### 1. Add member does not work
The add member button triggers `userService.setTeamPrivilege` but it errors out:
```
ServiceError({statusCode: 400, error: user.not.found, reason: User not found})
```
**Likely cause:** The `setTeamPrivilege` dispatcher sends `(username, teamId, privilegeType)` but the API may expect different argument shapes, or the watchChannels/arg resolution isn't picking up the TextField value correctly at trigger time. Needs debug tracing to check what args are actually sent.

### 2. Remove member not tested
The remove button publishes to `team.{{widgetId}}.removeMember` and a global ServiceCall listens, but this hasn't been tested end-to-end. May have the same arg resolution issue as add.

### 3. Privilege change not tested
The per-member ServiceCall for privilege change triggers on dropdown change, but hasn't been tested. May need the same fixes as add/remove.

## Remaining Features (by priority)

### High Priority
1. **Debug & fix add member** — trace the actual args being sent, fix the API call
2. **Test remove member** — verify the remove ServiceCall works end-to-end
3. **Test privilege change** — verify dropdown change triggers correct API call
4. **Refresh after mutations** — verify `refreshChannel` triggers member list reload after add/remove/change

### Medium Priority
5. **Create Team dialog** — FormDialog with name field, wired to `teamService.create` (needs dispatcher override to accept bare name string)
6. **Delete Team confirmation** — FormDialog with confirm/cancel, wired to `teamService.delete` (needs dispatcher override for get-then-delete since template only has ID, not rev)
7. **Sort dropdown** in toolbar — needs PopupMenu toolbar action (engine change was in reverted commits, may need to bring back)
8. **Search field** in toolbar — Filter primitive + toolbar search already exist

### Lower Priority
9. **Single-expand** — only one team open at a time (Collapsible doesn't enforce this natively, may need state management)
10. **Chevron rotation** — right arrow when collapsed, down arrow when expanded (bind icon to `{{expanded}}`)
11. **Editing rules** — disable dropdown/remove for non-admin users, hide remove for owner row
12. **Personal team filtering** — exclude user's personal folder from team list

## Files Modified (uncommitted)

| File | Summary |
|------|---------|
| `lib/main.dart` | ReactTo → EventScope fix for New Project dialog |
| `lib/sdui/service/service_call_dispatcher.dart` | setTeamPrivilege, findTeamMembers, model import |
| `packages/sdui/lib/src/registry/behavior_widgets.dart` | ServiceCall refreshChannel prop |
| `packages/sdui/lib/src/registry/builtin_widgets.dart` | TextField maxLines fix, IconButton hoverColor |
| `packages/tercen_ui_widgets/catalog.json` | Full TeamManager template, Teams button wiring |
