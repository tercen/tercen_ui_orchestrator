# Team Manager — Functional Specification

**Version:** 1.0.0
**Status:** Draft
**Last Updated:** 2026-04-14
**Widget Kind:** Window (Feature Window)
**Window Type:** Team Manager
**Type Colour:** `#0000FF` (Blue)
**Reference:** Tercen API — teamService, userService (sci_tercen_client)

---

## 1. Overview

### 1.1 Purpose

The Team Manager is the central hub for team membership and collaboration in the Tercen UI. It lists every team the current user belongs to, sorted by their privilege level, and provides standard management features: creating teams, viewing members, adding/removing members, and adjusting privileges. It does NOT show the user's personal folder (which is technically a team) — only named collaborative teams.

### 1.2 Users

| User | Relationship with the Team Manager |
|------|------------------------------------|
| **Team Owner** | Creates teams, manages all members and their privileges, deletes teams they own. Full control over teams they created. |
| **Team Admin** | Views all members, adds/removes members, changes member privileges. Cannot delete the team. |
| **Team Member (ReadWrite / Read)** | Views team membership. Can remove themselves from a team. Cannot modify other members. |

### 1.3 Scope

**In Scope:**
- List all teams the current user belongs to (excluding personal folder)
- Sort teams by privilege level or alphabetically (user-selectable)
- Expand a team to view its members (master-detail accordion)
- Create a new team (current user becomes owner)
- Add a member to a team by username or email
- Remove a member from a team
- Change a member's privilege level
- Remove yourself from a team (leave)
- Delete a team (owner only)

**Out of Scope:**
- Transfer team ownership
- Team resource usage / quota display
- Team billing or profile management
- Tab management, layout, or theme control (Frame concerns)
- The user's personal folder/team

### 1.4 Data Source

| Data | Source | Description |
|------|--------|-------------|
| User's teams | `teamService.findTeamByMember(userId)` | All teams the current user is a member of |
| Team members | `userService.findTeamMembers(keys: [teamId])` | Members of a specific team (loaded on expand) |
| Current user | Session context | The logged-in user's ID, used to determine privilege per team |

**SDUI Template Mapping:**

| Data | Service | Method | Args | Render Primitive |
|------|---------|--------|------|------------------|
| Team list | teamService | findTeamByMember | userId | ForEach + expandable Row |
| Team members | userService | findTeamMembers | teamId (key) | ForEach + Row (inside accordion) |
| Create team | teamService | create | name | Form dialog |
| Add member | userService | setTeamPrivilege | username, principal, privilege | Inline add row |
| Remove member | userService | setTeamPrivilege | username, principal, privilege=none | Button action |
| Change privilege | userService | setTeamPrivilege | username, principal, privilege | Dropdown action |
| Delete team | teamService | delete | id, rev | Confirmation dialog |

---

## 2. User Interface

### 2.1 Window Structure

```
┌─ Tab (rendered by Frame) ──────────────────────────┐
│ [■] Team Manager                  [maximize] [close]│
├─ Toolbar ──────────────────────────────────────────┤
│ [+ Create Team] [🗑 Delete]           [Sort ▾]      │
├─ Body ─────────────────────────────────────────────┤
│                                                      │
│  ▶ Research Team              [Admin]    3 members   │
│  ▼ Data Science               [Owner]    5 members   │
│  ┌──────────────────────────────────────────────┐    │
│  │  alice.jones       [Admin ▾]        [✕]      │    │
│  │  bob.smith         [ReadWrite ▾]    [✕]      │    │
│  │  carol.wu          [Read ▾]         [✕]      │    │
│  │  dave.chen         [ReadWrite ▾]    [✕]      │    │
│  │  [________________] [ReadWrite ▾]   [+ Add]  │    │
│  └──────────────────────────────────────────────┘    │
│  ▶ Bioinformatics             [Read]     12 members  │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### 2.2 Identity

| Property | Value |
|----------|-------|
| Type ID | `teamManager` |
| Type Colour | `#0000FF` (Blue) |
| Initial Label | "Team Manager" |
| Label Updates | None — label is always "Team Manager" |

### 2.3 Toolbar

| Position | Control | Type | Tooltip | Enabled When | Action |
|----------|---------|------|---------|-------------|--------|
| 1 | Create Team | icon+label | "Create a new team" | Always | Opens a Create Team dialog (name field + confirm) |
| 2 | Delete | icon-only | "Delete selected team" | A team is selected AND current user is the owner of that team AND it is not the personal team | Confirms, then deletes the selected team |
| trailing | Sort | dropdown | "Sort teams" | Always | Cycles sort order (see §2.6) |

### 2.4 Body States

#### Loading
- Triggered when fetching the team list from the server on initial load or refresh.
- Standard loading spinner (no hardcoded text).

#### Empty
- Triggered when the user belongs to no collaborative teams (only their personal folder, which is hidden).
- Centred empty-state icon (FontAwesome `users` or `people-group`) + message: "No teams yet" + detail: "Create a team to start collaborating" + the Create Team button remains active in the toolbar.

#### Active
- The team list is displayed as a master-detail accordion list (see §2.5).

#### Error
- Triggered when the team list fetch fails.
- Centred error icon + error message from the server + "Retry" button.

### 2.5 Master-Detail Accordion List

#### Team Row (Master)

Each collapsed team row displays:

| Element | Description |
|---------|-------------|
| Expand chevron | Right-pointing when collapsed, down-pointing when expanded |
| Team name | Text with ellipsis overflow |
| Privilege badge | The current user's privilege level in this team (Owner, Admin, ReadWrite, Read) |
| Member count | Number of members, e.g. "3 members" |

Clicking the row or chevron toggles the expanded state. Only one team may be expanded at a time (expanding a new team collapses the previous one). Expanding a team selects it (for toolbar actions like Delete).

The owner is determined by comparing `team.acl.owner` with the current user's ID. If they match, the badge reads "Owner".

#### Member Row (Detail)

When a team is expanded, member rows are displayed below it in an indented list. Each member row displays:

| Element | Description |
|---------|-------------|
| Username | The member's username, with ellipsis overflow |
| Privilege dropdown | A dropdown showing the member's current privilege (Admin, ReadWrite, Read). Changing the selection immediately calls `setTeamPrivilege`. |
| Remove button | An icon-only button (FontAwesome `xmark`) to remove the member from the team. |

**Editing rules:**

| Scenario | Privilege dropdown | Remove button |
|----------|-------------------|---------------|
| Current user is Owner or Admin of this team | Enabled for all non-owner members | Enabled for all non-owner members |
| Current user is ReadWrite or Read member | Disabled (read-only) | Disabled, EXCEPT on the current user's own row (they can leave) |
| The row is the team owner | Disabled (owner privilege is fixed) | Hidden (owner cannot be removed; they can only delete the team) |
| The row is the current user (non-owner) | Follows privilege rules above | Shown as "Leave" action — removes self from team |

#### Add Member Row

Below the last member row, a persistent "add member" row is displayed when the current user has Admin or Owner privilege:

| Element | Description |
|---------|-------------|
| Username/email field | A text input accepting a username or email address |
| Privilege dropdown | Defaults to "ReadWrite". Options: Admin, ReadWrite, Read. |
| Add button | Icon-only button (FontAwesome `plus`) — enabled when the text field is non-empty |

**Behaviour:**
- On Add, the system calls `setTeamPrivilege` with the entered username/email and selected privilege.
- If the username/email does not match any user in the system, a non-modal inline error message is shown below the add row (e.g. "User not found"). The error clears when the text field is modified.
- On success, the new member appears in the member list and the text field clears.

### 2.6 Sort Control

The sort dropdown in the trailing toolbar slot offers these options:

| Option | Behaviour |
|--------|-----------|
| **By Privilege** (default) | Owner first, then Admin, then ReadWrite, then Read. Within each group, alphabetical by team name. |
| **By Name (A–Z)** | Alphabetical ascending by team name |
| **By Name (Z–A)** | Alphabetical descending by team name |

### 2.7 Create Team Dialog

Triggered by the "Create Team" toolbar button. A modal dialog with:

| Element | Description |
|---------|-------------|
| Title | "Create Team" |
| Name field | Text input for team name. Required. |
| Cancel button | Dismisses the dialog |
| Create button | Calls `teamService.create(team)` with the entered name. On success, the new team appears in the list and the dialog closes. On failure (e.g. name already exists, invalid characters), an inline error is shown in the dialog. |

**Team name validation:** The API enforces URL-safe naming (alphanumeric, `-`, `_`, `.`, `~`). The dialog should show the server's error message if validation fails.

### 2.8 Delete Team Confirmation

Triggered by the "Delete" toolbar button (enabled only for owner-selected teams). A confirmation dialog with:

| Element | Description |
|---------|-------------|
| Title | "Delete Team" |
| Message | "Are you sure you want to delete **{team name}**? This action cannot be undone." |
| Cancel button | Dismisses the dialog |
| Delete button | Calls `teamService.delete(id, rev)`. On success, removes the team from the list. On failure, shows error. |

### 2.9 EventBus Communication

**Outbound (window publishes):**

| Channel | Intent Type | Payload | When |
|---------|-------------|---------|------|
| `window.intent` | `contentChanged` | `{windowId, label: "Team Manager"}` | Not used — label never changes |

**Inbound (window subscribes):**

| Channel | Event Type | Response |
|---------|------------|----------|
| `window.{id}.command` | `focus` / `blur` | Standard focus handling |

No custom EventBus channels are required. The Team Manager is self-contained — it does not navigate to other windows or emit `openResource` intents.

---

## 3. Mock Data

### 3.1 Data Requirements

Mock data should include:
- **3–5 teams** with varying privilege levels for the current user (at least one where user is Owner, one Admin, one ReadWrite, one Read)
- **2–8 members per team** with mixed privilege levels
- **One team with a single member** (the owner) to test the minimal member list
- **Team names** that are realistic (e.g. "Research Lab", "Data Science", "Bioinformatics", "External Reviewers")

Mock JSON fixtures should follow the Team and User model shapes from `sci_tercen_model`.

### 3.2 Mock EventBus Behaviour

- No inbound events to simulate — the Team Manager does not subscribe to custom channels.
- Standard `focus` / `blur` commands from the frame mock.

---

## 4. Assumptions

- Window runs inside the Tercen Frame — never standalone in production
- Frame provides tab rendering, focus management, theme broadcasting, and pane layout
- EventBus is available via the service locator
- The current user's personal folder/team is excluded from the team list (filtered client-side by comparing team ID with user ID, or by checking a known "personal team" marker)
- `findTeamByMember` returns teams with enough data to determine the current user's privilege (via the user's `teamAcl.aces`)
- `findTeamMembers` returns User objects with enough data to display username and determine privilege per team
- The `setTeamPrivilege` API with privilege `none` effectively removes a member from a team
- Team deletion cascades appropriately on the server side (the widget does not need to clean up related resources)

---

## 5. Optional Sections

### 5.1 New Primitive: Expandable Accordion List

This widget introduces a **master-detail accordion list** pattern not currently available as an SDUI primitive. The Phase 3 gap analysis should evaluate whether a reusable `AccordionList` or `ExpandableListItem` primitive is needed, with:

- Expand/collapse toggle per row
- Optional single-expand constraint (only one item expanded at a time)
- Nested content slot for the detail view
- Selection state (expanded item = selected)

### 5.2 Glossary

| Term | Definition |
|------|------------|
| Personal folder | Every Tercen user has a personal team (same ID as their username). It acts as their private workspace and cannot be deleted or left. It is excluded from the Team Manager. |
| Privilege | The access level a user has within a team. Levels: Owner (implicit, via ACL), Admin, ReadWrite, Read. |
| ACL | Access Control List — the permission structure on Tercen objects. Teams use ACLs to track ownership and member privileges. |
