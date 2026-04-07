# Phase 3 Catalog Integration — Header Widget

Kind-specific guide for translating a Phase 2 header mock into a catalog.json template.

---

## Header widget characteristics

- **Not a floating window.** The header is a frame-level chrome bar rendered by the orchestrator shell, not by the WindowManager.
- **Fixed height.** Typically 36px — specified via `Container` with `height` prop.
- **Always visible.** No loading/empty/error states — the header renders immediately.
- **Minimal data.** User identity comes from `{{context.username}}` and `{{context.userId}}`. No heavy DataSource calls needed for basic header.
- **No `handlesIntent`.** The header doesn't open in response to intents — it's always present.

---

## Step 1 specifics: Inventory the header mock

Common header mock elements and their SDUI mappings:

| Mock element | Typical mock implementation | SDUI approach |
|---|---|---|
| Brand mark / logo | SVG widget or custom painter | `Image` (if URL) or new `SvgImage` primitive (if inline SVG) |
| App title / wordmark | `Text` widget with custom font | `Text` with `textStyle` token |
| User avatar | Custom `IdenticonPainter` or `CircleAvatar` | `CircleAvatar` primitive (already exists) |
| User dropdown | Overlay/`PopupMenuButton` with items | `PopupMenu` primitive (already exists) |
| Theme toggle | Switch or menu item | `Action` publishing to theme channel |
| Navigation home | Tap on brand mark | `Action` with `onTap` gesture |
| LLM status indicator | Coloured dot or icon | `Icon` or `Container` with conditional color |
| Bottom border | `BoxDecoration` border | `Container` with `borderBottom` or `Divider` |

---

## Step 2 specifics: Common header gaps

Primitives that header widgets commonly need but may not exist:

| Element | Likely status | Resolution |
|---|---|---|
| `CircleAvatar` | EXISTS | Use text prop for initials |
| `PopupMenu` | EXISTS | Use items prop for menu entries |
| `Image` | EXISTS | Use for URL-based logos |
| SVG rendering | CHECK | May need `SvgImage` primitive if logo is inline SVG |
| Identicon | CHECK | May need `Identicon` primitive or use `CircleAvatar` with text fallback |

Always verify against current `builtin_widgets.dart` — primitives may have been added since this guide was written.

---

## Step 4 specifics: Header template structure

### Typical header layout

```json
{
  "type": "Container",
  "id": "{{widgetId}}-bar",
  "props": {
    "color": "surface",
    "height": 36
  },
  "children": [{
    "type": "Padding",
    "id": "{{widgetId}}-pad",
    "props": { "padding": "sm" },
    "children": [{
      "type": "Row",
      "id": "{{widgetId}}-row",
      "children": [
        { "left side: brand mark, title" : "..." },
        { "type": "Spacer", "id": "{{widgetId}}-spacer" },
        { "right side: status indicators, user avatar, dropdown" : "..." }
      ]
    }]
  }]
}
```

### User identity without DataSource

The header can display user info without a DataSource call because `{{context.username}}` and `{{context.userId}}` are always available:

```json
{
  "type": "CircleAvatar",
  "id": "{{widgetId}}-avatar",
  "props": {
    "text": "{{context.username}}",
    "radius": 14,
    "color": "primary"
  }
}
```

### User dropdown via PopupMenu

```json
{
  "type": "PopupMenu",
  "id": "{{widgetId}}-menu",
  "props": {
    "icon": "person",
    "items": [
      { "label": "About", "value": "about" },
      { "label": "Sign Out", "value": "signout" }
    ],
    "channel": "header.menu.selected"
  }
}
```

### Brand mark with navigation

```json
{
  "type": "Action",
  "id": "{{widgetId}}-home-tap",
  "props": {
    "gesture": "onTap",
    "channel": "system.intent",
    "payload": { "intent": "home" }
  },
  "children": [{
    "type": "Row",
    "id": "{{widgetId}}-brand",
    "children": [
      {
        "type": "Image",
        "id": "{{widgetId}}-logo",
        "props": { "src": "/assets/logo.svg", "height": 20 }
      },
      { "type": "SizedBox", "id": "{{widgetId}}-brand-gap", "props": { "width": 8 } },
      {
        "type": "Text",
        "id": "{{widgetId}}-brand-text",
        "props": { "text": "Tercen", "textStyle": "labelMedium", "color": "onSurface" }
      }
    ]
  }]
}
```

---

## Step 5 specifics: Header in the home configuration

Header widgets are not standard floating windows. How the orchestrator integrates the header depends on the shell implementation. Check the current shell:

1. Read `/home/martin/tercen/tercen_ui_orchestrator/lib/presentation/screens/shell_screen.dart`
2. If the shell has a dedicated header slot → the header template renders there
3. If the shell only has floating windows → the header may need to be rendered as a pinned, non-draggable window at the top

**Current state (verify):** The shell is currently a `Column` with `WorkspacePanel` + `ErrorBar`. The header may need to be added as a new element before the `WorkspacePanel`, or rendered as a floating window with special positioning.

If shell changes are needed, document them but do NOT modify the orchestrator — flag this for the user to decide.

For the catalog.json, add the header to the `home` section:

```json
"home": {
  "header": {
    "type": "MainHeader",
    "id": "main-header"
  },
  "windows": [ ... ]
}
```

**Note:** The `home.header` key may not be supported yet by the orchestrator's `_openHomeWindows()`. If so, flag this as a gap — the orchestrator needs to be updated to read `home.header` and render it in the shell's header slot.

---

## Assets

If the header uses assets (logos, SVGs):

1. Assets should be served by the orchestrator's server or referenced via URL
2. Do NOT embed base64 data in the catalog.json — use URLs
3. If the asset needs to be bundled with the orchestrator, note the file path and flag for the user
4. Theme-aware assets (e.g., light/dark logo variants) can use `Conditional` with a theme state binding, or the primitive should handle theme internally

---

## Checklist (header-specific)

- [ ] Template renders a fixed-height chrome bar (no loading/empty/error states needed)
- [ ] Brand mark is present on the left with home navigation action
- [ ] User avatar/menu is present on the right with `{{context.username}}`
- [ ] No DataSource calls unless the header genuinely needs live data
- [ ] All colors use semantic tokens, not hex
- [ ] All text uses `textStyle` tokens, not `fontSize`
- [ ] All spacing uses tokens (`xs`, `sm`, `md`), not pixel values
- [ ] No `handlesIntent` in metadata (header is always visible)
- [ ] Home section updated in catalog.json
- [ ] Shell integration path documented (how orchestrator renders the header)
