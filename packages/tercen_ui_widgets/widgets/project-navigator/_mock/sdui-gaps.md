# SDUI Primitive Gaps — Project Navigator

**Generated:** 2026-04-01
**Source:** Audit of catalog.json against SduiTheme.dart and builtin_widgets.dart
**Updated:** 2026-04-01 — all 3 blocking gaps resolved

---

## ~~GAP: IconButton — no variant prop (primary/secondary)~~ RESOLVED

**Resolution:** Added `variant` prop to `IconButton` accepting `"toolbar-primary"` (filled) and `"toolbar-secondary"` (outlined). Toolbar variants use `ctx.theme.window.toolbarButtonSize`, `ctx.theme.window.toolbarButtonRadius`, `ctx.theme.window.toolbarButtonBorderWidth`, `ctx.theme.window.toolbarButtonIconSize`. New `_ToolbarIconButton` StatefulWidget handles hover, disabled state, and animation using theme tokens.
**Catalog usage:** `"variant": "toolbar-primary"` for Upload/Download, `"variant": "toolbar-secondary"` for Team.

---

## ~~GAP: IconButton — does not read SduiWindowTokens~~ RESOLVED

**Resolution:** Toolbar variants (`toolbar-primary`, `toolbar-secondary`) read all `ctx.theme.window` tokens. Also fixed `_WindowToolbar`, `_LabeledShellButton`, `_IconShellButton` which had hardcoded values (36px, 1.5px border) diverged from theme tokens (32px, 1px). All now read from `ctx.theme.window.*`.

Additionally fixed `SduiTheme.fromJson` — 7 token groups (window, opacity, animation, dataTable, internalTab, button, iconSize) were hardcoded to defaults and never parsed from JSON. All 16 token groups now have `fromJson` factories and are wired in `SduiTheme.fromJson`.

---

## ~~GAP: Icon — no font weight variant (regular vs solid)~~ RESOLVED

**Resolution:** Added `weight` prop to both `Icon` and `IconButton` accepting `"regular"` (default, line style) or `"solid"` (filled). Added `_solidIconMap` with solid variants for common icons (file, folder, user, star, heart, bookmark, bell, comment, envelope, calendar, clock, image, etc.). `_resolveIcon(name, weight)` checks solid map first when weight is "solid", falls back to regular.
**Catalog usage:** `"weight": "solid"` for projects/teams/workflows/datasets, omit (or `"regular"`) for files/sub-folders.

---

## INFO: Known limitations (not blocking)

- **TreeView**: No dedicated TreeView primitive. Composed from ListView + ForEach + Conditional + Container indentation. Works but verbose. Consider a dedicated TreeView primitive for future widgets.
- **SearchField prefix icon**: TextField has no `prefixIcon` prop. Composed with Row + Icon + TextField. Works.
- **PopupMenu per-item icon colour**: PopupMenu items support `icon` but not per-item `iconColor`. Active/inactive colour differentiation for filter dropdown requires SDUI fix or is handled by the renderer defaulting to theme colours.
