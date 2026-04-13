# PngViewer — Real Implementation Guide

## Status

The SDUI mock is **approved** (2026-04-13). All annotation tools, selection, move, delete, auto-publish with crops, save-as-annotated, and toolbar separators work in the mock shell. This document covers what's needed to wire the PngViewer into the real orchestrator.

## What Already Works (no changes needed)

These live in `packages/sdui/lib/src/registry/builtin_widgets.dart` and are shared between mock and production:

- **AnnotatedImageViewer primitive** — all 6 drawing tools (polygon, rectangle, circle, arrow, freehand, text)
- **Unified gesture model** — annotations are interactive zones: click to select, click-drag to move, hover for cursor change. Tool stays active.
- **Toolbar toggle** — tool buttons fill primary when active via `primaryStateKey` → StateManager
- **Delete/Clear** — deletes selected annotation or clears all; tooltip switches via `stateKey`
- **Auto-publish** — every annotation state change publishes full snapshot to `visualization.annotations.send` with cropped image regions (base64 PNG) for rectangles, circles, and polygons
- **Save** — rasterizes image + annotations into a new PNG (browser download in mock)
- **Toolbar separators** — `{"isSeparator": true}` renders vertical dividers between button groups

## What Needs Wiring

### 1. Project Navigator → PngViewer (intent routing)

**Goal:** Clicking a `.png` file in the Project Navigator opens a PngViewer window.

**Current state:** The PngViewer catalog declares `handlesIntent: ["openImage"]` with propsMap `{fileId, fileName}`. But nothing publishes `openImage` intents.

**What to do:**
- In the Project Navigator's file click handler (Action/EventScope that fires on row click), detect when the clicked file has a `.png` extension or `image/png` mimetype
- Publish a `system.intent` event with `intent: "openImage"` and `{fileId, fileName}` in the payload
- The IntentRouter will match this to PngViewer and open a new window

**Files:**
- `packages/tercen_ui_widgets/catalog.json` — ProjectNavigator template (Action handler for file clicks)
- `packages/sdui/lib/src/renderer/sdui_renderer.dart` — IntentRouter (already wired)

**Note:** The DataSource in the PngViewer template calls `tableSchemaService.getStepImages` which expects `workflowId` + `stepId`. For single file opens (`openImage`), a different service call is needed — either add a `getFileImage` method to the dispatcher, or have the PngViewer handle both the `openImage` (single file) and `openStepImages` (workflow step) paths with conditional DataSource logic.

### 2. ChatBox — Receive Annotation Context

**Goal:** When PngViewer auto-publishes annotations, the ChatBox receives them and attaches as context to the next LLM prompt.

**Current state:** PngViewer publishes to `visualization.annotations.send` with type `annotationBundle`. ChatBox has zero references to this channel.

**What to do:**

**a) ChatBox provider — subscribe to annotations:**
- In ChatBox's provider (or a new annotation context provider), subscribe to `visualization.annotations.send` on the EventBus
- Store the latest `annotationBundle` payload (annotations array + sourceImage + crops)
- When the user sends a message, attach the stored annotation context

**b) LLM prompt injection:**
- When annotation context exists, prepend to the user's message or add as a system context block
- For text annotations: include `label` as natural language ("User noted: {label}")
- For region annotations (rectangle, circle, polygon): include the cropped base64 image as a multimodal content block so the LLM can "see" the selected region
- For arrows/freehand: include geometry description ("Arrow from (x1,y1) to (x2,y2)")

**c) Visual indicator:**
- Show a small badge or icon in the ChatBox input area when annotation context is attached
- Allow the user to dismiss/clear the annotation context

**Payload shape (what ChatBox receives):**
```json
{
  "annotations": [
    {"type": "rectangle", "points": [{"x": 100, "y": 200}, {"x": 350, "y": 400}]},
    {"type": "text", "points": [{"x": 255, "y": 170}], "label": "This cluster looks unusual"},
    {"type": "arrow", "points": [{"x": 120, "y": 340}, {"x": 250, "y": 180}]}
  ],
  "sourceImage": {
    "schemaId": "abc123",
    "filename": "View UMAP vs clusters.png",
    "url": "https://..."
  },
  "crops": [
    {"annotationIndex": 0, "type": "rectangle", "imageBase64": "iVBORw0KGgo..."}
  ]
}
```

**Files:**
- `packages/tercen_ui_widgets/widgets/chat-box/lib/presentation/providers/chat_provider.dart`
- `packages/tercen_ui_widgets/widgets/chat-box/chat-box-spec.md` — update spec
- `packages/tercen_ui_widgets/catalog.json` — ChatBox metadata (add `visualization.annotations.send` to inboundEvents)

### 3. Save to Project — Tercen API Upload

**Goal:** Replace browser download with actual file upload to the Tercen project.

**Current state:** `_saveAnnotatedImage()` rasterizes the image + annotations to PNG bytes and triggers browser download.

**What to do:**
- Instead of (or in addition to) browser download, upload the PNG bytes to the Tercen project via the API
- Use the file service (via `service_call_dispatcher` or direct API call) to create a new file document
- File name: `{originalName}_annotated.png`
- The file should appear in the same project folder as the original
- Optionally publish a `window.intent` event with `contentChanged` to refresh the Project Navigator

**API pattern:**
```
POST /api/v1/project/{projectId}/file
Content-Type: image/png
X-Filename: original_annotated.png
Body: <PNG bytes>
```

**Files:**
- `packages/sdui/lib/src/registry/builtin_widgets.dart` — `_saveAnnotatedImage()` method
- `lib/sdui/service/service_call_dispatcher.dart` — add file upload service call

### 4. Image Loading for Single Files

**Goal:** Support opening a single PNG file by `fileId` (not just step images).

**Current state:** The DataSource calls `tableSchemaService.getStepImages(workflowId, stepId)` which fetches images from workflow step outputs. This doesn't handle direct file opens.

**What to do:**
- Add a `getFileImage` method to the service call dispatcher that takes a `fileId` and returns the same `{images: [...]}` format
- The PngViewer template may need a Conditional around the DataSource to handle both opening paths
- Or: use a single service method that accepts either `(workflowId, stepId)` or `(fileId)` and returns the appropriate images

**Files:**
- `lib/sdui/service/service_call_dispatcher.dart` — add `getFileImage` method
- `packages/tercen_ui_widgets/catalog.json` — PngViewer template DataSource args

### 5. Authentication for Image URLs

**Goal:** Image URLs fetched from the Tercen API require authentication tokens.

**Current state:** The `_getStepImages` dispatcher already builds authenticated URLs with token in query params. The `AnnotatedImageViewer` primitive has an `authToken` prop but it's not used for `Image.network` headers.

**What to do:**
- Verify that the authenticated URLs built by `_getStepImages` work in production (they include the token in the URL params)
- If token-in-URL doesn't work in production, add HTTP headers to `Image.network` calls using the `headers` parameter
- The `authToken` prop on the primitive is already wired — just needs to be passed through in the catalog template

## Catalog State Block

The PngViewer catalog entry has a `state` block inside `metadata` (required for StateManager):
```json
"state": {
  "initialState": {
    "pngTool.polygon": false,
    "pngTool.rectangle": false,
    "pngTool.circle": false,
    "pngTool.arrow": false,
    "pngTool.freehand": false,
    "pngTool.text": false,
    "pngSelection": false
  }
}
```

This must stay inside `metadata`, not at the widget entry top level. Without it, all StateManager features silently fail.

## Testing Checklist

- [ ] Project Navigator: click `.png` file → PngViewer opens with correct image
- [ ] Workflow step images: open from workflow context → all step output images show in tabs
- [ ] Draw all 6 annotation types
- [ ] Click-drag to move annotations
- [ ] Delete single annotation + Clear All
- [ ] Toolbar buttons toggle primary when active
- [ ] Auto-publish fires on every annotation change
- [ ] ChatBox receives annotation context
- [ ] ChatBox attaches crops to LLM prompt (multimodal)
- [ ] LLM responds with awareness of annotated regions
- [ ] Save creates new `_annotated.png` file in project
- [ ] Saved file appears in Project Navigator
- [ ] Re-open saved file shows baked-in annotations (not editable)
- [ ] Toolbar separators visible between button groups
