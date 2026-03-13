import 'dart:convert';
import 'dart:io';

/// Lightweight MCP server (JSON-RPC 2.0 over stdio) that exposes
/// Tercen service discovery tools to Claude Code.
///
/// Tools:
///   - discover_services: List all available Tercen services
///   - discover_methods: List methods for a specific service
///
/// Protocol: https://modelcontextprotocol.io/specification
void main() {
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
  buf.writeln('Any findBy* method can be called directly with args: [startKey, endKey, limit?, skip?, descending?]');
  buf.writeln('Keys are arrays matching the view index fields in order.');
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
      buf.writeln('  - $view');
    }
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
      'findByIsPublicAndLastModifiedDate',
      'findByTeamAndIsPublicAndLastModifiedDate',
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
      'findTeamMembers',
      'findUserByCreatedDateAndName',
      'findUserByEmail',
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
      'findTeamByOwner',
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
      'findFileByWorkflowIdAndStepId',
      'findByDataUri',
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
      'findByHash',
      'findGCTaskByLastModifiedDate',
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
      'findSchemaByDataDirectory',
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
      'findByChannelAndDate',
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
      'findWorkflowByTagOwnerCreatedDate',
      'findProjectByOwnersAndName',
      'findProjectByOwnersAndCreatedDate',
      'findOperatorByOwnerLastModifiedDate',
      'findOperatorByUrlAndVersion',
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
      'findProjectObjectsByLastModifiedDate',
      'findProjectObjectsByFolderAndName',
      'findFileByLastModifiedDate',
      'findSchemaByLastModifiedDate',
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
      'findFolderByParentFolderAndName',
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
      'findByOwnerAndKindAndDate',
      'findByOwnerAndProjectAndKindAndDate',
      'findByOwnerAndKind',
      'findPublicByKind',
      'findByProjectAndKindAndDate',
    ],
  },

  'activityService': {
    'description': 'User and team activity tracking',
    'entity': 'Activity',
    'extras': [],
    'views': [
      'findByUserAndDate',
      'findByTeamAndDate',
      'findByProjectAndDate',
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
