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

  ServiceCallDispatcher(this.factory);

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

  Future<dynamic> _workflowServiceCall(
      String method, List<dynamic> args) async {
    final svc = factory.workflowService;
    switch (method) {
      case 'getCubeQuery':
        final result =
            await svc.getCubeQuery(args[0] as String, args[1] as String);
        return result.toJson();
      default:
        throw ArgumentError(
            'Method "$method" not found on workflowService');
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
