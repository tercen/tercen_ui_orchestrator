# Project Navigator — SDUI Gap Report

**Version:** 1.0  
**Date:** 2026-03-31  
**Source spec:** `project-navigator-spec.md` v1.1  
**Reference tokens:** `tercen-tokens.css`, `tokens.meta.json` v2.0.0  

---

## Summary

This report maps every UI element in the Project Navigator to its closest SDUI primitive. Gap types are classified as:

| Code | Meaning |
|------|---------|
| **COVERED** | An approved SDUI primitive exists and can be used directly |
| **EXTEND** | An approved primitive exists but needs a property or variant not currently defined |
| **NEW** | No existing SDUI primitive covers this element — a new primitive is needed |
| **COMPOSE** | Built from two or more existing primitives with no new primitive needed |

---

## Gap Table

| Element | SDUI Primitive | Gap Type | Notes |
|---------|----------------|----------|-------|
| **TOOLBAR** | | | |
| Toolbar container (48 px fixed height, surfaceContainerHigh bg) | `window.toolbarHeight` token + `surfaceContainerHigh` | COVERED | Token `window.toolbarHeight = 48` exists in `theme-export.json`. Background maps to `--color-surface-container-high`. |
| Upload button (primary, icon-only 32×32) | `button` / primary variant, sm size | COVERED | Primary button at `controlHeight.sm = 28px` — size close enough; Dart impl uses `toolbarButtonSize = 32`. Needs 32px size option. |
| Download button (ghost, icon-only 32×32, can be disabled) | `button` / ghost variant, sm size | EXTEND | Ghost button exists. Needs `icon-only` mode (no label, square aspect). Currently SDUI buttons always have a text label. |
| Refresh button (ghost, icon-only 32×32) | `button` / ghost variant, sm size | EXTEND | Same as Download. Icon-only square mode not defined in catalog. |
| Team button (ghost, icon-only 32×32, can be disabled) | `button` / ghost variant, sm size | EXTEND | Same gap. |
| Toolbar divider (1 px vertical, outlineVariant) | `outlineVariant` token + `lineWeight.subtle` | COMPOSE | No named divider primitive in catalog. Compose as a `Container(width: 1, color: outlineVariant)`. Recommend adding a `ToolbarDivider` primitive. |
| Type filter dropdown button (labeled, icon + text + chevron, 32 px height) | `button` / ghost variant — labeled | EXTEND | Labeled ghost button exists. Missing: trailing chevron, dropdown affordance. No catalog `Select` or `DropdownButton` primitive. |
| Type filter dropdown menu (All / File / Dataset / Workflow options with hover text) | — | NEW | No SDUI dropdown/menu primitive. Need `DropdownMenu` with `MenuItem` children (label, tooltip). |
| Text search input (flex-grow, 28 px height, placeholder, focus ring) | `textField` / sm size | EXTEND | `textField` exists. Missing: search-specific prefix icon slot (`fa-magnifying-glass`). Search inputs are conventionally distinct from form inputs. Recommend `SearchField` variant. |
| **BODY STATES** | | | |
| Loading state (centred spinner + "Loading projects..." text) | `LoadingState` pattern | COVERED | Pattern is established in Dart (`LoadingState` widget). SDUI needs a `loading` body-state template with `spinner` + `bodyMedium` text. |
| Empty state (centred icon + message + detail + action button) | `EmptyState` pattern | COVERED | Established pattern. Maps to: `icon(32px)` + `bodyMedium` + `bodySmall` + `button/secondary`. |
| Error state (centred error icon + message + detail + Retry button) | `ErrorState` pattern | COVERED | Established pattern. Maps to: `fa-circle-xmark(error)` + `bodyMedium(error)` + `bodySmall(onSurfaceDisabled)` + `button/danger`. |
| Active state layout (toolbar fixed top + tree fills remainder) | Column layout pattern | COVERED | Standard skeleton-window layout: `Column(toolbar, Expanded(treeView))`. |
| **TREE VIEW — ROWS** | | | |
| Team row (level 0, chevron + user/users icon + name + member count) | `ListTile` / tree variant | EXTEND | No `ListTile` in SDUI catalog. Tree rows need: indentation, chevron slot, icon slot, trailing badge slot. Recommend `TreeRow` primitive. |
| Project row (level 1, chevron + folder icon + name + version chip + git-status dot + public icon + github link) | `TreeRow` | NEW | Same as above. Project row has up to 4 trailing elements; no existing catalog primitive supports this layout. |
| Folder row (level 2+, chevron + folder icon + name) | `TreeRow` | NEW | Simpler than project row. Subset of `TreeRow`. |
| File row — generic (leaf, no chevron, file-lines icon + name) | `TreeRow` | NEW | Leaf variant of `TreeRow` (no chevron). |
| File row — ZIP (leaf, file-zipper icon + name) | `TreeRow` | NEW | Icon variant only. |
| File row — Image (leaf, image icon + name) | `TreeRow` | NEW | Icon variant only. |
| Dataset row (leaf, table icon + name) | `TreeRow` | NEW | Icon + colour differ from file. |
| Workflow row (leaf, diagram-project icon + name + workflow-status dot) | `TreeRow` | NEW | Has a trailing status dot. |
| Selected row state (primaryFixed bg + 3 px primary left border) | `table.rowSelectedBg` + `table.selectionBorderLeft` tokens | COVERED | Tokens exist (`primaryFixed`, `primary`, `selectionBorderWidth: 3`). They are table tokens — applicable here. No tree-specific selected-row tokens, but values are correct. |
| Hover row state (surfaceContainerLow bg) | `table.rowHoverBg` token | COVERED | Token `surfaceContainerLow` covers hover. |
| Indentation (per level, step = 16 px from spacing.md) | `spacing.md` token | COVERED | Indentation step = 16 px = `spacing.md`. |
| **STATUS INDICATORS** | | | |
| Git version chip (e.g. "v2.3", neutral badge, radius.sm) | `badge` / neutral variant | COVERED | `badge/neutral` maps to `surfaceContainer` bg + `onSurfaceMuted` text. Radius `radius.sm`. |
| Git-status dot — clean (7 px circle, success colour) | `status-dot` | EXTEND | No named `StatusDot` primitive. Compose as `Container(width:7, decoration: circle, color: success)`. Recommend formalising `StatusDot` with variants. |
| Git-status dot — modified | `status-dot` | EXTEND | Same. Warning colour variant. |
| Workflow status dot — idle | `status-dot` | EXTEND | onSurfaceMuted variant. |
| Workflow status dot — running | `status-dot` | EXTEND | info variant. |
| Workflow status dot — complete | `status-dot` | EXTEND | success variant. |
| Workflow status dot — error | `status-dot` | EXTEND | error variant. |
| Public project globe icon (`fa-globe`, info colour) | Icon + `info` colour token | COVERED | `fa-globe` + `--color-info`. Icon semantic mapping not in `tokens.meta.json` icons section — recommend adding `project.public = fa-globe`. |
| GitHub link icon (`fa-brands fa-github`, muted colour, external href) | Icon + `onSurfaceMuted` colour | COVERED | Colour token covered. `fa-brands` icons are not FontAwesome Solid — spec says FA 6 Solid only. **Gap: GitHub is a brand icon, not solid. No solid alternative exists for GitHub.** Recommend exempting brand icons for external links. |
| Member count text ("(3)", muted, bodySmall) | `bodySmall` + `onSurfaceMuted` | COVERED | Both tokens approved. |
| **UPLOAD** | | | |
| Drop target highlight (dashed primary outline + primaryFixed bg) | `primaryFixed` + `primary` border | COVERED | Both tokens approved. `primaryFixed` = `EFF6FF` (light). No catalog rule for dashed-border drop targets — recommend adding to patterns. |
| Upload progress bar (3 px track, primary fill, radius.full) | — | NEW | No `ProgressBar` / `LinearProgress` primitive in SDUI catalog. Needs: track colour (`surfaceContainerHigh`), fill colour (`primary`), height (3 px), radius (`radius.full`). |
| **TYPOGRAPHY** | | | |
| Node name text | `bodySmall` (12 px, 400 weight) | COVERED | `--text-body-small-size: 12px`. |
| Section header (UPPERCASE, 12 px, 600 weight, letter-spacing) | `sectionHeader` text style | COVERED | `text-section-header-*` tokens defined. |
| Badge label text (10 px, 500 weight) | `labelSmall` (12 px) | EXTEND | 10 px is below `labelSmall` (12 px). No 10 px label text style in tokens. Either use `labelSmall` and accept 12 px, or add a `micro` label variant. `micro` text style exists (8 px) — 10 px falls between `labelSmall` and `micro`. |
| **SPACING RULES AUDIT** | | | |
| Toolbar horizontal padding | `spacing.sm` (8 px) | COVERED | Dart impl uses `AppSpacing.sm`. |
| Toolbar button gap | `spacing.xs` (4 px) | COVERED | Dart impl uses `WindowConstants.toolbarGap`. |
| Toolbar button size (32×32) | `window.toolbarButtonSize = 32` | COVERED | Token exists in `theme-export.json`. |
| Tree row gap (4 px between icon elements) | `spacing.xs` | COVERED | |
| Progress bar indent (aligns with icon column ~52 px) | Composed from level indent + icon widths | COMPOSE | Not a token — derived from tree layout geometry. |

---

## New Primitives Recommended

| Primitive | Justification |
|-----------|--------------|
| `TreeRow` | Core building block for the navigator. Needs: indentation prop, chevron slot (optional), leading icon slot, name text, trailing slots (badges, dots, links). Leaf vs branch variants. |
| `StatusDot` | Reusable coloured status indicator dot. Variants: idle/neutral, running/info, complete/success, error/error, clean/success, modified/warning. Fixed 7–8 px size. |
| `ToolbarDivider` | Minimal vertical separator for toolbar button groups. 1 px, outlineVariant, 20 px tall. |
| `DropdownMenu` + `MenuItem` | Dropdown trigger + options list with hover tooltips. Needed for type filter. |
| `SearchField` | Text input with leading `fa-magnifying-glass` icon, clear button, and sm height (28 px). |
| `LinearProgress` | Inline upload progress bar. Props: value (0–1), colour (defaults to primary), height (3 px), radius (full). |

---

## Tokens Used — Approval Status

All colour tokens used in this mock are approved per `tokens.meta.json`:

| Token | Approved | Usage |
|-------|----------|-------|
| `primary` | Yes | Upload button bg, selected row border, progress fill, focus rings |
| `onPrimary` | Yes | Text on primary bg |
| `primaryContainer` | Yes | Button hover bg |
| `onPrimaryContainer` | Yes | Upload button hover bg |
| `primaryFixed` | Yes | Selected row bg, drop target bg |
| `tertiary` | Yes | Image node icon colour |
| `error` | Yes | Error state icon + text + button border |
| `errorContainer` | Yes | Error button hover |
| `surface` | Yes | Widget background |
| `onSurface` | Yes | Node name text |
| `onSurfaceVariant` | Yes | Toolbar button icons default |
| `surfaceContainerLow` | Yes | Row hover bg |
| `surfaceContainer` | Yes | Neutral badge bg, progress track |
| `surfaceContainerHigh` | Yes | Toolbar bg, spinner track |
| `outline` | Yes | Input border, filter dropdown border |
| `outlineVariant` | Yes | Toolbar divider, row separators, widget border |
| `onSurfaceMuted` | Yes | Muted text, chevrons, member counts, github icon, file icon |
| `onSurfaceDisabled` | Yes | Disabled button icons, body state detail text |
| `warning` | Yes | Project/folder icon colour, git-modified dot |
| `warningContainer` | Yes | (available for warning badges) |
| `success` | Yes | Workflow complete dot, git-clean dot |
| `successContainer` | Yes | (available for success badges) |
| `info` | Yes | Dataset icon colour, workflow-running dot, public icon |
| `infoContainer` | Yes | (available for info badges) |
| `link` | Yes | External link hover |

**Deleted tokens detected in Dart source:** `textDisabled`, `textMuted`, `borderSubtle`, `primaryBg`, `primaryDarker`, `primarySurface`. These appear in `empty_state.dart`, `error_state.dart`, `loading_state.dart`, and `window_toolbar.dart`. They must be migrated to approved replacements before Phase 3:

| Deleted token (Dart) | Approved replacement |
|----------------------|---------------------|
| `textDisabled` | `onSurfaceDisabled` |
| `textMuted` | `onSurfaceMuted` |
| `borderSubtle` | `outlineVariant` |
| `primaryBg` | `primaryFixed` |
| `primaryDarker` | `onPrimaryContainer` |
| `primarySurface` | `primaryContainer` |

---

## FileCategory Gaps

The Dart model defines `FileCategory` as `generic | zip | image` only. The spec (§7.4) calls for:

| Spec category | Dart model | Gap |
|---------------|-----------|-----|
| File — generic | `generic` | COVERED |
| File — FCS (science/lab icon) | no dedicated category | **MISSING** — FCS files render as generic. Need `fcs` category + `fa-flask` icon. |
| File — ZIP | `zip` | COVERED |
| File — Markdown / text | no dedicated category | **MISSING** — `.md` files render as generic. Need `markdown` category + `fa-file-lines` icon (already used for generic). Could share icon with different colour. |
| File — PNG / SVG / JPEG | `image` | COVERED |
| File — CSV | no dedicated category | **MISSING** — CSV files currently render as generic. Spec lists CSV as raw file but dataset implication is ambiguous. Recommend `csv` sub-type. |

---

## Open Spec Questions (from §20) — Impact on SDUI

| Question | SDUI Impact |
|----------|------------|
| Chat sessions in the tree | Adds `ChatNode` model + `ChatRow` tree row variant + 4th filter option |
| Multi-project focus | Affects `focusChanged` event payload — no direct SDUI primitive impact |
| Lazy load on expand | Adds per-node loading state to `TreeRow` — needs a `TreeRow` loading skeleton |
| Folder filter with type filter active | Logic change only — no new primitives |
