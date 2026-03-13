import 'package:sci_base/sci_client_base.dart';
import 'package:sci_base/sci_service.dart';
import 'package:sci_tercen_client/sci_client_service_factory.dart';

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

    // Try base CRUD methods first (available on all services)
    final baseResult = await _tryBaseMethod(service, method, args);
    if (baseResult != null) return baseResult;

    // Try service-specific methods
    return _callSpecificMethod(serviceName, method, args);
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
            limit: args.length > 3 ? args[3] as int : 20,
            skip: args.length > 4 ? args[4] as int : 0,
            descending: args.length > 5 ? args[5] as bool : true);
        return result.map((obj) => service.toJson(obj)).toList();

      case 'findKeys':
        if (service is! HttpClientService) return null;
        final viewName = args[0] as String;
        final keys = (args.length > 1 ? args[1] as List : []);
        final result = await service.findKeys(viewName, keys: keys);
        return result.map((obj) => service.toJson(obj)).toList();

      default:
        // Any findBy* method name is a CouchDB view — route to findStartKeys.
        // Args: [startKey, endKey, limit?, skip?, descending?]
        if (method.startsWith('findBy') && service is HttpClientService) {
          final result = await service.findStartKeys(method,
              startKey: args.isNotEmpty ? args[0] : null,
              endKey: args.length > 1 ? args[1] : null,
              limit: args.length > 2 ? args[2] as int : 20,
              skip: args.length > 3 ? args[3] as int : 0,
              descending: args.length > 4 ? args[4] as bool : true);
          return result.map((obj) => service.toJson(obj)).toList();
        }
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
            args[0] as String, args[1] as int, args[2] as int);
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
          args.length > 1 ? args[1] as int : 20,
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
          args[4] as int,
          args[5] as int,
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
          limit: args.length > 2 ? args[2] as int : 20,
        );
        return result.map((obj) => svc.toJson(obj)).toList();
      case 'findProjectObjectsByFolderAndName':
        final result = await svc.findProjectObjectsByFolderAndName(
          startKey: args.isNotEmpty ? args[0] : null,
          endKey: args.length > 1 ? args[1] : null,
          limit: args.length > 2 ? args[2] as int : 20,
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
}
