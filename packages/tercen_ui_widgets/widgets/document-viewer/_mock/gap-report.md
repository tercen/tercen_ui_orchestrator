# Document Editor — SDUI Primitive Mapping & Gap Report

**Date:** 2026-03-31
**Source:** Dart mock (`widgets/document-editor/lib/`)
**Token authority:** `tokens.meta.json` v2.0.0, `tercen-tokens.css`

---

## 1. Component Inventory

Every distinct visual primitive extracted from the Dart mock, mapped to SDUI primitives where they exist.

### 1.1 Tab Strip (`mock_tab_strip.dart`)

| Property | Dart value | Token / SDUI primitive | Status |
|----------|-----------|------------------------|--------|
| Strip height | 32px | `--tab-strip-height` (WindowConstants) | Mapped |
| Strip background | `surfaceElevated` (light) | `surfaceContainerHigh` | Mapped — old name deleted |
| Tab height | 28px | WindowConstants.tabHeight | Mapped |
| Tab max width | 220px | WindowConstants.tabMaxWidth | Mapped |
| Tab corner radius | 6px | `radius.sm` | Mapped |
| Focused tab bg | `surface` | `--color-surface` | Mapped |
| Focused tab weight | `FontWeight.w700` | `titleMedium.fontWeight` | Mapped |
| Inactive tab bg | transparent | — | Mapped |
| Inactive tab weight | `FontWeight.w400` | `bodyMedium.fontWeight` | Mapped |
| Tab type icon size | 8×8px, r=2px | WindowConstants.tabIconSize / tabIconRadius | Mapped |
| Tab font size | 11px | WindowConstants.tabFontSize | **Gap** — 11px is not in the text scale |
| Type colour (indigo) | `#6366F1` | Not in `approvedTypeColors` list | **Gap** — indigo not approved |
| Theme toggle icon size | 12px | — | Minor gap — falls between icon.xs(10) and icon.sm(12) |

### 1.2 Toolbar (`document_toolbar.dart`, `window_toolbar.dart`)

| Property | Dart value | Token / SDUI primitive | Status |
|----------|-----------|------------------------|--------|
| Toolbar height | 48px | `headerHeight` = `--toolbar-height` | Mapped |
| Button size | 32×32px | WindowConstants.toolbarButtonSize | Mapped — matches `controlHeight.sm` + square |
| Button icon size | 16px | `icon-size-sm` (16px) | Mapped |
| Button radius | 8px | `radius.md` | Mapped |
| Button gap | 8px | `spacing.sm` | Mapped |
| Toolbar padding h | 8px | `spacing.sm` | Mapped |
| Separator height | 24px | — | **Gap** — no explicit separator-height token |
| Separator colour | `borderSubtle` → deleted | `outlineVariant` | Mapped — old name deleted |
| Narrow threshold | 680px | — | **Gap** — breakpoint not in tokens |

### 1.3 Save Button

| State | Dart behaviour | SDUI component.button mapping | Status |
|-------|---------------|-------------------------------|--------|
| Clean (not dirty) | Transparent bg, primary border/icon | `button.secondary` | Mapped |
| Dirty (unsaved) | Primary filled, white icon | `button.primary` (icon-only) | Mapped |
| Saving | Primary spinner replaces icon | — custom spinner state | **Gap** — no spinner-inside-button primitive |
| Disabled | neutral border + icon | `button.secondary` disabled | Mapped |

### 1.4 Mode Toggle (segmented button)

| Property | Dart value | SDUI primitive | Status |
|----------|-----------|----------------|--------|
| Container height | 32px | matches toolbar button size | Mapped |
| Container border | `border` → deleted | `outline` | Mapped — old name deleted |
| Container radius | 8px | `radius.md` | Mapped |
| Segment width | 44px (14px h-pad × 2 + icon) | — | **Gap** — segmented button not in catalog |
| Selected bg | `primary` | `--color-primary` | Mapped |
| Selected fg | white (light) / black (dark) | `onPrimary` | Mapped |
| Unselected bg | transparent + hover `primarySurface` → deleted | `primaryContainer` | Mapped — old name deleted |
| Icons | `fa-code`, `fa-book` | FontAwesome 6 Solid | Mapped |

### 1.5 Formatting Buttons (ghost style)

| Property | Dart value | SDUI primitive | Status |
|----------|-----------|----------------|--------|
| Style | No border, transparent bg | `button.ghost` | Mapped |
| Active bg | `primarySurface` → deleted | `primaryContainer` | Mapped — old name deleted |
| Hover bg | `primarySurface` → deleted | `primaryContainer` | Mapped — old name deleted |
| Icon colour | `primary` | `--color-primary` | Mapped |
| Disabled icon | `neutral400` → old token | `onSurfaceDisabled` | Mapped — old name deleted |
| Active: H2 heading | `primarySurface` bg | `primaryContainer` | Mapped |

### 1.6 Body States

#### Loading state
| Property | Dart value | SDUI primitive | Status |
|----------|-----------|----------------|--------|
| Spinner size | 28×28px | WindowConstants.spinnerSize | Mapped |
| Spinner stroke | 3px | WindowConstants.spinnerStrokeWidth | **Gap** — no spinner-stroke token |
| Spinner colour | `primary` | `--color-primary` | Mapped |
| Track colour | `borderSubtle` → deleted | `outlineVariant` | Mapped — old name deleted |
| Message style | `AppTextStyles.body` | `bodyMedium` (14px/400) | Mapped |
| Message colour | `textMuted` → deleted | `onSurfaceMuted` | Mapped — old name deleted |

#### Error state
| Property | Dart value | SDUI primitive | Status |
|----------|-----------|----------------|--------|
| Icon | `Icons.error_outline` (Material) | `fa-circle-xmark` (FA6 Solid) | **Gap** — Dart uses Material icon; SDUI spec requires FA6 |
| Icon size | 32px | `icon-size-lg` (32px) | Mapped |
| Icon colour | `error` | `--color-error` | Mapped |
| Title colour | `error` | `--color-error` | Mapped |
| Detail style | `bodySmall` | `bodySmall` (12px/400) | Mapped |
| Detail colour | `textDisabled` → deleted | `onSurfaceDisabled` | Mapped — old name deleted |
| Max width | 280px | WindowConstants.bodyStateMaxWidth | Mapped |
| Retry button | `OutlinedButton` with error colour | `button.danger` | Mapped |
| Button radius | `radiusMd` (8px) | `radius.md` | Mapped |

#### Active state — banners
| Property | Dart value | SDUI primitive | Status |
|----------|-----------|----------------|--------|
| Success banner bg | `successLight` → deleted | `successContainer` | Mapped — old name deleted |
| Success fg | `success` | `--color-success` | Mapped |
| Success icon | `FontAwesomeIcons.circleCheck` | `fa-circle-check` | Mapped |
| Error banner bg | `#FEE2E2` hardcoded | `errorContainer` | **Gap** — hardcoded hex in Dart source |
| Error banner fg | `#B91C1C` hardcoded | `error` | **Gap** — hardcoded hex in Dart source |
| Error icon | `Icons.error_outline` (Material) | `fa-circle-xmark` | **Gap** — Material icon in banner too |
| Banner padding | `py=6 px=16` | custom (not in spacing scale) | Minor gap — 6px not in spacing scale |
| Banner icon size | 14px | — | Minor gap — between icon.xs(10) and icon.sm(16) |
| Banner text size | 12px | `bodySmall` / `labelSmall` | Mapped |

### 1.7 Source Editor

| Property | Dart value | SDUI primitive | Status |
|----------|-----------|----------------|--------|
| Background | `surface` | `--color-surface` | Mapped |
| Text colour | `textPrimary` → deleted | `onSurface` | Mapped — old name deleted |
| Font family | `monospace` (system) | — | **Gap** — no monospace font token |
| Font size | 14px | `bodyMedium` size | Mapped |
| Line height | 1.6 | — | **Gap** — no line-height token |
| Padding | 16px all | `spacing.md` | Mapped |
| Tab key | 2-space indent | — | Behaviour only, not a visual token |

### 1.8 Rendered Editor (Markdown preview)

| Property | Dart value | SDUI primitive | Status |
|----------|-----------|----------------|--------|
| Background | `surface` | `--color-surface` | Mapped |
| H1 style | `AppTextStyles.h1` (24px/600) | `headlineLarge` | Mapped |
| H2 style | `AppTextStyles.h2` (20px/600) | `headlineMedium` | Mapped |
| H3 style | `AppTextStyles.h3` (16px/600) | `headlineSmall` | Mapped |
| Body text | `AppTextStyles.body` (14px/400) | `bodyMedium` | Mapped |
| Link colour | `link` / `AppColors.link` | `--color-link` | Mapped |
| Code inline bg | `#F1F5F9` hardcoded | `surfaceContainer` | **Gap** — hardcoded hex |
| Code inline colour | `textPrimary` → deleted | `onSurface` | Mapped |
| Code block bg | `panelBackground` → deleted | `surfaceContainerLow` | Mapped — old name deleted |
| Code block border | `borderSubtle` → deleted | `outlineVariant` | Mapped — old name deleted |
| Code block radius | `radiusSm` (4px) | `radius.sm` | Mapped |
| Blockquote border | `primary` (3px left) | `--color-primary` | Mapped |
| Table header bg | `panelBackground` → deleted | `surfaceContainerLow` | Mapped — old name deleted |
| Table border | `borderSubtle` → deleted | `outlineVariant` | Mapped — old name deleted |
| Strikethrough colour | `textSecondary` → deleted | `onSurfaceVariant` | Mapped — old name deleted |
| HR border | `borderSubtle` → deleted | `outlineVariant` | Mapped — old name deleted |
| Image border | `borderSubtle` → deleted | `outlineVariant` | Mapped — old name deleted |
| Image radius | `radiusSm` (4px) | `radius.sm` | Mapped |

### 1.9 Window Shell / Background

| Property | Dart value | SDUI primitive | Status |
|----------|-----------|----------------|--------|
| Light bg | `Colors.white` hardcoded | `surface` | **Gap** — hardcoded; should be token |
| Dark bg | `#181A20` hardcoded | `surface` (dark = `#111827`) | **Gap** — custom dark colour not in tokens |

---

## 2. Deleted Token Usage Summary

The Dart source references 19 tokens that are listed as **deleted** in `tokens.meta.json`. Each must be replaced before SDUI catalog.json authoring.

| Deleted token (Dart) | Replacement token | Files affected |
|----------------------|-------------------|----------------|
| `primarySurface` | `primaryContainer` | document_toolbar.dart, window_toolbar.dart |
| `primaryDarker` | `onPrimaryContainer` | window_toolbar.dart |
| `primaryBg` | `primaryFixed` | (referenced in app_colors.dart) |
| `border` | `outline` | mock_tab_strip.dart, document_toolbar.dart |
| `borderSubtle` | `outlineVariant` | rendered_editor.dart, loading_state.dart, window_shell.dart |
| `textPrimary` | `onSurface` | source_editor.dart, rendered_editor.dart, loading_state.dart, mock_tab_strip.dart |
| `textSecondary` | `onSurfaceVariant` | rendered_editor.dart, mock_tab_strip.dart |
| `textMuted` | `onSurfaceMuted` | loading_state.dart |
| `textDisabled` | `onSurfaceDisabled` | error_state.dart |
| `successLight` | `successContainer` | active_state.dart |
| `panelBackground` | `surfaceContainerLow` | rendered_editor.dart |
| `surfaceElevated` | `surfaceContainerHigh` | mock_tab_strip.dart |
| `neutral400` | `onSurfaceDisabled` | window_toolbar.dart, document_toolbar.dart |
| `neutral300` | `outline` | window_toolbar.dart |
| `neutral600` | `onSurfaceMuted` | window_toolbar.dart, document_toolbar.dart |
| `neutral700` | `surfaceContainer` | window_toolbar.dart (dark hover) |
| `neutral200` | `surfaceContainerHigh` | mock_tab_strip.dart (light strip bg) |
| `errorLight` | `errorContainer` | (implicit in active_state.dart hardcoded hex) |

---

## 3. Hardcoded Values (Not Using Tokens)

These must be replaced with approved tokens before SDUI authoring.

| Location | Hardcoded value | Correct token |
|----------|----------------|---------------|
| `active_state.dart` line 80 | `Color(0xFF3B1111)` (dark error banner bg) | `errorContainer` dark |
| `active_state.dart` line 81 | `Color(0xFFFEE2E2)` (light error banner bg) | `errorContainer` light |
| `active_state.dart` line 82 | `Color(0xFFF87171)` (dark error fg) | `error` dark |
| `active_state.dart` line 83 | `Color(0xFFB91C1C)` (light error fg) | `error` light |
| `rendered_editor.dart` line 65 | `Color(0xFFF1F5F9)` (inline code bg) | `surfaceContainer` |
| `home_screen.dart` line 88 | `Color(0xFF181A20)` (dark scaffold bg) | `surface` dark |
| `home_screen.dart` line 101 | `Color(0xFF181A20)` (dark container) | `surface` dark |
| `window_shell.dart` line 33 | `Color(0xFF181A20)` (dark bg) | `surface` dark |
| `active_state.dart` line 46 | `Color(0xFF052E16)` (dark success bg) | `successContainer` dark |
| `main.dart` line 39 | `Color(0xFF6366F1)` (type colour) | See Gap #1 below |

---

## 4. Structured Gap List

### Gap 1 — Indigo type colour not approved
- **Token:** `#6366F1` (typeColor in `WindowIdentity`, `MockTabStrip`)
- **Issue:** Not listed in `tokens.meta.json` → `approvedTypeColors` array
- **Impact:** Tab type icon colour is non-compliant
- **Resolution options:** (a) Add `#6366F1` to `approvedTypeColors`, or (b) remap document-editor to nearest approved colour `#0000FF`

### Gap 2 — Tab font size 11px not in text scale
- **Token:** `WindowConstants.tabFontSize = 11.0`
- **Issue:** Text scale provides 12px (bodySmall/labelSmall) as smallest size; 11px is a one-off
- **Impact:** Tab labels use non-standard size
- **Resolution:** Map to `labelSmall` (12px, weight 500) or add a `micro` style (8px exists, 11px does not)

### Gap 3 — Segmented button not in SDUI catalog
- **Component:** `_ModeToggle` in `document_toolbar.dart`
- **Issue:** No `segmentedButton` primitive in `tokens.meta.json` → components
- **Impact:** Cannot express in catalog.json without a new primitive
- **Resolution:** Add `segmentedButton` primitive to components spec, or render as two adjacent `button.ghost` with shared border

### Gap 4 — Monospace font not tokenised
- **Property:** Source editor + code blocks use `fontFamily: 'monospace'` (system) / `'Fira Code'`
- **Issue:** No `--font-family-mono` token in `tercen-tokens.css`
- **Impact:** Cannot guarantee consistent rendering across platforms
- **Resolution:** Add `--font-family-mono: 'Fira Code', 'Cascadia Code', monospace` to tokens

### Gap 5 — Line-height 1.6 not in tokens
- **Property:** Source editor (`height: 1.6`), plain text preview (`height: 1.6`)
- **Issue:** Token file defines line-height in text styles (1.25 headings, 1.5 body) but not 1.6
- **Impact:** Editor comfort spacing is ad-hoc
- **Resolution:** Accept `bodyMedium` line-height of 1.5, or add `--text-editor-line-height: 1.6` as a one-off

### Gap 6 — Banner padding 6px not in spacing scale
- **Property:** Banners (`py=6px`)
- **Issue:** Spacing scale is `xs=4, sm=8` — 6px falls between them
- **Impact:** Minor visual inconsistency with other component spacing
- **Resolution:** Standardise to `spacing.sm` (8px) or `spacing.xs` (4px)

### Gap 7 — Spinner stroke width not tokenised
- **Property:** `WindowConstants.spinnerStrokeWidth = 3.0`
- **Issue:** No spinner-specific token; `lineWeight` scale tops out at `emphasis=2px`
- **Impact:** Cannot express spinner stroke in catalog.json
- **Resolution:** Add `--spinner-stroke-width: 3px` to tokens, or accept `lineWeight.emphasis` (2px) as close enough

### Gap 8 — Material icon in error banner and error state
- **Property:** `Icons.error_outline` (Material) used in `_SaveErrorBanner` and `ErrorState`
- **Issue:** SDUI spec requires FontAwesome 6 Solid for all generic icons
- **Resolution:** Replace with `fa-circle-xmark` (already in tokens.meta.json semantic mapping)

### Gap 9 — Dark background #181A20 is off-token
- **Property:** Dark scaffold and widget background `Color(0xFF181A20)`
- **Issue:** Dark `surface` token is `#111827`; `#181A20` is an intermediate shade with no approval
- **Impact:** Dark theme background is custom, not from token palette
- **Resolution:** Use `surface` dark (`#111827`) or `surfaceContainerLow` dark (`#111827` — same value)

### Gap 10 — No empty state defined
- **Property:** `ContentState.empty` falls through to `LoadingState` in `window_body.dart`
- **Issue:** By design ("document editor only opens with a target document") but the empty body is not spec'd
- **Impact:** If ever reached, shows a loading spinner with no affordance
- **Resolution:** Add a formal empty state spec, or document the intentional omission

### Gap 11 — Narrow breakpoint 680px not in token grid
- **Property:** `DocumentToolbar._collapseThreshold = 680.0`
- **Issue:** Token grid defines sm=400, md=600, lg=900 — 680px is between md and lg
- **Impact:** Collapse behaviour is inconsistent with standard breakpoints
- **Resolution:** Align to `md` (600px) or `lg` (900px), or add a `--toolbar-collapse-width` widget-specific token

### Gap 12 — Banner icon size 14px not standard
- **Property:** Banner icons rendered at 14px
- **Issue:** FA icon sizes in tokens: xs=10, sm=12 (but spec says sm=16), md=24, lg=32
- **Resolution:** Use 16px (`icon-size-sm`) for banners

---

## 5. Token Replacement Cheat-Sheet (for catalog.json authoring)

```
# Colour tokens — use these CSS variable names
onSurface           → var(--color-on-surface)
onSurfaceVariant    → var(--color-on-surface-variant)
onSurfaceMuted      → var(--color-on-surface-muted)
onSurfaceDisabled   → var(--color-on-surface-disabled)
surface             → var(--color-surface)
surfaceContainerLow → var(--color-surface-container-low)
surfaceContainerHigh→ var(--color-surface-container-high)
primary             → var(--color-primary)
onPrimary           → var(--color-on-primary)
primaryContainer    → var(--color-primary-container)
onPrimaryContainer  → var(--color-on-primary-container)
outline             → var(--color-outline)
outlineVariant      → var(--color-outline-variant)
error               → var(--color-error)
errorContainer      → var(--color-error-container)
success             → var(--color-success)
successContainer    → var(--color-success-container)
link                → var(--color-link)

# Spacing
spacing.xs → 4px    spacing.sm → 8px    spacing.md → 16px
spacing.lg → 24px   spacing.xl → 32px   spacing.xxl → 48px

# Radius
radius.sm → 4px     radius.md → 8px     radius.lg → 12px

# Icons (FontAwesome 6 Solid)
fa-floppy-disk      save
fa-code             source/edit mode segment
fa-book             rendered/view mode segment
fa-pen-to-square    format popover (narrow)
fa-bold / fa-italic / fa-strikethrough    text format
fa-heading          heading level prefix
fa-list-ul / fa-list-ol    lists
fa-link / fa-image / fa-code    insert
fa-minus            horizontal rule
fa-print            print
fa-circle-check     success banner
fa-circle-xmark     error banner + error state
fa-rotate           retry
fa-spinner          saving in progress
fa-moon / fa-sun    theme toggle (icon = target state)
```

---

## 6. Components Not Yet in SDUI Catalog

| Component | Description | Dart source |
|-----------|-------------|-------------|
| `segmentedButton` | 2-segment icon toggle with shared border and active fill | `_ModeToggle` in document_toolbar.dart |
| `sourceEditor` | Monospace textarea, no border, Tab→2-spaces, full-width/height | `source_editor.dart` |
| `renderedEditor` | Read-only markdown preview with link/image handling | `rendered_editor.dart` |
| `inlineBanner` | Full-width status banner (success/error) above body content | `_SaveSuccessBanner`, `_SaveErrorBanner` in active_state.dart |
| `toolbarSeparator` | 1px × 24px vertical divider between button groups | `_ToolbarSeparator` in document_toolbar.dart |
| `formatPopover` | Modal overlay with all formatting buttons (narrow toolbar) | `format_popover.dart` |
| `linkDialog` | Modal dialog: URL + display text fields + Insert button | `link_dialog.dart` |
| `imageDialog` | Modal dialog: URL + size selector (Small/Medium/Large) + Insert button | `image_dialog.dart` |

---

*Generated by migration tooling — 2026-03-31*
