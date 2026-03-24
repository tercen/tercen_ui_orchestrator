# Tercen UI Orchestrator

AI-driven Server-Driven UI (SDUI) system for the Tercen platform. An AI agent composes Flutter widget trees as JSON; the SDUI renderer turns them into live, interactive UI.

## Architecture

The orchestrator supports two AI backends:

```
                        ┌──────────────────────────────────────┐
                        │         Flutter Client               │
                        │  (SDUI renderer, Chat panel)         │
                        │  Tier 1+2 widgets, Theme tokens      │
                        └──────────┬───────────────┬───────────┘
                                   │               │
                   ┌───────────────┘               └───────────────┐
                   │ WebSocket (dev)                                │ Event Service (prod)
                   ▼                                               ▼
        ┌──────────────────┐                         ┌──────────────────────┐
        │  Dart Server      │                         │  tercen_agent        │
        │  (server/bin/)    │                         │  (Docker operator)   │
        │  Claude Code CLI  │                         │  Claude Agent SDK    │
        │  MCP servers      │                         │  tercenctl MCP       │
        └──────────────────┘                         └──────────────────────┘

Sibling repos:
  ../sdui                  — SDUI framework (renderer, registry, EventBus, theme)
  ../tercen-style          — Design tokens (tokens.json)
  ../tercen_ui_widgets     — Widget library (catalog.json templates)
```

| | Dev mode (Claude Code) | Production mode (Agent) |
|---|---|---|
| **Backend** | Dart shelf server + Claude Code CLI | `tercen_agent` Docker operator |
| **Transport** | WebSocket (`/ws/chat`, `/ws/ui`) | Tercen event service (Redis pub/sub) |
| **Cost** | Free (Claude Code subscription) | Anthropic API (pay per token) |
| **Requires** | Server running + `claude` CLI installed | Tercen instance + registered operator |

## Prerequisites

- **Flutter SDK** >= 3.5.0 (includes Dart)
- **Tercen instance** — local (`http://127.0.0.1:5400`) or remote
- **Tercen JWT token** — for authenticating API calls

### Additional prerequisites by mode

**Dev mode (Claude Code):**
- **Claude Code CLI** — [install](https://claude.ai/code)

**Production mode (Agent):**
- **Agent operator registered** in Tercen (see [Register the Agent Operator](#register-the-agent-operator))
- **Anthropic API key** — from [console.anthropic.com](https://console.anthropic.com)

### Getting a Tercen token

```bash
# Using tercenctl:
tercenctl context to-token --validity 30d
```

Or from the Tercen web UI: Profile → API Tokens → Create.

## Quick Start

### 1. Install dependencies

```bash
# Flutter client
flutter pub get

# Dart server (dev mode only)
cd server && dart pub get && cd ..

# SDUI package (sibling repo)
cd ../sdui && flutter pub get && cd -
```

### 2a. Dev mode — Claude Code (WebSocket)

Start the server:
```bash
cd server && ./start.sh
# Runs on http://127.0.0.1:8080
```

Start the Flutter client:
```bash
flutter run -d chrome \
  --web-hostname 127.0.0.1 \
  --web-port 12888 \
  --dart-define=SERVER_URL=ws://127.0.0.1:8080 \
  --dart-define=TERCEN_TOKEN=<your-jwt-token>
```

### 2b. Production mode — Tercen Agent

No server needed. The Flutter client communicates directly with the Tercen agent operator via the event service.

```bash
flutter run -d chrome \
  --web-hostname 127.0.0.1 \
  --web-port 12888 \
  --dart-define=TERCEN_TOKEN=<your-jwt-token> \
  --dart-define=AGENT_OPERATOR_ID=<operator-id> \
  --dart-define=ANTHROPIC_API_KEY=<your-api-key>
```

The mode is determined automatically: if `SERVER_URL` is set, WebSocket mode is used. Otherwise, if `AGENT_OPERATOR_ID` is set, agent mode is used.

### 3. Load a widget library

In the running app, click the "Load Library" button in the toolbar. The default URL is:
```
https://github.com/tercen/tercen_ui_widgets
```

Note: Widget library loading via the toolbar is only available in dev mode (WebSocket). In production mode, widget libraries are loaded at startup from the Tercen instance.

## Register the Agent Operator

Before using production mode, the agent operator must be registered in your Tercen instance. This is a one-time setup.

```bash
dart run tool/register_agent_operator.dart [serviceUri]
# Defaults to http://127.0.0.1:5400, authenticates as admin/admin
```

This creates a `DockerOperator` record pointing to `ghcr.io/tercen/tercen_agent:latest` and prints the operator ID:

```
Operator registered successfully!
  ID:        82c8313fcbe7b655963c2985740002dc
  Name:      tercen_agent
  Container: ghcr.io/tercen/tercen_agent:latest

Use this ID with the Flutter app:
  --dart-define=AGENT_OPERATOR_ID=82c8313fcbe7b655963c2985740002dc
```

The agent Docker image is built from `../sci/Dockerfile_tercen_agent` and includes `tercenctl` for MCP tool access.

## IDE Setup

### JetBrains (IntelliJ / Android Studio)

1. Open the `tercen_ui_orchestrator` directory as a Flutter project
2. Go to **Run → Edit Configurations → + → Flutter**
3. Set **Dart entrypoint** to `lib/main.dart`

**Dev mode configuration (Claude Code):**
- Name: `Orchestrator`
- Additional run args:
  ```
  -d chrome --web-hostname 127.0.0.1 --web-port 12888 --dart-define=SERVER_URL=ws://127.0.0.1:8080 --dart-define=TERCEN_TOKEN=<your-jwt> --dart-define=SERVICE_URI=http://127.0.0.1:5400 --dart-define=TEAM_ID=<your-team>
  ```

**Production mode configuration (Agent):**
- Name: `Orch. Agent`
- Additional run args:
  ```
  -d chrome --web-hostname 127.0.0.1 --web-port 12888 --dart-define=TERCEN_TOKEN=<your-jwt> --dart-define=AGENT_OPERATOR_ID=<operator-id> --dart-define=ANTHROPIC_API_KEY=<your-api-key> --dart-define=SERVICE_URI=http://127.0.0.1:5400 --dart-define=TEAM_ID=<your-team>
  ```

Replace `<your-jwt>`, `<operator-id>`, `<your-api-key>`, and `<your-team>` with your actual values.

### VS Code

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Orchestrator (Dev - Claude Code)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "args": [
        "-d", "chrome",
        "--web-hostname", "127.0.0.1",
        "--web-port", "12888",
        "--dart-define=SERVER_URL=ws://127.0.0.1:8080",
        "--dart-define=TERCEN_TOKEN=<your-jwt>",
        "--dart-define=SERVICE_URI=http://127.0.0.1:5400",
        "--dart-define=TEAM_ID=<your-team>"
      ]
    },
    {
      "name": "Orchestrator (Agent)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "args": [
        "-d", "chrome",
        "--web-hostname", "127.0.0.1",
        "--web-port", "12888",
        "--dart-define=TERCEN_TOKEN=<your-jwt>",
        "--dart-define=AGENT_OPERATOR_ID=<operator-id>",
        "--dart-define=ANTHROPIC_API_KEY=<your-api-key>",
        "--dart-define=SERVICE_URI=http://127.0.0.1:5400",
        "--dart-define=TEAM_ID=<your-team>"
      ]
    }
  ]
}
```

Replace the placeholder values with your own. The JWT token is compiled into the app at build time — restart the app when it expires.

### Environment variables reference

| Variable | Required | Mode | Description |
|---|---|---|---|
| `TERCEN_TOKEN` | Yes | Both | JWT token for Tercen API authentication |
| `SERVER_URL` | Dev only | Dev | WebSocket URL of the Dart server (e.g. `ws://127.0.0.1:8080`) |
| `AGENT_OPERATOR_ID` | Prod only | Prod | CouchDB ID of the registered agent operator |
| `ANTHROPIC_API_KEY` | Prod only | Prod | Anthropic API key for Claude access |
| `SERVICE_URI` | No | Both | Tercen service URI (extracted from JWT if omitted) |
| `TEAM_ID` | No | Both | Default team ID |

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
│   ├── main.dart                    — Flutter app entry point, auth, backend selection
│   ├── presentation/
│   │   ├── screens/shell_screen.dart — Main layout (chat + workspace + toolbar)
│   │   └── widgets/                 — Toolbar, chat panel, workspace
│   ├── sdui/service/
│   │   └── service_call_dispatcher.dart — Routes DataSource calls to Tercen API
│   └── services/
│       ├── chat_backend.dart        — Abstract ChatBackend interface
│       ├── orchestrator_client.dart  — WebSocket backend (dev mode)
│       ├── agent_client.dart        — Tercen agent backend (production mode)
│       └── layout_extractor.dart    — SDUI layout op extraction from text
├── server/                          — Dart backend server (dev mode only)
│   ├── bin/
│   │   ├── server.dart              — WebSocket server, Claude CLI, catalog
│   │   └── mcp_discover.dart        — MCP server for API discovery
│   ├── start.sh / stop.sh
│   └── pubspec.yaml
├── tool/
│   ├── test_api.dart                — CLI tool to test Tercen API calls
│   └── register_agent_operator.dart — Register the agent operator in Tercen
├── WIDGET_LIB_INSTRUCTIONS.md       — Full guide for building widget libraries
├── SDUI_CATALOG_AUTHORING_GUIDE.md  — Tier 2 JSON template authoring
└── README.md                        — This file

Sibling repos:
../sdui/                             — SDUI framework package
../tercen-style/tokens.json          — Design tokens (single source of truth)
../tercen_ui_widgets/catalog.json    — Widget library templates
../sci/tercen_agent/                 — Agent operator (TypeScript, Claude Agent SDK)
../sci/Dockerfile_tercen_agent       — Multi-stage Docker build for the agent
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
