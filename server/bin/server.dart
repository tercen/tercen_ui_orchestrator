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
These are the Flutter primitives you can compose:
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

## Data-Driven Widgets (dataSource)

Any node in the widget tree can include a `dataSource` field to load real data from Tercen services. The widget fetches the data and renders its children as templates with bindings.

### dataSource field
```json
"dataSource": {"service": "projectService", "method": "findByIsPublicAndLastModifiedDate", "args": [[true, "0000"], [true, "9999"], 20]}
```
The args for find methods are: [startKey, endKey, limit]. Keys are arrays matching the view's index fields.
IMPORTANT: To list projects, always use findByIsPublicAndLastModifiedDate — do NOT use explore (it returns empty results).

### Template bindings
- **List result** → children are repeated for each item. Use `{{item.fieldName}}` to bind fields.
- **Single object result** → Use `{{data.fieldName}}` to bind fields.
- Simple dot path: `{{item.acl.owner}}`, `{{data.lastModifiedDate.value}}`
- JSONPath (for arrays/filters): `{{item:\$.steps[0].name}}`, `{{item:\$.tags[?@.id=="x"].value}}`
  (Use double quotes inside JSONPath filter expressions)
- Bindings work in props and in node IDs (for uniqueness).
- Note: object IDs are in the `id` field. Null values render as empty string.

### Example — list of projects from real data:
```json
{"op": "addWindow", "id": "win-projects", "size": "medium", "align": "center", "title": "Projects",
 "content": {
   "type": "ListView", "id": "lv-projects", "props": {"padding": 12},
   "dataSource": {"service": "projectService", "method": "findByIsPublicAndLastModifiedDate", "args": [[true, "0000"], [true, "9999"], 20]},
   "children": [
     {"type": "Card", "id": "card-{{item.id}}", "props": {"elevation": 2}, "children": [
       {"type": "Padding", "id": "pad-{{item.id}}", "props": {"padding": 14}, "children": [
         {"type": "Column", "id": "col-{{item.id}}", "props": {"crossAxisAlignment": "start"}, "children": [
           {"type": "Text", "id": "name-{{item.id}}", "props": {"text": "{{item.name}}", "fontSize": 16, "fontWeight": "bold"}},
           {"type": "SizedBox", "id": "sb-{{item.id}}", "props": {"height": 4}},
           {"type": "Text", "id": "desc-{{item.id}}", "props": {"text": "{{item.description}}", "fontSize": 13, "color": "grey"}}
         ]}
       ]}
     ]}
   ]
 }}
```

### Example — single object detail:
```json
{"type": "Card", "id": "user-profile",
 "dataSource": {"service": "userService", "method": "get", "args": ["{{context.userId}}"]},
 "children": [
   {"type": "Text", "id": "user-name", "props": {"text": "{{data.name}}", "fontSize": 20, "fontWeight": "bold"}},
   {"type": "Text", "id": "user-email", "props": {"text": "{{data.email}}", "color": "grey"}}
 ]}
```

### Example — hardcoded content (no dataSource):
Widgets without `dataSource` work as before — static content with hardcoded values:
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

### Current Layout
If a <current_layout> block is present in the user message, it describes the windows currently on screen. Use their IDs to modify or remove them with updateContent or removeWindow.

### Example — removing a window:
```json
{"op": "removeWindow", "windowId": "win-projects"}
```

## Guidelines
- Keep text responses concise — the chat panel is narrow
- When asked to show or modify UI, respond with a brief explanation AND a layout operation JSON block
- If windows already exist on screen (shown in <current_layout>), prefer updateContent over addWindow
- **Always use dataSource for real data** — never hardcode mock data when a service can provide it
- Use discover_services/discover_methods to find the right service and method for the user's request
- Compose widget trees thoughtfully — use Card for items, Padding for spacing, Row/Column for layout
- Every node needs a unique "id" and a "type" — use `{{item.id}}` in IDs for data-driven lists
- Use descriptive window IDs like "win-projects", "win-dashboard" (not timestamps)
''';


/// Active Claude Code process (one conversation at a time for now).
Process? _claudeProcess;

void main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  final router = Router();

  // Health check
  router.get('/api/health', (Request req) => Response.ok('ok'));

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
      (message) => print('[ws/ui] received: $message'),
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

  final pipeline =
      Pipeline().addMiddleware(logRequests()).addHandler(cascade);

  final server = await io.serve(pipeline, '0.0.0.0', port);
  print('Server running on http://localhost:${server.port}');
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

    final mcpConfig = jsonEncode({
      'mcpServers': {
        'tercen': {
          'type': 'stdio',
          'command': 'dart',
          'args': ['run', mcpServerPath],
        },
      },
    });

    final args = [
      '-p', prompt,
      '--output-format', 'stream-json',
      '--verbose',
      '--mcp-config', mcpConfig,
      '--allowedTools', 'mcp__tercen__*',
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

/// Build the prompt with current layout state prepended.
String _buildPrompt(String userMessage) {
  if (_currentWindows.isEmpty) return userMessage;

  // Summarize current windows for Claude
  final windowSummaries = _currentWindows.entries.map((e) {
    final w = e.value;
    return jsonEncode({
      'id': w['id'],
      'title': w['title'],
      'size': w['size'],
      'content': w['content'],
    });
  }).join('\n');

  return '''
<current_layout>
$windowSummaries
</current_layout>

$userMessage''';
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
