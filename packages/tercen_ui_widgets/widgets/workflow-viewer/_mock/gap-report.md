# Workflow Viewer — SDUI Gap Report

**Widget:** workflow-viewer
**Spec version:** 1.0
**Report date:** 2026-03-31
**Primitives source:** `tercen-style/theme-export.json` → `primitives[]`

---

## How to read this table

| Gap Type | Meaning |
|---|---|
| **OK** | Element maps cleanly to an existing SDUI primitive with no changes needed |
| **Primitive gap** | No matching primitive exists at all — a new primitive must be created |
| **Variant gap** | Primitive exists but lacks the required visual variant |
| **Prop gap** | Primitive exists and variant matches but is missing a required prop |
| **Composition question** | Element is a composite of existing primitives — no gap, but needs an assembly pattern decision |
| **Style gap** | Primitive exists but a token or style override is required that is not currently expressible |

---

## Gap Table

| Element | SDUI Primitive | Gap Type | Notes |
|---|---|---|---|
| **LAYOUT** | | | |
| Window shell (tab strip + toolbar + body) | `Column` | Composition question | The three-zone layout (tab strip, toolbar, body) is a fixed composition. No single primitive covers it — needs a WindowShell composition pattern defined in the widget catalog. |
| Tab strip (Frame-provided chrome) | None (Frame layer) | Primitive gap | Tab strip is provided by the Frame, not the widget. No SDUI primitive needed inside the widget body. The mock tab strip shown is for design reference only. |
| Flowchart body (scrollable X+Y container) | `Container` | Prop gap | `Container` has no `overflow: scroll` or `scrollableX / scrollableY` props. Needs `overflow` prop added, or a dedicated `ScrollArea` primitive. |
| Flowchart canvas (absolute-position host) | `Container` | Prop gap | Canvas needs `position: relative` with pixel-level child placement. `Container` does not expose absolute positioning of children. A `Canvas` or `AbsoluteLayout` primitive would be required for production. |
| Toolbar layout ([Action Button] Spacer [Search]) | `Row` + `Spacer` | OK — maps to Row + Spacer | `Row` with `mainAxisAlignment: spaceBetween` or explicit `Spacer` achieves this. |
| **TOOLBAR CONTROLS** | | | |
| Action button — Run All / Stop All / Reset All | `PrimaryButton` | Variant gap | `PrimaryButton` maps to the filled primary style. However the button label and icon must change dynamically based on focused node + step state. `PrimaryButton` has no `icon` prop — only `text`. Needs an `icon` prop added, or use `Row(Icon + PrimaryButton)` composition. |
| Action button — Stop variant (red/error) | `PrimaryButton` | Style gap | The Stop All / Stop Step variant uses `--color-error` as the fill colour. `PrimaryButton` accepts a `color` prop but error-coloured primary buttons are not documented in the style guide. Needs explicit approval for `color: error` on `PrimaryButton`. |
| Search field | `TextField` | Variant gap | `TextField` exists with `hint`, `value`, `borderless` props. Missing: (1) prefix icon slot (`prefixIcon`), (2) clear button on non-empty input, (3) collapsible width behaviour (collapses to icon-only when toolbar is narrow). A `SearchField` variant of `TextField` is recommended. |
| Search field clear button (xmark) | `IconButton` | Composition question | The clear button inside the search field is a composed element. In production this is internal to the search field widget — not a standalone primitive in the toolbar. |
| **BODY STATE: LOADING** | | | |
| Loading spinner | `Icon` | Variant gap | `Icon` primitive renders a static FA6 icon. A rotating spinner requires `fa-spin` animation. No `animated` or `spinning` prop exists on `Icon`. Needs either a `Spinner` primitive or an `animated: spin` prop on `Icon`. |
| Loading label ("Loading workflow...") | `Text` | OK — maps to Text | `Text` with `textStyle: bodyMedium`, `color: onSurfaceMuted`. |
| Centred layout wrapper | `Center` | OK — maps to Center | `Center` primitive achieves the centred loading/empty/error state layout. |
| **BODY STATE: EMPTY** | | | |
| Empty state icon | `Icon` | OK — maps to Icon | `Icon` with `icon: sitemap`, `size: 48`, `color: onSurfaceMuted`. |
| Empty state title | `Text` | OK — maps to Text | `Text` with `textStyle: headlineSmall`. |
| Empty state subtitle | `Text` | OK — maps to Text | `Text` with `textStyle: bodyMedium`, `color: onSurfaceMuted`. |
| **BODY STATE: ERROR** | | | |
| Error icon | `Icon` | OK — maps to Icon | `Icon` with `icon: triangleExclamation`, `size: 48`, `color: error`. |
| Error title | `Text` | OK — maps to Text | Standard `Text` headlineSmall. |
| Error message | `Text` | OK — maps to Text | `Text` bodyMedium, `color: onSurfaceMuted`. |
| Retry button | `SecondaryButton` | OK — maps to SecondaryButton | `SecondaryButton` matches the outlined primary style. Channel: `workflow.retry`. |
| **FLOWCHART NODES — SHAPES** | | | |
| Box node (TableStep, DataStep, ExportStep, WizardStep) | None | Primitive gap | No `FlowchartBoxNode` or `WorkflowNode` primitive exists. The box node (rounded rect, icon + label, state-coloured icon, focus ring, hover highlight) is a domain-specific composite. Needs a new `WorkflowNode` primitive with `kind`, `state`, `name`, `focused`, `searchMatch` props. |
| Circle badge node (Workflow root, GroupStep, ViewStep) | None | Primitive gap | Same as above — no circle badge node primitive. The circle badge with external label, focus ring, and hover state is not composable from existing `Icon` + `Container` primitives cleanly, especially with focus path highlighting. Part of `WorkflowNode` primitive (see above). |
| Rounded square node (InStep, OutStep) | None | Primitive gap | Same `WorkflowNode` primitive gap — compact variant needed. |
| Hexagon node (JoinStep, MeltStep) | None | Primitive gap | `clip-path: polygon(...)` hexagon is not supported by any existing primitive. Needs hexagon variant on `WorkflowNode`. |
| **FLOWCHART NODES — BEHAVIOUR** | | | |
| Node focus ring | `Container` (bordered) | Prop gap | `Container` supports `borderColor` and `borderWidth`. But the focus ring is a 2px emphasis ring with `--color-primary` plus an outer 2px offset glow (`box-shadow: 0 0 0 2px primaryFixed`). `Container` has no `focusRingOffset` or `boxShadow` prop. Expressible via custom style but not via token props alone. |
| Node hover highlight | None | Style gap | Hover state must change `background` to `primaryFixed` and `borderColor` to `primary`. Interactive hover behaviour is not declaratively expressible in SDUI — requires either a `hoverable` prop or Flutter's `MouseRegion` in the primitive implementation. |
| Node click → focus (single-click) | None | Primitive gap | Click-to-focus behaviour requires the `WorkflowNode` primitive to publish a `focusChanged` event to the EventBus. Not achievable with current primitives. Needs `onTap` channel prop on `WorkflowNode`. |
| Node double-click → open step viewer | None | Primitive gap | Double-click (vs single-click) is not a supported gesture on any current primitive. Needs `onDoubleTap` channel prop on `WorkflowNode`. |
| Inline rename (slow double-click on label) | `TextField` | Composition question | Inline rename replaces the static label `Text` with a `TextField` on slow double-click. This is a stateful transition inside the node — not expressible as a pure SDUI composition. The `WorkflowNode` primitive should encapsulate this internally. No `TextField` primitive placement in catalog.json needed. |
| Step state spinner (running) | None | Primitive gap | When `state = running`, the static FA6 icon inside the node shape is replaced by a rotating spinner in `--color-info`. This is animated state that existing primitives do not support declaratively. Needs `animated: true` prop on the `WorkflowNode` primitive. |
| Search match highlight | None | Style gap | When a node matches the search query, it receives a coloured outline in `--color-warning`. This is reactive state driven by the search text. Needs a `searchMatch: bool` prop on `WorkflowNode` to apply the ring. |
| **FLOWCHART CONNECTORS** | | | |
| Elbow connector lines | None | Primitive gap | No `Connector` or `FlowchartLine` primitive exists. Elbow (right-angle) connectors require SVG `<polyline>` or Flutter `CustomPainter`. This is the most complex gap — connectors must be computed from node positions, respect focus path highlighting, and support variable weight (`vizData` vs `vizHighlight`). Needs a dedicated `WorkflowConnector` primitive or a canvas-level `FlowchartCanvas` primitive that owns both node layout and connector rendering. |
| Focused path connector (highlight) | None | Primitive gap | Same as above — the focused path uses `--line-weight-viz-highlight` (3px) and `--color-primary`. This is a sub-state of the connector layer rather than a separate element. Part of `WorkflowConnector`. |
| **OVERALL COMPOSITION** | | | |
| `WorkflowViewer` widget | None | Primitive gap | The workflow viewer as a whole is a Type 1 Feature Window that cannot be assembled from existing catalog.json primitives. It requires a dedicated `WorkflowViewer` primitive (or sub-widget) registered in the catalog with props: `workflowId`, `projectId`, `focusedStepId`, `searchText`, and EventBus channels for all emitted/received events (see spec section 11). |

---

## Summary by Gap Type

| Gap Type | Count |
|---|---|
| OK — maps cleanly | 8 |
| Primitive gap | 9 |
| Variant gap | 3 |
| Prop gap | 3 |
| Composition question | 4 |
| Style gap | 3 |
| **Total elements reviewed** | **30** |

---

## Priority Recommendations

### P0 — Blocking (must exist before catalog.json entry is possible)

1. **`WorkflowNode` primitive** — covers box, circle badge, rounded square, hexagon shapes; `kind`, `state`, `name`, `focused`, `searchMatch`, `onTap` channel, `onDoubleTap` channel props.
2. **`WorkflowConnector` / `FlowchartCanvas` primitive** — SVG/Canvas layer for elbow connectors with focus path highlighting and `vizData` / `vizHighlight` line weights.
3. **`WorkflowViewer` top-level primitive** — the full widget registered in the catalog.

### P1 — Required for toolbar completeness

4. **`icon` prop on `PrimaryButton`** — all toolbar action buttons have an icon (play, stop, reset).
5. **`SearchField` variant of `TextField`** — prefix icon, clear button, collapsible width.
6. **`Spinner` primitive** (or `animated: spin` prop on `Icon`) — loading state and running step state.

### P2 — Style guide clarifications needed

7. **Error-coloured `PrimaryButton`** — confirm `color: error` is an approved usage or introduce a `DangerButton` variant with an icon slot.
8. **`overflow: scroll` on `Container`** — or introduce `ScrollArea` primitive for the flowchart body.
9. **`hoverable` / `focusRing` props** — interactive hover and focus states on non-button elements (nodes) need a declarative pattern.
