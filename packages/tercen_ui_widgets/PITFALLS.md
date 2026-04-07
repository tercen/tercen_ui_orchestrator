# Known Pitfalls

Curated list of issues discovered during widget development. Agents should check this before authoring catalog.json entries. Remove entries when fixed in code.

## SDUI Scope Boundaries

**Conditional outside scope builder cannot access scope variables.**
A `Conditional` placed outside a `ChatStream` or `DataSource` children tree cannot see `{{isThinking}}`, `{{data}}`, etc. Scope variables are only available to children of the scope builder that defines them. Move the Conditional inside the scope builder's children.

## Layout Interactions

**StackFit.expand inside ListView causes infinite height.**
Fix: use `SingleChildScrollView` + `Column` instead of `ListView` when children use `StackFit.expand`.

**CrossAxisAlignment.stretch overrides child maxWidth.**
A Column with `CrossAxisAlignment.stretch` forces children to full width. A Container with `maxWidth` inside it still paints at parent width. Fix: wrap in `Center` to allow maxWidth constraints to work.

**AnimatedContainer causes hover overlap between adjacent rows.**
Fix: use `ColoredBox` instead of `AnimatedContainer` for hover backgrounds.

## Dart Type System

**LinkedMap vs Map<String, dynamic>.**
`service.toJson()` returns `LinkedMap<dynamic, dynamic>`, not `Map<String, dynamic>`. Type checks with `is Map<String, dynamic>` silently fail. Fix: use `is Map` instead.

## Flutter Behaviour

**Multiline TextField: onSubmitted doesn't fire.**
Flutter's `onSubmitted` only fires on single-line fields. For multiline Enter-to-send, use `Focus` widget with `onKeyEvent` returning `KeyEventResult.handled`. The SDUI TextField has a `submitOnEnter` prop for this.

## Deployment

**GitHub CDN lag: 1-5 minutes after push.**
`raw.githubusercontent.com` can lag behind a push. Catalog changes may not appear immediately in the orchestrator without a full app rebuild.

## Deleted Token Names

These names no longer resolve in SduiTheme. Use the M3 replacement:

| Deleted | Replacement |
|---------|-------------|
| `primaryHover` | Use M3 state layers (onPrimaryContainer for hover colour) |
| `primaryActive` | Use M3 state layers |
| `primaryBg` | `primaryFixed` |
| `panelBg` | `surfaceContainerLow` |
| `panelBackground` | `surfaceContainerLow` |
| `sectionHeaderBg` | `surfaceContainerHigh` |
| `surfaceElevated` | `surfaceContainerHigh` |
| `borderSubtle` | `outlineVariant` |
| `primaryDarker` | `onPrimaryContainer` |
| `primaryLighter` | `secondary` (if approved) |
| `primarySurface` | `primaryContainer` |
| `textPrimary` | `onSurface` |
| `textSecondary` | `onSurfaceVariant` |
| `textMuted` | `onSurfaceMuted` |
| `textDisabled` | `onSurfaceDisabled` |
| `successLight` | `successContainer` |
| `errorLight` | `errorContainer` |
| `warningLight` | `warningContainer` |
| `infoLight` | `infoContainer` |
| `surfaceVariant` | `surfaceContainerHighest` (if approved) |
| `border` | `outline` |
| `divider` | `outlineVariant` |
