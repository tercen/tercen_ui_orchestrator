# Window Widget — Phase 1 Functional Spec Template

**Reference:** `_references/window-design.md`

---

## Window Design Constraints

MUST follow these rules when designing the UI.

1. **Toolbar + Body layout:** Toolbar (48px header) at top + Body (flex fill) below. No left panel, no status panel, no footer. The tab above the toolbar is rendered by the Frame, not the window.
2. **Three structural layers:** Tab (defined by window, rendered by Frame) + Toolbar + Body. Individual window types build within these layers, not around them.
3. **Window is self-contained.** It does not know about other windows, tabs, panels, or layout. It renders content and communicates with the Frame exclusively through the EventBus.
4. **Toolbar actions are all left-aligned.** No spacer split. Actions flow left to right. Non-button controls (search, dropdowns) go in a trailing slot pushed right by a Spacer.
5. **Toolbar visibility:** Present for native window types. Hidden when hosting an existing Tercen app that provides its own header bar.
6. **Four body states are mandatory:** `loading`, `empty`, `active`, `error`. Every window must handle all four. If a state is intentionally unused, the spec must say so with justification.
7. **Theme is received, not controlled.** The window consumes theme state from the Frame. No theme toggle in the window.
8. **No right-click context menus.** All actions are visible buttons with tooltips.
9. **Available toolbar control types:** icon-only button, icon+label button, search field (collapsible), dropdown. Use icon-only by default; icon+label only for primary actions.
10. **Identity is mandatory.** Every window declares a `typeId`, `typeColor` (from the Tercen logo palette), and `label`.

### Window Type Colour Assignments

Each window type has a fixed colour from the Tercen 4x4 pixel-art logo:

| Window Type | Colour | Hex |
|---|---|---|
| Home | Multi (logo itself) | — |
| File Navigator | Yellow | `#FFBF00` |
| Chat | Cyan | `#00FFFF` |
| Workflow | Purple | `#9333EA` |
| Document | Orange | `#FF8200` |
| Data Viewer | Blue | `#0099FF` |
| Visualization | Green | `#66FF7F` |
| Audit Trail | Teal | `#0D9488` |

### EventBus Communication

Windows communicate with the Frame through an abstract EventBus. The spec must define what events the window emits and responds to.

**Standard outbound intents** (all windows emit these via `window.intent` channel):

| Intent | Payload | When |
|--------|---------|------|
| `close` | `{windowId}` | Window requests to be closed |
| `maximize` | `{windowId}` | Window requests to be maximized |
| `restore` | `{windowId}` | Window requests to be restored |
| `contentChanged` | `{windowId, label}` | Window's label has changed |
| `openResource` | `{windowId, resourceType, resourceId}` | User clicked something that should open in a new window |

**Standard inbound commands** (frame sends to `window.{id}.command`):

| Command | When |
|---------|------|
| `focus` | Frame is giving this window focus |
| `blur` | Frame is removing focus |

Window types may define additional intents and subscriptions as needed.

---

## Spec Template

Every window functional spec follows this structure. Sections 1–4 are required. Section 5 is optional.

```markdown
# [Widget Name] - Functional Specification

**Version:** 1.0.0
**Status:** Draft
**Last Updated:** [Date]
**Widget Kind:** Window (Feature Window)
**Window Type:** [Type from colour table — e.g., "Workflow", "Data Viewer"]
**Type Colour:** [Hex from colour table]
**Reference**: [Source material — existing widget, screenshots, description, etc.]

---

## 1. Overview

### 1.1 Purpose
[What problem does this window solve? What role does it play in the Tercen Frame? One paragraph.]

### 1.2 Users
[Who uses this window and how?]

### 1.3 Scope

**In Scope:**
- [Feature 1]
- [Feature 2]

**Out of Scope:**
- [Exclusion 1 — typically: layout/tab management, theme control, window creation]

### 1.4 Data Source
[What Tercen data does this window display or interact with? What services does it call?]

| Data | Source | Description |
|------|--------|-------------|
| [Data item] | [Service/method or EventBus channel] | [What it represents] |

**SDUI Template Mapping** (for Phase 3 — helps the integrator write DataSource nodes):

| Data | Service | Method | Args | Render Primitive |
|------|---------|--------|------|------------------|
| [Data item] | [e.g. workflowService] | [e.g. getWorkflowGraph] | [e.g. workflowId] | [e.g. DirectedGraph, DataTable, ForEach+Card] |

*Available services:* `tableSchemaService`, `fileService`, `projectService`, `workflowService`, `userService`, `projectDocumentService`, `operatorService`.
*Available domain primitives:* `DataGrid`, `DirectedGraph`, `ImageViewer`, `TabbedImageViewer`.

---

## 2. User Interface

### 2.1 Window Structure

[ASCII layout diagram. Example:]

┌─ Tab (rendered by Frame) ──────────────────────┐
│ [■] [label]                [maximize] [close]   │
├─ Toolbar ──────────────────────────────────────┤
│ [action] [action] [action]        [search]      │
├─ Body ─────────────────────────────────────────┤
│                                                  │
│  [Content area — state-driven]                   │
│                                                  │
└──────────────────────────────────────────────────┘

### 2.2 Identity

| Property | Value |
|----------|-------|
| Type ID | [e.g., `dataViewer`] |
| Type Colour | [Hex from colour table] |
| Initial Label | [e.g., "Data"] |
| Label Updates | [When and how — e.g., "Updates to filename when a file is opened"] |

### 2.3 Toolbar

| Position | Control | Type | Tooltip | Enabled When | Action |
|----------|---------|------|---------|-------------|--------|
| 1 | [name] | icon-only / icon+label | [tooltip text] | [condition] | [what happens] |
| trailing | [name] | search / dropdown | [tooltip text] | [condition] | [what happens] |

### 2.4 Body States

#### Loading
- [What triggers this state]
- [What the user sees — spinner text, etc.]

#### Empty
- [What triggers this state — or "Not applicable" with justification]
- [Icon, message, optional detail text]
- [Optional action button — label and what it does]

#### Active
- [Describe the main content layout and behaviour]
- [What interactions are available — click, hover, select, scroll, drag]
- [How content responds to data changes]

#### Error
- [What triggers this state]
- [Error message source]
- [Retry behaviour]

### 2.5 EventBus Communication

**Outbound (window publishes):**

| Channel | Intent Type | Payload | When |
|---------|-------------|---------|------|
| `window.intent` | `openResource` | `{resourceType, resourceId}` | [e.g., "User double-clicks a file"] |
| [custom channel] | [type] | [payload] | [when] |

**Inbound (window subscribes):**

| Channel | Event Type | Response |
|---------|------------|----------|
| `window.{id}.command` | `focus` / `blur` | [Any window-specific focus behaviour] |
| [custom channel] | [type] | [what the window does] |

---

## 3. Mock Data

### 3.1 Data Requirements
- [What example data is needed — JSON files, assets, generated data]
- [Data characteristics: volume, structure, edge cases]
- [How mock data maps to the data sources in Section 1.4]

### 3.2 Mock EventBus Behaviour
- [What events to simulate for standalone development]
- [Any inbound events the mock should fire on a timer or trigger]

---

## 4. Assumptions

- Window runs inside the Tercen Frame — never standalone in production
- Frame provides tab rendering, focus management, theme broadcasting, and panel layout
- EventBus is available via the service locator
- [Data assumptions — what we assume about data availability and format]
- [Any window-specific assumptions]

---

## 5. Optional Sections

Include any of these if they add value for the specific widget. Omit if not needed.

### 5.1 Non-Functional Requirements

| ID | Requirement |
|----|-------------|
| NFR-01 | [Only if unusual — e.g., large datasets, real-time streaming, specific latency] |

### 5.2 Glossary

| Term | Definition |
|------|------------|
| [Term] | [Only if the domain has unfamiliar terminology] |
```

---

## Discovery Process

Gather information in this order. Adapt questions to the input source (existing widget code, screenshots, verbal description, existing documentation).

### Round 1: Purpose and Identity

- What does this window do? Who uses it?
- Which window type is this? (Home, File Navigator, Chat, Workflow, Document, Data Viewer, Visualization, Audit Trail — or a new type?)
- What data from Tercen does it display or interact with?
- What is in scope? What is explicitly out of scope?
- Is there existing code, screenshots, or a running example?

### Round 2: Toolbar and Interactions

- What toolbar actions does this window need? (List each with tooltip, enabled condition, action)
- Are there trailing toolbar controls? (search field, filter dropdown)
- What interactions does the body content support? (click, hover, select, double-click, drag, scroll)
- Does the window emit `openResource` intents? If so, for what resource types?
- Are there any custom EventBus channels this window publishes or subscribes to? What are the channel names?

### Round 3: Body States and Data

- What does the active state look like? Describe the content layout.
- What triggers the empty state? (Or is it intentionally unused?)
- What data does the window fetch? What service/method?
- How does the window label update? When and to what?
- What does the loading state say?
- What errors can occur? How are they displayed?
- What mock data and mock EventBus behaviour is needed?

### Round 4: Draft and Review

- Write the complete spec following the template above.
- Present to user for review.
- Iterate until approved.

---

## Checklist

Before completing Phase 1:

- [ ] Identity table complete (typeId, typeColor, initial label, label update rule)
- [ ] ASCII layout diagram with Toolbar + Body structure (tab shown as Frame-rendered)
- [ ] Toolbar actions enumerated (type, tooltip, enabled condition, action)
- [ ] All four body states addressed (described, or marked "not applicable" with justification)
- [ ] EventBus communication defined with explicit channel names (outbound intents + inbound subscriptions)
- [ ] Custom channels documented if any
- [ ] Active state content layout described (interactions, data flow)
- [ ] Mock data and mock EventBus behaviour specified
- [ ] Out of scope explicitly lists Frame concerns (tabs, layout, theme toggle)
- [ ] No implementation detail (no code, no framework references)
- [ ] User has reviewed and approved
