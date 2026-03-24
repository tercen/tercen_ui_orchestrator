# Refactor: Replace Custom WebSockets with Tercen EventService

## Goal

Replace the hand-rolled WebSocket channels (`/ws/chat`, `/ws/ui`) in `OrchestratorClient` and `server.dart` with Tercen's native `EventService`. The local in-memory `EventBus` stays untouched for widget-to-widget communication.

End state: no custom WebSocket code remains for client↔server communication.

---

## Channel Naming Convention

All Tercen EventService channels are scoped per session to avoid cross-talk:

| Purpose | Tercen channel name |
|---|---|
| Selections (client → server) | `orchestrator.{sessionId}.selection` |
| Layout ops (server → client) | `orchestrator.{sessionId}.layout` |
| Chat messages (client → server) | `orchestrator.{sessionId}.chat.in` |
| Chat responses (server → client) | `orchestrator.{sessionId}.chat.out` |

- `sessionId` is a UUID generated per app session
- Payload carrier: `GenericEvent` (`type`: String, `content`: JSON-encoded String)
- All channels use `sendChannel` (transient, not persisted to CouchDB)

---

## Phase 1 — Client: Create TercenEventBridge

### New file: `lib/services/tercen_event_bridge.dart`

Replaces `OrchestratorClient`. Same public API surface so consumers barely change.

**Constructor**: takes `EventBus` (local) + `ServiceFactory` (Tercen auth). Generates a `sessionId` (UUID).

**`connect()` method**:
- Subscribes to `orchestrator.{sessionId}.layout` via `factory.eventService.channel(...)` — decodes incoming `GenericEvent`, publishes to local EventBus as `system.layout.op`
- Subscribes to `orchestrator.{sessionId}.chat.out` via `factory.eventService.channel(...)` — decodes incoming `GenericEvent`, exposes via `chatMessages` stream
- Listens to local EventBus `system.selection.*` prefix — wraps as `GenericEvent`, sends via `factory.eventService.sendChannel('orchestrator.{sessionId}.selection', evt)`
- Reconnection with exponential backoff on stream `onError`/`onDone`

**`sendChat(String message)`**: creates `GenericEvent` with `type: 'chat.message'`, `content: message`, sends via `sendChannel` on `chat.in`.

**Exposes**: `Stream<Map<String, dynamic>> chatMessages`, `String sessionId`, `ConnectionState state`.

### Modify: `lib/main.dart`

- Create `TercenEventBridge` *after* `ServiceFactory` is initialized (during auth bootstrap), not before
- Replace `OrchestratorClientScope` with new scope widget for the bridge
- If no token available, show "not authenticated" state — local EventBus still works

### Modify: `lib/presentation/widgets/chat_panel.dart`

- Update scope lookup from `OrchestratorClientScope` to new scope
- Public API is the same (`.chatMessages`, `.sendChat()`, `.state`) so changes are minimal

### Modify: `lib/presentation/widgets/toolbar.dart`

- Update scope lookup
- `_loadFromGitHub` currently uses `client.baseUrl` to build the catalog API URL — pass server HTTP URL as a separate config (not from the bridge)

### Testable checkpoint

App starts → auth bootstraps → bridge connects. Selections forward to Tercen channel. Chat sends to Tercen channel. (Server not yet listening, so no responses yet.)

---

## Phase 2 — Server: Subscribe to Tercen Channels

### Modify: `server/pubspec.yaml`

Add dependencies:
```yaml
sci_tercen_client:
  git:
    ref: 1.16.1
    url: https://github.com/tercen/sci_tercen_client
    path: sci_tercen_client
sci_base:
  git:
    ref: 1.16.1
    url: https://github.com/tercen/sci_tercen_client
    path: sci_base
sci_http_client:
  git:
    ref: 1.16.1
    url: https://github.com/tercen/sci_tercen_client
    path: sci_http_client
```

### Modify: `server/bin/server.dart`

**Add at startup**:
- Initialize `ServiceFactory` from `TERCEN_TOKEN` env var
- New endpoint `POST /api/session` — client sends `{"sessionId": "..."}`. Server stores sessionId and starts Tercen channel subscriptions for that session.

**Remove**:
- `/ws/chat` route and `webSocketHandler`
- `/ws/ui` route and `webSocketHandler`
- `_uiSinks` list
- `shelf_web_socket` import

**Replace WebSocket handlers with Tercen channel subscriptions**:
- `orchestrator.{sessionId}.chat.in` → on `GenericEvent` with `type: 'chat.message'`, extract `content`, call existing `_handleChatMessage` logic
- `orchestrator.{sessionId}.selection` → on `GenericEvent`, decode `content`, call existing `_handleSelectionEvent` logic

**Replace WebSocket sinks with Tercen sends**:
- `_processStreamEvent`: instead of writing to `chatSink`, create `GenericEvent` and `sendChannel` on `chat.out`
- `_extractAndDispatchLayoutOps`: instead of pushing to `_uiSinks`, create `GenericEvent` and `sendChannel` on `layout`

**Signature changes**:
- `_handleChatMessage(dynamic chatSink, String userMessage)` → `_handleChatMessage(String sessionId, String userMessage)`
- New helper: `_sendChatEvent(String sessionId, Map<String, dynamic> msg)`
- New helper: `_sendLayoutOp(String sessionId, Map<String, dynamic> op)`

### Testable checkpoint

Full roundtrip: chat message → Tercen → server → Claude → Tercen → client chat panel. Selections flow client → Tercen → server `_userContext`. Layout ops flow server → Tercen → client → local EventBus → WindowManager.

---

## Phase 3 — Cleanup

### Delete
- `lib/services/orchestrator_client.dart`

### Modify
- `pubspec.yaml` (client) — remove `web_socket_channel` dependency
- `server/pubspec.yaml` — remove `shelf_web_socket` dependency
- Remove any leftover imports of `orchestrator_client.dart`

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| **Auth timing** — bridge needs `ServiceFactory` before connecting | Create bridge after auth bootstrap; show "not authenticated" in chat until ready |
| **Server auth** — server needs Tercen token to use EventService | Read `TERCEN_TOKEN` from env var, same pattern as client |
| **Session coordination race** — client subscribes before server is ready | Client calls `POST /api/session` first, waits for 200, then subscribes |
| **Large chat payloads** in GenericEvent content | Use transient `sendChannel` (not persisted); stream individual `text_delta` events |
| **Reconnection on stream drop** | Wrap subscriptions with `onError`/`onDone` + exponential backoff, same as current logic |
| **sci_tercen_client on server** (no Flutter) | Uses `sci_http_client` IO variant — pure Dart, no Flutter dependency |
| **Multiple clients same channel** | `sessionId` is UUID-per-client, no cross-talk. Multi-client is a future feature if desired |

---

## Key Source Files

| File | Role |
|---|---|
| `lib/services/orchestrator_client.dart` | Current WebSocket client (TO BE REPLACED) |
| `server/bin/server.dart` | Current server with WS endpoints (TO BE MODIFIED) |
| `lib/main.dart` | App startup, dependency injection |
| `lib/presentation/widgets/chat_panel.dart` | Chat UI, consumes chatMessages stream |
| `lib/presentation/widgets/toolbar.dart` | Sends chat, loads catalogs |
| `sdui/lib/src/event_bus/event_bus.dart` | Local EventBus (KEEP UNTOUCHED) |
| `sci_tercen_client/.../event_service.dart` | Tercen EventService API (`channel`, `sendChannel`) |
| `sci_tercen_model/.../generic_event.dart` | `GenericEvent` model (`type` + `content` String fields) |

---
---

# Theme Module: Centralized Theming for SDUI Widgets

## Problem

The orchestrator defines a `ThemeData` in `main.dart`, but SDUI widgets completely ignore it. There are 40+ hardcoded color values across two packages (`sdui`, `tercen_ui_orchestrator`) and zero `Theme.of(context)` calls in the SDUI renderer. Catalog templates also bake in hex colors (`#1E1E1E`, `#1565C0`, `#888888`). There is no `Icon` primitive widget in the SDUI system.

This means:
- Changing the app theme has no effect on SDUI-rendered content
- No dark/light mode switching is possible
- Every widget library must guess the right colors
- AIs cannot add icons to widgets

## Design Principles

1. **Theme is invisible to the AI.** Widget primitives inherit theme defaults automatically. A `Text` without a `color` prop uses `theme.colors.onSurface`. A `Card` without a `color` prop uses `theme.colors.surface`. The AI never writes `"color": "{{theme.colors.primary}}"` — it just omits the prop and gets the right color.
2. **Explicit overrides still work.** Hex (`#1565C0`) and named colors (`red`, `blue`) keep working as prop values for cases where the AI intentionally deviates from the theme.
3. **Theme is owned by the orchestrator.** The orchestrator defines light and dark themes and broadcasts changes. The SDUI package consumes the theme but never defines it.
4. **Icons use Flutter's `Icons` library directly.** The AI specifies icon names as strings (e.g., `"folder"`, `"description"`, `"chevron_right"`). The SDUI `Icon` widget resolves them to `Icons.*` at render time. No custom icon registry needed for now.

---

## Theme Token Schema

A single `SduiTheme` object defines all tokens. Stored as a `ValueNotifier<SduiTheme>` in the orchestrator so changes trigger rebuilds.

```
theme.
├── colors.
│   ├── primary            — main accent (buttons, links, selection highlight)
│   ├── onPrimary          — text/icon on primary
│   ├── surface            — card/container background
│   ├── surfaceVariant     — elevated surface (window chrome, toolbar)
│   ├── background         — page/workspace background
│   ├── onSurface          — primary text on surface
│   ├── onSurfaceVariant   — secondary text (descriptions, hints)
│   ├── onSurfaceMuted     — tertiary text (timestamps, metadata)
│   ├── border             — default border color
│   ├── divider            — divider lines
│   ├── error              — error accent
│   ├── errorContainer     — error background
│   ├── onError            — text on error
│   ├── warning            — warning accent
│   ├── warningContainer   — warning background
│   ├── success            — success/online indicator
│   └── info               — info accent
├── elevation.
│   ├── none               — 0
│   ├── low                — 1
│   └── medium             — 4
├── radius.
│   ├── small              — 4
│   ├── medium             — 8
│   └── large              — 12
├── spacing.
│   ├── xs                 — 4
│   ├── sm                 — 8
│   ├── md                 — 12
│   ├── lg                 — 16
│   └── xl                 — 24
└── typography.
    ├── bodySize           — 14
    ├── captionSize        — 12
    ├── titleSize          — 16
    └── headingSize        — 20
```

---

## Phase 1 — Define SduiTheme, light/dark presets, and theme switching

### New file: `sdui/lib/src/theme/sdui_theme.dart`

```dart
class SduiTheme {
  final SduiColorTokens colors;
  final SduiSpacingTokens spacing;
  final SduiTypographyTokens typography;
  final SduiElevationTokens elevation;
  final SduiRadiusTokens radius;

  const SduiTheme({ ... });

  /// Light theme (default).
  const SduiTheme.light();

  /// Dark theme.
  const SduiTheme.dark();

  /// Convert to a flat Map for template scope injection (override use only).
  Map<String, dynamic> toScopeMap();

  /// Derive a Flutter ThemeData for Material widgets.
  ThemeData toMaterialTheme();
}
```

Sub-classes: `SduiColorTokens`, `SduiSpacingTokens`, `SduiTypographyTokens`, `SduiElevationTokens`, `SduiRadiusTokens` — each a simple data class with `const` constructor.

Light theme values: standard Material light palette (white surfaces, dark text, blue primary).
Dark theme values: match current hardcoded values (`#1E1E1E` surface, `Colors.white70` text, etc.) so existing look is preserved.

### Modify: `sdui/lib/src/renderer/sdui_render_context.dart`

Add `SduiTheme` field:
```dart
class SduiRenderContext {
  final EventBus eventBus;
  final TemplateResolver templateResolver;
  final SduiTheme theme;          // <-- NEW
  ServiceCaller? serviceCaller;
}
```

### Modify: `tercen_ui_orchestrator/lib/main.dart`

- Add `ValueNotifier<SduiTheme> _themeNotifier` initialized to `SduiTheme.light()`
- Wrap `MaterialApp` in `ValueListenableBuilder<SduiTheme>` — rebuilds on theme change
- `MaterialApp.theme` derived from `_themeNotifier.value.toMaterialTheme()`
- Pass `_themeNotifier.value` to `SduiRenderContext`
- Publish theme change on local EventBus channel `system.theme.changed` with payload `{"mode": "light"|"dark"}` — SDUI widgets with StatefulWidget internals can listen and rebuild

### Theme toggle

Add a theme toggle button to the toolbar (sun/moon icon). On tap:
```dart
_themeNotifier.value = (_themeNotifier.value == SduiTheme.light())
    ? SduiTheme.dark()
    : SduiTheme.light();
```
The `ValueListenableBuilder` rebuilds the entire `MaterialApp`, which:
- Updates Flutter's `ThemeData` for orchestrator widgets via `Theme.of(context)`
- Recreates `SduiRenderContext` with the new `SduiTheme` for SDUI widgets
- Publishes `system.theme.changed` event for any stateful widgets that need explicit refresh

### Testable checkpoint

- App starts in light mode by default
- Toggle switches between light and dark
- `SduiTheme.dark().toMaterialTheme()` produces the same look as current hardcoded theme
- `SduiTheme.light().toMaterialTheme()` produces a proper light theme
- `system.theme.changed` event fires on toggle

---

## Phase 2 — Replace hardcoded colors in SDUI widget primitives

The key change: **widget builders read defaults from `ctx.theme` instead of hardcoded `Colors.*` values.** The AI never needs to specify colors — omitting a color prop gives the themed default.

### Modify: `sdui/lib/src/registry/builtin_widgets.dart`

| Widget | Current default | New default |
|--------|----------------|-------------|
| `Text` color | `Colors.white70` | `ctx.theme.colors.onSurface` |
| `Text` fontSize | `14` | `ctx.theme.typography.bodySize` |
| `Card` color | none (Material default) | `ctx.theme.colors.surface` |
| `Card` elevation | `1` | `ctx.theme.elevation.low` |
| `Placeholder` color | `Colors.blue` | `ctx.theme.colors.primary` |
| `LoadingIndicator` text color | `Colors.white70` | `ctx.theme.colors.onSurfaceVariant` |
| `LoadingIndicator` spinner color | none | `ctx.theme.colors.primary` |
| `Padding` default | `8` | `ctx.theme.spacing.sm` |
| `Grid` spacing | `8` | `ctx.theme.spacing.sm` |

**`_parseColor` → `_resolveColor(dynamic value, SduiTheme theme)`**: now resolves semantic names too. If the AI (or template) explicitly passes `"primary"`, `"surface"`, `"error"` etc. as a color value, resolve against theme tokens. Precedence: hex → named Material color → semantic theme token → null.

### Modify: `sdui/lib/src/registry/behavior_widgets.dart`

| Widget state | Current colors | New colors |
|---|---|---|
| DataSource error | `Colors.red` variants | `theme.colors.error`, `theme.colors.errorContainer` |
| DataSource placeholder | `Colors.grey` variants | `theme.colors.onSurfaceMuted`, `theme.colors.surface` |
| DataSource spinner | `CircularProgressIndicator()` | color: `theme.colors.primary` |
| ForEach error | `Colors.red` variants | `theme.colors.error`, `theme.colors.errorContainer` |
| ForEach "No data" | `Colors.grey` | `theme.colors.onSurfaceMuted` |

### Modify: `sdui/lib/src/renderer/sdui_renderer.dart`

| Error type | Current | New |
|---|---|---|
| Render error container | `Colors.red` variants | `theme.colors.error`, `theme.colors.errorContainer` |
| Unknown widget | `Colors.orange` variants | `theme.colors.warning`, `theme.colors.warningContainer` |

### Modify: `sdui/lib/src/window/window_chrome.dart`

| Component | Current | New |
|---|---|---|
| Window background | `0xFF2D2D2D` | `theme.colors.surfaceVariant` |
| Title bar | `0xFF383838` | `theme.colors.surfaceVariant` |
| Title text | `Colors.white54` | `theme.colors.onSurfaceVariant` |
| Button icons | `Colors.white38` | `theme.colors.onSurfaceMuted` |
| Border | `Colors.white.withAlpha(25)` | `theme.colors.border` |

### Testable checkpoint

- Toggle theme → all SDUI widgets change colors immediately
- A widget with no color props renders correctly in both light and dark mode
- A widget with explicit `"color": "#FF0000"` still works (override is respected)

---

## Phase 3 — Add Icon primitive widget

### Modify: `sdui/lib/src/registry/builtin_widgets.dart`

Register a new `Icon` widget:

```dart
registry.register('Icon', _buildIcon,
    metadata: const WidgetMetadata(
      type: 'Icon',
      description: 'Material icon from the Flutter Icons library',
      props: {
        'icon': PropSpec(type: 'string', required: true,
            description: 'Icon name from Flutter Icons (e.g., folder, description, chevron_right, search, add, delete, settings)'),
        'size': PropSpec(type: 'number', defaultValue: 24),
        'color': PropSpec(type: 'string'),
      },
    ));
```

**`_buildIcon` implementation**: resolves the `icon` string prop to an `IconData` via a lookup map of common Flutter icon names → `Icons.*` constants. Default color: `ctx.theme.colors.onSurface`. Default size: `24`.

**Icon name mapping**: a `Map<String, IconData>` covering the most commonly used Material icons (~100-150 icons). Examples:
```dart
const _iconMap = {
  'folder': Icons.folder,
  'folder_open': Icons.folder_open,
  'file': Icons.insert_drive_file,
  'description': Icons.description,
  'search': Icons.search,
  'add': Icons.add,
  'delete': Icons.delete,
  'edit': Icons.edit,
  'settings': Icons.settings,
  'chevron_right': Icons.chevron_right,
  'chevron_left': Icons.chevron_left,
  'expand_more': Icons.expand_more,
  'expand_less': Icons.expand_less,
  'close': Icons.close,
  'check': Icons.check,
  'error': Icons.error,
  'warning': Icons.warning,
  'info': Icons.info,
  'home': Icons.home,
  'person': Icons.person,
  'star': Icons.star,
  'favorite': Icons.favorite,
  'visibility': Icons.visibility,
  'visibility_off': Icons.visibility_off,
  'refresh': Icons.refresh,
  'download': Icons.download,
  'upload': Icons.upload,
  'copy': Icons.content_copy,
  'share': Icons.share,
  'link': Icons.link,
  'lock': Icons.lock,
  'lock_open': Icons.lock_open,
  'calendar': Icons.calendar_today,
  'clock': Icons.access_time,
  'table': Icons.table_chart,
  'chart': Icons.bar_chart,
  'scatter': Icons.scatter_plot,
  'analytics': Icons.analytics,
  'science': Icons.science,
  'data': Icons.storage,
  'workflow': Icons.account_tree,
  'play': Icons.play_arrow,
  'pause': Icons.pause,
  'stop': Icons.stop,
  // ... etc.
};
```

If the icon name is not found, render `Icons.help_outline` and report via `ErrorReporter`.

### Usage in templates

The AI uses it like any other primitive:
```json
{"type": "Icon", "id": "ic-1", "props": {"icon": "folder", "size": 20}}
```

In a list item with icon + text:
```json
{
  "type": "Row", "id": "row-{{item.id}}",
  "props": {"crossAxisAlignment": "center"},
  "children": [
    {"type": "Icon", "id": "ic-{{item.id}}", "props": {"icon": "folder", "size": 18}},
    {"type": "SizedBox", "id": "sp-{{item.id}}", "props": {"width": 8}},
    {"type": "Text", "id": "name-{{item.id}}", "props": {"text": "{{item.name}}"}}
  ]
}
```

### Testable checkpoint

- `{"type": "Icon", "id": "i1", "props": {"icon": "folder"}}` renders a folder icon
- Icon color defaults to `theme.colors.onSurface`, changes with theme toggle
- Unknown icon name → `help_outline` + error reported
- AI can compose icons in templates without knowing about theme

---

## Phase 4 — Replace hardcoded colors in orchestrator presentation

Orchestrator presentation widgets are normal Flutter code — they use `Theme.of(context)` which is derived from `SduiTheme.toMaterialTheme()`.

### Modify: `lib/presentation/widgets/chat_panel.dart`

| Current hardcode | Replace with |
|---|---|
| `0xFF252525` background | `Theme.of(context).colorScheme.surface` |
| `0xFF1E1E1E` input | `Theme.of(context).colorScheme.surface` variant |
| `Colors.white24` hint | `Theme.of(context).hintColor` |
| `Colors.green` online | `Theme.of(context).colorScheme.tertiary` (map success to tertiary) |
| `Colors.red` offline/error | `Theme.of(context).colorScheme.error` |
| `Colors.blue` user icon | `Theme.of(context).colorScheme.primary` |

### Modify: `lib/presentation/widgets/toolbar.dart`

| Current hardcode | Replace with |
|---|---|
| `0xFF2D2D2D` background | `Theme.of(context).colorScheme.surfaceContainerHigh` |
| `Colors.white70` buttons | `Theme.of(context).colorScheme.onSurface` |

### Modify: `lib/presentation/widgets/error_bar.dart`

| Current hardcode | Replace with |
|---|---|
| `0xFF2D1010` background | `Theme.of(context).colorScheme.errorContainer` |
| `Colors.blue.shade300` info | `Theme.of(context).colorScheme.primary` |
| `Colors.orange.shade300` warning | mapped from `SduiTheme.colors.warning` via extended theme |
| `Colors.red.shade300` error | `Theme.of(context).colorScheme.error` |

### Modify: `lib/presentation/widgets/workspace_panel.dart`, `shell_screen.dart`

Replace `Color(0xFF1E1E1E)`, `Colors.white12`, etc. with `Theme.of(context).*`.

### Testable checkpoint

- Toggle theme → entire app (SDUI widgets + orchestrator chrome) switches between light and dark
- No hardcoded color values remain anywhere in the codebase

---

## Phase 5 — Update catalog authoring guide, system prompt, and templates

### Modify: `SDUI_CATALOG_AUTHORING_GUIDE.md`

- Add `Icon` to the primitives table (Section 6)
- Add a note: "Widget primitives inherit theme colors by default. Do NOT specify color props unless you intentionally want to override the theme. Omitting color gives the correct themed default."
- Document the available icon names
- Remove any guidance telling the AI to use `{{theme.*}}` tokens (it shouldn't need to)

### Modify: `test_widget_library` catalog and Dart source

Remove hardcoded colors from the ProjectNavigator template:
- `"color": "#1565C0"` in ReactTo `overrideProps` → keep (this is an intentional override for selection highlight — or change to `"primary"` semantic name)
- `"color": "#1E1E1E"` on Card → remove (theme default)
- `"color": "#888888"` on Text → remove (theme default for secondary text via fontSize heuristic, or leave if explicitly muted)
- `"color": "grey"` on Text → remove (theme default)

### Modify: `server/bin/server.dart` system prompt

- Add `Icon` to the widget list
- Add guidance: "Do not specify colors on widgets unless you want to override the theme. Omitting color gives the correct default."
- Document available icon names

### Testable checkpoint

- AI-generated widgets render correctly without any color props
- Existing catalog widgets render correctly in both light and dark themes
- AI can add icons to widget trees

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| **Breaking existing templates** with hardcoded colors | Hex and named colors still work as overrides. Templates with explicit colors render the same. Templates without colors now get theme defaults instead of hardcoded defaults — visually identical in dark mode. |
| **Icon name not found** | Render `Icons.help_outline` + `ErrorReporter` warning. AI gets feedback via error reporting. |
| **Large icon map** increases bundle size | ~150 entries is negligible. The map is a `const` so it's compiled in. |
| **Theme rebuild performance** | `ValueListenableBuilder` at the `MaterialApp` level rebuilds the whole tree. This is fine — theme changes are infrequent (user-initiated). Same pattern as Flutter's built-in theme switching. |
| **SDUI package Flutter dependency via `Icons`** | `Icons` is in `package:flutter/material.dart` — the SDUI package already depends on Flutter (it builds widgets). No new dependency. |
| **`SduiTheme.toMaterialTheme()` adds Flutter dependency to theme class** | Keep `toMaterialTheme()` in the orchestrator (a bridge function), not in `SduiTheme` itself. `SduiTheme` stores colors as hex strings or int values, not `Color` objects. |

---

## Files affected

### New
| File | Description |
|---|---|
| `sdui/lib/src/theme/sdui_theme.dart` | Theme data class + color/spacing/typography/elevation/radius token sub-classes + light/dark presets |

### Modified (SDUI package)
| File | Changes |
|---|---|
| `sdui/lib/src/renderer/sdui_render_context.dart` | Add `SduiTheme theme` field |
| `sdui/lib/src/renderer/sdui_renderer.dart` | Replace error colors with theme lookups |
| `sdui/lib/src/registry/builtin_widgets.dart` | Replace hardcoded defaults with theme lookups; add `Icon` widget; add `_resolveColor` with semantic names; add `_iconMap` |
| `sdui/lib/src/registry/behavior_widgets.dart` | Replace hardcoded error/placeholder colors with theme lookups |
| `sdui/lib/src/window/window_chrome.dart` | Replace window styling hardcodes with theme lookups |
| `sdui/lib/src/window/floating_window.dart` | Replace resize handle color |

### Modified (Orchestrator)
| File | Changes |
|---|---|
| `lib/main.dart` | `ValueNotifier<SduiTheme>`, `ValueListenableBuilder`, `toMaterialTheme()` bridge, theme toggle, `system.theme.changed` event |
| `lib/presentation/widgets/chat_panel.dart` | Use `Theme.of(context)` instead of hardcodes |
| `lib/presentation/widgets/toolbar.dart` | Use `Theme.of(context)` + add theme toggle button |
| `lib/presentation/widgets/error_bar.dart` | Use `Theme.of(context)` |
| `lib/presentation/widgets/workspace_panel.dart` | Use `Theme.of(context)` |
| `lib/presentation/screens/shell_screen.dart` | Use `Theme.of(context)` |

### Modified (Docs / Templates)
| File | Changes |
|---|---|
| `SDUI_CATALOG_AUTHORING_GUIDE.md` | Add Icon widget; add "theme is automatic" guidance; document icon names |
| `test_widget_library/lib/src/widgets/project_navigator.dart` | Remove explicit color props where theme default suffices |
| `test_widget_library/catalog.json` | Regenerate from updated Dart source |
| `server/bin/server.dart` | Update `_systemPrompt` with Icon widget + theme guidance |
