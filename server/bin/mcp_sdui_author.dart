import 'dart:convert';
import 'dart:io';

import '../../lib/sdui/archetypes/archetype_expander.dart';
import '../../lib/sdui/archetypes/archetypes.dart';

/// SDUI Authoring MCP server (JSON-RPC 2.0 over stdio).
///
/// Wraps all formal specs and tools for AI-assisted widget generation.
/// The AI calls these tools instead of reading raw spec files.
///
/// Tools:
///   - find_data: Search the OpenAPI spec for operations matching a description
///   - suggest_widget: Generate a widget from an archetype + slot values
///   - get_primitives: List all SDUI primitive widget types with props
///   - get_events: List all EventBus channels with payloads
///   - get_tokens: List all theme tokens (color, textStyle, spacing)
///   - get_intents: List all registered intents with handlers
///   - list_archetypes: List available widget archetypes with slot descriptions
///   - validate: Validate a widget template (delegates to flutter test)
///   - save_to_catalog: Append a widget to catalog.json

late final Map<String, dynamic> _openapiSpec;
late final Map<String, dynamic> _sduiSchema;
late final Map<String, dynamic> _eventSpec;

void _loadSpecs() {
  _openapiSpec = _loadJsonFile(_findSpec('tercen-api.openapi.json'));
  _sduiSchema = _loadJsonFile(_findSpec('sdui-components.schema.json'));
  _eventSpec = _loadJsonFile(_findSpec('sdui-events.json'));
}

Map<String, dynamic> _loadJsonFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('[mcp-sdui] Warning: $path not found');
    return {};
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

String _findSpec(String filename) {
  // Look in common locations relative to various working directories.
  final candidates = [
    '../$filename', // from orchestrator root → sibling
    '../../$filename', // from server/bin/ → repo root sibling
    '../../../$filename', // deeper nesting
    filename, // current directory
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  // Also check via environment variable for absolute path.
  final envDir = Platform.environment['SDUI_SPEC_DIR'];
  if (envDir != null) {
    final envPath = '$envDir/$filename';
    if (File(envPath).existsSync()) return envPath;
  }
  return candidates.first;
}

void main() {
  _loadSpecs();

  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (line.trim().isEmpty) return;
    try {
      final request = jsonDecode(line) as Map<String, dynamic>;
      final response = _handleRequest(request);
      if (response != null) {
        stdout.writeln(jsonEncode(response));
      }
    } catch (e, st) {
      stderr.writeln('[mcp-sdui] error: $e\n$st');
    }
  });
}

Map<String, dynamic>? _handleRequest(Map<String, dynamic> request) {
  final method = request['method'] as String?;
  final id = request['id'];

  switch (method) {
    case 'initialize':
      return _result(id, {
        'protocolVersion': '2024-11-05',
        'capabilities': {'tools': {}},
        'serverInfo': {'name': 'sdui-author', 'version': '1.0.0'},
      });

    case 'notifications/initialized':
      return null;

    case 'tools/list':
      return _result(id, {'tools': _toolDefinitions()});

    case 'tools/call':
      final params = request['params'] as Map<String, dynamic>? ?? {};
      final toolName = params['name'] as String? ?? '';
      final args = params['arguments'] as Map<String, dynamic>? ?? {};
      return _callTool(id, toolName, args);

    default:
      return _error(id, -32601, 'Method not found: $method');
  }
}

Map<String, dynamic> _callTool(
    dynamic id, String toolName, Map<String, dynamic> args) {
  try {
    final result = switch (toolName) {
      'find_data' => _findData(args),
      'suggest_widget' => _suggestWidget(args),
      'get_primitives' => _getPrimitives(args),
      'get_events' => _getEvents(args),
      'get_tokens' => _getTokens(args),
      'get_intents' => _getIntents(args),
      'list_archetypes' => _listArchetypes(args),
      'save_to_catalog' => _saveToCatalog(args),
      _ => throw ArgumentError('Unknown tool: $toolName'),
    };
    return _result(id, {
      'content': [
        {'type': 'text', 'text': result},
      ],
    });
  } catch (e) {
    return _result(id, {
      'content': [
        {'type': 'text', 'text': 'Error: $e'},
      ],
      'isError': true,
    });
  }
}

// ---------------------------------------------------------------------------
// Tool: find_data
// ---------------------------------------------------------------------------

String _findData(Map<String, dynamic> args) {
  final query = (args['query'] as String? ?? '').toLowerCase();
  if (query.isEmpty) return 'Usage: find_data({query: "search term"})';

  final paths = _openapiSpec['paths'] as Map<String, dynamic>? ?? {};
  final schemas = _openapiSpec['components']?['schemas'] as Map<String, dynamic>? ?? {};

  final matches = <Map<String, dynamic>>[];

  for (final entry in paths.entries) {
    final pathStr = entry.key;
    final ops = entry.value as Map<String, dynamic>;

    for (final opEntry in ops.entries) {
      final op = opEntry.value as Map<String, dynamic>;
      final operationId = op['operationId'] as String? ?? '';
      final summary = op['summary'] as String? ?? '';
      final tags = (op['tags'] as List?)?.join(', ') ?? '';

      if (operationId.toLowerCase().contains(query) ||
          summary.toLowerCase().contains(query) ||
          tags.toLowerCase().contains(query) ||
          pathStr.toLowerCase().contains(query)) {
        // Find response schema.
        String? responseModel;
        final resp200 = op['responses']?['200']?['content']?['application/json']?['schema'];
        if (resp200 != null) {
          if (resp200 is Map) {
            responseModel = resp200['\$ref'] as String? ??
                resp200['items']?['\$ref'] as String?;
          }
        }

        // If we have a response model, get its fields.
        List<String>? fields;
        if (responseModel != null) {
          final modelName = responseModel.split('/').last;
          fields = _getModelFields(schemas, modelName);
        }

        matches.add({
          'path': pathStr,
          'method': opEntry.key.toUpperCase(),
          'operationId': operationId,
          'summary': summary,
          if (op['x-tercen-view-type'] != null)
            'viewType': op['x-tercen-view-type'],
          if (op['x-tercen-key-fields'] != null)
            'keyFields': op['x-tercen-key-fields'],
          if (responseModel != null) 'responseModel': responseModel.split('/').last,
          if (fields != null) 'responseFields': fields,
        });
      }
    }
  }

  if (matches.isEmpty) return 'No operations found matching "$query"';
  return const JsonEncoder.withIndent('  ').convert(matches);
}

/// Recursively collect field names from a schema, following allOf inheritance.
List<String> _getModelFields(Map<String, dynamic> schemas, String modelName) {
  final fields = <String>[];
  final schema = schemas[modelName] as Map<String, dynamic>?;
  if (schema == null) return fields;

  // Follow allOf chain for inherited fields.
  final allOf = schema['allOf'] as List?;
  if (allOf != null) {
    for (final part in allOf) {
      if (part is Map) {
        final ref = part['\$ref'] as String?;
        if (ref != null) {
          fields.addAll(_getModelFields(schemas, ref.split('/').last));
        }
        final props = part['properties'] as Map<String, dynamic>?;
        if (props != null) {
          fields.addAll(props.keys.where((k) => k != 'kind'));
        }
      }
    }
  }

  // Direct properties.
  final props = schema['properties'] as Map<String, dynamic>?;
  if (props != null) {
    fields.addAll(props.keys.where((k) => k != 'kind'));
  }

  return fields;
}

// ---------------------------------------------------------------------------
// Tool: suggest_widget
// ---------------------------------------------------------------------------

String _suggestWidget(Map<String, dynamic> args) {
  final archetypeName = args['archetype'] as String? ?? '';
  final widgetType = args['widgetType'] as String? ?? '';
  final description = args['description'] as String?;
  final slots = args['slots'] as Map<String, dynamic>? ?? {};

  if (archetypeName.isEmpty || widgetType.isEmpty) {
    return 'Usage: suggest_widget({archetype: "data-list", widgetType: "MyWidget", slots: {...}})';
  }

  final expander = ArchetypeExpander();
  final result = expander.expand(
    archetypeName: archetypeName,
    widgetType: widgetType,
    description: description,
    slotValues: slots,
  );

  return const JsonEncoder.withIndent('  ').convert(result);
}

// ---------------------------------------------------------------------------
// Tool: get_primitives
// ---------------------------------------------------------------------------

String _getPrimitives(Map<String, dynamic> args) {
  final filter = (args['filter'] as String?)?.toLowerCase();
  final components = _sduiSchema['components'] as Map<String, dynamic>? ?? {};

  final result = <String, dynamic>{};
  for (final entry in components.entries) {
    final meta = entry.value as Map<String, dynamic>;
    if (filter != null) {
      final desc = (meta['description'] as String? ?? '').toLowerCase();
      if (!entry.key.toLowerCase().contains(filter) && !desc.contains(filter)) {
        continue;
      }
    }
    result[entry.key] = meta;
  }

  return const JsonEncoder.withIndent('  ').convert(result);
}

// ---------------------------------------------------------------------------
// Tool: get_events
// ---------------------------------------------------------------------------

String _getEvents(Map<String, dynamic> args) {
  final channels = _eventSpec['channels'] as Map<String, dynamic>? ?? {};
  final patterns = _eventSpec['patterns'] as Map<String, dynamic>? ?? {};

  return const JsonEncoder.withIndent('  ').convert({
    'channels': channels,
    'patterns': patterns,
  });
}

// ---------------------------------------------------------------------------
// Tool: get_tokens
// ---------------------------------------------------------------------------

String _getTokens(Map<String, dynamic> args) {
  final tokens = _sduiSchema['tokens'] as Map<String, dynamic>? ?? {};
  return const JsonEncoder.withIndent('  ').convert(tokens);
}

// ---------------------------------------------------------------------------
// Tool: get_intents
// ---------------------------------------------------------------------------

String _getIntents(Map<String, dynamic> args) {
  final intents = _eventSpec['intents'] as Map<String, dynamic>? ?? {};
  return const JsonEncoder.withIndent('  ').convert(intents);
}

// ---------------------------------------------------------------------------
// Tool: list_archetypes
// ---------------------------------------------------------------------------

String _listArchetypes(Map<String, dynamic> args) {
  final result = <String, dynamic>{};
  for (final entry in archetypes.entries) {
    final a = entry.value;
    final slots = <String, dynamic>{};
    for (final s in a.slots.entries) {
      slots[s.key] = {
        'type': s.value.type,
        'description': s.value.description,
        'required': s.value.required,
        if (s.value.defaultValue != null) 'default': s.value.defaultValue,
      };
    }
    result[entry.key] = {
      'description': a.description,
      'slots': slots,
    };
  }
  return const JsonEncoder.withIndent('  ').convert(result);
}

// ---------------------------------------------------------------------------
// Tool: save_to_catalog
// ---------------------------------------------------------------------------

String _saveToCatalog(Map<String, dynamic> args) {
  final widget = args['widget'] as Map<String, dynamic>?;
  if (widget == null) {
    return 'Usage: save_to_catalog({widget: {metadata: {...}, template: {...}}})';
  }

  // Find catalog.json.
  final candidates = [
    '../../tercen_ui_widgets/catalog.json', // from server/bin/
    '../tercen_ui_widgets/catalog.json',
  ];
  File? catalogFile;
  for (final path in candidates) {
    final f = File(path);
    if (f.existsSync()) {
      catalogFile = f;
      break;
    }
  }

  if (catalogFile == null) {
    return 'Error: catalog.json not found in ${candidates.join(", ")}';
  }

  final catalog =
      jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
  final widgets = catalog['widgets'] as List<dynamic>? ?? [];

  // Check for duplicate type.
  final newType = widget['metadata']?['type'] as String? ?? '';
  final existingIndex = widgets.indexWhere(
      (w) => (w as Map)['metadata']?['type'] == newType);

  if (existingIndex >= 0) {
    widgets[existingIndex] = widget;
    catalogFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(catalog));
    return 'Updated existing widget "$newType" in catalog (${widgets.length} total)';
  }

  widgets.add(widget);
  catalog['widgets'] = widgets;
  catalogFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(catalog));
  return 'Added "$newType" to catalog (${widgets.length} widgets total)';
}

// ---------------------------------------------------------------------------
// Tool definitions
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _toolDefinitions() {
  return [
    {
      'name': 'find_data',
      'description':
          'Search the Tercen API for data operations. '
          'Returns matching endpoints with response fields.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Search term (service name, model name, or keyword)',
          },
        },
        'required': ['query'],
      },
    },
    {
      'name': 'suggest_widget',
      'description':
          'Generate a complete SDUI widget from an archetype. '
          'Returns metadata + template JSON ready for the catalog.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'archetype': {
            'type': 'string',
            'description': 'Archetype name: data-list, detail-view, dashboard-card, form, master-detail',
          },
          'widgetType': {
            'type': 'string',
            'description': 'PascalCase widget type name (e.g., TeamMemberList)',
          },
          'description': {
            'type': 'string',
            'description': 'Human-readable widget description',
          },
          'slots': {
            'type': 'object',
            'description': 'Slot values for the archetype. Use list_archetypes to see available slots.',
          },
        },
        'required': ['archetype', 'widgetType', 'slots'],
      },
    },
    {
      'name': 'get_primitives',
      'description':
          'List all SDUI widget types with their props, children rules, '
          'scope provisions, and event contracts.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'filter': {
            'type': 'string',
            'description': 'Optional filter by name or description keyword',
          },
        },
      },
    },
    {
      'name': 'get_events',
      'description':
          'List all EventBus channels with publishers, subscribers, '
          'and payload keys. Includes intra-widget patterns.',
      'inputSchema': {'type': 'object', 'properties': {}},
    },
    {
      'name': 'get_tokens',
      'description':
          'List all theme tokens: color names, text style names, spacing tokens.',
      'inputSchema': {'type': 'object', 'properties': {}},
    },
    {
      'name': 'get_intents',
      'description':
          'List all registered intents with their handlers and param mappings.',
      'inputSchema': {'type': 'object', 'properties': {}},
    },
    {
      'name': 'list_archetypes',
      'description':
          'List all widget archetypes with their slots and descriptions. '
          'Use with suggest_widget to generate widgets.',
      'inputSchema': {'type': 'object', 'properties': {}},
    },
    {
      'name': 'save_to_catalog',
      'description':
          'Save a widget definition to catalog.json. '
          'Updates if type already exists, otherwise appends.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'widget': {
            'type': 'object',
            'description': 'Widget definition with metadata and template keys',
          },
        },
        'required': ['widget'],
      },
    },
  ];
}

// ---------------------------------------------------------------------------
// JSON-RPC helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _result(dynamic id, Map<String, dynamic> result) =>
    {'jsonrpc': '2.0', 'id': id, 'result': result};

Map<String, dynamic> _error(dynamic id, int code, String message) => {
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': message},
    };
