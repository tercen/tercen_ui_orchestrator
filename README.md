# Tercen UI Orchestrator

AI-driven Server-Driven UI (SDUI) system for the Tercen platform. An AI agent composes Flutter widget trees as JSON; the SDUI renderer turns them into live, interactive UI.

## Architecture

```
┌──────────────────┐     WebSocket      ┌──────────────────┐
│  Flutter Client   │ ◄──────────────► │  Dart Server      │
│  (SDUI renderer)  │                   │  (server/bin/)    │
│  Tier 1+2 widgets │                   │                   │
│  Theme tokens     │                   │  Claude Code CLI  │
└──────────────────┘                   │  MCP servers      │
                                        │  Theme tokens     │
                                        │  Widget catalog   │
                                        └──────────────────┘

Sibling repos:
  ../sdui                  — SDUI framework (renderer, registry, EventBus, theme)
  ../tercen-style          — Design tokens (tokens.json)
  ../tercen_ui_widgets     — Widget library (catalog.json templates)
```

## Prerequisites

- **Flutter SDK** >= 3.5.0 (includes Dart)
- **Claude Code CLI** — [install](https://claude.ai/code) — needed for the chat/AI agent
- **Tercen instance** — local (`http://127.0.0.1:5400`) or remote — needed for data widgets
- **Tercen JWT token** — for authenticating API calls from the Flutter client

### Getting a Tercen token

Option A — from a running Tercen instance:
```bash
# If you have tercenctl installed:
tercenctl context to-token --validity 30d
```

Option B — from the Tercen web UI:
1. Log in to your Tercen instance
2. Go to Profile → API Tokens
3. Create a new token

## Quick Start

### 1. Install dependencies

```bash
# Flutter client
flutter pub get

# Dart server
cd server && dart pub get && cd ..

# SDUI package (sibling repo)
cd ../sdui && flutter pub get && cd -
```

### 2. Start the server

```bash
cd server
./start.sh
# Server runs on http://127.0.0.1:8080 by default
# Set PORT=9090 to use a different port
```

Or manually:
```bash
cd server && dart run bin/server.dart
```

The server:
- Hosts the WebSocket endpoints (`/ws/chat`, `/ws/ui`)
- Serves the widget catalog API (`/api/widget-catalog`)
- Serves theme tokens (`/api/theme-tokens`)
- Loads `tokens.json` from `../tercen-style/tokens.json` (or `TERCEN_THEME_TOKENS` env var)
- Spawns Claude Code CLI for chat interactions
- Spawns the MCP discovery server for Tercen API introspection

### 3. Start the Flutter client

```bash
flutter run -d chrome \
  --web-hostname 127.0.0.1 \
  --web-port 12888 \
  --dart-define=SERVER_URL=ws://127.0.0.1:8080 \
  --dart-define=TERCEN_TOKEN=<your-jwt-token>
```

The token is compiled into the app at build time. If it expires, restart with a fresh token.

### 4. Load a widget library

In the running app, click the "Load Library" button in the toolbar. The default URL is:
```
https://github.com/tercen/tercen_ui_widgets
```

Or load from a local catalog via the API:
```bash
curl -X POST http://127.0.0.1:8080/api/widget-catalog/load \
  -H 'Content-Type: application/json' \
  -d '{"repo": "https://github.com/tercen/tercen_ui_widgets"}'
```

## MCP Discovery Server

The MCP server (`server/bin/mcp_discover.dart`) provides Tercen API introspection tools. It is **fully static** — method names and signatures come from the `sci_tercen_client` package source code. No token, no network, no running Tercen instance required.

### Tools provided

| Tool | Description |
|------|-------------|
| `discover_services` | Lists all Tercen services (projectService, teamService, etc.) |
| `discover_methods(service)` | Lists methods, views, and arg patterns for a service |
| `discover_widgets` | Lists installed template widgets from the catalog |
| `discover_interactions` | Action/ReactTo patterns and event channel conventions |
| `get_ui_state` | Current user selections and active windows |

### Using standalone (for catalog authoring)

The MCP server can be used directly with Claude Code — no orchestrator server needed:

```bash
cd server
claude --mcp-config '{
  "mcpServers": {
    "tercen": {
      "type": "stdio",
      "command": "dart",
      "args": ["run", "bin/mcp_discover.dart"]
    }
  }
}'
```

Then ask Claude to `discover_methods("teamService")` etc. before writing DataSource nodes in catalog templates.

### Service call patterns

The `discover_methods` output marks each view as `(startKeys)` or `(keys)`:

**startKeys** — range query:
```json
"args": [[false, ""], [true, "\uf000"], 20]
```

**keys** — key lookup:
```json
"args": [["owner-username"]]
```

See `WIDGET_LIB_INSTRUCTIONS.md` section 8.4-8.5 for full details.

## Widget Catalog (catalog.json)

Widget templates are JSON files that compose Tier 1 primitives into reusable Tier 2 widgets. They are loaded at runtime — no compilation needed.

### Tier 1 — Built-in primitives

**Layout:** Row, Column, Container, Expanded, SizedBox, Center, Spacer, ListView, Grid, Card, Padding

**Display:** Text, Icon, Divider, Chip, CircleAvatar, LoadingIndicator, Placeholder

**Interactive:** TextField, ElevatedButton, TextButton, IconButton, Switch, Checkbox, DropdownButton

**Behavior:** DataSource, ForEach, Action, ReactTo, Conditional, StateHolder, Sort, Filter

### Tier 2 — Template widgets (from catalog.json)

Loaded from widget libraries (e.g., `tercen_ui_widgets`). Examples: FileNavigator, WorkflowViewer, ChatBox, DataTableViewer, DocumentEditor.

### Template bindings

- `{{context.username}}` — logged-in user's username
- `{{context.userId}}` — logged-in user's ID
- `{{data}}` / `{{data.fieldName}}` — DataSource result
- `{{item}}` / `{{item.fieldName}}` — ForEach iteration item
- `{{loading}}`, `{{error}}`, `{{ready}}`, `{{errorMessage}}` — DataSource state
- `{{widgetId}}` — current widget instance ID

### Theming

All styling comes from `../tercen-style/tokens.json`. Use semantic tokens only:
- Colors: `primary`, `onSurface`, `surfaceContainerHigh`, `onSurfaceMuted`, etc.
- Text: `textStyle` prop with M3 slot names (`bodyMedium`, `titleLarge`, `labelSmall`, etc.)
- Spacing: token names in padding/spacing props (`sm`, `md`, `lg`)

Never hardcode hex colors or pixel font sizes in catalog templates.

## Project Structure

```
tercen_ui_orchestrator/
├── lib/
│   ├── main.dart                    — Flutter app entry point, auth, theme
│   ├── presentation/
│   │   ├── screens/shell_screen.dart — Main layout (chat + workspace + toolbar)
│   │   └── widgets/                 — Toolbar, chat panel, workspace
│   ├── sdui/service/
│   │   └── service_call_dispatcher.dart — Routes DataSource calls to Tercen API
│   └── services/
│       └── orchestrator_client.dart — WebSocket client
├── server/
│   ├── bin/
│   │   ├── server.dart              — Dart backend (WebSocket, catalog, Claude CLI)
│   │   └── mcp_discover.dart        — MCP server for API discovery
│   ├── start.sh / stop.sh
│   └── pubspec.yaml
├── tool/
│   └── test_api.dart              — CLI tool to test Tercen API calls via ServiceCallDispatcher
├── WIDGET_LIB_INSTRUCTIONS.md       — Full guide for building widget libraries
├── SDUI_THEME_TOKENS.md             — Theme token specification
└── README.md                        — This file

Sibling repos:
../sdui/                             — SDUI framework package
../tercen-style/tokens.json          — Design tokens (single source of truth)
../tercen_ui_widgets/catalog.json    — Widget library templates
```

## CLI Tools

### test_api.dart

A CLI tool for testing Tercen API calls via `ServiceCallDispatcher`. Useful for debugging data connection issues outside the Flutter app.

**Note:** Requires Flutter SDK (imports the sdui package which depends on Flutter). Cannot run with plain `dart run` on Dart VM — use `flutter run` or `flutter test` instead.

## Stopping

```bash
cd server && ./stop.sh
```

Or kill the server process manually — `stop.sh` also cleans up orphaned Claude CLI processes.
