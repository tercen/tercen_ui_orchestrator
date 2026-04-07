# PNG Viewer — SDUI Primitive Mapping & Gap Report

Extracted from Dart mock on 2026-03-31. No spec file existed; all design decisions
are reverse-engineered from the Flutter source.

---

## 1  Widget Structure

```
HomeScreen
├── MockTabStrip              [dev harness — not shipped]
├── _PngViewerToolbar         [48px, 3-zone Row]
│   ├── Zone LEFT:  6 × _ToolToggleButton   (drawing tools)
│   ├── Spacer
│   ├── Zone CENTRE: 3 × _ToolToggleButton  (Clear All, Send to Chat, Save to Project)
│   ├── Spacer
│   └── Zone RIGHT:  3 × _ToolToggleButton  (Zoom In, Zoom Out, Fit to Window)
├── Divider                   [1px, outline-variant, 50% opacity]
└── WindowShell (showToolbar: false)
    └── WindowBody
        ├── ContentState.loading → LoadingState
        ├── ContentState.empty   → EmptyState
        ├── ContentState.active  → ActiveState
        └── ContentState.error   → ErrorState
```

---

## 2  Token Mapping — All Approved Colour Usages

| Component | Dart source value | Approved token | CSS variable |
|---|---|---|---|
| Widget surface | `Colors.white` / `Color(0xFF181A20)` | `surface` | `--color-surface` |
| Canvas background (light) | `Color(0xFFF3F4F6)` | `surfaceContainer` | `--color-surface-container` |
| Canvas background (dark) | `Color(0xFF0A0A0A)` | `surface` (dark) | `--color-surface` |
| Toolbar + body background | `Colors.white` / `Color(0xFF181A20)` | `surface` | `--color-surface` |
| Toolbar divider | `Theme.dividerColor` at 50% | `outlineVariant` | `--color-outline-variant` |
| Tab strip background | `Color(0xFF181A20)` / neutral | `surfaceContainerHigh` | `--color-surface-container-high` |
| Tab active border | `AppColors.primary` | `primary` | `--color-primary` |
| Tab type dot | `Color(0xFF66FF7F)` | **unresolved** — see Gap §4.1 | — |
| Tab label text | neutral900 / neutral50 | `onSurface` | `--color-on-surface` |
| Spinner track | `AppColors.borderSubtle` → deleted | `outlineVariant` | `--color-outline-variant` |
| Spinner indicator | `AppColors.primary` | `primary` | `--color-primary` |
| Spinner label text | `AppColors.textMuted` → deleted | `onSurfaceMuted` | `--color-on-surface-muted` |
| Empty icon | `AppColors.textDisabled` → deleted | `onSurfaceDisabled` | `--color-on-surface-disabled` |
| Empty message text | `AppColors.textMuted` → deleted | `onSurfaceMuted` | `--color-on-surface-muted` |
| Empty detail text | `AppColors.textDisabled` → deleted | `onSurfaceDisabled` | `--color-on-surface-disabled` |
| Error icon | `AppColors.error` | `error` | `--color-error` |
| Error message text | `AppColors.error` | `error` | `--color-error` |
| Error detail text | `AppColors.textDisabled` → deleted | `onSurfaceDisabled` | `--color-on-surface-disabled` |
| Error retry border/text | `AppColors.error` | `error` | `--color-error` |
| Error retry hover bg | `AppColors.errorLight` → deleted | `errorContainer` | `--color-error-container` |
| Toolbar btn — secondary border | `AppColors.primary` | `primary` | `--color-primary` |
| Toolbar btn — secondary icon | `AppColors.primary` | `primary` | `--color-primary` |
| Toolbar btn — secondary hover | `AppColors.primarySurface` → deleted | `primaryContainer` | `--color-primary-container` |
| Toolbar btn — active fill | `AppColors.primary` | `primary` | `--color-primary` |
| Toolbar btn — active icon | `Colors.white` | `onPrimary` | `--color-on-primary` |
| Toolbar btn — active hover fill | `AppColors.primaryDarker` → deleted | `onPrimaryContainer` | `--color-on-primary-container` |
| Toolbar btn — disabled border | `AppColors.neutral300` → deleted | `outline` | `--color-outline` |
| Toolbar btn — disabled icon | `AppColors.neutral400` → deleted | `onSurfaceDisabled` | `--color-on-surface-disabled` |
| Annotation stroke | `Color(0xFFFF5722)` | **unresolved** — see Gap §4.2 | — |
| Annotation fill | `Color(0x33FF5722)` | **unresolved** — see Gap §4.2 | — |
| Annotation moving stroke | `Color(0xFF2196F3)` | **unresolved** — see Gap §4.2 | — |
| Annotation text inline input | `Color(0xFFFF5722)` | **unresolved** — see Gap §4.2 | — |

---

## 3  Token Mapping — Typography

| Style name | Dart | Approved token |
|---|---|---|
| Spinner label | `AppTextStyles.body` (14px/400/1.5) | `--text-body-medium-*` |
| Empty primary message | `AppTextStyles.body` (14px/400/1.5) | `--text-body-medium-*` |
| Empty detail text | `AppTextStyles.bodySmall` (12px/400/1.5) | `--text-body-small-*` |
| Error primary message | `AppTextStyles.body` (14px/400/1.5) | `--text-body-medium-*` |
| Error detail text | `AppTextStyles.bodySmall` (12px/400/1.5) | `--text-body-small-*` |
| Button labels | `AppTextStyles.labelSmall` (12px/500/1.5) | `--text-label-small-*` |
| Annotation text label | `TextStyle(fontSize:16,weight:w600)` | **unresolved** — see Gap §4.3 |
| Zoom badge | 10px | **unresolved** — see Gap §4.3 |

---

## 4  Gap Register

### 4.1  Tab type-colour dot (#66FF7F)

| Field | Value |
|---|---|
| Dart source | `WindowIdentity.typeColor = Color(0xFF66FF7F)` |
| Usage | 8×8px rounded square in mock tab strip |
| Problem | `#66FF7F` is a per-type brand colour, not a design-system token |
| Recommended resolution | Introduce a `visualizationTypeColor` token under a `typeColors` namespace, or inject it via SDUI `typeColor` property on the `mockTabStrip` primitive. Not a blocker for widget implementation. |

### 4.2  Annotation colours (#FF5722, #2196F3)

| Field | Value |
|---|---|
| Dart sources | `Color(0xFFFF5722)` stroke/fill/text; `Color(0xFF2196F3)` moving-highlight |
| Usage | All 6 annotation types drawn by `_AnnotationPainter` on the image canvas |
| Problem | Neither value maps to any approved token. These are hardcoded in Dart. |
| Recommended resolution | Add two annotation-specific tokens to the design system: `annotationStroke` (`#FF5722` / dark: same) and `annotationHighlight` (`#2196F3` / dark: same). These are domain-specific enough to warrant named tokens rather than repurposing `error` or `info`. |
| Interim | Use CSS custom properties `--annotation-stroke` and `--annotation-moving-stroke` in HTML mock (already done in styled.html). |

### 4.3  Non-token typography values

| Usage | Dart value | Gap |
|---|---|---|
| Annotation text labels | 16px / w600 | No matching token. `--text-headline-small-*` is 16px/600 but is a heading style. Consider adding `--text-annotation-size: 16px; --text-annotation-weight: 600` or reuse `headlineSmall`. |
| Zoom badge | 10px | No token. Below `--text-body-small-size` (12px). Consider `--text-micro-size: 8px` is too small; this is a gap. |
| Tab font size | 11px | No token. `WindowConstants.tabFontSize = 11px` has no CSS counterpart. |

### 4.4  Deleted tokens used in Dart source

The following Dart colour names are referenced in the widget but have been deleted from the design system. The HTML mock uses their approved replacements (shown above in §2).

| Deleted Dart token | Replacement |
|---|---|
| `AppColors.textMuted` | `onSurfaceMuted` |
| `AppColors.textDisabled` | `onSurfaceDisabled` |
| `AppColors.borderSubtle` | `outlineVariant` |
| `AppColors.primarySurface` | `primaryContainer` |
| `AppColors.primaryDarker` | `onPrimaryContainer` |
| `AppColors.primaryBg` | `primaryFixed` |
| `AppColors.errorLight` | `errorContainer` |
| `AppColors.neutral300` | `outline` |
| `AppColors.neutral400` | `onSurfaceDisabled` |
| `AppColors.surfaceElevated` | `surfaceContainerHigh` |

**Action required:** The Dart source files for this widget should be updated to use the current approved token names. This is a Dart-side refactor, not a blocking SDUI issue.

### 4.5  SDUI Primitive coverage

| UI element | Nearest SDUI primitive | Notes |
|---|---|---|
| Toolbar (48px, 3-zone) | `WindowToolbar` | Custom 3-zone layout extends WindowToolbar — needs `trailingLeading` slot or a new `PngViewerToolbar` primitive |
| Toggle button (on/off) | `ToolbarAction` via `WindowToolbar` | `isPrimary` flag maps to active state; SDUI needs a `isToggled` boolean |
| Loading state | `LoadingState` | Direct 1:1 mapping |
| Empty state | `EmptyState` | Direct 1:1. `actionLabel`/`onAction` wired as null in this widget — confirm no action button needed |
| Error state | `ErrorState` | Direct 1:1. `onRetry` → `provider.retryLoad()` |
| Active canvas | **No current SDUI primitive** | Pannable/zoomable canvas with annotation overlay is entirely bespoke. Needs new `ImageCanvas` SDUI component. |
| Annotation painter | **No current SDUI primitive** | 6 tool types, custom `CustomPainter`. Canvas interaction (gestures, hit-test, rubber-band) is pure Dart logic. |
| Send to Chat | EventBus `visualization.annotations.send` | SDUI event binding needed |
| Load Image | EventBus `visualization.{windowId}.loadImage` | SDUI event subscription needed |

---

## 5  Spacing & Dimension Tokens (all resolved)

| Dart constant | Value | Token |
|---|---|---|
| `AppSpacing.xs` | 4px | `--spacing-xs` |
| `AppSpacing.sm` | 8px | `--spacing-sm` |
| `AppSpacing.md` | 16px | `--spacing-md` |
| `AppSpacing.lg` | 24px | `--spacing-lg` |
| `AppSpacing.radiusMd` | 8px | `--radius-md` |
| `AppLineWeights.lineStandard` | 1.5px | `--line-weight-standard` |
| `AppLineWeights.lineSubtle` | 1px | `--line-weight-subtle` |
| `AppLineWeights.lineEmphasis` | 2px | `--line-weight-emphasis` |
| `AppLineWeights.vizData` | 2px | `--line-weight-viz-data` |
| `WindowConstants.toolbarHeight` | 48px | `--spacing-xxl` (same value) |
| `WindowConstants.toolbarButtonSize` | 32px | no token — fixed px value |
| `WindowConstants.toolbarButtonIconSize` | 16px | `--icon-size-sm` |
| `WindowConstants.toolbarButtonRadius` | 8px | `--radius-md` |
| `WindowConstants.toolbarGap` | 8px | `--spacing-sm` |
| `WindowConstants.spinnerSize` | 28px | `--control-height-sm` (same value) |
| `WindowConstants.spinnerStrokeWidth` | 3px | no token |
| `WindowConstants.bodyStateIconSize` | 32px | `--icon-size-lg` |
| `WindowConstants.bodyStateMaxWidth` | 280px | no token |
| `WindowConstants.toolbarButtonSize` | 32px | no token |

---

## 6  Summary

| Category | Count | Status |
|---|---|---|
| Colour tokens fully resolved | 26 | Ready |
| Colour tokens needing new additions | 3 (tab dot, annotation stroke, annotation highlight) | Gap |
| Deleted Dart tokens needing code update | 10 | Tech debt |
| Typography tokens resolved | 5 | Ready |
| Typography gaps | 3 (annotation text, zoom badge, tab font) | Gap |
| SDUI primitives with direct mapping | 3 (Loading, Empty, Error states) | Ready |
| SDUI primitives needing extension | 2 (Toolbar toggle, EmptyState no-action) | Minor gap |
| SDUI primitives with no current equivalent | 2 (ImageCanvas, AnnotationPainter) | Needs design |
