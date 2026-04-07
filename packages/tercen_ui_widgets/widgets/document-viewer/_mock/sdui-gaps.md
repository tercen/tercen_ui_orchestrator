# SDUI Primitive Gaps — Document Editor

**Date:** 2026-04-02
**Source:** Flutter mock (`widgets/document-editor/lib/`) → `document-editor-catalog.json`
**Catalog entry:** `document-editor-catalog.json` (temporary, pending merge to `catalog.json`)

---

## GAP: SegmentedButton — mode toggle primitive missing

**Mock needs:** Two-segment icon toggle (source/rendered) with shared border, active fill, and inactive transparent state. See `_ModeToggle` in `document_toolbar.dart`.
**SDUI has:** Individual `IconButton` primitives with `toolbar-primary` and `toolbar-secondary` variants.
**Missing:** `SegmentedButton` primitive — a multi-segment toggle that visually groups options with shared border/radius and highlights the active segment.
**Suggested fix:** Add `SegmentedButton` primitive to `builtin_widgets.dart` with props: `segments` (list of {icon, value, tooltip}), `value` (selected segment), `channel` (emits on change).
**Blocking:** `{{widgetId}}-btn-mode-source` and `{{widgetId}}-btn-mode-rendered` nodes. Currently workaround with two separate IconButtons — functional but visually different from mock.

---

## GAP: TextField — monospace fontFamily prop missing

**Mock needs:** Source editor uses monospace system font (`fontFamily: 'monospace'`) for raw markdown/text editing. See `source_editor.dart`.
**SDUI has:** `TextField` with `maxLines`, `borderless`, `submitOnEnter` props. Text style is hardcoded to theme `bodyMedium`.
**Missing:** `fontFamily` or `variant: "monospace"` prop on TextField.
**Suggested fix:** Add `fontFamily` prop (string, optional) to TextField in `builtin_widgets.dart`, or add a `variant: "code"` that applies monospace font.
**Blocking:** `{{widgetId}}-source-editor` node. Editor will render in proportional font instead of monospace.

---

## GAP: Text insertion actions — formatting buttons cannot manipulate TextField content

**Mock needs:** Toolbar formatting buttons (bold, italic, headings, lists, link, image, code, HR) insert markdown syntax at the cursor position in the source editor. See `DocumentToolbar._insertMarkdown()`.
**SDUI has:** `IconButton` with `channel` prop to emit events. No mechanism for one catalog.json node to modify another node's content.
**Missing:** Cross-node content manipulation. The catalog.json declarative model cannot express "insert `**` around the selected text in the TextField".
**Suggested fix:** The orchestrator needs a `TextFieldController` behavior that listens on a channel and manipulates a target TextField's content. This is platform-level behavior, not a catalog primitive.
**Blocking:** All formatting button nodes (`{{widgetId}}-btn-bold` through `{{widgetId}}-btn-hr`). Buttons will emit events but won't produce visible text changes without orchestrator support.

---

## GAP: Save state tracking — dirty/clean state management

**Mock needs:** Save button changes appearance (secondary → primary) when document is dirty. Dirty tracking compares current content against original. See `DocumentProvider.isDirty`.
**SDUI has:** `stateConfig` in metadata for simple state, `Conditional` for visibility. No built-in dirty-tracking mechanism that compares a TextField's current value against its initial value.
**Missing:** Dirty state derivation — automatic detection of whether TextField content has changed from the DataSource-provided value.
**Suggested fix:** Add a `dirtyTracking` behavior that compares a bound field's current value to its DataSource origin and publishes a `{{state.isDirty}}` variable. Or handle this in the orchestrator's widget state manager.
**Blocking:** `{{widgetId}}-btn-save` node. Save button currently uses static `toolbar-secondary` variant; cannot dynamically switch to `toolbar-primary` when dirty.

---

## GAP: Banner auto-dismiss — timed visibility not expressible

**Mock needs:** Success save banner auto-dismisses after 2 seconds via `Timer`. See `ActiveState._showSuccessBanner()`.
**SDUI has:** `Alert` with `dismissible` (manual close button). `Conditional` with `visible` binding. No timer or auto-dismiss behavior.
**Missing:** `autoHide` or `duration` prop on Alert, or a `Timer` behavior primitive.
**Suggested fix:** Add `autoHideDuration` prop (int, milliseconds) to `Alert` primitive. When set, the alert automatically hides after the specified duration.
**Blocking:** `{{widgetId}}-alert-success` node. Success banner will persist until manually dismissed instead of auto-hiding.

---

## GAP: Undo/redo — keyboard shortcuts and state stacks

**Mock needs:** Ctrl+Z / Ctrl+Shift+Z for undo/redo with a 50-item history stack. See `DocumentProvider._undoStack` and `HomeScreen._handleKeyEvent()`.
**SDUI has:** No keyboard shortcut binding mechanism. No undo/redo state stack primitive.
**Missing:** Keyboard shortcut registration and undo/redo state management are platform behaviors not expressible in catalog.json.
**Suggested fix:** The orchestrator could provide built-in undo/redo for TextField widgets. This is a platform-level feature, not a catalog primitive.
**Blocking:** No catalog.json nodes affected — this is entirely platform behavior. Document for orchestrator implementation.

---

## GAP: Link/image insert dialogs — custom FormDialog content

**Mock needs:** Modal dialogs for inserting links (URL + display text) and images (URL + size selector). See `link_dialog.dart` and `image_dialog.dart`.
**SDUI has:** `FormDialog` primitive exists but its content composition capabilities need verification.
**Missing:** Confirmation that FormDialog can contain arbitrary child nodes (TextField, DropdownButton) composed from catalog.json, and that it can return structured data (not just dismiss).
**Suggested fix:** Verify FormDialog supports custom children. If not, add `fields` prop that accepts a list of field definitions (text, dropdown) with return value binding.
**Blocking:** `{{widgetId}}-btn-link` and `{{widgetId}}-btn-image` format actions. Without dialog support, these buttons emit events but cannot collect user input for the URL/text values.

---

## GAP: Template state scope — `{{state.X}}` bindings not available

**Mock needs:** Save banners conditionally visible based on `state.saveSuccess`/`state.saveError`. Editor mode switching based on `state.editMode`. Save button variant switching based on `state.isDirty`.
**SDUI has:** Template resolver injects `props.*` and `widgetId` at template root, and `data`/`loading`/`error`/`ready` inside DataSource. StateManager exists as a Dart object but is NOT injected into the template scope under a `state` key.
**Missing:** `{{state.X}}` binding support in template resolver. No existing catalog entry uses this pattern.
**Suggested fix:** Inject `stateManager.snapshot` as `state` scope in `template_resolver.dart`, alongside `props` and `widgetId`. This is a platform-level change in the SDUI package.
**Blocking:** Save banners (removed, replaced with placeholder Alert), editor mode switching (both editors rendered, orchestrator must manage visibility), save button dirty state (static variant).

---

## GAP: Template expression evaluation — comparison operators in bindings

**Mock needs:** `{{state.editMode == 'source'}}` and `{{state.editMode == 'rendered'}}` as Conditional visible expressions to switch between source and rendered editors.
**SDUI has:** Template resolver regex matches only `{{scope.dotPath}}` and `{{scope:$jsonPath}}` forms. No expression evaluation (no `==`, `!=`, `&&`, `||` operators).
**Missing:** Expression evaluator in template binding grammar.
**Suggested fix:** Add a simple expression evaluator to Conditional's `visible` prop that supports `==` and `!=` comparisons, e.g. `{{state.editMode == 'source'}}` → boolean.
**Blocking:** Editor mode switching. Without this, both editors are rendered simultaneously and the orchestrator must hide/show via internal logic rather than declarative Conditionals.

---

## GAP: VerticalDivider — no primitive for vertical separator in Row

**Mock needs:** 1px wide, 24px tall vertical separators between toolbar button groups. See `_ToolbarSeparator` in `document_toolbar.dart`.
**SDUI has:** `Divider` primitive renders Flutter's horizontal `Divider` widget. No `VerticalDivider` registered.
**Missing:** `VerticalDivider` primitive, or a `direction` prop on existing `Divider`.
**Suggested fix:** Either register a `VerticalDivider` primitive in `builtin_widgets.dart`, or add `direction: "horizontal"|"vertical"` prop to existing `Divider`.
**Blocking:** Toolbar separator nodes. Currently using `Container(width:1, height:24, color: outlineVariant)` as workaround — functional but semantically incorrect.

---

## GAP: Formatting icon keys missing from _iconMap

**Mock needs:** Toolbar formatting buttons use FA6 icons: `bold`, `italic`, `strikethrough`, `heading`, `list-ul`, `list-ol`.
**SDUI has:** `_iconMap` in `builtin_widgets.dart` contains 175 keys but none of the above formatting icons.
**Missing:** 6 entries in `_iconMap`: `'bold': FontAwesomeIcons.bold`, `'italic': FontAwesomeIcons.italic`, `'strikethrough': FontAwesomeIcons.strikethrough`, `'heading': FontAwesomeIcons.heading`, `'list-ul': FontAwesomeIcons.listUl` (or `'list_ul'`), `'list-ol': FontAwesomeIcons.listOl` (or `'list_ol'`).
**Suggested fix:** Add all 6 keys to `_iconMap` in `builtin_widgets.dart`.
**Blocking:** All formatting toolbar IconButton nodes — replaced with Placeholder ERROR nodes.

---

## GAP: MimeType-conditional rendering — mode toggle and rendered editor should be markdown-only

**Mock needs:** The mode toggle (source/rendered) and rendered Markdown editor should only be available when `data.mimeType == 'text/markdown'`. For `text/plain` documents, only the source editor should appear and the mode toggle should be hidden. See `DocumentProvider.isMarkdown` and `DocumentToolbar._buildModeToggle()`.
**SDUI has:** `Conditional` with `visible` prop, but no expression evaluation (`==` operator not supported in binding grammar — see GAP #9).
**Missing:** Ability to conditionally render nodes based on `{{data.mimeType == 'text/markdown'}}`. Even if state scope (GAP #8) were resolved, expression evaluation (GAP #9) is still required.
**Suggested fix:** Depends on GAP #9 (expression evaluation). Once available, wrap mode toggle and rendered editor in `Conditional(visible: data.mimeType == 'text/markdown')`.
**Blocking:** Mode toggle and rendered editor nodes — both render regardless of document type. Plain text documents will incorrectly show a Markdown preview and a source/rendered toggle.

---

## Summary

| # | Gap | Severity | Workaround in catalog.json |
|---|-----|----------|---------------------------|
| 1 | SegmentedButton | Medium | Placeholder ERROR |
| 2 | Monospace TextField | Low | Placeholder ERROR |
| 3 | Text insertion actions | High | Placeholder ERROR (buttons + channels in _comment) |
| 4 | Dirty state tracking | Medium | Placeholder ERROR |
| 5 | Banner auto-dismiss | Low | Placeholder ERROR |
| 6 | Undo/redo | Low | Platform behavior, not in catalog |
| 7 | Link/image dialogs | Medium | Placeholder ERROR (channels in _comment) |
| 8 | Template state scope | High | Placeholder ERROR |
| 9 | Expression evaluation | High | Placeholder ERROR |
| 10 | VerticalDivider | Low | Placeholder ERROR |
| 11 | Formatting icon keys | Medium | Placeholder ERROR (6 icons missing from _iconMap) |
| 12 | MimeType-conditional | Medium | Placeholder ERROR (mode toggle + rendered editor always visible) |
