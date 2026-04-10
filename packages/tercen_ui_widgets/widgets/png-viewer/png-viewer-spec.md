# PNG Viewer — Functional Specification

**Version:** 1.1.0
**Status:** Draft
**Last Updated:** 2026-04-10
**Widget Kind:** Window (Feature Window)
**Window Type:** Visualization
**Type Colour:** #66FF7F (Visualization Green)
**Reference:** skeleton.yaml, operator.json, gap-report.md, sample-data.json

---

## 1. Overview

### 1.1 Purpose

The PNG Viewer displays PNG images and provides an annotation layer for marking up regions of interest. It serves as the primary image inspection and communication tool within the Tercen Frame. Images can originate from two paths: workflow step outputs (opened programmatically or by the LLM) and `.png` files in the project file tree (opened by double-clicking in the Project Navigator). In both cases the viewer allows users to inspect the image, draw annotations to highlight findings, and share annotated regions with the LLM via Chat.

### 1.2 Users

| User | Relationship with the viewer |
|------|------------------------------|
| **Scientist** | Primary user. Views step output images, draws annotations to highlight clusters or patterns, sends annotated observations to Chat for LLM discussion. |
| **Bioinformatician** | Inspects visualization outputs for correctness, annotates anomalies, saves annotated images to the project for documentation. |
| **Auditor** | Reviews saved visualizations and their annotations as part of workflow audit. Primarily reads, does not annotate. |

### 1.3 Scope

**In Scope:**

- Display PNG images from workflow step outputs or file resources
- Pan and zoom navigation of the image canvas
- Six annotation tools: polygon, rectangle, circle, arrow, freehand, text
- Clear all annotations
- Send annotation data to Chat via EventBus
- Save annotations to the project
- All four body states: loading, empty, active, error
- Receive image load requests via EventBus

**Out of Scope:**

- Tab rendering, focus management, and panel layout (provided by the Frame)
- Theme control or theme toggle (theme is received from the Frame)
- Window creation, tab drag/reorder (managed by the Frame)
- Image editing or manipulation (crop, resize, filters, colour adjustment)
- Multi-image gallery or tabbed image browsing
- Annotation persistence across sessions (save-to-project is a one-shot action)
- Right-click context menus
- Undo/redo for annotations
- Image format support beyond PNG

### 1.4 Data Source

| Data | Source | Description |
|------|--------|-------------|
| PNG file from project | `fileService.get(fileId)` | Retrieves a PNG file by its document ID (used when opened from the Project Navigator) |
| Step output images | `tableSchemaService.getStepImages(workflowId, stepId)` | Retrieves PNG image data for a given workflow step output |
| Image via event | EventBus `visualization.{windowId}.loadImage` | Inbound event carrying `{resourceType, resourceId}` — triggers a fetch via the appropriate service based on resourceType |

**SDUI Template Mapping** (for Phase 4):

| Data | Service | Method | Args | Render Primitive |
|------|---------|--------|------|------------------|
| PNG file | fileService | get | fileId | AnnotatedImageViewer |
| Step image | tableSchemaService | getStepImages | workflowId, stepId | AnnotatedImageViewer |

*Available services:* `tableSchemaService`, `fileService`, `projectService`, `workflowService`, `userService`, `projectDocumentService`, `operatorService`.
*Available domain primitives:* `DataGrid`, `DirectedGraph`, `ImageViewer`, `TabbedImageViewer`, `AnnotatedImageViewer`.

### 1.6 Primitive Refactoring — AnnotatedImageViewer (Phase 3)

An `AnnotatedImageViewer` primitive already exists in the SDUI engine. However, it currently bundles its own toolbar (manual Container + Row with Spacer-based 3-zone layout), which violates the WindowShell toolbar convention. This must be refactored before the catalog entry can be authored.

**What stays in the primitive (body-level concerns):**
- Pannable/zoomable canvas (InteractiveViewer)
- Annotation overlay (CustomPaint with all 6 drawing tools)
- Gesture handling (draw, move, hit-test, text input)
- Tab bar for multi-image support
- Annotation data model and coordinate transforms
- Image loading and error display

**What is removed from the primitive (toolbar concerns):**
- The built-in toolbar Container + Row (currently lines 5049–5092 of builtin_widgets.dart)
- The `_toolButton` and `_actionButton` helper methods
- The Spacer-based 3-zone layout

**What is added to the primitive (EventBus-driven control):**
The primitive subscribes to EventBus channels for all commands that were previously triggered by the built-in toolbar buttons:

| New Prop | Type | Description |
|----------|------|-------------|
| `toolChannel` | string | Subscribes to tool selection events. Payload: `{tool: "polygon" | "rectangle" | "circle" | "arrow" | "freehand" | "text" | "none"}` |
| `clearChannel` | string | Subscribes to clear-all events. Clears all annotations on the current image. |
| `zoomInChannel` | string | Subscribes to zoom-in events. Scales canvas by one step. |
| `zoomOutChannel` | string | Subscribes to zoom-out events. Scales canvas by one step. |
| `fitChannel` | string | Subscribes to fit-to-window events. Resets transform to identity. |
| `saveChannel` | string | Subscribes to save-to-project events. Triggers browser download. |

The existing `sendChannel` prop is retained (already publishes annotation bundle outbound).

**Catalog template pattern:** The catalog entry uses `WindowShell` with `toolbarActions` containing 12 standard action buttons (6 toggle drawing tools + 3 action buttons + 3 zoom controls), all left-aligned per convention. Each toolbar button publishes to the corresponding EventBus channel, and the `AnnotatedImageViewer` in the body subscribes to those channels.

**Why this matters:** Toolbar button sizing, spacing, hover states, toggle styling, and enabled/disabled rendering are all governed by `_WindowToolbar` using theme tokens (`theme.window.toolbarButtonSize`, `theme.window.toolbarGap`, etc.). Keeping toolbar logic in the primitive bypasses these conventions and creates a maintenance burden when toolbar styling changes system-wide.

### 1.5 Intent Routing — How This Window Gets Opened

The PNG Viewer can be opened in three ways. The orchestrator matches inbound intents to this widget's `handlesIntent` declarations and opens a new window tab with the mapped props.

**Opening path 1 — Double-click a `.png` file in the Project Navigator:**

The Project Navigator emits a `navigator.openViewer` event with `{nodeId, nodeType: "FileDocument", nodeName: "somefile.png"}`. The orchestrator inspects the file extension — if the name ends in `.png`, it opens a PNG Viewer with the intent `openImage`.

| Field | Value |
|-------|-------|
| Intent | `openImage` |
| Props received | `fileId`, `fileName` |
| Window title | `"{{fileName}}"` (e.g., "View UMAP vs. clusters.png") |
| Window size | `large` |

**Opening path 2 — LLM or programmatic open for step output images:**

The LLM (or another widget) emits a `window.intent` with `openStepImages` and step context. This is the path used when viewing plots generated by a workflow step.

| Field | Value |
|-------|-------|
| Intent | `openStepImages` |
| Props received | `workflowId`, `stepId`, `stepName` |
| Window title | `"Images: {{stepName}}"` |
| Window size | `large` |

**Opening path 3 — Inbound EventBus load into an existing window:**

Another widget (or the LLM) sends a `visualization.{windowId}.loadImage` event to an already-open PNG Viewer. This replaces the current image without opening a new tab. See Section 2.5 Custom Inbound.

**Orchestrator wiring required:**

The orchestrator's event listener for `navigator.openViewer` currently routes by `nodeType` and file extension (`.md`/`.txt` → DocumentEditor, `Workflow` → WorkflowViewer, `TableSchema` → DataTable). A new condition is needed:

- When `nodeType == "FileDocument"` and the name ends in `.png` → open PNG Viewer with intent `openImage`, passing `fileId` and `fileName`.

---

## 2. User Interface

### 2.1 Window Structure

```
+-- Tab (rendered by Frame) ------------------------------------+
| [#] [PNG Viewer]                       [maximize] [close]     |
+-- Toolbar ----------------------------------------------------+
| [polygon] [rect] [circle] [arrow] [freehand] [text]          |
| [clear] [send] [save]  [zoom-in] [zoom-out] [fit]            |
+-- Body -------------------------------------------------------+
|                                                                |
|  [Content area -- state-driven]                                |
|  (loading | empty | active | error)                            |
|                                                                |
+----------------------------------------------------------------+
```

All toolbar actions are left-aligned and flow left to right. There are no trailing controls (no search field, no dropdown).

### 2.2 Identity

| Property | Value |
|----------|-------|
| Type ID | `pngViewer` |
| Type Colour | #66FF7F (Visualization Green) |
| Initial Label | "PNG Viewer" |
| Label Updates | Updates to the image filename when an image is loaded (e.g., "View UMAP vs. clusters.png") |

### 2.3 Toolbar

All controls are icon-only buttons using FontAwesome 6 Solid icons. Drawing tools (positions 1-6) are toggle buttons: clicking an active tool deactivates it; clicking a different tool activates it and deactivates the previous one. At most one drawing tool is active at a time, or none.

| Position | Control | Type | Icon (FA6) | Tooltip | Enabled When | Action |
|----------|---------|------|------------|---------|-------------|--------|
| 1 | Polygon | icon-only toggle | `draw-polygon` | "Polygon" | Active state | Activates polygon drawing mode; click again to deactivate |
| 2 | Rectangle | icon-only toggle | `square` | "Rectangle" | Active state | Activates rectangle drawing mode; click again to deactivate |
| 3 | Circle | icon-only toggle | `circle` | "Circle" | Active state | Activates circle drawing mode; click again to deactivate |
| 4 | Arrow | icon-only toggle | `arrow-right` | "Arrow" | Active state | Activates arrow drawing mode; click again to deactivate |
| 5 | Freehand | icon-only toggle | `pen` | "Freehand" | Active state | Activates freehand drawing mode; click again to deactivate |
| 6 | Text | icon-only toggle | `font` | "Text" | Active state | Activates text annotation mode; click again to deactivate |
| 7 | Clear All | icon-only | `trash-can` | "Clear All" | At least one annotation exists | Removes all annotations from the canvas |
| 8 | Send to Chat | icon-only | `paper-plane` | "Send to Chat" | At least one annotation exists | Packages annotations and sends to Chat via EventBus |
| 9 | Save to Project | icon-only | `floppy-disk` | "Save to Project" | Image is loaded | Persists the current annotations to the project |
| 10 | Zoom In | icon-only | `magnifying-glass-plus` | "Zoom In" | Active state | Increases zoom level by one step |
| 11 | Zoom Out | icon-only | `magnifying-glass-minus` | "Zoom Out" | Active state | Decreases zoom level by one step |
| 12 | Fit to Window | icon-only | `expand` | "Fit to Window" | Active state | Resets zoom and pan to fit the full image within the body area |

### 2.4 Body States

#### Loading

- **Triggered when:** The widget is fetching image data from the service or processing an inbound loadImage event.
- **Display:** Centred spinner with the message "Loading image..."

#### Empty

- **Triggered when:** No image has been loaded and no loadImage event has been received. This is the initial state when the window opens without a target resource.
- **Display:** Centred image icon (`fa-image`) with the message "No image loaded" and the detail text "Open a PNG from the File Navigator or a step output."
- **No action button.** The user loads an image by navigating to one in the File Navigator or by running a workflow step that produces image output.

#### Active

- **Triggered when:** Image data has been successfully loaded and decoded.
- **Content:** A pannable, zoomable canvas displaying the loaded PNG image at its native resolution, scaled to fit the available body area by default.
- **Annotation overlay:** Annotations are rendered as a transparent overlay on top of the image. They move and scale with the image during pan and zoom operations.
- **Interactions:**
  - **Pan:** Click and drag on the canvas (when no drawing tool is active) to pan the image.
  - **Zoom:** Mouse wheel scrolls to zoom in and out. Zoom centres on the cursor position.
  - **Draw:** When a drawing tool is active, click/drag on the canvas creates a new annotation of that tool's type.
    - *Polygon:* Click to place vertices; double-click or click the first vertex to close the shape.
    - *Rectangle:* Click and drag to define opposite corners.
    - *Circle:* Click to set the centre, drag to set the radius.
    - *Arrow:* Click to set the start point, drag to set the end point with an arrowhead.
    - *Freehand:* Click and drag to draw a continuous path.
    - *Text:* Click to place the text anchor, then type a label. Press Enter or click elsewhere to confirm.
  - **Cursor:** The cursor changes to indicate the current mode (crosshair when a drawing tool is active, grab hand for panning).
- **Annotations** are drawn using domain-specific annotation colours (distinct from UI chrome tokens). Each annotation stores its type and an array of coordinate points relative to the image. Circles additionally store a radius. Text annotations additionally store a label string.

#### Error

- **Triggered when:** Image fetch fails (network error, resource not found, decode failure).
- **Display:** Centred error icon with the error message and detail text describing the failure. A "Retry" button below the detail text re-attempts the image fetch.

### 2.5 EventBus Communication

**Standard outbound intents** (all windows emit these via `window.intent`):

| Channel | Intent Type | Payload | When |
|---------|-------------|---------|------|
| `window.intent` | `close` | `{windowId}` | Window requests to be closed |
| `window.intent` | `maximize` | `{windowId}` | Window requests to be maximized |
| `window.intent` | `restore` | `{windowId}` | Window requests to be restored |
| `window.intent` | `contentChanged` | `{windowId, label}` | Window label updates to the loaded image filename |
| `window.intent` | `openResource` | `{windowId, resourceType, resourceId}` | Not used by this widget |

**Custom outbound:**

| Channel | Intent Type | Payload | When |
|---------|-------------|---------|------|
| `visualization.annotations.send` | `sendAnnotations` | `{windowId, imageName, imageWidth, imageHeight, annotations[]}` | User clicks "Send to Chat" toolbar button |

Each annotation in the payload array contains: `{type, points[], radius? (circle only), label? (text only)}`.

**Standard inbound commands:**

| Channel | Event Type | Response |
|---------|------------|----------|
| `window.{id}.command` | `focus` | Highlights the window as focused (standard Frame behaviour) |
| `window.{id}.command` | `blur` | Removes focus highlight (standard Frame behaviour) |

**Custom inbound:**

| Channel | Event Type | Response |
|---------|------------|----------|
| `visualization.{windowId}.loadImage` | `loadImage` | Receives `{resourceType, resourceId}`. Transitions to the loading state and fetches the specified image. On success, transitions to active state and updates the window label to the image filename. |

---

## 3. Mock Data

### 3.1 Data Requirements

- **Test image:** A sample PNG file (approximately 1200 x 900 pixels) representing a typical workflow step output such as a UMAP scatter plot. Located at `assets/data/View UMAP vs. clusters.png`.
- **Annotation fixtures:** A set of six sample annotations, one of each type (rectangle, circle, arrow, polygon, freehand, text), positioned at various locations on the test image. Defined in `_fixtures/sample-data.json`.
- **State fixtures:** All four body states must be exercisable from mock data:
  - Loading: spinner with "Loading image..." message
  - Empty: "No image loaded" with detail text
  - Active: test image displayed with sample annotations and a neutral zoom level
  - Error: "Something went wrong" with a descriptive detail message and retry button
- **Image model:** Each loaded image is represented by: resourceId, resourceType, name (filename), width, height, and image bytes.

### 3.2 Mock EventBus Behaviour

- **On startup:** The mock fires a `visualization.{windowId}.loadImage` event after a brief delay to simulate a step output triggering image load. This transitions the widget from empty to loading to active.
- **Send to Chat:** The mock logs the outbound `visualization.annotations.send` event payload to the console for verification.
- **State cycling:** The mock provides a mechanism (e.g., toolbar in the mock harness, not in the widget itself) to switch between the four body states for visual testing.

---

## 4. Assumptions

- Window runs inside the Tercen Frame; it is never standalone in production.
- Frame provides tab rendering, focus management, theme broadcasting, and panel layout.
- EventBus is available via the service locator.
- Images are always PNG format. Other formats (JPEG, SVG, etc.) are not supported by this widget.
- Image data is fetched as binary bytes from the Tercen backend; the widget does not load images from external URLs.
- Annotations are ephemeral within a session. They persist only if the user explicitly saves them via "Save to Project." Closing the window without saving discards annotations.
- The "Send to Chat" action transmits annotation geometry and metadata, not a screenshot or rasterized image.
- The "Save to Project" action calls the appropriate project service to persist annotation data; the exact persistence mechanism is determined during implementation.
- Annotation coordinates are stored relative to the image's native pixel dimensions, not the display/viewport dimensions. This ensures annotations remain correctly positioned at any zoom level.

---

## 5. Optional Sections

### 5.1 Non-Functional Requirements

| ID | Requirement |
|----|-------------|
| NFR-01 | Image rendering must remain responsive for images up to 4000 x 4000 pixels. |
| NFR-02 | Pan and zoom interactions must feel smooth with no perceptible lag. |
| NFR-03 | The annotation overlay must not degrade canvas performance with up to 50 annotations visible simultaneously. |

### 5.2 Annotation Domain Model

The six annotation types share a common structure with optional type-specific fields:

| Annotation Type | Points Meaning | Additional Fields |
|-----------------|---------------|-------------------|
| Polygon | Ordered vertices forming a closed shape | None |
| Rectangle | Two opposite corners (top-left, bottom-right) | None |
| Circle | Single point (centre) | `radius` |
| Arrow | Two points (start, end with arrowhead) | None |
| Freehand | Ordered points along the drawn path | None |
| Text | Single point (anchor position) | `label` |

### 5.3 Glossary

| Term | Definition |
|------|------------|
| Annotation | A user-drawn shape or text label overlaid on the image, stored as coordinate geometry relative to the image's native dimensions. |
| Step output | A file or data artifact produced by a workflow step. In this context, a PNG image generated by a visualization step. |
| Canvas | The pannable, zoomable display area showing the image and its annotation overlay. |

---

## Checklist

- [x] Identity table complete (typeId, typeColor, initial label, label update rule)
- [x] ASCII layout diagram with Toolbar + Body structure (tab shown as Frame-rendered)
- [x] Toolbar actions enumerated (type, tooltip, enabled condition, action)
- [x] All four body states addressed (loading, empty, active, error)
- [x] EventBus communication defined with explicit channel names (outbound intents + inbound subscriptions)
- [x] Custom channels documented (`visualization.annotations.send`, `visualization.{windowId}.loadImage`)
- [x] Intent routing defined — all opening paths documented (`openImage`, `openStepImages`, inbound event)
- [x] Orchestrator wiring requirement documented (Project Navigator `.png` routing)
- [x] Primitive refactoring plan documented (strip toolbar from AnnotatedImageViewer, add EventBus channels)
- [x] WindowShell + toolbarActions pattern enforced (no custom toolbar in primitives)
- [x] Active state content layout described (interactions, data flow)
- [x] Mock data and mock EventBus behaviour specified
- [x] Out of scope explicitly lists Frame concerns (tabs, layout, theme toggle)
- [x] No implementation detail (no code, no framework references)
- [ ] User has reviewed and approved
