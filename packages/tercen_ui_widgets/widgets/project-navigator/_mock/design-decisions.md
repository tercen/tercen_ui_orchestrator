# Design Decisions — Project Navigator

**Generated:** 2026-04-01
**Mock:** _mock/styled.html
**Spec:** project-navigator-spec.md

## Authority

This document records approved design decisions from mock refinement.
Where a decision conflicts with the functional spec, **this document wins**.
The catalog-integrator (Phase 4) MUST read this document before the spec.

---

## Decisions

### Removed: Team member counts

**Spec says:** Section 7.5 — Team nodes display member count in parentheses, muted text, e.g. `MartinLibrary (3)`
**Mock implements:** No member counts shown on team nodes.
**Reason:** Refined during mock iteration — keeps the tree clean.
**Binding:** YES — do NOT add member counts in catalog.json

---

### Removed: Refresh button in toolbar

**Spec says:** Section 6.1 — Refresh button (standard, always active) re-fetches tree data.
**Mock implements:** No refresh button in toolbar. Only Upload, Download, Team, Filter, Search.
**Reason:** Refined during mock iteration — refresh handled via EventBus `refreshTree` event from LLM/frame, not user-initiated.
**Binding:** YES — do NOT add a refresh button

---

### Removed: Upload drop zone / drag-and-drop visual

**Spec says:** Section 8 — Drop feedback: highlight target row with tinted primary background and dashed border. Drag from desktop supported.
**Mock implements:** Upload via toolbar button only, which triggers OS native file picker. No drag-and-drop visual, no drop zone styling.
**Reason:** Refined during mock iteration — simpler UX, avoids complex drag-and-drop implementation.
**Binding:** YES — upload is button-triggered only, no drop zone

---

### Removed: Upload progress bar

**Spec says:** Section 8 — Inline progress bar below the target node in primary accent colour.
**Mock implements:** No progress bar. Upload emits `navigator.contentChanged` on completion.
**Reason:** Refined during mock iteration — progress feedback deferred to toast notifications.
**Binding:** YES — no inline progress bar in catalog.json

---

### Removed: Workflow status dots

**Spec says:** Section 7.5 — Workflow nodes show small coloured dot: idle=neutral, running=info, complete=success, error=error.
**Mock implements:** No workflow status dots.
**Reason:** Refined during mock iteration — status monitoring belongs to Workflow Viewer (Window 3), not the navigator tree.
**Binding:** YES — do NOT add workflow status dots

---

### Removed: Git status dot on projects

**Spec says:** Section 7.5 — Project nodes show git status dot: clean=success, modified=warning.
**Mock implements:** Git chip (GitHub icon + version tag) and public globe icon only. No git status dot.
**Reason:** Refined during mock iteration — the version chip is sufficient. Detailed git status belongs in project detail views.
**Binding:** YES — git chip with version only, no status dot

---

### Removed: GitHub external link icon

**Spec says:** Section 7.5 — Small external-link icon on git-backed projects, opens browser.
**Mock implements:** GitHub icon is part of the git version chip. No separate external-link icon.
**Reason:** Refined during mock iteration — the chip itself serves as the link indicator.
**Binding:** YES — GitHub icon is inside the version chip, not a separate element

---

### Removed: Public badge as globe icon on projects

**Spec says:** Section 7.5 — Small globe/public icon in info colour.
**Mock implements:** Globe icon present but uses `onSurfaceMuted` colour, not info colour.
**Reason:** Refined during mock iteration — info colour was too prominent. Muted is more appropriate for a status indicator.
**Binding:** YES — public globe uses `onSurfaceMuted`

---

### Changed: Type filter dropdown — icon-only items

**Spec says:** Section 6.2 — Dropdown with text labels: "All", "File", "Data Set", "Workflow" with hover text descriptions.
**Mock implements:** Narrow popup with icon-only items (no text labels). "All" shows text, others show their type icon. Active item highlighted in primary colour. Inactive items use their tree-matching colours (file=onSurfaceVariant, dataset=warning, workflow=info).
**Reason:** Refined during mock iteration — compact dropdown fits the toolbar better.
**Binding:** YES — use PopupMenu primitive with icon-only items

---

### Changed: Type icons — mixed solid and regular

**Spec says:** Section 7.4 — Icons by type with colour meanings, no specification of solid vs regular weight.
**Mock implements:** Specific icon weight per node type:
- Team: `fa-solid fa-user-group` (solid) — colour: `primary`
- Project: `fa-solid fa-folder` (solid) — colour: `primary`
- Sub-folder: `fa-regular fa-folder-open` (regular/line) — colour: `onPrimaryContainer`
- File (generic): `fa-regular fa-file` (regular/line) — colour: `onSurfaceVariant`
- File (zip): `fa-regular fa-file-zipper` (regular/line) — colour: `onSurfaceVariant`
- File (image): `fa-regular fa-image` (regular/line) — colour: `onSurfaceVariant`
- Dataset: `fa-solid fa-table` (solid) — colour: `warning`
- Workflow: `fa-solid fa-sitemap` (solid) — colour: `info`
**Reason:** Solid for structural/primary nodes (team, project, workflow, dataset), regular/line for content nodes (files, sub-folders). Sub-folders use `onPrimaryContainer` (darker navy) to distinguish from project folders (`primary`).
**Binding:** YES — use these exact icons and colours

---

### Changed: Sub-folder colour

**Spec says:** Section 7.4 — Folder icon uses muted/tertiary colour.
**Mock implements:** Sub-folders use `onPrimaryContainer` (`#1E3A8A` light / `#2DD4BF` dark).
**Reason:** Approved during mock review — distinguishes sub-folders from project folders while staying in the primary colour family.
**Binding:** YES — sub-folders use `onPrimaryContainer`

---

### Changed: Sort order within projects/folders

**Spec says:** No explicit sort order defined. Section 4.2 says "flat list of Tercen documents".
**Mock implements:** Type-based sort priority:
1. README.md (always first, priority 0)
2. Workflows (alphabetical, priority 1)
3. Datasets (alphabetical, priority 2)
4. Files (alphabetical, priority 3)
5. Folders (alphabetical, priority 4)
**Reason:** Refined during mock iteration — surfaces the most important items first.
**Binding:** YES — implement this sort order

---

### Changed: Toolbar button variants

**Spec says:** Section 6.1 — Upload uses primary accent colour. Other buttons are standard.
**Mock implements:** Upload and Download are both `primary` variant (filled blue). Team is `secondary` variant (outlined). Filter is `secondary` variant (outlined).
**Reason:** Refined during mock iteration — two primary actions (upload/download), two secondary controls (team, filter).
**Binding:** YES — use these exact variants

---

### Changed: Secondary button border rendering

**Spec says:** `button-border-width: 1.5px` in tokens.
**Mock implements:** 2px border in HTML to achieve visual parity with Flutter's Skia 1.5px rendering. The SDUI catalog should use the token value (`1.5px`) — the orchestrator renders via Flutter/Skia which handles sub-pixel correctly.
**Reason:** Browser sub-pixel rendering rounds 1.5px down to 1px on standard DPI. The HTML mock compensates. Real implementation uses the token.
**Binding:** YES — catalog.json uses standard token, HTML mock uses 2px

---

### Added: Convenience bar (dev-only, not in spec)

**Spec says:** Nothing — this is a development artifact.
**Mock implements:** Dark top bar with tab mock, state switcher (Active/Loading/Empty/Error), and theme toggle. Clearly marked as dev-only.
**Reason:** Standardized for all HTML mocks. Widgets have no border — they get wrapped by a pane in the orchestrator.
**Binding:** NO — do NOT include in catalog.json. This is mock infrastructure only.

---

### Added: EventBus log bar and toast (dev-only, not in spec)

**Spec says:** Section 13 defines events but no visual logging.
**Mock implements:** Bottom monospace log bar showing last emitted event. Toast notification appears with channel + payload + validation against expected spec events.
**Reason:** Development aid for verifying event wiring. Not part of the widget.
**Binding:** NO — do NOT include in catalog.json. EventBus wiring uses SDUI event channels.

---

### Added: Custom CSS tooltips

**Spec says:** No tooltip specification.
**Mock implements:** Grey (#616161) tooltips positioned below elements, matching Flutter Material tooltip style. Applied to toolbar buttons, git chips (show GitHub URL), and public icons.
**Reason:** Browser native tooltips had wrong colour (green on Linux). Custom tooltips match Flutter.
**Binding:** YES — toolbar buttons should have tooltip text. Git chip tooltip shows the GitHub URL.

---

## Unchanged from Spec

The following features carry forward from the spec as-is:

- Window identity: tab label "Navigator", type colour yellow (#F59E0B)
- Four body states: loading (spinner + "Loading projects..."), empty (folder icon + "No projects yet" + "Ask the AI to create a project"), active (toolbar + tree), error (error icon + "Something went wrong" + detail + Retry button)
- Tree hierarchy: Personal team auto-expanded, other teams collapsed, projects collapsed within teams
- Single-click: expand/collapse branch nodes + emit `focusChanged` (except team nodes which only expand/collapse)
- Double-click on leaf: emit `openViewer`
- Selected row: `primaryFixed` background + `emphasis` (2px) left border in `primary` colour, name bold (600)
- Hover row: `surfaceContainer` background
- Search: case-insensitive substring match, auto-expands matching ancestors
- Type filter + search work together: intersection filtering
- EventBus channels: `navigator.focusChanged`, `navigator.openViewer`, `navigator.openTeamWidget`, `navigator.downloadFile`, `navigator.contentChanged`
- Inbound events: `navigateTo`, `refreshTree`
- Tree indentation: 20px per depth level + 4px base
- Chevron: 10px FontAwesome chevron-right/chevron-down, `onSurfaceMuted` colour
- Git version chip: `surfaceContainerHigh` background, `textTertiary` text, GitHub brand icon + version string
- Toolbar height: 48px, button size: 32px, icon size: 16px, gap: 8px
