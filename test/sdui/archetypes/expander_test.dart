import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdui/sdui.dart';

import 'package:tercen_ui_orchestrator/sdui/archetypes/archetype_expander.dart';
import 'package:tercen_ui_orchestrator/sdui/archetypes/skeleton_theme.dart';
import 'package:tercen_ui_orchestrator/sdui/validator/template_validator.dart';

const _catalogPath = 'packages/tercen_ui_widgets/catalog.json';

// ---------------------------------------------------------------------------
// Fresh widget builders using SkeletonTheme
// ---------------------------------------------------------------------------

/// Standard toolbar: icon + title on left, subtitle on right.
Map<String, dynamic> _toolbar(String prefix, String title,
    {String? icon, String? subtitle}) {
  final row = <Map<String, dynamic>>[
    {
      'type': 'Row',
      'id': '$prefix-toolbar-left',
      'children': [
        if (icon != null) ...[
          {'type': 'Icon', 'id': '$prefix-toolbar-icon',
            'props': {'icon': icon, 'size': SkeletonTheme.itemIconSize, 'color': 'primary'}},
          {'type': 'SizedBox', 'id': '$prefix-toolbar-gap', 'props': {'width': SkeletonTheme.iconTextGap}},
        ],
        {'type': 'Text', 'id': '$prefix-title',
          'props': {'text': title, 'textStyle': SkeletonTheme.section.textStyle, 'color': SkeletonTheme.section.color}},
      ],
    },
    if (subtitle != null)
      {'type': 'Text', 'id': '$prefix-subtitle',
        'props': {'text': subtitle, 'textStyle': SkeletonTheme.secondary.textStyle, 'color': SkeletonTheme.secondary.color}},
  ];
  return {
    'type': 'Container', 'id': '$prefix-toolbar',
    'props': {'color': SkeletonTheme.toolbarBg, 'padding': SkeletonTheme.toolbarPadding},
    'children': [
      {'type': 'Row', 'id': '$prefix-toolbar-row',
        'props': {'mainAxisAlignment': 'spaceBetween'},
        'children': row},
    ],
  };
}

/// Standard loading/error/ready conditionals wrapping a DataSource's content.
List<Map<String, dynamic>> _dataStateChildren(String prefix, List<Map<String, dynamic>> readyContent) {
  return [
    {'type': 'Conditional', 'id': '$prefix-loading', 'props': {'visible': '{{loading}}'},
      'children': [
        {'type': 'Center', 'id': '$prefix-spinner', 'children': [
          {'type': 'LoadingIndicator', 'id': '$prefix-li', 'props': {'variant': 'skeleton', 'text': 'Loading\u2026'}},
        ]},
      ]},
    {'type': 'Conditional', 'id': '$prefix-error', 'props': {'visible': '{{error}}'},
      'children': [
        {'type': 'Center', 'id': '$prefix-err-center', 'children': [
          {'type': 'Column', 'id': '$prefix-err-col', 'props': {'mainAxisAlignment': 'center'}, 'children': [
            {'type': 'Icon', 'id': '$prefix-err-icon', 'props': {'icon': 'error_outline', 'size': SkeletonTheme.errorIconSize, 'color': SkeletonTheme.errorColor}},
            {'type': 'SizedBox', 'id': '$prefix-err-gap', 'props': {'height': SkeletonTheme.iconTextGap}},
            {'type': 'Text', 'id': '$prefix-err-text', 'props': {'text': '{{errorMessage}}', 'textStyle': SkeletonTheme.primary.textStyle, 'color': SkeletonTheme.errorColor}},
          ]},
        ]},
      ]},
    {'type': 'Conditional', 'id': '$prefix-ready', 'props': {'visible': '{{ready}}'},
      'children': readyContent},
  ];
}

// ---------------------------------------------------------------------------
// Build each widget fresh
// ---------------------------------------------------------------------------

Map<String, dynamic> _buildProjectNavigator() {
  return {
    'metadata': {
      'type': 'ProjectNavigator',
      'tier': 2,
      'description': 'File browser for a Tercen project. Lists project documents with selection and intent navigation.',
      'emittedEvents': ['navigator.focusChanged', 'system.intent'],
      'handlesIntent': {
        'intent': 'openProjectNavigator',
        'propsMap': {'projectId': 'projectId'},
        'windowTitle': 'Files: {{projectName}}',
        'windowSize': 'medium',
      },
      'state': {
        'selection': {'channel': 'navigator.focusChanged', 'matchField': 'id', 'payloadField': 'nodeId'},
        'publishTo': ['navigator.focusChanged'],
      },
    },
    'template': {
      'type': 'Column', 'id': '{{widgetId}}-root',
      'props': {'crossAxisAlignment': 'stretch'},
      'children': [
          _toolbar('{{widgetId}}', 'Navigator', icon: 'folder_open'),
          {'type': 'Expanded', 'id': '{{widgetId}}-body', 'children': [
            {'type': 'DataSource', 'id': '{{widgetId}}-ds',
              'props': {
                'service': 'projectDocumentService',
                'method': 'findProjectObjectsByLastModifiedDate',
                'args': [['{{projectId}}', ''], ['{{projectId}}', ''], 50],
              },
              'children': _dataStateChildren('{{widgetId}}', [
                {'type': 'ListView', 'id': '{{widgetId}}-lv', 'props': {'padding': SkeletonTheme.listPadding},
                  'children': [
                    {'type': 'ForEach', 'id': '{{widgetId}}-fe', 'props': {'items': '{{data}}'},
                      'children': [
                        {'type': 'Action', 'id': 'dbl-{{item.id}}',
                          'props': {'gesture': 'onDoubleTap', 'channel': 'system.intent',
                            'payload': {'intent': '{{item.kind}}', 'id': '{{item.id}}', 'name': '{{item.name}}', 'kind': '{{item.kind}}', 'subKind': '{{item.subKind}}'}},
                          'children': [
                            {'type': 'Action', 'id': 'tap-{{item.id}}',
                              'props': {'gesture': 'onTap', 'channel': 'navigator.focusChanged',
                                'payload': {'nodeId': '{{item.id}}', 'nodeType': '{{item.kind}}', 'nodeName': '{{item.name}}'}},
                              'children': [
                                {'type': 'Padding', 'id': 'pad-{{item.id}}', 'props': {'padding': SkeletonTheme.listItemPadding},
                                  'children': [
                                    {'type': 'Row', 'id': 'row-{{item.id}}', 'children': [
                                      {'type': 'Icon', 'id': 'icon-{{item.id}}', 'props': {'icon': 'description', 'size': SkeletonTheme.itemIconSize, 'color': SkeletonTheme.itemIconColor}},
                                      {'type': 'SizedBox', 'id': 'gap-{{item.id}}', 'props': {'width': SkeletonTheme.iconTextGap}},
                                      {'type': 'Expanded', 'id': 'exp-{{item.id}}', 'children': [
                                        {'type': 'Text', 'id': 'name-{{item.id}}', 'props': {'text': '{{item.name}}', 'textStyle': SkeletonTheme.primary.textStyle}},
                                      ]},
                                      {'type': 'Text', 'id': 'kind-{{item.id}}', 'props': {'text': '{{item.kind}}', 'textStyle': SkeletonTheme.secondary.textStyle, 'color': SkeletonTheme.secondary.color}},
                                    ]},
                                  ]},
                              ]},
                          ]},
                      ]},
                  ]},
              ]),
            },
          ]},
        ],
      },
  };
}

Map<String, dynamic> _buildWorkflowViewer() {
  return {
    'metadata': {
      'type': 'WorkflowViewer',
      'tier': 2,
      'description': 'Interactive directed graph viewer for Tercen workflows.',
      'emittedEvents': ['workflow.selection'],
      'handlesIntent': [
        {'intent': 'openWorkflow', 'propsMap': {'workflowId': 'workflowId'}, 'windowTitle': 'Workflow: {{workflowName}}', 'windowSize': 'large'},
        {'intent': 'Workflow', 'propsMap': {'id': 'workflowId', 'name': 'workflowName'}, 'windowTitle': 'Workflow: {{name}}', 'windowSize': 'large'},
      ],
    },
    'template': {
      'type': 'Column', 'id': '{{widgetId}}-root', 'props': {'crossAxisAlignment': 'stretch'},
      'children': [
        {'type': 'Expanded', 'id': '{{widgetId}}-body', 'children': [
          {'type': 'DataSource', 'id': '{{widgetId}}-ds',
            'props': {'service': 'workflowService', 'method': 'getWorkflowGraph', 'args': ['{{workflowId}}']},
            'children': _dataStateChildren('{{widgetId}}', [
              {'type': 'Column', 'id': '{{widgetId}}-content', 'props': {'crossAxisAlignment': 'stretch'}, 'children': [
                _toolbar('{{widgetId}}', '{{data.name}}', icon: 'account_tree', subtitle: '{{data.nodes.length}} steps'),
                {'type': 'Divider', 'id': '{{widgetId}}-div', 'props': {'color': SkeletonTheme.dividerColor}},
                {'type': 'Expanded', 'id': '{{widgetId}}-graph-exp', 'children': [
                  {'type': 'DirectedGraph', 'id': '{{widgetId}}-graph', 'props': {'channel': 'workflow.selection'}},
                ]},
              ]},
            ]),
          },
        ]},
      ],
    },
  };
}

Map<String, dynamic> _buildDataTableViewer() {
  return {
    'metadata': {
      'type': 'DataTableViewer',
      'tier': 2,
      'description': 'Tabular data viewer for Tercen workflow step tables.',
      'emittedEvents': ['system.selection.table'],
      'handlesIntent': {'intent': 'openStepTables', 'propsMap': {'workflowId': 'workflowId', 'stepId': 'stepId'}, 'windowTitle': 'Tables: {{stepName}}', 'windowSize': 'large'},
    },
    'template': {
      'type': 'Column', 'id': '{{widgetId}}-root', 'props': {'crossAxisAlignment': 'stretch'},
      'children': [
        {'type': 'Expanded', 'id': '{{widgetId}}-body', 'children': [
          {'type': 'DataSource', 'id': '{{widgetId}}-ds',
            'props': {'service': 'workflowService', 'method': 'getStepTables', 'args': ['{{workflowId}}', '{{stepId}}', '{{tableType}}']},
            'children': _dataStateChildren('{{widgetId}}', [
              {'type': 'Column', 'id': '{{widgetId}}-content', 'props': {'crossAxisAlignment': 'stretch'}, 'children': [
                _toolbar('{{widgetId}}', '{{data.stepName}}', icon: 'table_chart', subtitle: '{{data.tableType}}'),
                {'type': 'Divider', 'id': '{{widgetId}}-div', 'props': {'color': SkeletonTheme.dividerColor}},
                {'type': 'Expanded', 'id': '{{widgetId}}-table-exp', 'children': [
                  {'type': 'DataGrid', 'id': '{{widgetId}}-grid', 'props': {
                    'items': '{{data.tables[0].items}}',
                    'columns': '{{data.tables[0].columns}}',
                    'columnMode': 'scroll',
                    'showRowNumbers': true,
                    'sortable': true,
                    'searchMode': 'highlight',
                    'selectionMode': 'single',
                  }},
                ]},
              ]},
            ]),
          },
        ]},
      ],
    },
  };
}

Map<String, dynamic> _buildDocumentViewer() {
  return {
    'metadata': {
      'type': 'DocumentViewer',
      'tier': 2,
      'description': 'Document viewer for Tercen files. Fetches metadata and content.',
      'emittedEvents': ['system.selection.file'],
      'handlesIntent': [
        {'intent': 'openFile', 'propsMap': {'fileId': 'fileId'}, 'windowTitle': '{{fileName}}', 'windowSize': 'medium'},
        {'intent': 'FileDocument', 'propsMap': {'id': 'fileId', 'name': 'fileName'}, 'windowTitle': '{{name}}', 'windowSize': 'medium'},
        {'intent': 'ProjectDocument', 'propsMap': {'id': 'fileId', 'name': 'fileName'}, 'windowTitle': '{{name}}', 'windowSize': 'medium'},
      ],
    },
    'template': {
      'type': 'Column', 'id': '{{widgetId}}-root', 'props': {'crossAxisAlignment': 'stretch'},
      'children': [
        _toolbar('{{widgetId}}', '{{fileName}}', icon: 'description'),
        {'type': 'Expanded', 'id': '{{widgetId}}-body', 'children': [
          {'type': 'DataSource', 'id': '{{widgetId}}-ds',
            'props': {'service': 'fileService', 'method': 'download', 'args': ['{{fileId}}']},
            'children': _dataStateChildren('{{widgetId}}', [
              {'type': 'Padding', 'id': '{{widgetId}}-content-pad', 'props': {'padding': SkeletonTheme.listItemPadding},
                'children': [
                  {'type': 'SelectableText', 'id': '{{widgetId}}-content', 'props': {'text': '{{data}}', 'textStyle': SkeletonTheme.primary.textStyle}},
                ]},
            ]),
          },
        ]},
      ],
    },
  };
}

Map<String, dynamic> _buildPngViewer() {
  return {
    'metadata': {
      'type': 'PngViewer',
      'tier': 2,
      'description': 'Image viewer for Tercen workflow step outputs.',
      'handlesIntent': {'intent': 'openStepImages', 'propsMap': {'workflowId': 'workflowId', 'stepId': 'stepId'}, 'windowTitle': 'Images: {{stepName}}', 'windowSize': 'large'},
    },
    'template': {
      'type': 'Column', 'id': '{{widgetId}}-root', 'props': {'crossAxisAlignment': 'stretch'},
      'children': [
        {'type': 'Expanded', 'id': '{{widgetId}}-body', 'children': [
          {'type': 'DataSource', 'id': '{{widgetId}}-ds',
            'props': {'service': 'tableSchemaService', 'method': 'getStepImages', 'args': ['{{workflowId}}', '{{stepId}}']},
            'children': _dataStateChildren('{{widgetId}}', [
              {'type': 'Column', 'id': '{{widgetId}}-content', 'props': {'crossAxisAlignment': 'stretch'}, 'children': [
                _toolbar('{{widgetId}}', '{{data.stepName}}', icon: 'image', subtitle: '{{data.images.length}} images'),
                {'type': 'Divider', 'id': '{{widgetId}}-div', 'props': {'color': SkeletonTheme.dividerColor}},
                {'type': 'Expanded', 'id': '{{widgetId}}-viewer-exp', 'children': [
                  {'type': 'TabbedImageViewer', 'id': '{{widgetId}}-viewer'},
                ]},
              ]},
            ]),
          },
        ]},
      ],
    },
  };
}

Map<String, dynamic> _buildAuditTrail() {
  return {
    'metadata': {
      'type': 'AuditTrail',
      'tier': 2,
      'description': 'Audit trail log viewer (stub).',
      'emittedEvents': ['window.intent'],
    },
    'template': {
      'type': 'Column', 'id': '{{widgetId}}-root', 'props': {'crossAxisAlignment': 'stretch'},
      'children': [
        _toolbar('{{widgetId}}', 'Audit Trail', icon: 'checklist'),
        {'type': 'Expanded', 'id': '{{widgetId}}-body', 'children': [
          {'type': 'Center', 'id': '{{widgetId}}-placeholder', 'children': [
            {'type': 'Text', 'id': '{{widgetId}}-placeholder-text',
              'props': {'text': 'Select a scope to view audit events', 'textStyle': SkeletonTheme.secondary.textStyle, 'color': SkeletonTheme.secondary.color}},
          ]},
        ]},
      ],
    },
  };
}

Map<String, dynamic> _buildTeamManager() {
  return {
    'metadata': {
      'type': 'TeamManager',
      'tier': 2,
      'description': 'Team management widget for viewing and editing team members.',
      'handlesIntent': {'intent': 'openTeamWidget', 'propsMap': {'teamId': 'teamId'}, 'windowTitle': 'Team Manager', 'windowSize': 'large'},
    },
    'template': {
      'type': 'Column', 'id': '{{widgetId}}-root', 'props': {'crossAxisAlignment': 'stretch'},
      'children': [
        _toolbar('{{widgetId}}', 'Team Manager', icon: 'group'),
        {'type': 'Expanded', 'id': '{{widgetId}}-body', 'children': [
          {'type': 'Center', 'id': '{{widgetId}}-placeholder', 'children': [
            {'type': 'Text', 'id': '{{widgetId}}-placeholder-text',
              'props': {'text': 'Team management coming soon', 'textStyle': SkeletonTheme.secondary.textStyle, 'color': SkeletonTheme.secondary.color}},
          ]},
        ]},
      ],
    },
  };
}

// ChatBox, HomePanel, MainHeader, TaskMonitor — read from catalog.json backup
// since they use compiled scope builders (ChatStream, TaskStream, WindowShell)
// that archetypes can't generate. We copy metadata + template, stripping
// removed widgets (StateHolder).
Map<String, dynamic> _copyFromCatalog(Map<String, dynamic> catalog, String type) {
  final widget = (catalog['widgets'] as List).firstWhere(
    (w) => (w as Map)['metadata']?['type'] == type,
    orElse: () => throw StateError('$type not found in catalog'),
  ) as Map<String, dynamic>;
  // Deep copy, then strip removed widget types.
  final copy = jsonDecode(jsonEncode(widget)) as Map<String, dynamic>;
  _stripRemovedWidgets(copy['template'] as Map<String, dynamic>);
  return copy;
}

/// Recursively strip removed widget types (StateHolder) — unwrap to children.
/// Also removes props that depend on removed widgets (pageSizeChannel, {{state}}).
void _stripRemovedWidgets(Map<String, dynamic> node) {
  // Remove props that reference removed systems.
  final props = node['props'] as Map<String, dynamic>?;
  if (props != null) {
    props.remove('pageSizeChannel');
    props.remove('initialState');
    // Remove any prop value that references {{state}}
    props.removeWhere((k, v) =>
        v is String && v.contains('{{state'));
  }

  final children = node['children'] as List<dynamic>?;
  if (children == null) return;

  for (var i = 0; i < children.length; i++) {
    final child = children[i] as Map<String, dynamic>;
    if (child['type'] == 'StateHolder') {
      final inner = child['children'] as List<dynamic>? ?? [];
      if (inner.isNotEmpty) {
        children[i] = inner.first;
      }
    }
  }

  for (final child in children) {
    if (child is Map<String, dynamic>) {
      _stripRemovedWidgets(child);
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  test('build catalog from scratch using formal specs', () {
    // Read backup for widgets we need to copy (compiled scope builders).
    // The backup was created before this migration.
    final backupFile = File('packages/tercen_ui_widgets/catalog.json.bak');
    final sourceFile = backupFile.existsSync() ? backupFile : File(_catalogPath);
    if (!sourceFile.existsSync()) fail('No catalog source found');
    final originalCatalog =
        jsonDecode(sourceFile.readAsStringSync()) as Map<String, dynamic>;

    // Build all widgets fresh.
    final widgets = <Map<String, dynamic>>[
      // Archetype / SkeletonTheme rewrites
      _buildProjectNavigator(),
      _buildWorkflowViewer(),
      _buildDataTableViewer(),
      _buildDocumentViewer(),
      _buildPngViewer(),
      _buildAuditTrail(),
      _buildTeamManager(),
      // Compiled scope builders — copied from catalog.json
      _copyFromCatalog(originalCatalog, 'ChatBox'),
      _copyFromCatalog(originalCatalog, 'HomePanel'),
      _copyFromCatalog(originalCatalog, 'MainHeader'),
      _copyFromCatalog(originalCatalog, 'TaskMonitor'),
    ];

    // Build catalog.
    final catalog = <String, dynamic>{
      'widgets': widgets,
      'home': originalCatalog['home'],
    };

    // Validate each fresh widget.
    final registry = WidgetRegistry();
    registerBuiltinWidgets(registry);
    registry.loadCatalog(catalog);
    final validator = TemplateValidator(registry: registry);

    var freshErrors = 0;
    for (final w in widgets) {
      final type = w['metadata']['type'] as String;
      final meta = WidgetMetadata.fromJson(w['metadata'] as Map<String, dynamic>);
      final node = SduiNode.fromJson(w['template'] as Map<String, dynamic>);
      final results = validator.validate(metadata: meta, template: node);
      final errors = results.where((r) => r.isError).toList();
      final warnings = results.where((r) => r.isWarning).toList();

      // ignore: avoid_print
      print('  $type: ${errors.length} errors, ${warnings.length} warnings');
      for (final r in errors) {
        // ignore: avoid_print
        print('    [E] ${r.ruleId}: ${r.message}');
      }

      // Only count non-scope errors from fresh widgets.
      // Scope errors for intent-provided props (projectId, workflowId, etc.)
      // are expected — these resolve at runtime from window props.
      if (!{'ChatBox', 'HomePanel', 'MainHeader', 'TaskMonitor'}.contains(type)) {
        freshErrors += errors
            .where((r) => !r.ruleId.contains('out-of-scope'))
            .length;
      }
    }

    // Write catalog.json.
    final catalogFile = File(_catalogPath);
    catalogFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(catalog));

    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('Wrote ${widgets.length} widgets to catalog.json');
    // ignore: avoid_print
    print('Fresh widget errors: $freshErrors');

    expect(freshErrors, 0, reason: 'Fresh widgets should have no validation errors');
  });
}
