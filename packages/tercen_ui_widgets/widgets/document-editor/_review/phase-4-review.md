# Phase 4 Review — DocumentEditor

**Verdict: FAIL**

Reviewed: `/home/martin/tercen/tercen_ui_widgets/document-editor-catalog.json`
Date: 2026-04-02
Reviewer: conformance agent

---

## Issues to fix

### Issue 1 — DangerButton: wrong prop names (`label`, `icon` not registered)

**Location:** `{{widgetId}}-err-retry` node (line ~174)

The catalog entry uses:
```json
"type": "DangerButton",
"props": {
  "label": "Retry",
  "icon": "rotate",
  "channel": "document.refresh"
}
```

The registered primitive (`_buildDangerButton` in `builtin_widgets.dart`) accepts only `text`, `channel`, `payload`, and `enabled`. It has no `label` prop and no `icon` prop. The `text` prop is required. As written, the button will render with no text and the `icon` prop will be silently ignored.

**Fix:** Replace `"label"` with `"text"` and remove `"icon"`. If an icon is needed, the gap must be logged against DangerButton and an IconButton workaround used until the primitive is updated.

```json
"props": {
  "text": "Retry",
  "channel": "document.refresh"
}
```

---

### Issue 2 — `{{state.X}}` bindings are unresolvable

**Location:** Four nodes:
- `{{widgetId}}-banner-success`: `"visible": "{{state.saveSuccess}}"`
- `{{widgetId}}-banner-error`: `"visible": "{{state.saveError}}"`
- `{{widgetId}}-alert-error`: `"message": "{{state.saveErrorMessage}}"`
- `{{widgetId}}-source-cond`: `"visible": "{{state.editMode == 'source'}}"`
- `{{widgetId}}-rendered-cond`: `"visible": "{{state.editMode == 'rendered'}}"`

The template resolver (`template_resolver.dart`) exposes only `props.*` and `widgetId` at template root scope. The StateManager is stored in `renderContext.stateManager` (a Dart object) and is NOT injected into the template scope under a `state` key. No existing catalog entry uses `{{state.X}}` bindings. These will all resolve to the unresolved literal string (e.g. `"{{state.saveSuccess}}"`) which is a non-empty, non-`false` string — meaning Conditional will evaluate it as truthy and the banners will always be shown.

Additionally, `{{state.editMode == 'source'}}` uses a comparison operator. The template resolver regex only handles `{{scope.dotPath}}` and `{{scope:$jsonPath}}` forms. Expression syntax (`==`) is outside the regex entirely and will not evaluate.

**Fix:** The `{{state.X}}` scope is not implemented in the current renderer. This is a platform-level gap. Options:
1. Use `EventScope` nodes to expose state via EventBus channels instead of direct state bindings, OR
2. Add a platform fix to inject StateManager snapshot as `state` scope before this pattern can be used in catalog.json.

Until resolved, the affected nodes must be annotated with `_comment` explaining the gap, and this gap must be added to `sdui-gaps.md`.

---

### Issue 3 — Divider used as vertical separator inside a Row

**Location:** Nodes `{{widgetId}}-tb-sep1`, `{{widgetId}}-tb-sep2`, `{{widgetId}}-fmt-sep1`, `{{widgetId}}-fmt-sep2`, `{{widgetId}}-fmt-sep3` (five instances)

These nodes use:
```json
"type": "Divider",
"props": { "height": 24, "color": "outlineVariant" }
```

The `Divider` primitive is registered as "Horizontal divider line" and renders Flutter's `Divider` widget, which is always horizontal. Placing it inside a `Row` with `height: 24` does not produce a vertical separator. The existing catalog uses Divider only for horizontal separators.

There is no registered vertical separator primitive. This is a gap that must be documented.

**Fix:** Remove the Divider nodes from the toolbar Row and document the gap: a `VerticalDivider` primitive is needed (or the existing `Divider` primitive needs a `direction` prop). Use `SizedBox(width: 1)` with a `Container` background color as a workaround, or drop the visual separators until the primitive exists. Add to `sdui-gaps.md`.

---

### Issue 4 — `{{state.X}}` expression gap not documented in sdui-gaps.md

The gap report (`widgets/document-editor/_mock/sdui-gaps.md`) documents 7 gaps but does not include the `{{state.X}}` binding gap or the vertical separator (`VerticalDivider`) gap. The phase 4 skill requires all unresolvable items to be documented.

**Fix:** Add two entries to `sdui-gaps.md`:
- GAP: `{{state.X}}` template bindings — StateManager state not injected into template resolver scope
- GAP: VerticalDivider — no registered primitive for vertical separator inside Row/toolbar

---

### Issue 5 — `{{state.editMode == 'source'}}` is not a valid binding expression

**Location:** `{{widgetId}}-source-cond` and `{{widgetId}}-rendered-cond`

Beyond the scope availability problem (Issue 2), the expression `{{state.editMode == 'source'}}` uses comparison syntax that the template resolver does not support. The regex pattern only matches `{{scopeName.dotPath}}` or `{{scopeName:$jsonPath}}` or `{{bareKey}}`. Equality operators are not in the grammar.

Even if `state` were in scope, this expression would not resolve to a boolean. It is an invalid binding form.

**Fix:** This requires either a template expression evaluator (platform fix) or a different architecture for mode switching (e.g. publish mode to an EventScope channel and bind `{{mode.value}}`).

---

### Issue 6 — Spacing value `height: 24` on SizedBox nodes is not an approved grid value

**Location:** Not present — clarification: `height: 24` appears only on Divider nodes (Issue 3), not on SizedBox nodes. SizedBox values used are 8, 4, 16 which are valid (sm=8, xs=4, md=16). `width: 8` and `width: 4` are also valid.

**However**, `height: 24` (= `lg`) on a Divider, and the Divider `height` prop semantics: the Divider `height` prop sets the space allocated to the widget, not the thickness. Using `height: 24` on a horizontal Divider to create visual padding above/below is borderline — it is a structural dimension, not a spacing token. The phase 4 rule says "no numeric spacing except Icon size". Using raw `24` on Divider height rather than a spacing token is technically non-conformant, but the Divider primitive only accepts a numeric `height` prop (no token support). This is a pre-existing limitation of the primitive.

**Recommendation:** Flag as a known limitation — the Divider primitive does not accept spacing tokens. Not a hard block but note it.

---

### Issue 7 — `maxLines: 999` is an arbitrary magic number

**Location:** `{{widgetId}}-source-editor` TextField node

```json
"maxLines": 999
```

This is a magic number used as a proxy for "unlimited lines". The spec says no arbitrary numeric values outside the approved grid. If the TextField primitive does not support `maxLines: null` or `maxLines: 0` for unlimited, the gap should be noted in `sdui-gaps.md` and a comment added. Using `999` as a workaround is not conformant.

**Fix:** Check if TextField supports `maxLines: null` (omit the prop) for unlimited-lines behaviour. If it does, remove the `maxLines` prop. If it requires an explicit value and has no unlimited variant, add this to `sdui-gaps.md` and annotate with `_comment`.

---

## What was checked (pass items)

- All primitive types used (`Column`, `Row`, `Expanded`, `DataSource`, `Conditional`, `Center`, `LoadingIndicator`, `Icon`, `SizedBox`, `Text`, `Container`, `Padding`, `TextField`, `Markdown`, `Alert`, `Spacer`, `Divider`, `IconButton`) are registered in `builtin_widgets.dart` or `behavior_widgets.dart`. `DangerButton` is registered but with wrong props (Issue 1).
- Node IDs: all use `{{widgetId}}-suffix` pattern. No duplicate suffixes found.
- Color tokens used: `surfaceContainerHigh`, `outlineVariant`, `error`, `onSurfaceDisabled` — all approved in `tokens.meta.json`.
- `typeColor`: `"#9333EA"` is in the `approvedTypeColors` list in `tokens.meta.json`.
- No raw hex values in template props.
- No pixel font sizes in template.
- Icons used: `circle-xmark`, `floppy-disk`, `code`, `book`, `bold`, `italic`, `strikethrough`, `heading`, `list-ul`, `list-ol`, `link`, `image`, `minus`, `rotate`, `print` — all are FontAwesome 6 Solid names.
- DataSource scope bindings: `{{loading}}`, `{{error}}`, `{{errorMessage}}`, `{{ready}}`, `{{data.content}}` are all valid DataSource scope variables (confirmed in `_DataSourceWidgetState._renderChildren`).
- `{{props.documentId}}` in DataSource args is valid (used inside template scope where `props` is injected).
- Metadata required fields present: `type`, `kind`, `tier`, `description`, `handlesIntent`, `emittedEvents`, `inboundEvents`.
- `handlesIntent` is an object (consistent with other window widgets that use this form).
- `emittedEvents`/`inboundEvents` naming matches existing catalog convention.
- Alert primitive supports `dismissible` and `channel` props as used.
- LoadingIndicator supports `variant: "skeleton"` as used.
- Gap report (`sdui-gaps.md`) exists and documents the 7 gaps that were identified during authoring.

---

## Summary table

| # | Severity | Issue |
|---|----------|-------|
| 1 | FAIL — wrong prop names | DangerButton uses `label`/`icon`; must use `text`, no `icon` |
| 2 | FAIL — unresolvable binding | `{{state.X}}` not injected into template scope |
| 3 | FAIL — wrong primitive | `Divider` used as vertical separator in Row; renders horizontal |
| 4 | FAIL — gap not documented | `{{state.X}}` scope and VerticalDivider gaps missing from sdui-gaps.md |
| 5 | FAIL — invalid expression | `==` operator not supported in template binding syntax |
| 6 | WARN — magic number | `maxLines: 999` should be omitted or gap-documented |
