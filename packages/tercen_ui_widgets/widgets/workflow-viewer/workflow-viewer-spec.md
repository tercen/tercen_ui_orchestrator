# Workflow Viewer — Functional Specification

**Version:** 1.0
**Last Updated:** 2026-03-11
**Reference:** Original specification
**Window:** 3 (Workflow Viewer)
**App Type:** skeleton-window (Feature Window for Tercen Frame)
**Status:** Ready for review

---

## 1. Purpose

The Workflow Viewer is the primary pipeline visualisation and control tool in the Tercen LLM platform. It presents the full structure of a Tercen workflow as a hybrid tree/org-chart flowchart, showing every step's type, state, and data flow connections.

The viewer exists for **three user actions**:

1. **Set focus** — single-click a step to tell the LLM what you are looking at
2. **Control execution** — run, stop, or reset steps via a context-sensitive toolbar button
3. **Open** — double-click a step to view it in its dedicated viewer

All other operations (add steps, wire connections, configure operators) are performed by the **LLM via Chat**. The viewer is read-heavy and control-light by design.

---

## 2. Context — Where This Fits

### 2.1 Product context

The Tercen LLM platform has eight feature windows:

| # | Window | Role |
|---|--------|------|
| 0 | Home Page | Entry point and project navigation |
| 1 | File Navigator | Browse hierarchy, upload, set focus, open viewers |
| 2 | Chat | Primary LLM interaction surface |
| **3** | **Workflow Viewer** | **This spec — pipeline visualisation, step focus, execution control** |
| 4 | Document Viewer/Editor | Markdown, SVG, reports |
| 5 | Data Viewer/Annotator | Tercen data tables |
| 6 | Visualisation Viewer/Annotator | Plots and images with markup |
| 7 | Audit Trail | Logs and history |

### 2.2 Three user types

| User | Relationship with the viewer |
|------|---------------------------------|
| **Scientist** | Primary user. Clicks steps to focus the LLM, runs/resets workflows, opens step viewers. Does not build pipelines directly — asks the LLM. |
| **Bioinformatician** | Inspects workflow structure, checks step states, monitors long-running computations. May rename steps for clarity. |
| **Auditor** | Reviews workflow structure and execution history. Primarily reads, does not modify or run. |

---

## 3. Architecture — skeleton-window Conformance

This window conforms to the **skeleton-window** pattern from `skeletons/window/`.

### 3.1 App type

**Type 1 Feature Window** — rendered inside the Tercen Frame. The Frame provides tabs above this window. The viewer communicates with the Frame and other windows exclusively via the **EventBus**.

### 3.2 Four body states

The window MUST implement all four body states per the skeleton-window pattern:

| State | When | Display |
|-------|------|---------|
| **Loading** | Fetching workflow data from Tercen | Centred spinner + "Loading workflow..." |
| **Empty** | No workflow is open (no workflow ID provided) | Centred icon + "No workflow selected" + "Select a workflow in the Navigator" |
| **Active** | Workflow data loaded | Toolbar + Flowchart View |
| **Error** | Tercen connection failed or workflow not found | Centred error icon + message + "Retry" button |

### 3.3 Layout

Toolbar (fixed height) at top, Flowchart View (scrollable in both axes, fills remaining space) below. No side panels — the flowchart occupies the full body area.

```text
+------------------------------------------+
| Toolbar                                  |
+------------------------------------------+
|                                          |
| Flowchart View (scrollable X + Y)       |
|                                          |
+------------------------------------------+
```

### 3.4 State

The widget tracks the following state:

| State | Purpose |
|-------|---------|
| Workflow data | The full workflow model: steps, links, and metadata |
| Focused node | The currently focused step or the workflow root (single selection) |
| Search text | Active text search string |
| Search matches | List of step IDs matching the current search |
| Window state | Current body state (loading, empty, active, error) |
| Error message | Detail text when in the error state |
| Editing node | Which node name is currently being inline-edited (null if none) |

### 3.5 Theming

- All UI chrome must be theme-aware (light and dark modes)
- Use only the shared design token system — no hardcoded colours, font sizes, spacing, or stroke widths
- Flowchart shapes, connectors, and state colours must work correctly in both light and dark modes

### 3.6 Window identity

| Property | Value |
|----------|-------|
| Tab label | "Workflow" |
| Tab icon | Small coloured square per feature-window-base-spec |

---

## 4. Workflow Model

### 4.1 Tercen step type hierarchy

The Tercen data model defines the following step inheritance:

```text
Step (base)
  +-- ModelStep
  |     +-- RelationStep
  |     |     +-- TableStep
  |     |     +-- InStep
  |     |     +-- OutStep
  |     |     +-- NamespaceStep
  |     |           +-- JoinStep
  |     |           +-- MeltStep
  |     |           +-- WizardStep
  |     |           +-- CrossTabStep
  |     |                 +-- DataStep
  |     +-- ExportStep
  +-- ViewStep
  +-- GroupStep
```

All steps share these base properties: `id`, `groupId`, `name`, `inputs[]`, `outputs[]`, `rectangle`, `state`, `description`.

### 4.2 Step grouping

- Every step has a `groupId` that references its parent GroupStep (or empty string for top-level steps)
- GroupStep acts as a container — its children are all steps whose `groupId` matches the GroupStep's `id`
- GroupSteps are legacy sub-workflows. They have no visual boundary, just a section-header role in the flowchart
- InStep and OutStep are legacy port markers within groups, shown for compatibility

### 4.3 Workflow links

Links connect step outputs to step inputs. Each link has:

- `inputStepId` — the step receiving data
- `outputStepId` — the step producing data

Links define the data flow and determine the connector lines drawn between shapes.

### 4.4 Step states

Every step has a `state` property with one of four values:

| State class | Meaning |
|-------------|---------|
| `InitState` | Step has not been run (waiting) |
| `DoneState` | Step completed successfully |
| `RunningState` | Step is currently executing |
| `FailedState` | Step encountered an error |

There is no `CancelledState` in Tercen.

---

## 5. Step Type Display Matrix

Each step type has specific visual rules governing its appearance and layout behaviour.

| Step Type | Display Style | Name Display | Shape | Row Rule | Focusable | Editable Name | FA6 Icon |
|---|---|---|---|---|---|---|---|
| Workflow | Icon | Label Outside | circle badge | root node (row 0) | yes | yes | `sitemap` |
| GroupStep | Icon | Label Outside | circle badge | new row | yes | yes | `sitemap` |
| TableStep | Box | Always visible | rounded rect | new row | yes | yes | `table` |
| JoinStep | Icon | Always visible | hexagon 90deg | half-space row | yes | yes | `codeMerge` |
| DataStep | Box | Always visible | rounded rect | new row | yes | yes | `cubes` |
| ViewStep | Icon | Hover only | circle badge | SAME row as parent | yes | yes | `eye` |
| InStep | Icon | Hover only | rounded square | first row in group | yes | no | `rightToBracket` |
| OutStep | Icon | Hover only | rounded square | last row in group | yes | no | `rightFromBracket` |
| MeltStep | Box | Always visible | hexagon 90deg | new row | yes | yes | `shuffle` |
| ExportStep | Box | Always visible | rounded rect | new row | yes | yes | `file` |
| WizardStep | Icon | Hover only | rounded rect | new row | yes | yes | `wandMagicSparkles` |

### 5.1 Column definitions

**Display Style** — determines how the step renders:

- **Icon** — a shape containing only the FA6 icon. The step name appears outside the shape (below or beside it) or on hover, depending on the Name Display column.
- **Box** — a larger shape containing both the FA6 icon and the step name as inline text.

**Name Display** — when the step name is visible:

- **Always visible** — name text is rendered inside the box at all times.
- **Label Outside** — name text is rendered below or beside the icon shape at all times.
- **Hover only** — name text appears in a tooltip on mouse hover. Not visible by default.

**Shape** — the geometric outline of the node:

- **circle badge** — small circle containing the icon.
- **rounded rect** — standard rectangle with rounded corners.
- **rounded square** — small square with rounded corners (compact, icon-only).
- **hexagon 90deg** — hexagon rotated 90 degrees so flat sides face east and west, with points facing north and south. Inputs connect from the left (west flat side), output exits downward from the south point.

**Row Rule** — vertical placement in the flowchart:

- **root node (row 0)** — the workflow itself, always at the top.
- **new row** — starts a new vertical level below its predecessor.
- **SAME row as parent** — shares the horizontal row with its parent step (e.g. ViewStep sits beside its DataStep).
- **half-space row** — positioned vertically between its two input rows, showing the merge point (JoinStep only).
- **first row in group** — placed at the first row within its GroupStep section.
- **last row in group** — placed at the last row within its GroupStep section.

**Editable Name** — whether the step name supports inline rename via slow double-click (see Section 7.3).

---

## 6. Visual Design

### 6.1 Shape styling

All shapes are styled like grey buttons with an accent ring border, following the button style guide from the skeleton. There is NO fill-colour coding by step type — the icon and shape geometry differentiate step types.

| Element | Light mode | Dark mode |
|---------|------------|-----------|
| Shape fill | Neutral button background | Dark neutral button background |
| Shape border | `lineStandard` (1.5px), accent ring colour | Same weight, dark-mode accent |
| Focused shape border | `lineEmphasis` (2.0px), primary colour | Same weight, dark primary |
| Hover effect | Subtle background highlight (button hover pattern) | Same pattern, dark mode |

### 6.2 State colours (icon colour)

Step state is communicated through the icon colour inside the shape. There is no separate badge or overlay.

| State | Icon Colour Token | Visual Effect |
|-------|-------------------|---------------|
| Waiting/Init | `neutral600` (light) / `neutral400` (dark) | Static icon, grey |
| Done | `success` | Static icon, green |
| Running | `info` | Spinner animation replaces the static icon, blue |
| Error | `error` | Static icon, red |

The spinner animation for Running state replaces the FA6 icon entirely with a rotating spinner in the `info` colour. When the state changes away from Running, the static icon returns.

### 6.3 Connectors

Connectors are elbow (right-angle) lines connecting shapes, drawn like an org-chart wiring diagram.

| Property | Value |
|----------|-------|
| Line style | Elbow (right-angle segments only, no curves) |
| Default weight | `vizData` (2.0px) |
| Default colour | Neutral connector colour (theme-aware) |
| Focused path weight | `vizHighlight` (3.0px) |
| Focused path colour | Primary highlight colour (theme-aware) |

**Branching layout:** Children stack vertically below their parent. When a step has multiple children, they fan out to the right in a file-explorer tree style — the parent connects down, then right to each child.

**Focus path highlighting:** When a step is focused, the entire path from the workflow root to the focused step is highlighted using `vizHighlight` weight and primary colour. This traces the data lineage.

### 6.4 Overall layout

- **Everything always visible** — there is no expand/collapse mechanism. All steps render at all times.
- **Compact but readable** — spacing is tight enough for large workflows (65+ steps) to fit without excessive scrolling, but readable enough that names and icons are clear.
- **Scroll** — the flowchart body scrolls in both X and Y axes when the content exceeds the viewport.
- **GroupSteps as section headers** — GroupStep nodes appear as icon badges with their name label, acting as visual section headers. Their children are laid out below them. There is no bounding box or border around a group's children.

### 6.5 ViewStep placement

ViewSteps sit on the SAME row as their parent DataStep, positioned to the right. If a DataStep has multiple ViewSteps, they stack horizontally along the same row. ViewSteps are small circle badges with the `eye` icon; their name only appears on hover.

### 6.6 JoinStep placement

A JoinStep merges two input branches. It is positioned at a half-space row — vertically between the rows of its two input steps. Connector lines enter from the left (west flat side of the hexagon), and the output exits downward from the south point.

---

## 7. Interactions

### 7.1 Click interactions

| Gesture | On any node |
|---------|-------------|
| **Single-click** | Set focus on this node. Updates toolbar state. Emits `focusChanged`. Highlights the path from root to this node. |
| **Single-click on background** | Clear focus (select workflow root). Toolbar returns to workflow-level state. |
| **Double-click** | Open step viewer (emits `openStepViewer` on EventBus). |
| **Slow double-click on name** | Begin inline rename (if Editable Name = yes for this step type and the node is already focused). See Section 7.3. |

### 7.2 Focus behaviour

- Exactly one node is focused at all times. On initial load, the workflow root is focused.
- Focusing a node updates the toolbar action button label and tooltip (see Section 8.1).
- Focusing a node highlights the connector path from root to the focused node using `vizHighlight` styling.
- Focus emits `focusChanged` on the EventBus, which the Chat window reads to update LLM context.

### 7.3 Inline rename

For step types where Editable Name = yes:

1. User single-clicks a node to focus it.
2. User single-clicks again on the name text of the already-focused node (slow double-click pattern — two distinct clicks, not a rapid double-click).
3. The name text becomes an editable text field with the current name pre-selected.
4. User types the new name and presses Enter to confirm, or Escape to cancel.
5. On confirm, emits `stepRenamed` on the EventBus with the step ID and new name.
6. On cancel, the name reverts to its previous value.

The editable field uses `AppTextStyles.body` and matches the width of the name area. Only one name can be edited at a time.

### 7.4 Search interaction

The toolbar search field (Section 8.2) drives search highlighting:

1. As the user types, all steps whose name contains the search text (case-insensitive) are marked as matches.
2. Matching nodes receive a visual highlight (distinct from focus highlight — e.g. a coloured outline or background tint).
3. Non-matching nodes remain fully visible — search does NOT filter or hide anything.
4. The flowchart scrolls to bring the first matching node into view.
5. Clearing the search field removes all search highlights.

### 7.5 Keyboard navigation

| Key | Action |
|-----|--------|
| **Arrow keys** | Move focus between nodes (up/down follows row order, left/right follows sibling order) |
| **Enter** | Open step viewer (same as double-click) |
| **Escape** | Cancel inline rename if active; clear search if search field is focused |

---

## 8. Toolbar

Fixed height (48px). Follows the skeleton-window toolbar pattern. Two controls only.

### 8.1 Stateful action button

A single button whose label and tooltip change based on two factors: what is focused (workflow root vs. individual step) and the state of the focused item.

| Focused On | Step State | Button Label | Tooltip |
|---|---|---|---|
| Workflow root | Init (any step waiting) | **Run All** | "Run all steps in {workflow name}" |
| Workflow root | Running (any step running) | **Stop All** | "Stop all running steps" |
| Workflow root | Done or Error (no step running or waiting) | **Reset All** | "Reset all steps in {workflow name}" |
| Individual step | Init | **Run Step** | "Run {step name}" |
| Individual step | Running | **Stop Step** | "Stop {step name}" |
| Individual step | Done or Error | **Reset Step** | "Reset {step name}" |

**Workflow-level state derivation:** When the workflow root is focused, the button state is derived from the aggregate of all step states:

- If ANY step is in `RunningState`, the workflow is "Running".
- Else if ANY step is in `InitState`, the workflow is "Init".
- Else the workflow is "Done or Error" (all steps are either Done or Failed).

**Button appearance:** Uses primary accent styling per toolbar conventions. The button is always enabled in the Active body state.

**Button action:** Clicking the button emits the corresponding EventBus event (see Section 11). The viewer does not execute steps itself — it emits an intent and the orchestrator acts on it.

### 8.2 Search field

Uses the skeleton's `ToolbarSearchField` component:

- Collapses to 36px (icon only) when the toolbar is narrow; expands up to configurable max width.
- FontAwesome `magnifyingGlass` prefix icon, `xmark` clear button.
- Placeholder text: "Search steps..."
- Positioned in the trailing slot of the toolbar (pushed right by a Spacer).
- `onChanged` triggers the search highlighting described in Section 7.4.
- Tooltip: "Search"

### 8.3 Toolbar layout

```text
[Action Button]  ................  [Search Field]
 (left)              (Spacer)        (trailing)
```

---

## 9. Operations Matrix

### 9.1 Local actions (the viewer handles these internally)

| Action | Workflow root | Any step |
|--------|-------------|----------|
| **Focus** | Single-click background | Single-click node |
| **Search highlight** | Applies to all nodes | Applies to all nodes |
| **Inline rename** | Yes (workflow name) | Yes (where Editable Name = yes) |
| **Scroll to match** | On search | On search |

### 9.2 Emitted intents (EventBus — Frame orchestrates the response)

The viewer does not run steps, open windows, or modify workflow structure directly. It emits intents and the Frame acts on them.

| Intent | Workflow root | Individual step |
|--------|-------------|-----------------|
| `focusChanged` | Click background | Single-click |
| `openStepViewer` | -- | Double-click |
| `runWorkflow` | Action button (Init state) | -- |
| `stopWorkflow` | Action button (Running state) | -- |
| `resetWorkflow` | Action button (Done/Error state) | -- |
| `runStep` | -- | Action button (Init state) |
| `stopStep` | -- | Action button (Running state) |
| `resetStep` | -- | Action button (Done/Error state) |
| `stepRenamed` | Inline rename | Inline rename |

---

## 10. Focus (Chat Integration)

Single-click on any node (step or workflow root):

1. Updates the widget's focused-node state
2. Emits `focusChanged(stepId, stepType, stepName, workflowId)` on EventBus
3. The Chat window (Window 2) reads this event and updates its **Focus field**
4. The LLM receives the focus context automatically with every subsequent message

When the workflow root is focused, the focus payload communicates the workflow itself (not a specific step). This tells the LLM "I am looking at the whole workflow."

---

## 11. EventBus Communication

### 11.1 Events the viewer emits

| Event | Payload | Triggered by |
|-------|---------|-------------|
| `focusChanged` | `stepId`, `stepType`, `stepName`, `workflowId` | Single-click on node or background |
| `openStepViewer` | `stepId`, `stepType`, `workflowId` | Double-click on a step |
| `runWorkflow` | `workflowId` | Action button when workflow focused + Init |
| `stopWorkflow` | `workflowId` | Action button when workflow focused + Running |
| `resetWorkflow` | `workflowId` | Action button when workflow focused + Done/Error |
| `runStep` | `stepId`, `workflowId` | Action button when step focused + Init |
| `stopStep` | `stepId`, `workflowId` | Action button when step focused + Running |
| `resetStep` | `stepId`, `workflowId` | Action button when step focused + Done/Error |
| `stepRenamed` | `stepId`, `newName`, `workflowId` | Inline rename confirmed |

### 11.2 Events the viewer listens to

| Event | Payload | Action |
|-------|---------|--------|
| `openWorkflow` | `workflowId` | Load the specified workflow and display it |
| `stepStateChanged` | `stepId`, `newState` | Update the icon colour/animation for the affected step |
| `workflowUpdated` | `workflowId` | Re-fetch and re-render the entire workflow |
| `navigateToStep` | `stepId` | Scroll to and focus the specified step |

### 11.3 Window interaction map

| Window | Direction | Event |
|--------|-----------|-------|
| File Navigator (1) | Navigator --> Frame --> Viewer | `openWorkflow` — when user double-clicks a workflow in the navigator |
| Chat (2) | Viewer --> Chat | `focusChanged` — set Chat Focus field with step context |
| Chat (2) | Chat --> Viewer | `navigateToStep` — LLM directs attention to a specific step |
| Chat (2) | Chat --> Viewer | `workflowUpdated` — after LLM modifies workflow structure |
| Frame | Viewer --> Frame | `openStepViewer` — Frame routes to appropriate viewer window |
| Frame | Viewer --> Frame | `runWorkflow`, `stopWorkflow`, `resetWorkflow` — Frame executes |
| Frame | Viewer --> Frame | `runStep`, `stopStep`, `resetStep` — Frame executes |
| Frame | Frame --> Viewer | `stepStateChanged` — Frame notifies state transitions |

### 11.4 EventBus scope note

EventBus message definitions and payloads are **out of scope** for the Phase 2 mock build. The controls and visual states described above will be implemented with mock data and local state changes. Actual EventBus wiring will be provided by the EventBus developer in Phase 3.

---

## 12. Domain Models

### 12.1 WorkflowModel

Represents the loaded workflow. Properties:

- `id` — unique workflow identifier
- `name` — display name (editable)
- `projectId` — owning project
- `steps` — list of StepModel objects
- `links` — list of LinkModel objects

### 12.2 StepModel

Represents a single step in the workflow. Properties:

- `id` — unique step identifier
- `name` — display name
- `groupId` — parent GroupStep ID (empty string for top-level)
- `kind` — step type string (e.g. "DataStep", "TableStep", "GroupStep", etc.)
- `state` — current execution state (init, done, running, failed)
- `inputs` — list of input port descriptors
- `outputs` — list of output port descriptors
- `description` — optional description text
- `rectangle` — layout rectangle from Tercen (x, y, width, height)

### 12.3 LinkModel

Represents a data-flow connection between steps. Properties:

- `inputStepId` — receiving step ID
- `outputStepId` — producing step ID

### 12.4 Step kind enumeration

| Kind value | Display type | Maps to Tercen class |
|------------|-------------|---------------------|
| `Workflow` | Root node | Workflow object itself |
| `GroupStep` | Section header | GroupStep |
| `TableStep` | Data source box | TableStep |
| `JoinStep` | Merge icon | JoinStep |
| `DataStep` | Processing box | DataStep |
| `ViewStep` | View icon | ViewStep |
| `InStep` | Group input icon | InStep |
| `OutStep` | Group output icon | OutStep |
| `MeltStep` | Transform box | MeltStep |
| `ExportStep` | Export box | ExportStep |
| `WizardStep` | Wizard icon | WizardStep |

---

## 13. Layout Algorithm

### 13.1 Overview

The layout produces a vertical flowchart (top-to-bottom data flow) where all nodes are always visible. The algorithm assigns each node a row (vertical position) and column (horizontal position) based on the step type rules and link topology.

### 13.2 Row assignment rules

1. **Workflow root** is placed at row 0.
2. Steps with `groupId = ""` (top-level) are processed in topological order based on links.
3. **New row** steps (TableStep, DataStep, GroupStep, MeltStep, ExportStep, WizardStep) each start a new row, incrementing from their predecessor.
4. **SAME row** steps (ViewStep) share the row of their parent step (the step that links to them).
5. **Half-space row** steps (JoinStep) are placed at the vertical midpoint between their two input rows.
6. **First/last row in group** steps (InStep, OutStep) are placed at the first and last row within their GroupStep's section respectively.

### 13.3 Column assignment rules

1. The primary data flow occupies column 0 (leftmost).
2. When a step has multiple children that each start new rows, children stack vertically in column 0 — the layout is depth-first, not breadth-first.
3. ViewSteps are placed in columns 1, 2, 3... to the right of their parent DataStep on the same row.
4. When branches diverge (e.g. before a JoinStep), each branch occupies its own column track.

### 13.4 GroupStep layout

A GroupStep's children are laid out as a contiguous vertical section:

1. The GroupStep icon/label appears at the top of the section.
2. InStep (if present) appears on the first row of the section.
3. Child steps are laid out using the standard row/column rules.
4. OutStep (if present) appears on the last row of the section.
5. There is no bounding box or visual border around the group — the GroupStep node and its children's spatial proximity provide the grouping.

### 13.5 Spacing

| Dimension | Token / Value | Purpose |
|-----------|---------------|---------|
| Row height | Sufficient for tallest shape + label + padding | Vertical distance between row centres |
| Column width | Sufficient for widest box + label + padding | Horizontal distance between column centres |
| ViewStep offset | Compact horizontal gap from parent | Same-row spacing for view icons |
| Minimum margin | Padding around the full flowchart | Ensures nodes are not clipped at edges |

Exact pixel values are implementation details for Phase 2. The spec requires compact-but-readable spacing suitable for workflows of 65+ steps.

---

## 14. Service Interfaces

The viewer depends on two services, which will have mock (Phase 2) and real (Phase 3) implementations.

### 14.1 Workflow data service

Responsible for fetching workflow data from Tercen:

- **Fetch workflow** — given a workflow ID and project ID, returns the full WorkflowModel with all steps and links
- **Rename step** — given a step ID and new name, persists the rename

### 14.2 Event bus service

Responsible for communication with the Frame and other windows:

**Emits:**

- Focus changed (step id, step type, step name, workflow id)
- Open step viewer (step id, step type, workflow id)
- Run workflow (workflow id)
- Stop workflow (workflow id)
- Reset workflow (workflow id)
- Run step (step id, workflow id)
- Stop step (step id, workflow id)
- Reset step (step id, workflow id)
- Step renamed (step id, new name, workflow id)

**Listens to:**

- Open workflow (workflow id)
- Step state changed (step id, new state)
- Workflow updated (workflow id)
- Navigate to step (step id)

---

## 15. Reference Workflow Data

The reference workflow for mock data and testing is from stage.tercen.com:

| Property | Value |
|----------|-------|
| Workflow ID | `abefdbb9bafdfd191f735d19689d53d1` |
| Project ID | `bdd5a7d79e8808876678026cd3001c46` |
| Workflow name | "Run - 2026-03-05 15.56" |
| Total steps | 65 |
| Total links | 59 |
| All step states | DoneState |

### 15.1 Step kinds present

| Kind | Count | Examples |
|------|-------|---------|
| TableStep | 2 | FCS Files.zip, Sample Annotation.txt |
| DataStep | ~30 | Channel Selection, PhenoGraph, UMAP, Heatmaps, etc. |
| GroupStep | 5 | Data preprocessing, Clustering and Dimension Reduction, Cluster Interpretation, Differential Analysis, Export |
| ViewStep | ~15 | (attached to various DataSteps) |
| InStep | 6 | (within GroupSteps) |
| OutStep | 4 | (within GroupSteps) |
| JoinStep | 1 | Join 1 (merges Read FCS + Input Annotation) |

### 15.2 Top-level structure (groupId = "")

These steps have no parent group and appear at the top level of the flowchart:

1. FCS Files.zip (TableStep)
2. Sample Annotation.txt (TableStep)
3. Data preprocessing (GroupStep)
4. Clustering and Dimension Reduction (GroupStep)
5. Cluster Interpretation (GroupStep)
6. Differential Analysis (GroupStep)
7. Export (GroupStep)

The two TableSteps feed into the Data preprocessing group. The groups form a linear pipeline from Data preprocessing through to Export, with branches within each group.

---

## 16. What the Viewer Does NOT Do

| Action | Where it is handled |
|--------|-------------------|
| Add, remove, or wire steps | LLM via Chat (Window 2) |
| Configure step operators or parameters | Step viewer windows (opened via `openStepViewer`) |
| Display computation logs | Audit Trail (Window 7) |
| Preview step output data | Data Viewer (Window 5) / Visualisation Viewer (Window 6) |
| Manage workflow metadata (description, tags) | LLM via Chat (Window 2) |
| Create or delete workflows | LLM via Chat (Window 2), triggered from File Navigator (Window 1) |
| Drag-and-drop step reordering | Not supported — layout is automatic |
| Zoom in/out | Not supported in rev 1 — scroll only |
| Pan via drag | Not supported in rev 1 — scroll bars only |
| Step grouping or ungrouping | LLM via Chat (Window 2) |

---

## 17. Wireframe

```text
+--------------------------------------------------------------+
| [Run All v]  ............................  [Search steps...]  |  <- Toolbar
+--------------------------------------------------------------+
|                                                              |
|  (O) Run - 2026-03-05 15.56                                 |  <- Workflow root
|   |                                                          |     (sitemap icon, green=done)
|   +---+                                                      |
|   |   |                                                      |
|  [table] FCS Files.zip      [table] Sample Annotation.txt   |  <- TableSteps (row 1)
|   |                           |                              |
|   +----------+----------------+                              |
|              |                                               |
|  (O) Data preprocessing                                     |  <- GroupStep
|   |                                                          |
|  (>) InStep                                                  |  <- InStep (hover name)
|   |                                                          |
|  [cubes] Channel Selection   (eye)(eye)                      |  <- DataStep + ViewSteps
|   |                                                          |
|  [cubes] Read FCS            (eye)                           |  <- DataStep + ViewStep
|   |                                                          |
|  [cubes] Input Annotation                                    |  <- DataStep
|   |                                                          |
|  (<) OutStep                                                 |  <- OutStep (hover name)
|   |                                                          |
|   +----------+                                               |
|   |          |                                               |
|  [cubes] Read FCS Out    [cubes] Input Ann. Out              |  <- feeding JoinStep
|   |          |                                               |
|   +----<>----+                                               |
|        |                                                     |
|  (O) Clustering and Dimension Reduction                      |  <- GroupStep
|   |                                                          |
|  [cubes] PhenoGraph         (eye)(eye)                       |
|   |                                                          |
|  [cubes] UMAP               (eye)(eye)                       |
|   |                                                          |
|   :  ... more steps ...                                      |
|                                                              |
+--------------------------------------------------------------+

Legend:
  (O)     = circle badge icon (GroupStep, Workflow)
  [type]  = box with icon + name (TableStep, DataStep, ExportStep)
  (eye)   = small circle badge (ViewStep, hover for name)
  (>)(<)  = rounded square icons (InStep, OutStep, hover for name)
  <>      = hexagon 90deg (JoinStep)
  |,+,--- = elbow connectors (vizData 2.0px, vizHighlight 3.0px when focused)
```

---

## 18. LLM Integration

The LLM interacts with the workflow viewer indirectly through the EventBus:

1. **Reads focus** — when the user single-clicks a step, `focusChanged` is broadcast. The LLM receives the step's ID, type, name, and workflow ID as context with every subsequent Chat message. This tells the LLM exactly which part of the pipeline the user is examining.

2. **Navigates to steps** — after creating or modifying a step, the LLM emits `navigateToStep` to scroll the flowchart and focus the relevant step.

3. **Triggers refresh** — after modifying workflow structure (adding steps, wiring links), the LLM emits `workflowUpdated` so the viewer re-fetches and re-renders.

4. **Does not use the viewer directly** — the LLM uses Tercen MCP tools to create steps, configure operators, and wire links. The viewer simply reflects the current workflow state.

5. **Reads step context** — when a step is focused, the LLM can provide context-aware assistance (e.g. "This DataStep runs PhenoGraph clustering. Would you like to adjust the k parameter?").

---

## 19. Decision Log

Decisions made during the design process, for reference:

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Hybrid tree/org-chart layout with everything always visible | Scientists need to see the full pipeline at a glance. Collapsing hides context that the LLM needs. |
| 2 | Only two toolbar controls: action button + search | The viewer is observation-focused. Execution control is a single context-sensitive button. Everything else is done by the LLM via Chat. |
| 3 | State communicated through icon colour only, no badges | Keeps the visual design clean and compact. Icon colour is sufficient to communicate four states. |
| 4 | No fill-colour coding by step type | Shape geometry and icon already differentiate step types. Adding fill colours would create visual noise in large workflows. |
| 5 | GroupSteps have no bounding box | GroupSteps are legacy sub-workflows. A bounding box would add visual clutter. Spatial proximity and the section-header icon are sufficient. |
| 6 | ViewSteps on the SAME row as their parent | ViewSteps are visual outputs of DataSteps. Placing them beside their parent shows the relationship without consuming vertical space. |
| 7 | JoinStep at half-space row | Visually shows the merge point between two data branches. The hexagon shape reinforces the "merge" concept. |
| 8 | Single-click = focus, double-click = open viewer | Consistent with project-navigator interaction pattern. Focus tells the LLM what you are looking at. Open launches a detailed view. |
| 9 | Slow double-click for inline rename | Distinguishes rename from open-viewer (rapid double-click). Requires the node to already be focused before the rename click. Standard desktop pattern. |
| 10 | Elbow connectors, not curved | Right-angle lines are cleaner and easier to follow in dense flowcharts. Consistent with org-chart and file-tree visual language. |
| 11 | No zoom or pan in rev 1 | Scroll is sufficient for the reference workflow (65 steps). Zoom/pan adds significant complexity and can be added in a future revision. |
| 12 | InStep/OutStep shown for compatibility | These are legacy group port markers. They are rare (6 InSteps, 4 OutSteps in reference workflow) but must be displayed for complete workflow representation. |
| 13 | Hexagon 90deg for JoinStep and MeltStep | Both are data transformation steps that merge or reshape inputs. The hexagon shape with horizontal flat sides visually suggests data flowing in from the sides. |
| 14 | Toolbar action button derives workflow state from aggregate | When focused on the workflow root, the button must determine which action makes sense based on whether any steps are running, waiting, or complete. |
| 15 | Search highlights in place, no filtering | Filtering would hide steps and break the spatial layout. In-place highlighting preserves context while directing attention. |
| 16 | The viewer conforms to skeleton-window from tercen-flutter-skills | Ensures consistency with all other Tercen windows: same theming, state management, DI, and mock/real switching patterns. |

---

## 20. Open Questions

| # | Question | Impact |
|---|----------|--------|
| 1 | **CrossTabStep** — Should CrossTabStep (parent of DataStep in the hierarchy) have its own display rules, or inherit DataStep's appearance? | May need an additional row in the display matrix if CrossTabStep instances appear in real workflows. |
| 2 | **Multiple JoinStep inputs** — Can a JoinStep have more than two inputs? If so, how is the half-space row calculated? | Affects layout algorithm for merge points with 3+ branches. |
| 3 | **Workflow-level state edge cases** — What if a workflow has a mix of DoneState and FailedState steps with none Running or Init? Is the action button "Reset All"? | Current spec says yes (Done or Error = Reset). Confirm this is correct. |
| 4 | **Large workflow performance** — For workflows significantly larger than 65 steps, should virtualised rendering be used? | Affects Phase 2 implementation choice (Canvas vs. Widget tree). |
| 5 | **Step description tooltip** — Should hovering over a step show its `description` field (if non-empty) in addition to the name? | Adds a tooltip layer beyond the hover-name behaviour for Icon display style steps. |
| 6 | **Link direction indicators** — Should connector lines have arrowheads showing data flow direction? | Arrows add clarity but also visual noise. Current spec relies on top-to-bottom layout convention. |
| 7 | **Zoom/pan in future revision** — When zoom is added, should it include fit-to-view and minimap features? | Deferred to a future revision but worth noting for architecture planning. |
