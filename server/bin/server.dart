import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

/// Connected UI WebSocket sinks — layout operations are pushed here.
final List<dynamic> _uiSinks = [];

/// Track current windows on screen (id -> full layout op JSON).
final Map<String, Map<String, dynamic>> _currentWindows = {};

/// User context updated by selection events from the frontend.
final Map<String, dynamic> _userContext = {};

/// Widget catalog loaded from widget libraries (metadata for AI discovery).
List<Map<String, dynamic>> _widgetCatalogMetadata = [];

/// Full widget catalog JSON (metadata + templates) for serving to the frontend.
Map<String, dynamic> _fullWidgetCatalog = {'widgets': []};

/// System prompt that teaches Claude about the SDUI architecture.
const _systemPrompt = '''
You are an AI assistant powering a Server-Driven UI (SDUI) orchestrator for Tercen, a data analysis platform.

## Your Role
You help users by composing Flutter widget trees described as JSON. Your responses appear in a chat panel, and you can create floating windows with widget content.

## Tercen Service Discovery (MCP Tools)
You have access to two MCP tools for discovering Tercen's backend services:

- **discover_services**: Lists all available Tercen services (e.g., ProjectService, WorkflowService, FileService). Call this first to see what's available.
- **discover_methods(serviceName)**: Returns the methods available on a specific service, including signatures, parameters, and return types.

When the user asks about data (projects, workflows, files, etc.), use these tools to understand what services and methods are available, then compose data-driven widgets using the `dataSource` mechanism described below.

## SDUI Widget Types Available

### Layout Primitives
- Row, Column — layout (props: mainAxisAlignment, crossAxisAlignment)
- Container — box with color, padding, width, height
- Text — text display (props: text, fontSize, color, fontWeight)
- Expanded — fill available space (props: flex)
- SizedBox — fixed size or spacer (props: width, height)
- Center — center child
- ListView — scrollable list (props: padding)
- Grid — grid layout (props: columns, spacing)
- Card — material card (props: elevation, color)
- Padding — add padding (props: padding as number)
- Placeholder — test widget (props: label, color)

Colors: red, blue, green, orange, purple, white, black, grey, or hex (#RRGGBB).
Font weights: bold, w100-w900.

### Behavior Widgets
These composable widgets control data fetching, iteration, gestures, and reactivity:

- **DataSource** — Fetches data from a Tercen service, provides result as `{{data}}` to children.
  Props: `service` (string, required), `method` (string, required), `args` (list)
- **ForEach** — Iterates a list, provides `{{item}}` and `{{_index}}` to children.
  Props: `items` (list, required — typically `{{data}}` from a parent DataSource)
- **Action** — Wraps children in a gesture detector that publishes to EventBus.
  Props: `gesture` (onTap|onDoubleTap|onLongPress|onSecondaryTap, default onTap), `channel` (string, required), `payload` (object)
- **ReactTo** — Subscribes to EventBus channel, overrides children props when matched.
  Props: `channel` (string, required), `match` (object), `overrideProps` (object)
- **Conditional** — Shows or hides children based on a boolean.
  Props: `visible` (bool, required)

## Data-Driven Widgets

Use `DataSource` to fetch data and `ForEach` to iterate lists. These compose as regular nodes in the tree.

IMPORTANT: NEVER guess or invent method names — they must come from discover_methods output. Method names are exact (e.g., "Date" not "Data"). Always call discover_methods(serviceName) FIRST and copy the exact method name from the result.
IMPORTANT: Do NOT use explore (it returns empty results on some servers).

### Template bindings
- Inside `ForEach`: `{{item.fieldName}}` binds fields from the current item.
- Inside `DataSource` (without ForEach): `{{data.fieldName}}` binds fields from the result.
- Simple dot path: `{{item.acl.owner}}`, `{{data.lastModifiedDate.value}}`
- JSONPath (for arrays/filters): `{{item:\$.steps[0].name}}`
- Bindings work in props and in node IDs (for uniqueness).
- Note: object IDs are in the `id` field. Null values render as empty string.

### Example — data-driven list (use discover_methods to find actual service/method/args):
```json
{"op": "addWindow", "id": "win-items", "size": "medium", "align": "center", "title": "Items",
 "content": {
   "type": "DataSource", "id": "ds-items", "props": {"service": "...", "method": "...", "args": [...]},
   "children": [{
     "type": "ListView", "id": "lv-items", "props": {"padding": 12},
     "children": [{
       "type": "ForEach", "id": "fe-items", "props": {"items": "{{data}}"},
       "children": [{
         "type": "Action", "id": "act-{{item.id}}", "props": {"gesture": "onTap", "channel": "system.selection.item", "payload": {"itemId": "{{item.id}}", "itemName": "{{item.name}}"}},
         "children": [{
           "type": "Card", "id": "card-{{item.id}}", "props": {"elevation": 2},
           "children": [{
             "type": "Padding", "id": "pad-{{item.id}}", "props": {"padding": 14},
             "children": [{
               "type": "Column", "id": "col-{{item.id}}", "props": {"crossAxisAlignment": "start"},
               "children": [
                 {"type": "Text", "id": "name-{{item.id}}", "props": {"text": "{{item.name}}", "fontSize": 16, "fontWeight": "bold"}},
                 {"type": "SizedBox", "id": "sb-{{item.id}}", "props": {"height": 4}},
                 {"type": "Text", "id": "desc-{{item.id}}", "props": {"text": "{{item.description}}", "fontSize": 13, "color": "grey"}}
               ]}
             ]}
           ]}
         ]}
       ]}
     ]}
   ]}
 }}
```
IMPORTANT: The "..." values above are placeholders. You MUST call discover_methods first and use the EXACT method names from its output. Do NOT guess method names — even small typos (e.g., "Data" vs "Date") will cause errors.
For CouchDB views with isPublic in the key, use startKey [false, ...] and endKey [true, ...] to include BOTH public and private items.

### Example — single object detail:
```json
{"type": "DataSource", "id": "ds-user",
 "props": {"service": "userService", "method": "get", "args": ["{{context.userId}}"]},
 "children": [{
   "type": "Column", "id": "col-user", "props": {"crossAxisAlignment": "start"},
   "children": [
     {"type": "Text", "id": "user-name", "props": {"text": "{{data.name}}", "fontSize": 20, "fontWeight": "bold"}},
     {"type": "Text", "id": "user-email", "props": {"text": "{{data.email}}", "color": "grey"}}
   ]}
 ]}
```

### Example — hardcoded content (no DataSource):
Static content — just use layout primitives directly:
```json
{"type": "Text", "id": "t-1", "props": {"text": "Welcome to Tercen", "fontSize": 18}}
```

## Layout Operations
To create or modify UI, output a JSON code block with a layout operation. The system parses it and renders it.

### Window operations:
- addWindow: Create a new floating window. Fields: op, id, content, size, align, title
- removeWindow: Close a window. Fields: op, windowId
- updateContent: Replace entire content tree of an existing window. Fields: op, windowId, content

### Sizes: small, medium, large, column, row, full
### Alignments: topLeft, topRight, bottomLeft, bottomRight, center, left, right, top, bottom

### Modifying existing windows
Use get_ui_state to see what windows are on screen. Use their IDs to modify or remove them with updateContent or removeWindow.

### Example — removing a window:
```json
{"op": "removeWindow", "windowId": "win-projects"}
```

## UI Discovery (MCP Tools)
You have additional MCP tools for widget discovery, interactions, and current state:

- **discover_widgets**: Returns installed template widgets (Tier 2). Use these by type name instead of composing from Tier 1 primitives. Always check this first — if a template widget exists for the task, use it.
- **discover_interactions**: Returns gesture actions, event channels, and reactive bindings. Call this when building interactive widgets.
- **get_ui_state**: Returns current user selections and active windows. When the user says "this project" or similar, the answer is here.

Always call discover_widgets first to check if a higher-level widget exists for the user's request.
Call get_ui_state when the user references something they've selected or visible on screen.

## tercenctl MCP Tools
You have access to tercenctl tools (prefixed mcp__tercenctl__) for querying and managing real Tercen data.
Use **search_tools** to discover available tercenctl tools by keyword. Key tools include:
- **execute_jq**: Run jq queries against Tercen's data hierarchy
- **get_model_description**: Get Tercen API model schema
- **patch_object**: Modify Tercen objects
- **create_workflow / run_workflow / reset_workflow**: Workflow lifecycle
- **upload_csv_file / export_table_csv**: Data import/export

## Guidelines
- Keep text responses concise — the chat panel is narrow
- When asked to show or modify UI, respond with a brief explanation AND a layout operation JSON block
- If windows already exist on screen (check via get_ui_state), prefer updateContent over addWindow
- **Always use DataSource for real data** — never hardcode mock data when a service can provide it
- Use discover_services/discover_methods to find the right service and method for the user's request
- Compose widget trees thoughtfully — use Card for items, Padding for spacing, Row/Column for layout
- Every node needs a unique "id" and a "type" — use `{{item.id}}` in IDs for data-driven lists
- Use descriptive window IDs like "win-projects", "win-dashboard" (not timestamps)
- **Always make list items interactive** — call discover_interactions to learn the patterns
''';


/// Active Claude Code process (one conversation at a time for now).
Process? _claudeProcess;

void main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  final router = Router();

  // Health check
  router.get('/api/health', (Request req) => Response.ok('ok'));

  // Widget catalog: GET returns current in-memory catalog,
  // POST adds a catalog to memory.
  router.get('/api/widget-catalog', (Request req) {
    return Response.ok(
      jsonEncode(_fullWidgetCatalog),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Load a widget catalog from a GitHub repo.
  // Body: {"repo": "https://github.com/tercen/test_widget_library", "ref": "main"}
  router.post('/api/widget-catalog/load', (Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final repo = body['repo'] as String;
      final ref = body['ref'] as String? ?? 'main';

      // Convert GitHub URL to raw content URL
      final uri = Uri.parse(repo);
      final segments = uri.pathSegments; // e.g. ['tercen', 'test_widget_library']
      if (segments.length < 2) {
        return Response(400,
          body: jsonEncode({'error': 'Invalid repo URL — expected github.com/owner/repo'}),
          headers: {'Content-Type': 'application/json'});
      }
      final rawUrl = 'https://raw.githubusercontent.com/${segments[0]}/${segments[1]}/$ref/catalog.json';
      print('[catalog] Fetching $rawUrl');

      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(rawUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        httpClient.close();
        return Response(502,
          body: jsonEncode({'error': 'GitHub returned ${response.statusCode} for $rawUrl'}),
          headers: {'Content-Type': 'application/json'});
      }

      final responseBody = await response.transform(utf8.decoder).join();
      httpClient.close();

      final catalog = jsonDecode(responseBody) as Map<String, dynamic>;
      _loadCatalog(catalog);

      final total = (_fullWidgetCatalog['widgets'] as List).length;
      return Response.ok(
        jsonEncode({'status': 'ok', 'total': total}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('[catalog] Load failed: $e');
      return Response(400,
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'});
    }
  });

  // WebSocket: chat channel
  router.all('/ws/chat', webSocketHandler((ws, _) {
    print('[ws/chat] client connected');
    ws.stream.listen(
      (message) {
        print('[ws/chat] received: $message');
        _handleChatMessage(ws.sink, message as String);
      },
      onDone: () => print('[ws/chat] client disconnected'),
    );
  }));

  // WebSocket: UI command channel
  router.all('/ws/ui', webSocketHandler((ws, _) {
    print('[ws/ui] client connected');
    _uiSinks.add(ws.sink);
    ws.stream.listen(
      (message) {
        print('[ws/ui] received: $message');
        try {
          final json = jsonDecode(message as String) as Map<String, dynamic>;
          final type = json['type'] as String?;
          if (type == 'selection') {
            _handleSelectionEvent(json);
          }
        } catch (e) {
          print('[ws/ui] failed to parse message: $e');
        }
      },
      onDone: () {
        print('[ws/ui] client disconnected');
        _uiSinks.remove(ws.sink);
      },
    );
  }));

  // Static files: serve Flutter web build
  final staticHandler = createStaticHandler(
    '../build/web',
    defaultDocument: 'index.html',
  );

  final cascade = Cascade().add(router.call).add(staticHandler).handler;

  final pipeline = Pipeline()
      .addMiddleware(_corsMiddleware())
      .addMiddleware(logRequests())
      .addHandler(cascade);

  final host = Platform.environment['HOST'] ?? '127.0.0.1';
  final server = await io.serve(pipeline, host, port);
  print('Server running on http://${server.address.address}:${server.port}');
}

/// Update user context based on selection events from the frontend.
void _handleSelectionEvent(Map<String, dynamic> event) {
  final channel = event['channel'] as String? ?? '';
  final data = event['data'] as Map<String, dynamic>? ?? {};

  if (channel == 'system.selection.project') {
    _userContext['selectedProjectId'] = data['projectId'];
    _userContext['selectedProjectName'] = data['projectName'];
    // Clear dependent selections when project changes
    _userContext.remove('selectedWorkflowId');
    _userContext.remove('selectedWorkflowName');
  } else if (channel == 'system.selection.workflow') {
    _userContext['selectedWorkflowId'] = data['workflowId'];
    _userContext['selectedWorkflowName'] = data['workflowName'];
  } else {
    // Generic: store all data keys prefixed with channel leaf name
    // e.g., system.selection.file → data keys stored as-is
    data.forEach((key, value) {
      if (!key.startsWith('_')) {
        _userContext[key] = value;
      }
    });
  }

  print('[context] updated: $_userContext');
}

/// Spawn `claude -p` with stream-json and pipe events to the chat WebSocket.
Future<void> _handleChatMessage(dynamic chatSink, String userMessage) async {
  // Kill any previous claude process
  _claudeProcess?.kill();
  _claudeProcess = null;

  try {
    // Find claude binary
    final claudePath = _findClaude();
    if (claudePath == null) {
      chatSink.add(jsonEncode({
        'type': 'error',
        'text': 'Claude CLI not found. Install it: https://claude.ai/code',
      }));
      return;
    }

    print('[claude] spawning: $claudePath -p --output-format stream-json');

    // Remove CLAUDECODE env vars to avoid nesting detection
    final env = Map<String, String>.from(Platform.environment);
    env.remove('CLAUDECODE');
    env.remove('CLAUDE_CODE_SSE_PORT');
    env.remove('CLAUDE_CODE_ENTRYPOINT');

    // Build the prompt with current layout state context
    final prompt = _buildPrompt(userMessage);

    // Resolve the MCP discover server path relative to this script
    final scriptDir = Platform.script.resolve('.').toFilePath();
    final mcpServerPath = '${scriptDir}mcp_discover.dart';

    // Find tercenctl binary
    final tercenctlPath = _findTercenctl();

    // Serialize current UI state for the MCP discover server
    final uiStateJson = jsonEncode({
      'userContext': _userContext,
      'currentWindows': _currentWindows.values.toList(),
    });

    final mcpConfig = jsonEncode({
      'mcpServers': {
        'tercen': {
          'type': 'stdio',
          'command': 'dart',
          'args': ['run', mcpServerPath],
          'env': {
            'TERCEN_UI_STATE': uiStateJson,
            if (_widgetCatalogMetadata.isNotEmpty)
              'TERCEN_WIDGET_CATALOG': jsonEncode(_widgetCatalogMetadata),
          },
        },
        if (tercenctlPath != null)
          'tercenctl': {
            'type': 'stdio',
            'command': tercenctlPath,
            'args': ['mcp', '--transport', 'stdio'],
          },
      },
    });

    final args = [
      '-p', prompt,
      '--output-format', 'stream-json',
      '--verbose',
      '--mcp-config', mcpConfig,
      '--allowedTools', 'mcp__tercen__*,mcp__tercenctl__*',
      '--system-prompt', _systemPrompt,
    ];
    print('[claude] args: $args');

    final process = await Process.start(
      claudePath,
      args,
      environment: env,
    );
    _claudeProcess = process;
    print('[claude] pid: ${process.pid}');

    // Close stdin — otherwise claude waits for input and never starts.
    await process.stdin.close();

    // Accumulate text for the final assistant message
    final textBuffer = StringBuffer();
    // Track whether we're inside a ```json code block (to hide from chat)
    final jsonBlockFilter = _JsonBlockFilter();

    // Stream stdout line-by-line
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      print('[claude stdout] $line');
      if (line.trim().isEmpty) return;

      Map<String, dynamic> json;
      try {
        json = jsonDecode(line) as Map<String, dynamic>;
      } catch (e) {
        print('[claude] non-json line: $line');
        return;
      }

      _processStreamEvent(json, chatSink, textBuffer, jsonBlockFilter);

      // Workaround: stream-json hangs after completion (known bug).
      // Kill the process when we see the result event.
      final type = json['type'] as String?;
      if (type == 'result') {
        print('[claude] got result event, killing process');
        process.kill();
      }
    });

    // Log stderr
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      print('[claude stderr] $line');
    });

    // Wait for exit
    final exitCode = await process.exitCode;
    _claudeProcess = null;
    print('[claude] exited with code $exitCode (pid: ${process.pid})');

    // Send final done signal
    chatSink.add(jsonEncode({
      'type': 'done',
      'exitCode': exitCode,
    }));
  } catch (e, st) {
    print('[claude] error: $e\n$st');
    chatSink.add(jsonEncode({
      'type': 'error',
      'text': 'Failed to run Claude: $e',
    }));
  }
}

/// Process a single stream-json event from Claude Code.
///
/// Claude Code's `--output-format stream-json` emits these event types:
///   - {"type":"system","subtype":"init",...} — session init (ignore)
///   - {"type":"assistant","message":{"content":[{"type":"text","text":"..."},{"type":"tool_use",...}],...}} — assistant turn
///   - {"type":"user","message":{"content":[{"type":"tool_result",...}],...}} — tool results (ignore)
///   - {"type":"result","result":"...","stop_reason":"end_turn",...} — final result
void _processStreamEvent(
  Map<String, dynamic> json,
  dynamic chatSink,
  StringBuffer textBuffer,
  _JsonBlockFilter jsonBlockFilter,
) {
  final type = json['type'] as String?;

  // Handle the final result event — extract layout ops and send done.
  if (type == 'result') {
    final result = json['result'] as String? ?? textBuffer.toString();
    _extractAndDispatchLayoutOps(result);

    // Send the complete assistant message (stripped of JSON blocks)
    final cleanText = _stripJsonCodeBlocks(textBuffer.toString());
    if (cleanText.trim().isNotEmpty) {
      chatSink.add(jsonEncode({
        'type': 'assistant_message',
        'role': 'assistant',
        'text': cleanText.trim(),
        'stopReason': json['stop_reason'] ?? 'end_turn',
      }));
    }
    return;
  }

  // Handle assistant messages — these contain the actual content blocks.
  if (type == 'assistant') {
    final message = json['message'] as Map<String, dynamic>?;
    if (message == null) return;

    final content = message['content'] as List<dynamic>?;
    if (content == null) return;

    for (final block in content) {
      if (block is! Map<String, dynamic>) continue;
      final blockType = block['type'] as String?;

      if (blockType == 'thinking') {
        // Notify frontend that Claude is thinking
        chatSink.add(jsonEncode({'type': 'thinking'}));
      } else if (blockType == 'text') {
        final text = block['text'] as String? ?? '';
        if (text.isEmpty) continue;
        textBuffer.write(text);

        // Filter out ```json...``` blocks — only forward visible text
        final visible = jsonBlockFilter.feed(text);
        if (visible.isNotEmpty) {
          chatSink.add(jsonEncode({
            'type': 'text_delta',
            'text': visible,
          }));
        }
      } else if (blockType == 'tool_use') {
        final toolName = block['name'] as String? ?? '';
        final toolId = block['id'] as String? ?? '';
        // Notify frontend a tool call started
        chatSink.add(jsonEncode({
          'type': 'tool_start',
          'toolId': toolId,
          'toolName': toolName,
        }));
      }
    }
    return;
  }

  // Handle tool results — mark tool as done.
  if (type == 'user') {
    final message = json['message'] as Map<String, dynamic>?;
    if (message == null) return;

    final content = message['content'] as List<dynamic>?;
    if (content == null) return;

    for (final block in content) {
      if (block is! Map<String, dynamic>) continue;
      if (block['type'] == 'tool_result') {
        final toolId = block['tool_use_id'] as String? ?? '';
        final isError = block['is_error'] == true;
        chatSink.add(jsonEncode({
          'type': 'tool_end',
          'toolId': toolId,
          'toolName': '', // tool name not available in result event
          'isError': isError,
        }));
      }
    }
    return;
  }

  // Ignore system, rate_limit_event, etc.
}

/// Find the claude binary.
String? _findClaude() {
  // Check common locations
  final candidates = [
    '/home/${Platform.environment['USER']}/.local/bin/claude',
    '/usr/local/bin/claude',
    '/usr/bin/claude',
  ];

  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }

  // Try PATH via `which`
  try {
    final result = Process.runSync('which', ['claude']);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
  } catch (_) {}

  return null;
}

/// Find the tercenctl binary.
String? _findTercenctl() {
  final candidates = [
    '/home/${Platform.environment['USER']}/.local/bin/tercenctl',
    '/usr/local/bin/tercenctl',
    '/usr/bin/tercenctl',
  ];

  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }

  try {
    final result = Process.runSync('which', ['tercenctl']);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
  } catch (_) {}

  return null;
}

/// Load a widget catalog into server memory (metadata for AI + full catalog for frontend).
void _loadCatalog(Map<String, dynamic> catalog) {
  final widgets = catalog['widgets'] as List<dynamic>? ?? [];
  final allWidgets = <Map<String, dynamic>>[];

  for (final w in widgets) {
    if (w is Map<String, dynamic>) {
      allWidgets.add(w);
      if (w['metadata'] != null) {
        _widgetCatalogMetadata.add(w['metadata'] as Map<String, dynamic>);
      }
    }
  }

  // Merge into the in-memory catalog
  final existing = _fullWidgetCatalog['widgets'] as List<dynamic>? ?? [];
  _fullWidgetCatalog = {'widgets': [...existing, ...allWidgets]};
  print('[catalog] Loaded ${widgets.length} widget(s), total: ${(existing.length + allWidgets.length)}');
}

/// CORS middleware — allows the Flutter dev server (different port) to call API endpoints.
Middleware _corsMiddleware() {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  return (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }
      final response = await handler(request);
      return response.change(headers: corsHeaders);
    };
  };
}

/// Build the prompt. State is now discoverable via get_ui_state MCP tool.
String _buildPrompt(String userMessage) {
  return userMessage;
}

/// Extract JSON code blocks from Claude's response and dispatch as layout ops.
void _extractAndDispatchLayoutOps(String text) {
  final pattern = RegExp(r'```json\s*\n([\s\S]*?)\n```');
  for (final match in pattern.allMatches(text)) {
    final jsonStr = match.group(1)?.trim();
    if (jsonStr == null) continue;

    try {
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (parsed.containsKey('op')) {
        final op = parsed['op'] as String;
        print('[layout] dispatching op: $op');

        // Track window state
        if (op == 'addWindow') {
          final id = parsed['id'] as String;
          _currentWindows[id] = parsed;
        } else if (op == 'removeWindow') {
          _currentWindows.remove(parsed['windowId']);
        } else if (op == 'updateContent') {
          final id = parsed['windowId'] as String;
          if (_currentWindows.containsKey(id)) {
            _currentWindows[id]!['content'] = parsed['content'];
          }
        }

        for (final sink in _uiSinks) {
          sink.add(jsonEncode(parsed));
        }
      }
    } catch (e) {
      print('[layout] failed to parse JSON block: $e');
    }
  }
}

/// Remove JSON code blocks from text for clean chat display.
String _stripJsonCodeBlocks(String text) {
  return text.replaceAll(RegExp(r'```json\s*\n[\s\S]*?\n```'), '').trim();
}

/// Filters out ```json...``` code blocks from a stream of text chunks.
///
/// Text arrives in small deltas (e.g. "Here", "'s a ", "```", "json\n{...").
/// This class tracks whether we're inside a JSON code block and suppresses
/// those chunks so the user only sees the prose.
class _JsonBlockFilter {
  final StringBuffer _pending = StringBuffer();
  bool _insideBlock = false;

  /// Feed a text chunk, returns the portion that should be shown to the user.
  String feed(String chunk) {
    final output = StringBuffer();

    for (int i = 0; i < chunk.length; i++) {
      final char = chunk[i];
      _pending.write(char);
      final buf = _pending.toString();

      if (_insideBlock) {
        // Look for closing ```
        if (buf.endsWith('```')) {
          _insideBlock = false;
          _pending.clear();
        }
      } else {
        // Look for opening ```json or ```JSON
        if (buf.endsWith('```json') || buf.endsWith('```JSON')) {
          _insideBlock = true;
          // Remove the ```json marker from output — take everything before it
          final marker = buf.endsWith('```json') ? '```json' : '```JSON';
          final before = buf.substring(0, buf.length - marker.length);
          output.write(before);
          _pending.clear();
        } else if (buf.endsWith('```')) {
          // Could be start of ```json — wait for more chars
          // Don't flush yet, keep buffering
        } else if (!_couldBeMarker(buf)) {
          // No chance this is a marker prefix — flush the buffer
          output.write(buf);
          _pending.clear();
        }
      }
    }

    return output.toString();
  }

  /// Check if the buffer could be the start of a ```json marker.
  bool _couldBeMarker(String buf) {
    const marker = '```json';
    const markerUpper = '```JSON';
    // Check if buf ends with a prefix of the marker
    for (int len = 1; len <= marker.length && len <= buf.length; len++) {
      final suffix = buf.substring(buf.length - len);
      if (marker.startsWith(suffix) || markerUpper.startsWith(suffix)) {
        return true;
      }
    }
    return false;
  }
}
