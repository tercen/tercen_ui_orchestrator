# Data Table — Functional Specification

**Version:** 1.0
**Last Updated:** 2026-03-16
**Window:** 5 (Data Viewer/Annotator)
**App Type:** skeleton-window (Feature Window for Tercen Frame)
**Reference:** Original specification
**Status:** Ready for review

---

## 1. Purpose

The Data Table is the primary tabular data inspection and annotation surface in the Tercen platform. It renders any Tercen table — user-uploaded datasets, computed outputs, and crosstab query results — as a scrollable, searchable grid.

The widget exists for **five user actions**:

1. **View** — inspect tabular data in a virtualised scrollable grid
2. **Search** — find values across all visible columns with match highlighting
3. **Inspect** — check table metadata (row count, column count, table ID, column names and types)
4. **Download** — export the current table as a `.csv` file
5. **Annotate** — enter annotation mode, edit individual cells, and save the changes as a new annotation table (the original data is never modified)

Each widget instance displays **one table**. Opening a different table opens a new widget instance. The widget listens for update events on the EventBus so that changes made by the LLM (via Chat) are reflected live.

---

## 2. Context — Where This Fits

### 2.1 Product context

The Tercen LLM platform has eight feature windows:

| # | Window | Role |
|---|--------|------|
| 0 | Home Page | Entry point and project navigation |
| 1 | File Navigator | Browse hierarchy, upload, set focus, open viewers |
| 2 | Chat | Primary LLM interaction surface |
| 3 | Workflow Viewer | Pipeline visualisation, step focus, execution control |
| 4 | Document Viewer/Editor | Markdown, SVG, reports |
| **5** | **Data Table** | **This spec — tabular data viewing and annotation** |
| 6 | Visualisation Viewer/Annotator | Plots and images with markup |
| 7 | Audit Trail | Logs and history |

### 2.2 Three user types

| User | Relationship with the data table |
|------|---------------------------------|
| **Scientist** | Primary user. Opens datasets to inspect imported data, review computed results, check channel values, and annotate samples with QC flags or manual classifications. |
| **Bioinformatician** | Inspects computed output tables from workflow steps (UMAP coordinates, cluster assignments, statistics). Downloads CSV for external analysis in R/Python. |
| **Auditor** | Reviews data tables to verify data integrity, check annotation history, and confirm that original data has not been modified. |

### 2.3 Tercen table kinds

The widget displays all three Tercen table kinds:

| Kind | What it is | Example |
|------|-----------|---------|
| **TableSchema** | User-uploaded data (CSV, FCS imports) | `crabs-long.csv`, `OMIP-069 - Sample Annotation.txt` |
| **ComputedTableSchema** | Output from workflow operators | `Variables` (channel list), `Observations` (event index), cluster assignments |
| **CubeQueryTableSchema** | Crosstab query results from DataSteps | Crosstab output with `.ci`, `.ri`, `.y` columns |

---

## 3. Architecture — skeleton-window Conformance

This window conforms to the **skeleton-window** pattern.

### 3.1 App type

**Type 1 Feature Window** — rendered inside the Tercen Frame. The Frame provides tabs above this window. The data table communicates with the Frame and other windows exclusively via the **EventBus**.

### 3.2 Four body states

The window MUST implement all four body states per the skeleton-window pattern:

| State | When | Display |
|-------|------|---------|
| **Loading** | Fetching table schema or data from Tercen | Centred spinner + "Loading table..." |
| **Empty** | No table has been opened (no table ID provided) | Centred icon + "No table selected" + "Open a data set from the File Navigator" |
| **Active** | Table data loaded | Toolbar + Table Grid |
| **Error** | Table could not be loaded (network failure, invalid ID, access denied) | Centred error icon + message + "Retry" button |

### 3.3 Layout

Toolbar (fixed height) at top, Table Grid (virtualised scrollable area, fills remaining space) below.

```text
┌──────────────────────────────────────────────┐
│ Toolbar                                      │
├──────────────────────────────────────────────┤
│                                              │
│ Table Grid (virtual-scrolled X and Y)        │
│                                              │
└──────────────────────────────────────────────┘
```

### 3.4 State

The widget tracks the following state:

| State | Purpose |
|-------|---------|
| Table ID | The Tercen schema ID of the currently displayed table |
| Table kind | Which schema kind (TableSchema, ComputedTableSchema, CubeQueryTableSchema) |
| Table name | Display name of the table |
| Schema | Column definitions (name, type) and row count |
| Loaded rows | The currently loaded window of row data (virtualised) |
| Sort column | Which column is currently sorted (if any) and direction |
| Sort direction | Ascending or descending |
| Search text | Active search query |
| Search matches | List of cell coordinates matching the search |
| Current match index | Which match is currently focused (for next/previous navigation) |
| Annotation mode | Whether annotation mode is active |
| Annotation edits | Map of (row, column) → new value for pending annotation changes |
| Go-to-row value | Current value in the row number input field |
| Window state | Current body state (loading, empty, active, error) |
| Error message | Detail text when in the error state |

### 3.5 Theming

- All UI chrome must be theme-aware (light and dark modes)
- Use only the shared design token system from the skeleton — no custom values
- The table grid content area follows standard theme conventions from the skeleton

### 3.6 Window identity

| Property | Value |
|----------|-------|
| Tab label | "Data" |
| Tab icon | Per skeleton-window identity convention |

---

## 4. Data Model

### 4.1 Table schema

The table schema describes the structure of the loaded table:

- `id` — Tercen schema ID (the unique table identifier)
- `name` — display name (e.g. "crabs-long.csv", "Variables", "qt")
- `kind` — one of TableSchema, ComputedTableSchema, CubeQueryTableSchema
- `nRows` — total row count
- `columns` — ordered list of column definitions, each with:
  - `name` — column name (e.g. "channel_name", ".ci", "umap.umap.1")
  - `type` — data type (string, double, int32, uint64, uint16)

### 4.2 Row data

Row data is fetched in pages/windows for virtualised scrolling. Each page contains:

- `offset` — starting row index
- `limit` — number of rows in this page
- `rows` — list of row objects, each mapping column name → cell value

### 4.3 Annotation table

When the user saves annotations, a new table is created containing only the modified cells:

- `sourceTableId` — the ID of the original table being annotated
- `columns` — includes a row index column (`.ri`) plus one column per annotated column
- `rows` — one row per annotated row, containing the row index and the new cell values

The annotation table is saved as a CSV file and stored as a new TableSchema in the same project. The original table is never modified.

### 4.4 Column type display

| Tercen type | Display format |
|-------------|---------------|
| `string` | Raw text, left-aligned |
| `double` | Decimal number (up to 6 significant digits), right-aligned |
| `int32` | Integer, right-aligned |
| `uint64` | Integer, right-aligned |
| `uint16` | Integer, right-aligned |

---

## 5. Toolbar

Fixed height. Follows the skeleton-window toolbar pattern.

### 5.1 Buttons and controls

| Control | Position | Icon (FA6) | Tooltip | Active when | Action |
|---------|----------|------------|---------|-------------|--------|
| **Search** | Trailing | `magnifyingGlass` | "Search" | Always | Toggle search field visibility; when visible, focus the text input |
| **Info** | Left | `circleInfo` | "Table Info" | Always | Open metadata popover (see Section 8) |
| **Download** | Left | `download` | "Download CSV" | Always | Export current table as CSV and trigger browser download |
| **Annotate** | Left | `penToSquare` | "Annotation Mode" | Always | Toggle annotation mode on/off (see Section 10) |
| **Go to row** | Trailing | Number input | "Go to row" | Always | Text field accepting a row number; on Enter or blur, scrolls the table to that row |

### 5.2 Search field

The search field uses the skeleton's `ToolbarSearchField`:

- Collapses to icon-only when not active
- When expanded, accepts free-text input
- Searches across all columns (see Section 7)
- Shows match count indicator (e.g. "3 of 12")
- Next/previous match navigation via up/down arrow buttons or Enter/Shift+Enter

### 5.3 Annotation mode indicator

When annotation mode is active:

- The Annotate button shows a visually distinct "active" state (toggled appearance)
- Two additional controls appear in the toolbar:
  - **Save** (`floppyDisk`, "Save Annotations") — saves pending edits as a new annotation table
  - **Discard** (`xmark`, "Discard Changes") — discards all pending edits and exits annotation mode
- The Save button is enabled only when there are pending edits

### 5.4 Toolbar layout

```text
[Info] [Download] [Annotate]  ...  [Go to row: ___] [Search]
 (left)                          (Spacer)           (trailing)

When annotation mode is active:
[Info] [Download] [Annotate ✓] [Save] [Discard]  ...  [Go to row: ___] [Search]
```

---

## 6. Table Grid

The table grid is the main content area displaying tabular data.

### 6.1 Virtual scrolling

The grid uses virtual scrolling in both directions (vertical and horizontal) to handle tables of any size efficiently:

- Only the visible rows and columns are rendered at any time
- Scrolling loads new rows on demand
- Row height is fixed (single line per row)
- Column widths are calculated from the column name length and a sample of cell values, with a minimum and maximum width

### 6.2 Column headers

The header row is fixed at the top of the grid and does not scroll vertically (but scrolls horizontally with the data):

- Each header cell displays the column name
- Text overflow uses ellipsis for long column names
- Clicking a column header toggles sort: first click → ascending, second → descending, third → remove sort
- The currently sorted column shows a directional arrow indicator
- A tooltip on each header shows the full column name and data type

### 6.3 Data cells

- Cell values are formatted according to their column type (see Section 4.4)
- Text overflow uses ellipsis; full value shown in a tooltip on hover
- Cells matched by the active search query are visually highlighted
- The currently focused search match has a distinct highlight

### 6.4 Row numbers

A fixed first column displays the row index (0-based, matching Tercen's internal row indexing). This column:

- Does not scroll horizontally (always visible)
- Is visually distinct from data columns (muted styling)
- Is not sortable or editable

### 6.5 Go-to-row behaviour

When the user enters a row number in the toolbar input and confirms (Enter or blur):

- If the number is valid (0 ≤ n < nRows), the grid scrolls to place that row in view
- If the number is out of range, the input shows a brief error indication and the grid does not scroll
- The target row receives a brief highlight animation to help the user locate it

### 6.6 Sorting

- Single-column sort only
- Sorting is performed on the full dataset (server-side if the table is large, client-side for small tables)
- The sort state is reflected in the column header (arrow indicator)
- Sorting preserves the original row indices displayed in the row number column

---

## 7. Search

### 7.1 Search behaviour

- Search is triggered as the user types (debounced)
- The search query is matched against all visible columns
- Matching is case-insensitive substring match
- For numeric columns, the search matches against the formatted display value

### 7.2 Match highlighting

- All cells containing a match are highlighted with a distinct background
- The currently focused match has a stronger highlight
- The grid auto-scrolls to bring the focused match into view

### 7.3 Match navigation

- The search field shows a match count: "N of M"
- Enter or a "next" button advances to the next match
- Shift+Enter or a "previous" button goes to the previous match
- Navigation wraps around (after the last match, next goes to the first)

### 7.4 Search scope

Search applies to the full dataset, not just the currently visible rows. The service must support server-side search for large tables, with the results returned as a list of (row, column) coordinates.

---

## 8. Meta Info

### 8.1 Info popover

Clicking the Info toolbar button opens a popover displaying table metadata:

| Field | Value |
|-------|-------|
| **Table name** | Display name of the table |
| **Table ID** | Tercen schema ID (copyable) |
| **Kind** | TableSchema, ComputedTableSchema, or CubeQueryTableSchema |
| **Rows** | Total row count |
| **Columns** | Total column count |

### 8.2 Column list

Below the summary fields, the popover shows a scrollable list of all columns:

| Column info | Display |
|-------------|---------|
| Column name | Full name (no truncation) |
| Column type | Data type (string, double, int32, etc.) |

### 8.3 Copy table ID

The table ID field has a copy-to-clipboard button. Clicking it copies the schema ID and shows a brief "Copied" confirmation.

---

## 9. CSV Download

### 9.1 Download behaviour

Clicking the Download toolbar button exports the **full table** (all rows, all columns) as a `.csv` file:

- The file name is derived from the table name (e.g. `crabs-long.csv`, `Variables.csv`)
- If the table name already ends in `.csv`, no suffix is added
- The CSV uses comma separators and standard quoting rules
- The first row is the column header row
- Download is triggered as a browser file download

### 9.2 Large table handling

For large tables (many thousands of rows), the download may take time. While the download is in progress:

- The Download button shows a loading indicator
- The button is disabled to prevent duplicate downloads
- The rest of the widget remains interactive

---

## 10. Annotation Mode

Annotation mode allows the user to modify cell values without altering the original data. All changes are collected and saved as a **new annotation table**.

### 10.1 Entering annotation mode

- Click the Annotate toolbar button to enter annotation mode
- The table grid appearance changes to indicate editability (the skeleton provides the styling)
- The Save and Discard buttons appear in the toolbar

### 10.2 Cell editing

In annotation mode:

- Clicking a data cell makes it editable (inline text input)
- The cell shows the current value (original or previously edited) in an editable field
- Pressing Enter or clicking away confirms the edit
- Pressing Escape cancels the edit and reverts to the previous value
- Edited cells are visually marked to distinguish them from unmodified cells
- The row number column and column headers are never editable

### 10.3 Edit tracking

- All edits are tracked as pending changes in a map of (row index, column name) → new value
- The number of pending edits is shown near the Save button (e.g. "Save (3)")
- Edits can be overwritten by clicking the same cell again
- There is no undo/redo in rev 1 — the user can re-edit a cell or discard all changes

### 10.4 Saving annotations

Clicking Save:

1. Collects all pending edits
2. Constructs an annotation table with:
   - A `.ri` column containing the row indices of edited rows
   - One column per edited column, containing the new values
   - Only rows that were actually edited are included
3. Saves the annotation table as a new CSV file in the same project
4. The file is named `{original_table_name}_annotations.csv`
5. On success: clears pending edits, shows a brief success confirmation, exits annotation mode
6. On failure: shows an error message, keeps pending edits intact, remains in annotation mode

### 10.5 Discarding annotations

Clicking Discard:

- If there are pending edits, shows a confirmation prompt ("Discard N unsaved changes?")
- On confirm: clears all pending edits and exits annotation mode
- On cancel: remains in annotation mode with edits intact

### 10.6 Exiting annotation mode

The user exits annotation mode by:

- Clicking Save (saves and exits)
- Clicking Discard (after confirmation, exits)
- Clicking the Annotate button again (treated as Discard — prompts if there are pending edits)

---

## 11. Orchestrator & EventBus Communication

The Data Table widget runs inside the **Tercen UI Orchestrator**. The orchestrator uses an SDUI (Server-Driven UI) architecture with:

- A channel-based **EventBus** for pub/sub messaging
- **Layout operations** for window creation/management (AddWindow, RemoveWindow, FocusWindow, etc.)
- **Window intents** for window-to-frame communication
- **Window commands** for frame-to-window communication
- **Selection channels** for cross-window context sharing

### 11.1 Orchestrator EventBus — channel naming conventions

| Prefix | Purpose | Examples |
|--------|---------|---------|
| `system.layout.op` | Layout operations (add/remove/resize windows) | AI or widget triggers window changes |
| `system.selection.*` | User selections (project, workflow, file, **table**) | `system.selection.project`, `system.selection.table` |
| `system.data.*` | Data update notifications | `system.data.tableUpdated`, `system.data.annotationSaved` |
| `window.intent` | Window-to-frame intents | `close`, `maximize`, `contentChanged`, `openResource` |
| `window.{windowId}.command` | Frame-to-window commands | `focus`, `blur` |

### 11.2 Existing orchestrator events (reused by this widget)

These channels already exist in the orchestrator and the Data Table subscribes or publishes to them:

| Channel | Direction | Payload | Data Table behaviour |
|---------|-----------|---------|---------------------|
| `system.selection.project` | Other → Data Table | `{projectId, projectName}` | Stores project context (needed for annotation save) |
| `system.selection.workflow` | Other → Data Table | `{workflowId, workflowName}` | Stores workflow context (informational) |
| `system.selection.file` | Other → Data Table | `{fileId, fileName}` | No action (files are not tables) |
| `window.{windowId}.command` | Orchestrator → Data Table | `{type: "focus"}` or `{type: "blur"}` | Updates internal focus state |
| `window.intent` | Data Table → Orchestrator | `{type: "close", windowId}` | When user closes the window |
| `window.intent` | Data Table → Orchestrator | `{type: "contentChanged", windowId, label}` | When table loads, updates tab title to table name |
| `window.intent` | Other → Orchestrator | `{type: "openResource", resourceType, resourceId}` | Orchestrator routes `openResource` with `resourceType: "table"` to open a Data Table window |

### 11.3 New events required for the Data Table

These channels **do not yet exist** in the orchestrator and must be added:

| Channel | Direction | Payload | Purpose | Status |
|---------|-----------|---------|---------|--------|
| **`system.selection.table`** | Data Table → All | `{tableId, tableName, tableKind}` | Broadcast which table the user is viewing (analogous to `system.selection.project`). Chat/LLM receives this as context. | **NEW** |
| **`system.data.tableUpdated`** | Any → Data Table | `{tableId}` | Notify that a table's data has changed (e.g. LLM re-ran an operator, imported new data). The Data Table reloads if it matches the currently displayed table. | **NEW** |
| **`system.data.annotationSaved`** | Data Table → All | `{sourceTableId, annotationTableId, annotationName}` | Broadcast that an annotation table was created. Allows Chat/LLM to reference the new annotation, and File Navigator to refresh. | **NEW** |

### 11.4 How the Data Table is opened

The Data Table is opened via the orchestrator's existing `openResource` intent mechanism on the `window.intent` channel:

1. A source window (File Navigator, Workflow Viewer, or LLM/Chat) publishes on `window.intent`:
   ```json
   {
     "type": "openResource",
     "resourceType": "table",
     "resourceId": "<tableId>",
     "resourceName": "<tableName>",
     "resourceKind": "<TableSchema|ComputedTableSchema|CubeQueryTableSchema>"
   }
   ```
2. The orchestrator receives this and dispatches an `AddWindow` layout operation to create a new Data Table widget instance with the table ID, name, and kind passed as widget props.
3. The Data Table reads these props on initialisation and loads the table.

**Note:** The `openResource` intent already exists in the orchestrator with a pending resource-to-window mapping. The Data Table is the first concrete implementation of this mapping for `resourceType: "table"`.

### 11.5 How the LLM triggers a table refresh

When the LLM modifies data (re-runs an operator, imports data, etc.) it publishes on the new `system.data.tableUpdated` channel:

```json
{
  "type": "tableUpdated",
  "sourceWidgetId": null,
  "data": { "tableId": "<affected_table_id>" }
}
```

The Data Table subscribes to `system.data.tableUpdated`. If the payload's `tableId` matches the currently displayed table, it reloads the schema and row data.

### 11.6 Window interaction map (orchestrator channels)

| Source | Target | Channel | Event | Trigger |
|--------|--------|---------|-------|---------|
| File Navigator | Orchestrator | `window.intent` | `openResource(table, id)` | User double-clicks a dataset |
| Workflow Viewer | Orchestrator | `window.intent` | `openResource(table, id)` | User opens a step's output table |
| Orchestrator | Data Table | `AddWindow` layout op | Window created with table props | Routed from `openResource` |
| Data Table | All | `system.selection.table` | `{tableId, tableName, tableKind}` | On table load |
| Data Table | Orchestrator | `window.intent` | `contentChanged(label)` | On table load (updates tab title) |
| Chat / LLM | Data Table | `system.data.tableUpdated` | `{tableId}` | LLM modified table data |
| Data Table | All | `system.data.annotationSaved` | `{sourceTableId, annotationTableId}` | User saves annotations |
| Orchestrator | Data Table | `window.{id}.command` | `focus` / `blur` | User clicks window |

### 11.7 Phase 2 mock — EventBus simulation

In the Phase 2 mock build, the widget runs standalone (not inside the orchestrator). The mock must simulate the relevant EventBus interactions:

**Mock EventBus channels to implement:**

| Channel | Mock behaviour |
|---------|---------------|
| `system.selection.table` | Published on load with mock table metadata. Logged to console. |
| `system.data.tableUpdated` | A mock toolbar button ("Simulate Refresh") publishes this event to test the reload flow. |
| `system.data.annotationSaved` | Published after mock annotation save. Logged to console with the annotation file path. |
| `window.intent` (`contentChanged`) | Published on table load with the table name as label. Logged to console. |

The mock EventBus uses the skeleton-window's `EventBus` class (stream-based pub/sub with channel routing), matching the orchestrator's channel naming conventions so that Phase 3 integration requires only wiring — no channel renaming.

---

## 12. Service Interfaces

The data table depends on two services, which will have mock (Phase 2) and real (Phase 3) implementations.

### 12.1 Table data service

Responsible for fetching table data from Tercen:

- **Get schema** — given a table ID, returns the schema (column definitions, row count, name, kind)
- **Get rows** — given a table ID, offset, and limit, returns a page of row data
- **Search** — given a table ID and search string, returns a list of (row, column) match coordinates
- **Sort** — given a table ID, column name, and direction, returns sorted row indices (or the service handles sort order in subsequent `getRows` calls)

### 12.2 Annotation service

Responsible for saving annotation data:

- **Save annotations** — given a source table ID, project ID, and a map of edits, creates a new annotation CSV file and returns the new table ID

### 12.3 Event bus service

Responsible for communication with the Frame and other windows:

**Emits:**

- Focus changed (table ID, source window name, table name)
- Annotation saved (source table ID, new annotation table ID)

**Listens to:**

- Open table (table ID, table name, table kind)
- Table updated (table ID)
- Focus changed (from other windows)

---

## 13. Mock Data

Phase 2 requires realistic table data that exercises the full rendering and interaction surface. All mock data is sourced from real Tercen tables on stage.tercen.com.

### 13.1 Mock table 1: "crabs-long.csv" (User-uploaded dataset)

A biological measurement dataset with mixed column types.

- **Source:** `stage.tercen.com`, schema ID `1031e001d79f01cb971e6167d3a142e1`
- **Kind:** TableSchema
- **Rows:** 1,000
- **Columns:** 6

| Column | Type | Sample values |
|--------|------|---------------|
| sp | string | "B", "O" |
| sex | string | "M", "F" |
| index | double | 1.0, 2.0, 3.0 ... |
| observation | double | 1.0, 2.0, 3.0 ... |
| variable | string | "FL", "RW", "CL", "CW", "BD" |
| measurement | double | 8.1, 8.8, 9.2 ... |

This table exercises: string and numeric columns, sorting on different types, search across mixed types, CSV download, and annotation of measurement values.

### 13.2 Mock table 2: "Variables" (Computed channel reference)

A flow cytometry channel metadata table.

- **Source:** `stage.tercen.com`, schema ID `abefdbb9bafdfd191f735d19689d92aa`
- **Kind:** ComputedTableSchema
- **Rows:** 47
- **Columns:** 3

| Column | Type | Sample values |
|--------|------|---------------|
| channel_name | string | "CCR5", "CD3", "CD4", "CD8", "FSC-A", "SSC-A" |
| channel_description | string | "CCR5", "CD3", "CD4", "CD8", "FSC-A", "SSC-A" |
| channel_id | double | 1.0 through 47.0 |

This table exercises: small table rendering (no virtual scroll needed), text-heavy content, and annotation of channel descriptions.

### 13.3 Mock table 3: "Dose-Response - Acidiq" (Numeric-heavy dataset)

A dose-response experiment with decimal-heavy numeric data.

- **Source:** `stage.tercen.com`, schema ID `3476e4b4606ca7f0d28e22779c9d2499`
- **Kind:** TableSchema
- **Rows:** 180
- **Columns:** 3

| Column | Type | Sample values |
|--------|------|---------------|
| Dose | double | 0.0, 39.0625, 78.125, 156.25 |
| Group | string | "P999", "P100" |
| Response | double | 0.290467984, 0.283475624 ... |

This table exercises: decimal number formatting, numeric sorting, search for numeric values.

### 13.4 Mock table 4: "UMAP + Clusters" (Computed workflow output)

A combined view of UMAP coordinates and cluster assignments, representing a typical workflow output.

- **Source:** `stage.tercen.com`, UMAP schema `ae097ec6a927b63010333ff3d4023bf5` + Cluster schema `ae097ec6a927b63010333ff3d401f880`
- **Kind:** ComputedTableSchema
- **Rows:** 4,000
- **Columns:** 3

| Column | Type | Sample values |
|--------|------|---------------|
| umap.umap.1 | double | 7.811, -7.049, -3.148 ... |
| umap.umap.2 | double | -0.468, -0.601, 4.003 ... |
| clust.cluster_id | string | "c00", "c04", "c05", "c06", "c09", "c12" |

This table exercises: large table virtual scrolling, high-precision decimals, categorical computed values, go-to-row navigation, and search for specific cluster IDs.

### 13.5 Mock default table

On load, the mock service displays Mock table 1 (crabs-long.csv) as the default. The mock Info popover and toolbar should all be fully functional with this data.

### 13.6 Mock annotation save

When the user saves annotations in the mock:

- The annotation table is written as a CSV file to a local path (not uploaded to Tercen)
- A success message is shown with the file path
- The file contains the `.ri` column plus edited columns, with only edited rows

### 13.7 Mock latency simulation

In production, all data comes from the Tercen server over the network. The mock must simulate realistic server latency so that every loading state, progress indicator, and disabled-button state is exercised and visible during review. Without simulated delays, transient UI states (spinners, disabled buttons, progress indicators) flash too fast to evaluate.

**Every mock service method that represents a server call must include a simulated delay.** The mock builder should use the following latency bands:

| Operation | Simulated delay | What the user should see |
|-----------|----------------|--------------------------|
| **Initial table load** (get schema + first page of rows) | 800–1200 ms | Full Loading body state (centred spinner + "Loading table...") for a visible duration |
| **Page fetch** (virtual scroll requests additional rows) | 200–400 ms | Brief loading indicator on the scroll edge or row placeholders |
| **Sort** (re-fetch sorted data) | 500–800 ms | Column header shows a brief loading state; grid content refreshes |
| **Search** (server-side search across all rows) | 400–600 ms | Search field shows a spinner or "Searching..." indicator before match count appears |
| **CSV download** (export full table) | 1000–2000 ms | Download button shows loading indicator and is disabled for the full duration |
| **Annotation save** | 600–1000 ms | Save button shows loading indicator and is disabled; success confirmation appears after delay |
| **Table refresh** (triggered by `system.data.tableUpdated`) | 800–1200 ms | Loading body state re-appears briefly, then table reloads with data |

**Mock latency requirements:**

- Each delay must use a random duration within its band to avoid a mechanical feel
- During each delay, the corresponding button or control must be **disabled** and show a **loading indicator** (spinner icon replacing the normal icon, or a small inline spinner)
- The widget body state must transition through the correct sequence: Active → Loading → Active (for refresh), or Empty → Loading → Active (for initial load)
- The "Simulate Refresh" mock button (Section 11.7) must trigger the full Loading → Active transition with the table refresh delay band
- The Error body state must also be testable: a 10% random chance on initial load should trigger the Error state with a "Connection timeout" message and Retry button. Clicking Retry re-attempts with the normal load delay.

---

## 14. What the Data Table Does NOT Do

| Action | Where it is handled |
|--------|-------------------|
| Browse files or navigate projects | File Navigator (Window 1) |
| Execute workflow steps or operators | Workflow Viewer (Window 3) |
| Render visualisations or charts | Visualisation Viewer (Window 6) |
| Edit markdown or document content | Document Editor (Window 4) |
| Create, rename, or delete tables | LLM via Chat (Window 2) |
| Join or merge tables | LLM via workflow operators |
| Column reordering or drag-and-drop | Out of scope for rev 1 |
| Column show/hide | Out of scope for rev 1 |
| Column pinning (freeze columns) | Out of scope for rev 1 |
| Multi-row checkbox selection | Out of scope for rev 1 |
| Conditional formatting or heatmaps | Out of scope for rev 1 |
| Undo/redo for annotations | Out of scope for rev 1 |
| Batch annotation (apply value to multiple rows) | Out of scope for rev 1 |
| Column statistics (min/max/mean) | Out of scope for rev 1 |
| Import annotations from external file | Out of scope for rev 1 |
| Filter per column (range sliders, multi-select) | Out of scope for rev 1 |
| Multiple tables in one widget | Out of scope — each table opens a new widget instance |

---

## 15. Wireframe

```text
┌──────────────────────────────────────────────────────────────────┐
│ [ⓘ Info] [⬇ Download] [✏ Annotate]  ···  [Row: ____] [🔍]     │  ← Toolbar
├──────────────────────────────────────────────────────────────────┤
│    │ sp    ▲│ sex    │ index  │ observation │ variable │ measur…│
│────┼────────┼────────┼────────┼─────────────┼──────────┼────────│
│  0 │ B      │ M      │    1.0 │         1.0 │ FL       │    8.1 │
│  1 │ B      │ M      │    2.0 │         2.0 │ FL       │    8.8 │
│  2 │ B      │ M      │    3.0 │         3.0 │ FL       │    9.2 │
│  3 │ B      │ M      │    4.0 │         4.0 │ FL       │    9.6 │
│  4 │ B      │ M      │    5.0 │         5.0 │ FL       │    9.8 │
│  5 │ B      │ M      │    6.0 │         6.0 │ FL       │   10.8 │
│  6 │ B      │ M      │    7.0 │         7.0 │ FL       │   11.1 │
│  7 │ B      │ M      │    8.0 │         8.0 │ FL       │   11.6 │
│  8 │ B      │ M      │    9.0 │         9.0 │ FL       │   11.8 │
│  9 │ B      │ M      │   10.0 │        10.0 │ FL       │   11.8 │
│ 10 │ B      │ M      │   11.0 │        11.0 │ FL       │   12.2 │
│    │        │        │        │             │          │        │
└──────────────────────────────────────────────────────────────────┘

Annotation mode active:
┌──────────────────────────────────────────────────────────────────┐
│ [ⓘ] [⬇] [✏ ✓] [💾 Save (2)] [✕ Discard]  ···  [Row: ____] [🔍]│  ← Toolbar
├──────────────────────────────────────────────────────────────────┤
│    │ sp     │ sex    │ index  │ observation │ variable │ measur…│
│────┼────────┼────────┼────────┼─────────────┼──────────┼────────│
│  0 │ B      │ M      │    1.0 │         1.0 │ FL       │    8.1 │
│  1 │ B      │ M      │    2.0 │         2.0 │ FL       │  [8.5]•│ ← edited
│  2 │ B      │ M      │    3.0 │         3.0 │ FL       │    9.2 │
│  3 │ B      │ M      │    4.0 │         4.0 │ FL       │  [9.9]•│ ← edited
│  4 │ B      │ M      │    5.0 │         5.0 │ FL       │    9.8 │
│    │        │        │        │             │          │        │
└──────────────────────────────────────────────────────────────────┘

Search active:
┌──────────────────────────────────────────────────────────────────┐
│ [ⓘ] [⬇] [✏]  ···  [Row: ____] [🔍 "CD4"  ◀ 2 of 5 ▶]        │  ← Toolbar
├──────────────────────────────────────────────────────────────────┤
│    │ channel_name │ channel_description │ channel_id            │
│────┼──────────────┼─────────────────────┼───────────────────────│
│ 24 │ [CD4]        │ [CD4]               │                 25.0  │ ← focused match
│ 25 │ CD45         │ CD45                │                 26.0  │
│ 26 │ CD45RA       │ CD45RA              │                 27.0  │  ← other match
│    │              │                     │                       │
└──────────────────────────────────────────────────────────────────┘

Info popover:
┌─────────────────────────────┐
│ Table Info                  │
│                             │
│ Name:    crabs-long.csv     │
│ ID:      1031e001d7... [📋] │
│ Kind:    TableSchema        │
│ Rows:    1,000              │
│ Columns: 6                  │
│                             │
│ ─── Columns ───             │
│ sp          string          │
│ sex         string          │
│ index       double          │
│ observation double          │
│ variable    string          │
│ measurement double          │
└─────────────────────────────┘
```

---

## 16. LLM Integration

The LLM interacts with the Data Table as follows:

1. **Receives table context** — when the Data Table loads a table, it publishes on `system.selection.table`. The orchestrator server injects this into `_userContext` so the LLM knows which table the user is looking at.

2. **Can trigger table opens** — the LLM emits an `openResource` intent with `resourceType: "table"` on `window.intent`. The orchestrator creates a new Data Table window instance.

3. **Can trigger refreshes** — when the LLM modifies data (e.g. re-runs an operator, imports new data), the server publishes on `system.data.tableUpdated` so the Data Table reloads.

4. **Does not control the widget directly** — the LLM communicates through the orchestrator's EventBus. It cannot scroll, search, sort, or annotate on behalf of the user.

5. **Annotation awareness** — when the user saves an annotation table, the `system.data.annotationSaved` event is broadcast. The LLM can reference this annotation in subsequent operations.

---

## 17. Decision Log

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | One table per widget instance | Keeps the widget simple. Multiple tables = multiple widget instances, managed by the Frame. |
| 2 | Virtual scrolling, not pagination | Scientists expect continuous scrolling when exploring data. Pagination interrupts the flow. |
| 3 | Annotations saved as new CSV / TableSchema | Non-destructive editing is critical for scientific data integrity. The original data must never be modified. |
| 4 | Annotation table uses `.ri` for row linkage | Matches Tercen's internal row indexing convention. Enables joining annotations back to original data via standard Tercen operators. |
| 5 | Single-column sort only | Multi-column sort adds complexity with minimal benefit for data inspection. Can be added in a future revision. |
| 6 | Go-to-row input instead of row checkbox selection | User requested direct row navigation. Multi-select and batch operations are deferred to rev 2. |
| 7 | Server-side search for large tables | Client-side search is impractical for tables with hundreds of thousands of rows. The service interface supports both. |
| 8 | All three table kinds (TableSchema, ComputedTableSchema, CubeQueryTableSchema) | This is the universal table viewer. Computed tables from workflow steps need a viewer, and this is it. |
| 9 | No style specifications in spec | All styling delegated to the skeleton-window design system. The mock builder uses skeleton conventions exclusively. |
| 10 | Mock data sourced from real Tercen tables | Using real data from stage.tercen.com ensures the mock accurately represents real-world use cases. |
| 11 | EventBus `tableUpdated` for live refresh | Enables the LLM to modify tables and have the widget update without the user manually refreshing. |
| 12 | Annotation file named `{table}_annotations.csv` | Clear naming convention that links annotations to their source table. |

---

## 18. Open Questions

| # | Question | Impact |
|---|----------|--------|
| 1 | **Annotation table persistence** — In Phase 3, should the annotation table be created via `TableSchemaService` or `FileService` (upload CSV)? | Affects the real annotation service implementation. |
| 2 | **Annotation merge** — If the user annotates the same table multiple times, should subsequent annotation tables overwrite or accumulate? | Affects naming convention and project clutter. |
| 3 | **Computed table sort** — Can Tercen's `TableSchemaService.select()` return sorted data, or must sorting always be client-side? | Affects sort performance for large computed tables. |
| 4 | **Table size threshold** — At what row count should the widget switch from loading all rows to paginated fetching? | Affects the virtual scroll buffer strategy. |
| 5 | **Search server support** — Does Tercen provide server-side search on table data, or must search always be client-side? | Affects search performance for large tables. |
| 6 | **Annotation permissions** — Can any user annotate any table, or are annotations restricted by project/team ACLs? | Affects whether the Annotate button should be conditionally disabled. |
| 7 | **Widget instance identity** — When multiple Data Table instances are open, how does the Frame route `tableUpdated` events to the correct instance? | Affects EventBus channel naming (e.g. `tableUpdated:{tableId}`). |
