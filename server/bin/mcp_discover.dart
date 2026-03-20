import 'dart:convert';
import 'dart:io';

/// Lightweight MCP server (JSON-RPC 2.0 over stdio) that exposes
/// Tercen service/interaction discovery tools to Claude Code.
///
/// Tools:
///   - discover_services: List all available Tercen services
///   - discover_methods: List methods for a specific service
///   - discover_interactions: Widget interaction patterns (Action, ReactTo, event channels)
///   - get_ui_state: Current selections and active windows
///
/// Protocol: https://modelcontextprotocol.io/specification

/// UI state passed from server.dart via TERCEN_UI_STATE env var.
/// Contains userContext (selections) and currentWindows (active windows).
late final Map<String, dynamic> _uiState;

void _loadUiState() {
  final raw = Platform.environment['TERCEN_UI_STATE'];
  if (raw != null && raw.isNotEmpty) {
    try {
      _uiState = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _uiState = {};
    }
  } else {
    _uiState = {};
  }
}

/// Widget catalog metadata passed from server.dart via TERCEN_WIDGET_CATALOG env var.
late final List<dynamic> _widgetCatalog;

void _loadWidgetCatalog() {
  final raw = Platform.environment['TERCEN_WIDGET_CATALOG'];
  if (raw != null && raw.isNotEmpty) {
    try {
      _widgetCatalog = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      _widgetCatalog = [];
    }
  } else {
    _widgetCatalog = [];
  }
}

void main() {
  _loadUiState();
  _loadWidgetCatalog();

  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (line.trim().isEmpty) return;

    try {
      final request = jsonDecode(line) as Map<String, dynamic>;
      final response = _handleRequest(request);
      if (response != null) {
        stdout.writeln(jsonEncode(response));
      }
    } catch (e) {
      stderr.writeln('[mcp_discover] error: $e');
    }
  });
}

Map<String, dynamic>? _handleRequest(Map<String, dynamic> request) {
  final method = request['method'] as String?;
  final id = request['id'];

  switch (method) {
    case 'initialize':
      return _jsonRpcResult(id, {
        'protocolVersion': '2024-11-05',
        'capabilities': {
          'tools': {},
        },
        'serverInfo': {
          'name': 'tercen-discover',
          'version': '1.0.0',
        },
      });

    case 'notifications/initialized':
      // Client ack — no response needed
      return null;

    case 'tools/list':
      return _jsonRpcResult(id, {
        'tools': [
          {
            'name': 'discover_services',
            'description':
                'List all available Tercen API services with descriptions. '
                    'Call this first to understand what data you can access.',
            'inputSchema': {
              'type': 'object',
              'properties': {},
            },
          },
          {
            'name': 'discover_methods',
            'description':
                'Get detailed method signatures for a specific Tercen service. '
                    'Returns method names, parameters, and return types.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'service': {
                  'type': 'string',
                  'description': 'Service name (e.g. "projectService")',
                },
              },
              'required': ['service'],
            },
          },
          {
            'name': 'discover_interactions',
            'description':
                'Returns the full catalog of SDUI widget interaction patterns: '
                    'gesture actions (onTap/onDoubleTap/onLongPress), event channels, '
                    'Action and ReactTo widget usage, and event channels. '
                    'Call this when building interactive widgets.',
            'inputSchema': {
              'type': 'object',
              'properties': {},
            },
          },
          {
            'name': 'get_ui_state',
            'description':
                'Returns the current UI state: user selections (selected project, '
                    'workflow, etc.) and active windows on screen. '
                    'Call this to understand what the user sees and has selected.',
            'inputSchema': {
              'type': 'object',
              'properties': {},
            },
          },
          {
            'name': 'discover_widgets',
            'description':
                'Returns the catalog of installed template widgets (Tier 2). '
                    'These are higher-level widgets that compose Tier 1 primitives. '
                    'Use them by type name instead of building from scratch.',
            'inputSchema': {
              'type': 'object',
              'properties': {},
            },
          },
        ],
      });

    case 'tools/call':
      final params = request['params'] as Map<String, dynamic>?;
      final toolName = params?['name'] as String?;
      final toolArgs =
          params?['arguments'] as Map<String, dynamic>? ?? {};

      switch (toolName) {
        case 'discover_services':
          return _jsonRpcResult(id, {
            'content': [
              {
                'type': 'text',
                'text': _discoverServices(),
              }
            ],
          });

        case 'discover_methods':
          final service = toolArgs['service'] as String?;
          if (service == null) {
            return _jsonRpcError(id, -32602, 'Missing "service" parameter');
          }
          final result = _discoverMethods(service);
          if (result == null) {
            return _jsonRpcResult(id, {
              'content': [
                {
                  'type': 'text',
                  'text': 'Service "$service" not found. '
                      'Call discover_services to see available services.',
                }
              ],
              'isError': true,
            });
          }
          return _jsonRpcResult(id, {
            'content': [
              {
                'type': 'text',
                'text': result,
              }
            ],
          });

        case 'discover_interactions':
          return _jsonRpcResult(id, {
            'content': [
              {'type': 'text', 'text': _discoverInteractions()}
            ],
          });

        case 'get_ui_state':
          return _jsonRpcResult(id, {
            'content': [
              {'type': 'text', 'text': _getUiState()}
            ],
          });

        case 'discover_widgets':
          return _jsonRpcResult(id, {
            'content': [
              {'type': 'text', 'text': _discoverWidgets()}
            ],
          });

        default:
          return _jsonRpcError(id, -32601, 'Unknown tool: $toolName');
      }

    default:
      // Unknown method — return error for requests with id, ignore notifications
      if (id != null) {
        return _jsonRpcError(id, -32601, 'Method not found: $method');
      }
      return null;
  }
}

// -- Tool implementations --

String _discoverServices() {
  final buf = StringBuffer();
  buf.writeln('# Tercen API Services');
  buf.writeln();
  buf.writeln('All services share base CRUD methods:');
  buf.writeln('  get(id) → object');
  buf.writeln('  list(ids) → List<object>');
  buf.writeln('  create(object) → object');
  buf.writeln('  update(object) → revision string');
  buf.writeln('  delete(id, rev)');
  buf.writeln('  findStartKeys(viewName, {startKey, endKey, limit, skip, descending}) → List<object>');
  buf.writeln('  findKeys(viewName, {keys}) → List<object>');
  buf.writeln();
  buf.writeln('Call discover_methods(service) for service-specific methods.');
  buf.writeln();

  for (final entry in _serviceCatalog.entries) {
    buf.writeln('- ${entry.key}: ${entry.value['description']}');
    final extras = entry.value['extras'] as List?;
    if (extras != null && extras.isNotEmpty) {
      buf.writeln('  Extra methods: ${extras.map((e) => (e as Map)['name']).join(', ')}');
    }
  }

  return buf.toString();
}

String? _discoverMethods(String service) {
  final info = _serviceCatalog[service];
  if (info == null) return null;

  final buf = StringBuffer();
  buf.writeln('# $service');
  buf.writeln();
  buf.writeln('${info['description']}');
  buf.writeln('Entity type: ${info['entity']}');
  buf.writeln();
  buf.writeln('## Base CRUD methods (inherited)');
  buf.writeln('  get(String id) → ${info['entity']}');
  buf.writeln('  list(List<String> ids) → List<${info['entity']}>');
  buf.writeln('  create(${info['entity']} object) → ${info['entity']}');
  buf.writeln('  update(${info['entity']} object) → String (revision)');
  buf.writeln('  delete(String id, String rev)');
  buf.writeln('  findStartKeys(String viewName, {startKey, endKey, int limit=20, int skip=0, bool descending=true}) → List<${info['entity']}>');
  buf.writeln('  findKeys(String viewName, {List keys}) → List<${info['entity']}>');
  buf.writeln();
  buf.writeln('## Named find methods (CouchDB views)');
  buf.writeln('There are TWO call patterns — check the view definition below:');
  buf.writeln();
  buf.writeln('**findStartKeys pattern** (range query, views with "startKey/endKey"):');
  buf.writeln('  args: [startKey, endKey, limit?, skip?, descending?]');
  buf.writeln('  Keys are arrays matching the view index fields.');
  buf.writeln('  Example: args: [[false, ""], [true, "\\uf000"], 20]');
  buf.writeln();
  buf.writeln('**findKeys pattern** (key lookup, views with "keys"):');
  buf.writeln('  args: [[key1, key2, ...]]  — a SINGLE list wrapping the lookup keys');
  buf.writeln('  Example: args: [["owner-username"]]');
  buf.writeln();
  buf.writeln('Each view below is marked (startKeys) or (keys) to indicate which pattern.');
  buf.writeln('Object IDs are in the "id" field.');
  buf.writeln();

  final extras = info['extras'] as List?;
  if (extras != null && extras.isNotEmpty) {
    buf.writeln('## Service-specific methods');
    for (final method in extras) {
      final m = method as Map<String, dynamic>;
      buf.writeln('  ${m['signature']}');
      if (m['description'] != null) {
        buf.writeln('    ${m['description']}');
      }
    }
  }

  final views = info['views'] as List?;
  if (views != null && views.isNotEmpty) {
    buf.writeln();
    buf.writeln('## Named views (for findStartKeys/findKeys)');
    for (final view in views) {
      if (view is Map) {
        final type = view['type'] ?? 'startKeys';
        buf.writeln('  - ${view['name']} ($type)');
        if (view['keys'] != null) buf.writeln('    Keys: ${view['keys']}');
        if (view['example'] != null) buf.writeln('    Example: ${view['example']}');
      } else {
        buf.writeln('  - $view');
      }
    }
  }

  return buf.toString();
}

// -- Interaction discovery --

String _discoverInteractions() {
  final buf = StringBuffer();
  buf.writeln('# SDUI Widget Interactions');
  buf.writeln();
  buf.writeln('## Action Widget');
  buf.writeln('Wrap any widget in an Action node to make it interactive.');
  buf.writeln('Props: gesture (onTap|onDoubleTap|onLongPress|onSecondaryTap), channel, payload');
  buf.writeln();
  buf.writeln('### Example — selectable card:');
  buf.writeln('```json');
  buf.writeln('{"type": "Action", "id": "act-{{item.id}}",');
  buf.writeln(' "props": {"gesture": "onTap", "channel": "system.selection.project",');
  buf.writeln('           "payload": {"projectId": "{{item.id}}", "projectName": "{{item.name}}"}},');
  buf.writeln(' "children": [{"type": "Card", "id": "card-{{item.id}}", ...}]}');
  buf.writeln('```');
  buf.writeln();
  buf.writeln('### Example — nested gestures (tap to select, double-tap to open):');
  buf.writeln('```json');
  buf.writeln('{"type": "Action", "id": "tap-{{item.id}}",');
  buf.writeln(' "props": {"gesture": "onTap", "channel": "system.selection.project", "payload": {"projectId": "{{item.id}}"}},');
  buf.writeln(' "children": [');
  buf.writeln('   {"type": "Action", "id": "dbl-{{item.id}}",');
  buf.writeln('    "props": {"gesture": "onDoubleTap", "channel": "system.layout.op",');
  buf.writeln('              "payload": {"op": "addWindow", "id": "win-{{item.id}}", "title": "{{item.name}}", "size": "medium", "align": "center",');
  buf.writeln('                          "content": {"type": "Text", "id": "t-{{item.id}}", "props": {"text": "Details for {{item.name}}"}}}},');
  buf.writeln('    "children": [{"type": "Card", "id": "card-{{item.id}}", ...}]}');
  buf.writeln(' ]}');
  buf.writeln('```');
  buf.writeln();
  buf.writeln('## ReactTo Widget');
  buf.writeln('Wrap a widget in ReactTo to change its props when an EventBus event matches.');
  buf.writeln('Props: channel, match (object — keys to compare), overrideProps (object — props to merge when matched)');
  buf.writeln();
  buf.writeln('### Example — highlight selected card:');
  buf.writeln('```json');
  buf.writeln('{"type": "ReactTo", "id": "rt-{{item.id}}",');
  buf.writeln(' "props": {"channel": "system.selection.project",');
  buf.writeln('           "match": {"projectId": "{{item.id}}"},');
  buf.writeln('           "overrideProps": {"elevation": 4, "color": "#1565C0"}},');
  buf.writeln(' "children": [{"type": "Card", "id": "card-{{item.id}}", "props": {"elevation": 2}, ...}]}');
  buf.writeln('```');
  buf.writeln();
  buf.writeln('## Event Channels');
  buf.writeln();
  buf.writeln('### Selection Channels (system.selection.*)');
  buf.writeln('| Channel | Payload | Effect |');
  buf.writeln('|---------|---------|--------|');
  buf.writeln('| system.selection.project | {projectId, projectName} | Sets selected project, clears workflow selection |');
  buf.writeln('| system.selection.workflow | {workflowId, workflowName} | Sets selected workflow |');
  buf.writeln('| system.selection.<custom> | {any keys} | All payload keys stored in user context |');
  buf.writeln();
  buf.writeln('### Layout Operation Channel');
  buf.writeln('| Channel | Payload | Effect |');
  buf.writeln('|---------|---------|--------|');
  buf.writeln('| system.layout.op | Full layout operation JSON | Triggers addWindow/removeWindow/updateContent |');
  buf.writeln();
  buf.writeln('## Best Practices');
  buf.writeln('- Wrap list items in Action for selection');
  buf.writeln('- Nest Action > ReactTo > Card for select-and-highlight patterns');
  buf.writeln('- Use onDoubleTap Action with system.layout.op to open detail windows');
  buf.writeln('- Selection channels cascade: selecting a new project clears workflow selection');
  buf.writeln('- Use get_ui_state to check current selections before responding');
  return buf.toString();
}

// -- UI state --

String _getUiState() {
  final buf = StringBuffer();
  buf.writeln('# Current UI State');
  buf.writeln();

  final userContext =
      _uiState['userContext'] as Map<String, dynamic>? ?? {};
  final windows =
      _uiState['currentWindows'] as List<dynamic>? ?? [];

  buf.writeln('## User Selections');
  if (userContext.isEmpty) {
    buf.writeln('No active selections.');
  } else {
    for (final entry in userContext.entries) {
      buf.writeln('- ${entry.key}: ${entry.value}');
    }
  }
  buf.writeln();

  buf.writeln('## Active Windows');
  if (windows.isEmpty) {
    buf.writeln('No windows on screen.');
  } else {
    for (final w in windows) {
      if (w is Map<String, dynamic>) {
        buf.writeln('- id: ${w['id']}, title: ${w['title']}, size: ${w['size']}');
        // Include content summary (type of root node) not the full tree
        final content = w['content'];
        if (content is Map<String, dynamic>) {
          buf.writeln('  root widget: ${content['type']} (id: ${content['id']})');
        }
      }
    }
  }

  return buf.toString();
}

// -- Widget catalog --

String _discoverWidgets() {
  final buf = StringBuffer();
  buf.writeln('# Installed Template Widgets');
  buf.writeln();
  buf.writeln('These are higher-level widgets you can use by type name.');
  buf.writeln('They compose Tier 1 primitives internally — just provide the type and props.');
  buf.writeln();

  if (_widgetCatalog.isEmpty) {
    buf.writeln('No template widgets installed.');
    return buf.toString();
  }

  for (final widget in _widgetCatalog) {
    if (widget is! Map<String, dynamic>) continue;
    final type = widget['type'] ?? 'unknown';
    final description = widget['description'] ?? '';
    final tier = widget['tier'] ?? 2;
    buf.writeln('## $type (Tier $tier)');
    buf.writeln(description);
    buf.writeln();

    final props = widget['props'] as Map<String, dynamic>?;
    if (props != null && props.isNotEmpty) {
      buf.writeln('Props:');
      for (final entry in props.entries) {
        final spec = entry.value;
        if (spec is Map<String, dynamic>) {
          final type = spec['type'] ?? 'any';
          final required = spec['required'] == true ? ' (required)' : '';
          final def = spec['default'] != null ? ', default: ${spec['default']}' : '';
          final desc = spec['description'] != null ? ' — ${spec['description']}' : '';
          buf.writeln('  - ${entry.key}: $type$required$def$desc');
        }
      }
      buf.writeln();
    }

    final events = widget['emittedEvents'] as List<dynamic>?;
    if (events != null && events.isNotEmpty) {
      buf.writeln('Emits: ${events.join(', ')}');
    }

    final actions = widget['acceptedActions'] as List<dynamic>?;
    if (actions != null && actions.isNotEmpty) {
      buf.writeln('Gestures: ${actions.join(', ')}');
    }

    buf.writeln();
    buf.writeln('Usage: `{"type": "$type", "id": "my-$type", "props": {...}}`');
    buf.writeln();
  }

  return buf.toString();
}

// -- Service catalog --
// Generated from sci_tercen_client service definitions.

final _serviceCatalog = <String, Map<String, dynamic>>{
  'projectService': {
    'description': 'Manage Tercen projects (CRUD, explore, clone)',
    'entity': 'Project',
    'extras': [
      // explore is unreliable on some server versions — use findByIsPublicAndLastModifiedDate instead
      {
        'name': 'recentProjects',
        'signature': 'recentProjects(String userId) → List<Project>',
        'description': 'Get recently accessed projects for a user',
      },
      {
        'name': 'cloneProject',
        'signature': 'cloneProject(String projectId, Project project) → Project',
        'description': 'Clone an entire project',
      },
      {
        'name': 'profiles',
        'signature': 'profiles(String projectId) → Profiles',
        'description': 'Get project member profiles',
      },
      {
        'name': 'resourceSummary',
        'signature': 'resourceSummary(String projectId) → ResourceSummary',
        'description': 'Get project resource usage summary',
      },
    ],
    'views': [
      {
        'name': 'findByIsPublicAndLastModifiedDate', 'type': 'startKeys',
        'keys': '[isPublic: bool, lastModifiedDate: string]',
        'example': 'args: [[false, ""], [true, "\\uf000"], 20] — gets all projects (public + private)',
      },
      {
        'name': 'findByTeamAndIsPublicAndLastModifiedDate', 'type': 'startKeys',
        'keys': '[owner: string, isPublic: bool, lastModifiedDate: string]',
        'example': 'args: [["teamName", false, ""], ["teamName", true, "\\uf000"], 20]',
      },
    ],
  },

  'workflowService': {
    'description': 'Manage Tercen workflows (computational pipelines)',
    'entity': 'Workflow',
    'extras': [
      {
        'name': 'getCubeQuery',
        'signature': 'getCubeQuery(String workflowId, String stepId) → CubeQuery',
        'description': 'Get the cube query for a workflow step',
      },
      {
        'name': 'copyApp',
        'signature': 'copyApp(String workflowId, String projectId) → Workflow',
        'description': 'Copy a workflow/app to another project',
      },
    ],
  },

  'userService': {
    'description': 'User management, authentication, profiles',
    'entity': 'User',
    'extras': [
      {
        'name': 'connect',
        'signature': 'connect(String usernameOrEmail, String password) → UserSession',
        'description': 'Authenticate user',
      },
      {
        'name': 'createUser',
        'signature': 'createUser(User user, String password) → User',
      },
      {
        'name': 'createToken',
        'signature': 'createToken(String userId, int validityInSeconds) → String',
        'description': 'Create auth token',
      },
      {
        'name': 'profiles',
        'signature': 'profiles(String userId) → Profiles',
      },
      {
        'name': 'getServerVersion',
        'signature': 'getServerVersion(String module) → Version',
      },
      {
        'name': 'getClientConfig',
        'signature': 'getClientConfig(List<String> keys) → List<Pair>',
      },
    ],
    'views': [
      {'name': 'findUserByCreatedDateAndName', 'type': 'startKeys', 'keys': '[createdDate: string, name: string]'},
      {'name': 'findUserByEmail', 'type': 'keys', 'keys': '[email: string]',
       'example': 'args: [["user@example.com"]]'},
      {'name': 'findTeamMembers', 'type': 'keys', 'keys': '[teamId: string]',
       'example': 'args: [["team-id"]]'},
    ],
  },

  'teamService': {
    'description': 'Team management and membership',
    'entity': 'Team',
    'extras': [
      {
        'name': 'profiles',
        'signature': 'profiles(String teamId) → Profiles',
        'description': 'Get team member profiles',
      },
      {
        'name': 'resourceSummary',
        'signature': 'resourceSummary(String teamId) → ResourceSummary',
      },
    ],
    'views': [
      {'name': 'findTeamByOwner', 'type': 'keys', 'keys': '[owner: userId]',
       'example': 'args: [["{{context.userId}}"]] — owner is a userId, not username'},
    ],
  },

  'fileService': {
    'description': 'File upload, download, and management',
    'entity': 'FileDocument',
    'extras': [
      {
        'name': 'upload',
        'signature': 'upload(FileDocument file, Stream<List> bytes) → FileDocument',
      },
      {
        'name': 'append',
        'signature': 'append(FileDocument file, Stream<List> bytes) → FileDocument',
      },
      {
        'name': 'download',
        'signature': 'download(String fileDocumentId) → Stream<List<int>>',
      },
      {
        'name': 'listZipContents',
        'signature': 'listZipContents(String fileDocumentId) → List<ZipEntry>',
      },
      {
        'name': 'downloadZipEntry',
        'signature': 'downloadZipEntry(String fileDocumentId, String entryPath) → Stream<List<int>>',
      },
    ],
    'views': [
      {'name': 'findFileByWorkflowIdAndStepId', 'type': 'startKeys', 'keys': '[workflowId: string, stepId: string]'},
      {'name': 'findByDataUri', 'type': 'startKeys', 'keys': '[dataUri: string]'},
    ],
  },

  'taskService': {
    'description': 'Task execution, monitoring, and cancellation',
    'entity': 'Task',
    'extras': [
      {
        'name': 'runTask',
        'signature': 'runTask(String taskId) → void',
        'description': 'Start a computation task',
      },
      {
        'name': 'cancelTask',
        'signature': 'cancelTask(String taskId) → void',
        'description': 'Cancel a running task',
      },
      {
        'name': 'waitDone',
        'signature': 'waitDone(String taskId) → Task',
        'description': 'Wait for task completion',
      },
      {
        'name': 'getWorkers',
        'signature': 'getWorkers(List<String> names) → List<Worker>',
      },
      {
        'name': 'getTasks',
        'signature': 'getTasks(List<String> names) → List<Task>',
      },
    ],
    'views': [
      {'name': 'findByHash', 'type': 'startKeys', 'keys': '[taskHash: string]'},
      {'name': 'findGCTaskByLastModifiedDate', 'type': 'startKeys', 'keys': '[removeOnGC: bool, lastModifiedDate: string]'},
    ],
  },

  'tableSchemaService': {
    'description': 'Data table schemas and table data access',
    'entity': 'Schema',
    'extras': [
      {
        'name': 'select',
        'signature': 'select(String tableId, List<String> cnames, int offset, int limit) → Table',
        'description': 'Query table data by column names with pagination',
      },
      {
        'name': 'selectCSV',
        'signature': 'selectCSV(String tableId, List<String> cnames, int offset, int limit, String separator, bool quote, String encoding) → Stream<List<int>>',
        'description': 'Export table data as CSV stream',
      },
      {
        'name': 'uploadTable',
        'signature': 'uploadTable(FileDocument file, Stream<List> bytes) → Schema',
      },
    ],
    'views': [
      {'name': 'findSchemaByDataDirectory', 'type': 'startKeys', 'keys': '[dataDirectory: string]'},
    ],
  },

  'operatorService': {
    'description': 'Tercen operators (computational modules)',
    'entity': 'Operator',
    'extras': [],
  },

  'eventService': {
    'description': 'Real-time event channels and task monitoring',
    'entity': 'Event',
    'extras': [
      {
        'name': 'channel',
        'signature': 'channel(String name) → Stream<Event>',
        'description': 'Subscribe to a named event channel',
      },
      {
        'name': 'sendChannel',
        'signature': 'sendChannel(String channel, Event evt) → void',
        'description': 'Publish event to a channel',
      },
      {
        'name': 'listenTaskChannel',
        'signature': 'listenTaskChannel(String taskId, bool start) → Stream<TaskEvent>',
      },
    ],
    'views': [
      {'name': 'findByChannelAndDate', 'type': 'startKeys', 'keys': '[channel: string, date: string]'},
    ],
  },

  'documentService': {
    'description': 'Cross-type document search and library browsing',
    'entity': 'Document',
    'extras': [
      {
        'name': 'search',
        'signature': 'search(String query, int limit, bool useFactory, String bookmark) → SearchResult',
        'description': 'Full-text search across all documents',
      },
      {
        'name': 'getLibrary',
        'signature': 'getLibrary(String projectId, List<String> teamIds, List<String> docTypes, List<String> tags, int offset, int limit) → List<Document>',
        'description': 'Browse the Tercen library (operators, templates, datasets)',
      },
      {
        'name': 'getTercenOperatorLibrary',
        'signature': 'getTercenOperatorLibrary(int offset, int limit) → List<Operator>',
      },
    ],
    'views': [
      {'name': 'findWorkflowByTagOwnerCreatedDate', 'type': 'startKeys', 'keys': '[tag: string, owner: string, createdDate: string]'},
      {'name': 'findProjectByOwnersAndName', 'type': 'startKeys', 'keys': '[owners: string, name: string]'},
      {'name': 'findProjectByOwnersAndCreatedDate', 'type': 'startKeys', 'keys': '[owners: string, createdDate: string]'},
      {'name': 'findOperatorByOwnerLastModifiedDate', 'type': 'startKeys', 'keys': '[owner: string, lastModifiedDate: string]'},
      {'name': 'findOperatorByUrlAndVersion', 'type': 'startKeys', 'keys': '[url: string, version: string]'},
    ],
  },

  'projectDocumentService': {
    'description': 'Documents within a project (files, schemas, workflows)',
    'entity': 'ProjectDocument',
    'extras': [
      {
        'name': 'cloneProjectDocument',
        'signature': 'cloneProjectDocument(String documentId, String projectId) → ProjectDocument',
      },
      {
        'name': 'getParentFolders',
        'signature': 'getParentFolders(String documentId) → List<FolderDocument>',
      },
      {
        'name': 'getFromPath',
        'signature': 'getFromPath(String projectId, String path, bool useFactory) → ProjectDocument',
      },
    ],
    'views': [
      {'name': 'findProjectObjectsByLastModifiedDate', 'type': 'startKeys', 'keys': '[projectId: string, lastModifiedDate: string]'},
      {'name': 'findProjectObjectsByFolderAndName', 'type': 'startKeys', 'keys': '[projectId: string, folderId: string, name: string]'},
      {'name': 'findFileByLastModifiedDate', 'type': 'startKeys', 'keys': '[projectId: string, lastModifiedDate: string]'},
      {'name': 'findSchemaByLastModifiedDate', 'type': 'startKeys', 'keys': '[projectId: string, lastModifiedDate: string]'},
    ],
  },

  'folderService': {
    'description': 'Folder management within projects',
    'entity': 'FolderDocument',
    'extras': [
      {
        'name': 'getOrCreate',
        'signature': 'getOrCreate(String projectId, String path) → FolderDocument',
        'description': 'Get or create a folder at the given path',
      },
    ],
    'views': [
      {'name': 'findFolderByParentFolderAndName', 'type': 'startKeys', 'keys': '[projectId: string, parentFolderId: string, name: string]'},
    ],
  },

  'queryService': {
    'description': 'Advanced data queries including jq expressions',
    'entity': 'PersistentObject',
    'extras': [
      {
        'name': 'jq',
        'signature': 'jq(String expression, int limit) → Stream<String>',
        'description': 'Execute jq query against Tercen data hierarchy (.teams[], .projects[], .workflows[], etc.)',
      },
    ],
    'views': [
      {'name': 'findByOwnerAndKindAndDate', 'type': 'startKeys', 'keys': '[owner: string, kind: string, date: string]'},
      {'name': 'findByOwnerAndProjectAndKindAndDate', 'type': 'startKeys', 'keys': '[owner: string, projectId: string, kind: string, date: string]'},
      {'name': 'findByOwnerAndKind', 'type': 'startKeys', 'keys': '[owner: string, kind: string]'},
      {'name': 'findPublicByKind', 'type': 'startKeys', 'keys': '[isPublic: bool, kind: string]'},
      {'name': 'findByProjectAndKindAndDate', 'type': 'startKeys', 'keys': '[projectId: string, kind: string, date: string]'},
    ],
  },

  'activityService': {
    'description': 'User and team activity tracking',
    'entity': 'Activity',
    'extras': [],
    'views': [
      {'name': 'findByUserAndDate', 'type': 'startKeys', 'keys': '[userId: string, date: string]'},
      {'name': 'findByTeamAndDate', 'type': 'startKeys', 'keys': '[teamId: string, date: string]'},
      {'name': 'findByProjectAndDate', 'type': 'startKeys', 'keys': '[projectId: string, date: string]'},
    ],
  },

  'persistentService': {
    'description': 'Low-level object persistence and dependency tracking',
    'entity': 'PersistentObject',
    'extras': [
      {
        'name': 'summary',
        'signature': 'summary(String teamOrProjectId) → Summary',
      },
      {
        'name': 'getDependentObjects',
        'signature': 'getDependentObjects(String id) → List<PersistentObject>',
      },
      {
        'name': 'createNewIds',
        'signature': 'createNewIds(int n) → List<String>',
      },
    ],
  },
};

// -- JSON-RPC helpers --

Map<String, dynamic> _jsonRpcResult(dynamic id, Map<String, dynamic> result) => {
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    };

Map<String, dynamic> _jsonRpcError(dynamic id, int code, String message) => {
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': message},
    };
