import 'dart:convert';

import 'package:sci_base/sci_client_base.dart';
import 'package:sci_base/sci_service.dart';
import 'package:sci_tercen_client/sci_client_service_factory.dart';
import 'package:sdui/sdui.dart' show PropConverter;

/// Dispatches service calls by name and returns JSON-serializable results.
///
/// Used by the SDUI renderer's dataSource feature:
///   dataSource: {"service": "projectService", "method": "explore", "args": ["", 0, 20]}
///   → dispatcher.call("projectService", "explore", ["all", 0, 20])
///   → List<Map<String, dynamic>>
class ServiceCallDispatcher {
  final ServiceFactory factory;
  final String? authToken;

  ServiceCallDispatcher(this.factory, {this.authToken});

  /// Main entry point. Returns a List<Map> for list methods, or a Map for single-object methods.
  Future<dynamic> call(
      String serviceName, String method, List<dynamic> args) async {
    final service = _getService(serviceName);
    if (service == null) {
      throw ArgumentError('Unknown service: $serviceName');
    }

    // Try base CRUD methods first (get, list, findStartKeys, findKeys)
    final baseResult = await _tryBaseMethod(service, method, args);
    if (baseResult != null) return baseResult;

    // Try service-specific methods (these have correct named-param calling)
    try {
      return await _callSpecificMethod(serviceName, method, args);
    } on ArgumentError {
      // Not a known specific method — fall through to generic find handler
    }

    // Generic find handler — last resort for find* methods not explicitly handled
    return _tryGenericFind(service, method, args);
  }

  Service? _getService(String name) {
    switch (name) {
      case 'projectService':
        return factory.projectService;
      case 'workflowService':
        return factory.workflowService;
      case 'userService':
        return factory.userService;
      case 'teamService':
        return factory.teamService;
      case 'fileService':
        return factory.fileService;
      case 'taskService':
        return factory.taskService;
      case 'tableSchemaService':
        return factory.tableSchemaService;
      case 'operatorService':
        return factory.operatorService;
      case 'eventService':
        return factory.eventService;
      case 'documentService':
        return factory.documentService;
      case 'projectDocumentService':
        return factory.projectDocumentService;
      case 'folderService':
        return factory.folderService;
      case 'activityService':
        return factory.activityService;
      case 'persistentService':
        return factory.persistentService;
      case 'queryService':
        return factory.queryService;
      default:
        return null;
    }
  }

  /// Handles base CRUD methods that exist on every service.
  Future<dynamic> _tryBaseMethod(
      Service service, String method, List<dynamic> args) async {
    switch (method) {
      case 'get':
        final result = await service.get(args[0] as String);
        return service.toJson(result);

      case 'list':
        final ids = (args[0] as List).cast<String>();
        final result = await service.list(ids);
        return result.map((obj) => service.toJson(obj)).toList();

      case 'findStartKeys':
        if (service is! HttpClientService) return null;
        final viewName = args[0] as String;
        final result = await service.findStartKeys(viewName,
            startKey: args.length > 1 ? args[1] : null,
            endKey: args.length > 2 ? args[2] : null,
            limit: args.length > 3 ? PropConverter.to<int>(args[3]) ?? 20 : 20,
            skip: args.length > 4 ? PropConverter.to<int>(args[4]) ?? 0 : 0,
            descending: args.length > 5 ? args[5] == true : true);
        return result.map((obj) => service.toJson(obj)).toList();

      case 'findKeys':
        if (service is! HttpClientService) return null;
        final viewName = args[0] as String;
        final keys = (args.length > 1 ? args[1] as List : []);
        final result = await service.findKeys(viewName, keys: keys);
        return result.map((obj) => service.toJson(obj)).toList();

      default:
        return null; // Not a base method — try specific
    }
  }

  /// Dispatches service-specific methods.
  Future<dynamic> _callSpecificMethod(
      String serviceName, String method, List<dynamic> args) async {
    switch (serviceName) {
      case 'projectService':
        return _projectServiceCall(method, args);
      case 'userService':
        return _userServiceCall(method, args);
      case 'teamService':
        return _teamServiceCall(method, args);
      case 'documentService':
        return _documentServiceCall(method, args);
      case 'projectDocumentService':
        return _projectDocumentServiceCall(method, args);
      case 'fileService':
        return _fileServiceCall(method, args);
      case 'tableSchemaService':
        return _tableSchemaServiceCall(method, args);
      case 'workflowService':
        return _workflowServiceCall(method, args);
      case 'taskService':
        return _taskServiceCall(method, args);
      default:
        throw ArgumentError(
            'Method "$method" not found on service "$serviceName"');
    }
  }

  Future<dynamic> _projectServiceCall(String method, List<dynamic> args) async {
    final svc = factory.projectService;
    switch (method) {
      case 'explore':
        final result = await svc.explore(
            args[0] as String, PropConverter.to<int>(args[1]) ?? 0, PropConverter.to<int>(args[2]) ?? 20);
        return result.map((obj) => svc.toJson(obj)).toList();
      case 'recentProjects':
        final result = await svc.recentProjects(args[0] as String);
        return result.map((obj) => svc.toJson(obj)).toList();
      case 'profiles':
        final result = await svc.profiles(args[0] as String);
        return result.toJson();
      case 'resourceSummary':
        final result = await svc.resourceSummary(args[0] as String);
        return result.toJson();
      default:
        throw ArgumentError(
            'Method "$method" not found on projectService');
    }
  }

  Future<dynamic> _userServiceCall(String method, List<dynamic> args) async {
    final svc = factory.userService;
    switch (method) {
      case 'profiles':
        final result = await svc.profiles(args[0] as String);
        return result.toJson();
      default:
        throw ArgumentError('Method "$method" not found on userService');
    }
  }

  Future<dynamic> _teamServiceCall(String method, List<dynamic> args) async {
    final svc = factory.teamService;
    switch (method) {
      case 'profiles':
        final result = await svc.profiles(args[0] as String);
        return result.toJson();
      case 'resourceSummary':
        final result = await svc.resourceSummary(args[0] as String);
        return result.toJson();
      default:
        throw ArgumentError('Method "$method" not found on teamService');
    }
  }

  Future<dynamic> _documentServiceCall(
      String method, List<dynamic> args) async {
    final svc = factory.documentService;
    switch (method) {
      case 'search':
        final result = await svc.search(
          args[0] as String,
          args.length > 1 ? PropConverter.to<int>(args[1]) ?? 20 : 20,
          args.length > 2 ? args[2] as bool : false,
          args.length > 3 ? args[3] as String : '',
        );
        return result.toJson();
      case 'getLibrary':
        final result = await svc.getLibrary(
          args[0] as String,
          (args[1] as List).cast<String>(),
          (args[2] as List).cast<String>(),
          (args[3] as List).cast<String>(),
          PropConverter.to<int>(args[4]) ?? 0,
          PropConverter.to<int>(args[5]) ?? 20,
        );
        return result.map((obj) => svc.toJson(obj)).toList();
      default:
        throw ArgumentError(
            'Method "$method" not found on documentService');
    }
  }

  Future<dynamic> _projectDocumentServiceCall(
      String method, List<dynamic> args) async {
    final svc = factory.projectDocumentService;
    switch (method) {
      case 'findProjectObjectsByLastModifiedDate':
        final result = await svc.findProjectObjectsByLastModifiedDate(
          startKey: args.isNotEmpty ? args[0] : null,
          endKey: args.length > 1 ? args[1] : null,
          limit: args.length > 2 ? PropConverter.to<int>(args[2]) ?? 20 : 20,
        );
        return result.map((obj) => svc.toJson(obj)).toList();
      case 'findProjectObjectsByFolderAndName':
        final result = await svc.findProjectObjectsByFolderAndName(
          startKey: args.isNotEmpty ? args[0] : null,
          endKey: args.length > 1 ? args[1] : null,
          limit: args.length > 2 ? PropConverter.to<int>(args[2]) ?? 20 : 20,
        );
        return result.map((obj) => svc.toJson(obj)).toList();
      default:
        throw ArgumentError(
            'Method "$method" not found on projectDocumentService');
    }
  }

  Future<dynamic> _fileServiceCall(String method, List<dynamic> args) async {
    final svc = factory.fileService;
    switch (method) {
      case 'download':
        // Download file content as UTF-8 text.
        // Args: [fileDocumentId]
        // Returns: {"content": "...", "fileId": "..."}
        final fileId = args[0] as String;
        final content = await utf8.decodeStream(svc.download(fileId));
        return {'content': content, 'fileId': fileId};
      case 'downloadUrl':
        // Build an authenticated download URL for a file.
        // Works for any file type (images, documents, ZIPs).
        // Args: [fileDocumentId]
        // Returns: {"url": "https://...", "fileId": "..."}
        final fileId = args[0] as String;
        final baseUri = (svc as dynamic)
            .getServiceUri(Uri.parse('api/v1/file/download'));
        final params = json.encode({'fileDocumentId': fileId});
        final queryParams = <String, String>{'params': params};
        if (authToken != null && authToken!.isNotEmpty) {
          queryParams['authorization'] = authToken!;
        }
        final url = baseUri.replace(queryParameters: queryParams).toString();
        return {'url': url, 'fileId': fileId};
      default:
        throw ArgumentError('Method "$method" not found on fileService');
    }
  }

  Future<dynamic> _tableSchemaServiceCall(
      String method, List<dynamic> args) async {
    final svc = factory.tableSchemaService;
    switch (method) {
      case 'getStepImages':
        // Args: [workflowId, stepId]
        // Returns: {stepName, images: [{schemaId, filename, mimetype, url}]}
        return _getStepImages(args[0] as String, args[1] as String);
      case 'select':
        // Args: [schemaId, columnNames, offset, limit]
        final schemaId = args[0] as String;
        final cnames = (args[1] as List).cast<String>();
        final offset = PropConverter.to<int>(args[2]) ?? 0;
        final limit = PropConverter.to<int>(args[3]) ?? 100;
        final table = await svc.select(schemaId, cnames, offset, limit);
        return _serializeTable(table);
      default:
        throw ArgumentError(
            'Method "$method" not found on tableSchemaService');
    }
  }

  /// Serializes a Table object to a clean JSON map.
  Map<String, dynamic> _serializeTable(dynamic table) {
    final cols = <Map<String, dynamic>>[];
    final tableJson = Map<String, dynamic>.from((table as dynamic).toJson() as Map);
    final nRows = PropConverter.to<int>(tableJson['nRows']) ?? 0;
    final columns = tableJson['columns'] as List? ?? [];
    for (final col in columns) {
      final colMap = Map<String, dynamic>.from(col as Map);
      cols.add({
        'name': colMap['name'] ?? '',
        'type': colMap['type'] ?? '',
        'values': colMap['values'] ?? [],
      });
    }
    return {'nRows': nRows, 'columns': cols};
  }

  /// Gets all generated images for a workflow step.
  /// Walks computedRelation → finds file content schemas → lists filenames/mimetypes → builds URLs.
  Future<Map<String, dynamic>> _getStepImages(
      String workflowId, String stepId) async {
    final workflow = await factory.workflowService.get(workflowId);
    final wfJson = Map<String, dynamic>.from(
        factory.workflowService.toJson(workflow));
    final steps = wfJson['steps'] as List? ?? [];

    Map<String, dynamic>? stepJson;
    for (final s in steps) {
      final sm = Map<String, dynamic>.from(s as Map);
      if (sm['id'] == stepId) {
        stepJson = sm;
        break;
      }
    }
    if (stepJson == null) {
      throw ArgumentError('Step "$stepId" not found in workflow "$workflowId"');
    }

    final stepName = stepJson['name'] as String? ?? stepId;

    // Collect schema IDs from computedRelation
    final schemaIds = <String>{};
    _collectSimpleRelationIds(stepJson['computedRelation'], schemaIds);

    if (schemaIds.isEmpty) {
      return {'stepName': stepName, 'images': []};
    }

    // Fetch schemas and find file content schemas
    final tss = factory.tableSchemaService;
    final images = <Map<String, dynamic>>[];

    // Build base URL from the tableSchemaService
    final baseUri = (tss as dynamic).getServiceUri(
        Uri.parse('api/v1/schema/getFileMimetypeStream'));

    for (final schemaId in schemaIds) {
      try {
        final schema = await tss.get(schemaId);
        final schemaJson = Map<String, dynamic>.from(tss.toJson(schema));
        final columns = schemaJson['columns'] as List? ?? [];

        // Check if this is a file content schema (.content + filename + mimetype)
        final hasContent = columns.any((c) => (c as Map)['name'] == '.content');
        final filenameCol = columns.cast<Map>().where(
            (c) => (c['name'] as String).endsWith('filename')).firstOrNull;
        final mimetypeCol = columns.cast<Map>().where(
            (c) => (c['name'] as String).endsWith('mimetype')).firstOrNull;

        if (!hasContent || filenameCol == null || mimetypeCol == null) continue;

        // Select filename and mimetype values
        final nRows = PropConverter.to<int>(schemaJson['nRows']) ?? 0;
        if (nRows == 0) continue;
        final table = await tss.select(
            schemaId,
            [filenameCol['name'] as String, mimetypeCol['name'] as String],
            0, nRows);
        final serialized = _serializeTable(table);
        final cols = serialized['columns'] as List;
        final fnCol = cols.firstWhere((c) =>
            (c as Map)['name'] == filenameCol['name']);
        final mtCol = cols.firstWhere((c) =>
            (c as Map)['name'] == mimetypeCol['name']);
        final filenames = (fnCol as Map)['values'] as List;
        final mimetypes = (mtCol as Map)['values'] as List;

        for (var i = 0; i < filenames.length; i++) {
          final filename = filenames[i]?.toString() ?? '';
          final mimetype = i < mimetypes.length
              ? mimetypes[i]?.toString() ?? ''
              : '';
          if (filename.isEmpty) continue;

          // Build authenticated URL — token in query params (same pattern as MCP client)
          final params = json.encode({
            'tableId': schemaId,
            'filename': filename,
          });
          final queryParams = <String, String>{'params': params};
          // Add auth token to URL if available
          if (authToken != null && authToken!.isNotEmpty) {
            queryParams['authorization'] = authToken!;
          }
          final url = baseUri.replace(
            queryParameters: queryParams,
          ).toString();

          images.add({
            'schemaId': schemaId,
            'filename': filename,
            'mimetype': mimetype,
            'url': url,
          });
        }
      } catch (_) {
        // Skip schemas that fail
      }
    }

    return {'stepName': stepName, 'images': images};
  }

  Future<dynamic> _workflowServiceCall(
      String method, List<dynamic> args) async {
    final svc = factory.workflowService;
    switch (method) {
      case 'getCubeQuery':
        final result =
            await svc.getCubeQuery(args[0] as String, args[1] as String);
        return result.toJson();
      case 'getWorkflowGraph':
        return _getWorkflowGraph(args[0] as String);
      case 'getStepTables':
        // Args: [workflowId, stepId, tableType]
        // tableType: "output" (default) or "input"
        final tableType = args.length > 2
            ? PropConverter.to<String>(args[2]) ?? 'output'
            : 'output';
        return _getStepTables(args[0] as String, args[1] as String, tableType);
      default:
        throw ArgumentError(
            'Method "$method" not found on workflowService');
    }
  }

  /// Fetches tables for a workflow step.
  /// [tableType]: "output" → step's computedRelation, "input" → source step(s) via links.
  /// Returns {stepName, tableType, tables: [{schemaId, name, kind, nRows, columns: [{name, type, values}]}]}
  Future<Map<String, dynamic>> _getStepTables(
      String workflowId, String stepId, String tableType) async {
    // 1. Get workflow and build step index
    final workflow = await factory.workflowService.get(workflowId);
    final wfJson = Map<String, dynamic>.from(
        factory.workflowService.toJson(workflow));
    final steps = wfJson['steps'] as List? ?? [];
    final links = wfJson['links'] as List? ?? [];

    final stepIndex = <String, Map<String, dynamic>>{};
    for (final s in steps) {
      final sm = Map<String, dynamic>.from(s as Map);
      stepIndex[sm['id'] as String] = sm;
    }

    final stepJson = stepIndex[stepId];
    if (stepJson == null) {
      throw ArgumentError('Step "$stepId" not found in workflow "$workflowId"');
    }

    final stepName = stepJson['name'] as String? ?? stepId;

    // 2. Collect schema IDs based on tableType
    final schemaIds = <String>{};

    if (tableType == 'input') {
      // Find source steps via workflow links that connect to this step's input ports
      for (final link in links) {
        final lm = Map<String, dynamic>.from(link as Map);
        final inputId = lm['inputId'] as String? ?? '';
        if (inputId.startsWith(stepId)) {
          // Follow outputId back to source step
          final outputId = lm['outputId'] as String? ?? '';
          final sourceStepId = outputId.contains('-o-')
              ? outputId.substring(0, outputId.lastIndexOf('-o-'))
              : '';
          final sourceStep = stepIndex[sourceStepId];
          if (sourceStep != null) {
            // Collect from source step's model.relation (for TableSteps)
            final modelRelation = (sourceStep['model'] as Map?)?['relation'];
            if (modelRelation != null) {
              _collectSimpleRelationIds(modelRelation, schemaIds);
            }
            // Also check source step's computedRelation (for DataSteps feeding into this step)
            final cr = sourceStep['computedRelation'];
            if (cr != null) {
              _collectSimpleRelationIds(cr, schemaIds);
            }
          }
        }
      }
    } else {
      // Output: walk this step's computedRelation
      final cr = stepJson['computedRelation'];
      _collectSimpleRelationIds(cr, schemaIds);
    }

    if (schemaIds.isEmpty) {
      return {'stepName': stepName, 'tableType': tableType, 'tables': []};
    }

    // 3. For each schema, get metadata + select data
    final tables = await _fetchTableData(schemaIds);

    return {'stepName': stepName, 'tableType': tableType, 'tables': tables};
  }

  /// Fetches schema metadata and row data for a set of schema IDs.
  Future<List<Map<String, dynamic>>> _fetchTableData(
      Set<String> schemaIds) async {
    final tables = <Map<String, dynamic>>[];
    final tss = factory.tableSchemaService;
    for (final schemaId in schemaIds) {
      try {
        final schema = await tss.get(schemaId);
        final schemaJson = Map<String, dynamic>.from(tss.toJson(schema));
        final columns = schemaJson['columns'] as List? ?? [];
        final nRows = PropConverter.to<int>(schemaJson['nRows']) ?? 0;
        final cnames =
            columns.map((c) => (c as Map)['name'] as String).toList();

        // Select up to 100 rows
        final fetchRows = nRows > 100 ? 100 : nRows;
        final table = await tss.select(schemaId, cnames, 0, fetchRows);
        final serialized = _serializeTable(table);

        tables.add({
          'schemaId': schemaId,
          'name': schemaJson['name'] as String? ?? schemaId,
          'kind': schemaJson['kind'] as String? ?? '',
          'nRows': nRows,
          'columns': serialized['columns'],
        });
      } catch (e) {
        tables.add({
          'schemaId': schemaId,
          'name': schemaId,
          'kind': 'error',
          'nRows': 0,
          'columns': [],
          'error': e.toString(),
        });
      }
    }
    return tables;
  }

  /// Recursively walks a relation tree (JSON) and collects all SimpleRelation IDs.
  /// Transforms a workflow into a generic directed graph for the DirectedGraph widget.
  /// Returns {name, nodes: [{id, label, x, y, width, height, shape, icon, iconColor, fill, borderColor, subtitle}], edges: [{from, to}]}
  Future<Map<String, dynamic>> _getWorkflowGraph(String workflowId) async {
    final workflow = await factory.workflowService.get(workflowId);
    final wfJson = Map<String, dynamic>.from(
        factory.workflowService.toJson(workflow));
    final steps = wfJson['steps'] as List? ?? [];
    final links = wfJson['links'] as List? ?? [];
    final wfName = wfJson['name'] as String? ?? workflowId;

    final nodes = <Map<String, dynamic>>[];
    for (final s in steps) {
      final sm = Map<String, dynamic>.from(s as Map);
      final kind = sm['kind'] as String? ?? '';
      final name = sm['name'] as String? ?? '';
      final id = sm['id'] as String? ?? '';
      final rect = sm['rectangle'] as Map? ?? {};
      final tl = rect['topLeft'] as Map? ?? {};
      final ext = rect['extent'] as Map? ?? {};
      final state = sm['state'] as Map? ?? {};
      final taskState = (state['taskState'] as Map?)?['kind'] as String? ?? 'InitState';

      nodes.add({
        'id': id,
        'label': name,
        'x': PropConverter.to<double>(tl['x']) ?? 0,
        'y': PropConverter.to<double>(tl['y']) ?? 0,
        'width': PropConverter.to<double>(ext['x']) ?? 0,
        'height': PropConverter.to<double>(ext['y']) ?? 36,
        'shape': _stepKindToShape(kind),
        'icon': _stepKindToIcon(kind),
        'iconColor': _taskStateToColor(taskState),
        'fill': 'surface',
        'borderColor': 'outline',
        'subtitle': kind,
      });
    }

    // Resolve link port IDs → step IDs
    final edges = <Map<String, String>>[];
    for (final l in links) {
      final lm = Map<String, dynamic>.from(l as Map);
      final outputId = lm['outputId'] as String? ?? '';
      final inputId = lm['inputId'] as String? ?? '';
      // Port IDs are "stepId-o-N" and "stepId-i-N"
      final fromStep = outputId.contains('-o-')
          ? outputId.substring(0, outputId.lastIndexOf('-o-'))
          : outputId;
      final toStep = inputId.contains('-i-')
          ? inputId.substring(0, inputId.lastIndexOf('-i-'))
          : inputId;
      if (fromStep.isNotEmpty && toStep.isNotEmpty) {
        edges.add({'from': fromStep, 'to': toStep});
      }
    }

    return {'name': wfName, 'nodes': nodes, 'edges': edges};
  }

  static String _stepKindToShape(String kind) => switch (kind) {
    'TableStep' => 'roundedRect',
    'DataStep' => 'roundedRect',
    'MeltStep' => 'hexagon',
    'JoinStep' => 'hexagon',
    'ViewStep' => 'circle',
    'InStep' => 'roundedSquare',
    'OutStep' => 'roundedSquare',
    'ExportStep' => 'roundedSquare',
    'WizardStep' => 'roundedRect',
    'GroupStep' => 'circle',
    _ => 'roundedRect',
  };

  static String _stepKindToIcon(String kind) => switch (kind) {
    'TableStep' => 'table_chart',
    'DataStep' => 'hub',
    'MeltStep' => 'shuffle',
    'JoinStep' => 'call_merge',
    'ViewStep' => 'visibility',
    'InStep' => 'input',
    'OutStep' => 'output',
    'ExportStep' => 'insert_drive_file',
    'WizardStep' => 'auto_fix_high',
    'GroupStep' => 'account_tree',
    _ => 'widgets',
  };

  static String _taskStateToColor(String taskState) => switch (taskState) {
    'DoneState' => 'success',
    'RunningState' => 'info',
    'RunningDependentState' => 'warning',
    'FailedState' => 'error',
    'CanceledState' => 'onSurfaceMuted',
    'PendingState' => 'onSurfaceMuted',
    _ => 'onSurfaceVariant', // InitState and unknown
  };

  void _collectSimpleRelationIds(dynamic obj, Set<String> ids) {
    if (obj is Map) {
      if (obj['kind'] == 'SimpleRelation') {
        final id = obj['id'];
        if (id is String && id.isNotEmpty) ids.add(id);
      }
      for (final v in obj.values) {
        _collectSimpleRelationIds(v, ids);
      }
    } else if (obj is List) {
      for (final v in obj) {
        _collectSimpleRelationIds(v, ids);
      }
    }
  }

  Future<dynamic> _taskServiceCall(String method, List<dynamic> args) async {
    final svc = factory.taskService;
    switch (method) {
      case 'runTask':
        await svc.runTask(args[0] as String);
        return {'success': true};
      case 'cancelTask':
        await svc.cancelTask(args[0] as String);
        return {'success': true};
      default:
        throw ArgumentError('Method "$method" not found on taskService');
    }
  }

  /// Generic find handler — uses the known findKeys view name mapping
  /// to determine whether to call findKeys or findStartKeys.
  Future<dynamic> _tryGenericFind(
      Service service, String method, List<dynamic> args) async {
    if (!method.startsWith('find') || service is! HttpClientService) {
      throw ArgumentError('Method "$method" not found');
    }

    // Check if this is a known findKeys method (view name differs from method name)
    final viewName = _findKeysViewName(method);
    final isKnownFindKeys = viewName != method;

    if (isKnownFindKeys) {
      // findKeys: args[0] is the keys list
      final result = await service.findKeys(viewName,
          keys: args.isNotEmpty ? (args[0] is List ? args[0] as List : [args[0]]) : []);
      return result.map((obj) => service.toJson(obj)).toList();
    } else {
      // findStartKeys: method name IS the view name
      final result = await service.findStartKeys(method,
          startKey: args.isNotEmpty ? args[0] : null,
          endKey: args.length > 1 ? args[1] : null,
          limit: args.length > 2 ? PropConverter.to<int>(args[2]) ?? 20 : 20,
          skip: args.length > 3 ? PropConverter.to<int>(args[3]) ?? 0 : 0,
          descending: args.length > 4 ? args[4] == true : true);
      return result.map((obj) => service.toJson(obj)).toList();
    }
  }

  /// Maps findKeys method names to their actual CouchDB view names.
  ///
  /// For findStartKeys methods, the method name IS the view name.
  /// For findKeys methods, the view name may differ (e.g., findTeamByOwner → teamByOwner).
  /// This mapping is derived from sci_tercen_client service base classes.
  static String _findKeysViewName(String method) => switch (method) {
    'findTeamByOwner' => 'teamByOwner',
    'findTeamMembers' => 'teamMembers',
    'findUserByEmail' => 'userByEmail',
    'findSecretByUserId' => 'secret',
    'findSubscriptionPlanByCheckoutSessionId' => 'checkoutSessionId',
    // These findKeys methods happen to match their view name
    'findDeleted' => 'findDeleted',
    'findByKind' => 'findByKind',
    'findByOwner' => 'findByOwner',
    // Default: assume method name = view name
    _ => method,
  };
}
