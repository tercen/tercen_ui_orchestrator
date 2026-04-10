import 'dart:math';

import 'package:flutter/foundation.dart';

/// Maps service names to the Tercen model kind they return.
const _serviceModelKind = <String, String>{
  'projectService': 'Project',
  'projectDocumentService': 'ProjectDocument',
  'workflowService': 'Workflow',
  'fileService': 'FileDocument',
  'folderService': 'FolderDocument',
  'teamService': 'Team',
  'userService': 'User',
  'taskService': 'Task',
  'tableSchemaService': 'TableSchema',
  'operatorService': 'DockerOperator',
  'documentService': 'Document',
  'activityService': 'Activity',
  'eventService': 'Activity',
};

/// Data scenario that controls how many items the mock returns.
enum MockScenario {
  /// 5 items with plausible data.
  normal('Normal (5 items)'),

  /// 0 items — tests empty-state UI.
  empty('Empty (0 items)'),

  /// 1 item.
  single('Single (1 item)'),

  /// 50 items — tests scrolling / pagination.
  many('Many (50 items)'),

  /// Throws an exception — tests error-state UI.
  error('Error');

  final String label;
  const MockScenario(this.label);
}

/// A [ServiceCaller] implementation that returns generated mock data.
///
/// It never touches the network. It uses the (service, method) pair to decide
/// _what kind_ of object to return, and the current [scenario] to decide
/// _how many_ (or whether to fail).
///
/// The caller interface is identical to [ServiceCallDispatcher.call]:
///   `Future<dynamic> call(String service, String method, List<dynamic> args)`
class MockServiceCaller extends ChangeNotifier {
  MockScenario _scenario = MockScenario.normal;
  final _rng = Random(42); // deterministic for reproducibility

  /// Log of every call received, most recent first.
  final List<MockCallRecord> callLog = [];

  MockScenario get scenario => _scenario;
  set scenario(MockScenario s) {
    if (_scenario == s) return;
    _scenario = s;
    notifyListeners();
  }

  /// The [ServiceCaller]-compatible entry point.
  Future<dynamic> call(
      String service, String method, List<dynamic> args) async {
    callLog.insert(0, MockCallRecord(
      service: service,
      method: method,
      args: args,
      timestamp: DateTime.now(),
    ));

    // Simulate a short network delay so loading states are visible.
    await Future.delayed(const Duration(milliseconds: 300));

    if (_scenario == MockScenario.error) {
      throw Exception('Mock error: $service.$method');
    }

    final kind = _serviceModelKind[service] ?? 'Document';

    // Single-object methods.
    if (_isSingleMethod(method)) {
      final id = args.isNotEmpty ? args[0]?.toString() ?? 'mock-id' : 'mock-id';
      return _generateOne(kind, 0, idOverride: id);
    }

    // Composite / special methods.
    final composite = _tryComposite(service, method, args);
    if (composite != null) return composite;

    // List methods (find*, list, explore, recent*, search, etc.).
    final count = switch (_scenario) {
      MockScenario.empty => 0,
      MockScenario.single => 1,
      MockScenario.many => 50,
      _ => 5,
    };
    return List.generate(count, (i) => _generateOne(kind, i));
  }

  // ---------------------------------------------------------------------------
  // Single-method detection
  // ---------------------------------------------------------------------------

  bool _isSingleMethod(String method) =>
      method == 'get' || method == 'download' || method == 'downloadUrl';

  // ---------------------------------------------------------------------------
  // Composite methods that return non-standard shapes.
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? _tryComposite(
      String service, String method, List<dynamic> args) {
    if (service == 'workflowService' && method == 'getWorkflowGraph') {
      return _workflowGraph();
    }
    if (service == 'workflowService' && method == 'getStepTables') {
      return _stepTables();
    }
    if (service == 'tableSchemaService' && method == 'getStepImages') {
      return _stepImages();
    }
    if (service == 'tableSchemaService' && method == 'select') {
      return _selectTable();
    }
    if (service == 'userService' && method == 'profiles') {
      return _userProfiles();
    }
    if (service == 'teamService' && method == 'profiles') {
      return _teamProfiles();
    }
    if (service == 'projectService' && method == 'resourceSummary') {
      return _resourceSummary();
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Generic model generator
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _generateOne(String kind, int index,
      {String? idOverride}) {
    final id = idOverride ?? '$kind-${index.toString().padLeft(3, '0')}';
    final now = DateTime.now()
        .subtract(Duration(hours: index * 3 + _rng.nextInt(10)));

    // Base document fields — shared by all models.
    final doc = <String, dynamic>{
      'kind': kind,
      'id': id,
      'rev': '1-${_hexString(8)}',
      'name': '${_humanName(kind)} ${index + 1}',
      'description': 'A sample ${kind.toLowerCase()} for testing',
      'isPublic': index % 3 == 0,
      'version': '1.0.0',
      'tags': <String>[],
      'meta': <Map<String, dynamic>>[],
      'urls': <Map<String, dynamic>>[],
      'url': {'uri': ''},
      'acl': {
        'owner': 'mock-user',
        'aces': <Map<String, dynamic>>[],
      },
      'createdDate': _dateObj(now.subtract(const Duration(days: 30))),
      'lastModifiedDate': _dateObj(now),
    };

    // Kind-specific fields.
    switch (kind) {
      case 'Project':
        // No extra fields beyond Document.
        break;

      case 'ProjectDocument':
      case 'FileDocument':
      case 'FolderDocument':
      case 'Workflow':
      case 'TableSchema':
        doc['projectId'] = 'proj-001';
        doc['folderId'] = '';
        if (kind == 'FileDocument') {
          doc['dataUri'] = '';
          doc['size'] = _rng.nextInt(50000) + 100;
          doc['metadata'] = {'contentType': 'application/octet-stream'};
        }
        if (kind == 'Workflow') {
          doc['steps'] = <Map<String, dynamic>>[];
          doc['links'] = <Map<String, dynamic>>[];
          doc['offset'] = {'x': 0.0, 'y': 0.0};
          doc['scale'] = 1.0;
        }
        // ProjectDocument items often appear as mixed kinds in navigator.
        if (kind == 'ProjectDocument') {
          final kinds = ['Workflow', 'FileDocument', 'FolderDocument', 'TableSchema'];
          doc['kind'] = kinds[index % kinds.length];
        }
        break;

      case 'Team':
      case 'User':
        doc['email'] = 'user${index + 1}@example.com';
        doc['isValidated'] = true;
        doc['domain'] = '';
        doc['roles'] = <String>['user'];
        doc['teamAcl'] = {
          'owner': 'mock-user',
          'aces': <Map<String, dynamic>>[],
        };
        doc['invitedByUsername'] = '';
        doc['invitationCounts'] = 0;
        doc['maxInvitation'] = 10;
        doc['billingInfo'] = {'plan': 'free'};
        break;

      case 'Task':
        doc['state'] = _taskState(index);
        doc['taskHash'] = _hexString(16);
        doc['environment'] = <Map<String, dynamic>>[];
        doc['projectId'] = 'proj-001';
        break;

      case 'DockerOperator':
        doc['container'] = 'ghcr.io/tercen/mock_operator:latest';
        doc['properties'] = <Map<String, dynamic>>[];
        break;

      case 'Activity':
        final actType = ['create', 'update', 'delete', 'run'][index % 4];
        final objKind = ['Workflow', 'FileDocument', 'TableSchema', 'Project', 'FolderDocument'][index % 5];
        doc['type'] = actType;
        doc['objectKind'] = objKind;
        doc['objectId'] = 'obj-${index.toString().padLeft(3, '0')}';
        doc['objectName'] = '$objKind ${index + 1}';
        doc['userId'] = ['alice', 'bob', 'carol', 'dave'][index % 4];
        doc['teamId'] = ['science-team', 'data-team', 'admin'][index % 3];
        doc['projectId'] = 'proj-${(index % 3).toString().padLeft(3, '0')}';
        doc['projectName'] = ['Cancer Genomics', 'Proteomics Pipeline', 'QC Dashboard'][index % 3];
        doc['date'] = _dateObj(now);
        doc['properties'] = <Map<String, dynamic>>[
          {'kind': 'Pair', 'key': 'name', 'value': '$objKind ${index + 1}'},
          {'kind': 'Pair', 'key': 'objectId', 'value': 'obj-${index.toString().padLeft(3, '0')}'},
        ];
        break;
    }

    return doc;
  }

  // ---------------------------------------------------------------------------
  // Composite generators
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _workflowGraph() {
    if (_scenario == MockScenario.empty) {
      return {'name': 'Empty Workflow', 'nodes': <Map<String, dynamic>>[], 'edges': <Map<String, dynamic>>[]};
    }
    // Extended Crabs Workflow — exercises all node shapes from spec Section 5.
    // Workflow root at row 0, TableStep, DataStep, ViewStep, JoinStep, MeltStep.
    return {
      'name': 'Crabs Workflow',
      'nodes': [
        // Row 0: Workflow root — circle badge 48px, label outside
        {'id': 'workflow-root', 'label': 'Crabs Workflow', 'x': 300.0, 'y': 30.0, 'width': 48.0, 'height': 48.0, 'shape': 'circle', 'icon': 'sitemap', 'iconColor': 'success', 'fill': 'surface', 'borderColor': 'outline', 'subtitle': 'Workflow', 'labelPosition': 'outside'},
        // Row 1: TableStep — rounded rect, table icon
        {'id': 'ts-crabs', 'label': 'Crabs Data', 'x': 290.0, 'y': 120.0, 'width': 110.0, 'height': 36.0, 'shape': 'roundedRect', 'icon': 'table', 'iconColor': 'success', 'fill': 'surface', 'borderColor': 'outline', 'subtitle': 'TableStep'},
        // Row 2: DataSteps — rounded rect, cubes icon
        {'id': 'ds-heatmap', 'label': 'Heatmap', 'x': 80.0, 'y': 210.0, 'width': 100.0, 'height': 36.0, 'shape': 'roundedRect', 'icon': 'cubes', 'iconColor': 'success', 'fill': 'surface', 'borderColor': 'outline', 'subtitle': 'DataStep'},
        {'id': 'ds-pairwise', 'label': 'Multi Pairwise', 'x': 230.0, 'y': 210.0, 'width': 120.0, 'height': 36.0, 'shape': 'roundedRect', 'icon': 'cubes', 'iconColor': 'success', 'fill': 'surface', 'borderColor': 'outline', 'subtitle': 'DataStep'},
        {'id': 'ds-pca', 'label': 'PCA', 'x': 410.0, 'y': 210.0, 'width': 80.0, 'height': 36.0, 'shape': 'roundedRect', 'icon': 'cubes', 'iconColor': 'info', 'fill': 'surface', 'borderColor': 'outline', 'subtitle': 'DataStep'},
        // Row 2 same-row: ViewStep — circle badge 36px, eye icon, label outside (hover only in prod)
        {'id': 'vs-heatmap-view', 'label': 'View', 'x': 190.0, 'y': 210.0, 'width': 36.0, 'height': 36.0, 'shape': 'circle', 'icon': 'eye', 'iconColor': 'success', 'fill': 'surface', 'borderColor': 'outline', 'subtitle': 'ViewStep'},
        // Row 3: DataStep from PCA
        {'id': 'ds-pc-view', 'label': 'PC Scatter Plot', 'x': 370.0, 'y': 300.0, 'width': 130.0, 'height': 36.0, 'shape': 'roundedRect', 'icon': 'cubes', 'iconColor': 'onSurfaceVariant', 'fill': 'surface', 'borderColor': 'outline', 'subtitle': 'DataStep'},
        // Row 3: JoinStep — hexagon, code-merge icon (merges Heatmap + Pairwise)
        {'id': 'js-join', 'label': 'Join', 'x': 140.0, 'y': 300.0, 'width': 80.0, 'height': 36.0, 'shape': 'hexagon', 'icon': 'code-merge', 'iconColor': 'success', 'fill': 'surface', 'borderColor': 'outline', 'subtitle': 'JoinStep'},
        // Row 4: MeltStep — hexagon box (wider, shows name), shuffle icon
        {'id': 'ms-gather', 'label': 'Gather', 'x': 120.0, 'y': 390.0, 'width': 100.0, 'height': 36.0, 'shape': 'hexagon', 'icon': 'shuffle', 'iconColor': 'error', 'fill': 'surface', 'borderColor': 'outline', 'subtitle': 'MeltStep'},
        // Row 5: OutStep — rounded square, right-from-bracket icon
        {'id': 'os-output', 'label': 'Output', 'x': 145.0, 'y': 470.0, 'width': 36.0, 'height': 36.0, 'shape': 'roundedSquare', 'icon': 'right-from-bracket', 'iconColor': 'onSurfaceVariant', 'fill': 'surface', 'borderColor': 'outline', 'subtitle': 'OutStep'},
      ],
      'edges': [
        {'from': 'workflow-root', 'to': 'ts-crabs'},
        {'from': 'ts-crabs', 'to': 'ds-heatmap'},
        {'from': 'ts-crabs', 'to': 'ds-pairwise'},
        {'from': 'ts-crabs', 'to': 'ds-pca'},
        {'from': 'ds-heatmap', 'to': 'vs-heatmap-view'},
        {'from': 'ds-heatmap', 'to': 'js-join'},
        {'from': 'ds-pairwise', 'to': 'js-join'},
        {'from': 'ds-pca', 'to': 'ds-pc-view'},
        {'from': 'js-join', 'to': 'ms-gather'},
        {'from': 'ms-gather', 'to': 'os-output'},
      ],
    };
  }

  Map<String, dynamic> _stepTables() {
    return {
      'tables': List.generate(3, (i) {
        return <String, dynamic>{
          'id': 'table-$i',
          'name': ['main', 'columns', 'metadata'][i],
          'nRows': 100 + i * 50,
          'columns': List.generate(4, (c) {
            return <String, dynamic>{
              'name': ['rowId', 'value', 'label', 'score'][c],
              'type': ['int32', 'double', 'string', 'double'][c],
              'nRows': 100 + i * 50,
            };
          }),
        };
      }),
    };
  }

  Map<String, dynamic> _stepImages() {
    return {
      'images': [
        <String, dynamic>{
          'schemaId': 'schema-img-0',
          'filename': 'View UMAP vs. clusters.png',
          'mimetype': 'image/png',
          'url': 'https://picsum.photos/800/600',
        },
      ],
    };
  }

  Map<String, dynamic> _selectTable() {
    return {
      'columns': ['rowId', 'value', 'label'],
      'rows': List.generate(10, (r) => [r, r * 1.5, 'row-$r']),
    };
  }

  Map<String, dynamic> _userProfiles() {
    return {
      'users': [_generateOne('User', 0)],
      'totalCount': 1,
    };
  }

  Map<String, dynamic> _teamProfiles() {
    return {
      'teams': List.generate(2, (i) => _generateOne('Team', i)),
      'totalCount': 2,
    };
  }

  Map<String, dynamic> _resourceSummary() {
    return {
      'projectCount': 5,
      'workflowCount': 12,
      'fileCount': 34,
      'storageBytes': 1024 * 1024 * 150,
    };
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _humanName(String kind) {
    // "ProjectDocument" → "Project Document"
    // Insert space before each uppercase letter preceded by lowercase.
    final buf = StringBuffer();
    for (var i = 0; i < kind.length; i++) {
      if (i > 0 &&
          kind.codeUnitAt(i) >= 65 &&
          kind.codeUnitAt(i) <= 90 &&
          kind.codeUnitAt(i - 1) >= 97 &&
          kind.codeUnitAt(i - 1) <= 122) {
        buf.write(' ');
      }
      buf.write(kind[i]);
    }
    return buf.toString();
  }

  Map<String, dynamic> _dateObj(DateTime dt) => {
        'kind': 'Date',
        'value': dt.toUtc().toIso8601String(),
      };

  String _hexString(int length) {
    const chars = '0123456789abcdef';
    return List.generate(length, (_) => chars[_rng.nextInt(16)]).join();
  }

  Map<String, dynamic> _taskState(int index) {
    final states = ['InitState', 'RunningState', 'DoneState', 'FailedState'];
    return {'kind': states[index % states.length]};
  }
}

/// A single service call recorded for the inspector panel.
class MockCallRecord {
  final String service;
  final String method;
  final List<dynamic> args;
  final DateTime timestamp;

  const MockCallRecord({
    required this.service,
    required this.method,
    required this.args,
    required this.timestamp,
  });

  @override
  String toString() => '$service.$method(${args.length} args)';
}
