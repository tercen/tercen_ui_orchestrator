import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';

import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sci_http_client/http_auth_client.dart' as auth_http;
import 'package:sci_http_client/http_browser_client.dart' as io_http;
import 'package:sci_http_client/http_client.dart' as http_api;
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sci_tercen_client/sci_client_service_factory.dart' as tercen;
import 'package:tercen_ui_orchestrator/presentation/screens/shell_screen.dart';

import 'package:sdui/sdui.dart';
import 'package:tercen_ui_orchestrator/sdui/service/service_call_dispatcher.dart';
import 'package:tercen_ui_orchestrator/services/agent_client.dart';
import 'package:tercen_ui_orchestrator/services/chat_backend.dart';

import 'package:tercen_ui_orchestrator/sdui/widgets/chat_stream.dart';
import 'package:tercen_ui_orchestrator/sdui/widgets/task_stream.dart';
import 'package:tercen_ui_orchestrator/services/layout_persistence_service.dart';
import 'package:tercen_ui_orchestrator/services/orchestrator_client.dart';
import 'package:tercen_ui_orchestrator/services/task_monitor_service.dart';

// Compile-time defaults, overridable via URL query parameters:
//   ?token=eyJ...    → TERCEN_TOKEN
//   ?server=ws://... → SERVER_URL
final String _serverUrl = Uri.base.queryParameters['server'] ??
    const String.fromEnvironment('SERVER_URL', defaultValue: '');
final String _anthropicApiKey =
    const String.fromEnvironment('ANTHROPIC_API_KEY', defaultValue: '');
final String _tercenToken = Uri.base.queryParameters['token'] ??
    const String.fromEnvironment('TERCEN_TOKEN', defaultValue: '');
final String _serviceUriOverride = Uri.base.queryParameters['serviceUri'] ??
    const String.fromEnvironment('SERVICE_URI', defaultValue: '');

/// Decodes the JWT payload.
Map<String, dynamic> _decodeJwtPayload(String token) {
  if (token.isEmpty) return {};
  try {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    var payload = parts[1];
    switch (payload.length % 4) {
      case 2: payload += '=='; break;
      case 3: payload += '='; break;
    }
    final decoded = utf8.decode(base64Url.decode(payload));
    return jsonDecode(decoded) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

/// Extracts the service URI from the JWT token's `iss` (issuer) field.
String _parseServiceUriFromToken(String token) {
  return _decodeJwtPayload(token)['iss'] as String? ?? '';
}

void main() {
  // 1. Flutter build/layout/paint errors → ErrorReporter + default red widget
  FlutterError.onError = (details) {
    ErrorReporter.instance.report(
      details.exception,
      stackTrace: details.stack,
      source: 'flutter.${details.library ?? 'unknown'}',
      context: details.context?.toString(),
      severity: ErrorSeverity.fatal,
    );
    // Still show Flutter's default red error widget
    FlutterError.presentError(details);
  };

  // 2. Uncaught async errors (Futures, microtasks, Zones) → ErrorReporter
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorReporter.instance.report(
      error,
      stackTrace: stack,
      source: 'dart.async',
      severity: ErrorSeverity.fatal,
    );
    return true; // handled — don't crash the app
  };

  runApp(const OrchestratorApp());
}

class OrchestratorApp extends StatefulWidget {
  const OrchestratorApp({super.key});

  @override
  State<OrchestratorApp> createState() => _OrchestratorAppState();
}

class _OrchestratorAppState extends State<OrchestratorApp> {
  late final SduiContext _sduiContext;
  late ChatBackend _chatBackend;
  OrchestratorClient? _wsClient; // Only set in WebSocket mode
  bool _isDark = false; // Light mode is the default
  Map<String, dynamic>? _themeTokens;
  bool _authReady = false;
  String? _authError;
  String? _defaultProjectId; // agent_internal project, used as fallback for layout saves
  LayoutPersistenceService? _layoutPersistence;
  Map<String, dynamic>? _loadedCatalog; // cached for home layout reload
  TaskMonitorService? _taskMonitor;

  /// Stable chat message stream that survives backend swaps.
  /// When _chatBackend changes, we re-pipe from the new backend's stream.
  final _chatBridge = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _chatBridgeSub;

  SduiTheme get _currentTheme {
    final tokens = _themeTokens;
    if (tokens != null) {
      return SduiTheme.fromJson(tokens, themeName: _isDark ? 'dark' : 'light');
    }
    return _isDark ? const SduiTheme.dark() : const SduiTheme.light();
  }

  @override
  void initState() {
    super.initState();
    _sduiContext = SduiContext.create(theme: const SduiTheme.light());
    _registerResourceMappings();
    _registerOrchestratorWidgets();
    _listenHeaderIntents();
    _listenWindowIntents();
    _listenAuditDateRange();
    _listenAuditSelectionRelay();
    _listenChatActions();
    _listenWorkflowActions();
    _listenFileUpload();
    _listenFileDownload();
    _listenTypeFilter();
    _listenFocusRelay();

    if (_serverUrl.isNotEmpty) {
      // Dev mode: WebSocket to local Dart server
      final wsClient = OrchestratorClient(
        baseUrl: _serverUrl,
        eventBus: _sduiContext.eventBus,
      );
      wsClient.connect();
      _wsClient = wsClient;
      _chatBackend = wsClient;
      debugPrint('[init] Using WebSocket backend: $_serverUrl');
    } else {
      // Placeholder — AgentClient is created after auth bootstrap
      // when ServiceFactory is available
      _chatBackend = _PlaceholderBackend();
      debugPrint('[init] Will use Agent backend after auth');
    }

    // Wire chat backend into SDUI via a stable bridge stream.
    // The bridge survives backend swaps (placeholder → AgentClient).
    _pipeChatBackend();
    _sduiContext.renderContext.chatStreamProvider = (
      messages: _chatBridge.stream,
      send: (text) {
        debugPrint('[chat-bridge] sendChat("$text") via ${_chatBackend.runtimeType}');
        _chatBackend.sendChat(text);
      },
      isConnected: () => _chatBackend.isConnected,
      resetSession: () {
        debugPrint('[chat-bridge] resetSession via ${_chatBackend.runtimeType}');
        _chatBackend.resetSession();
      },
    );

    _startup();
  }

  /// Pipe current _chatBackend's message stream into the stable bridge.
  void _pipeChatBackend() {
    _chatBridgeSub?.cancel();
    debugPrint('[chat-bridge] Piping from ${_chatBackend.runtimeType}');
    _chatBridgeSub = _chatBackend.chatMessages.listen(
      (msg) {
        debugPrint('[chat-bridge] → ${msg['type']}');
        _chatBridge.add(msg);
      },
      onError: (e) => _chatBridge.addError(e),
    );
  }

  /// Listen for header menu actions (theme toggle, etc.)
  int _chatSessionCounter = 0;
  int _workflowViewerCounter = 0;

  /// Clear all panes and reload the home layout from catalog.json.
  void _navigateHome() {
    final catalog = _loadedCatalog;
    if (catalog == null) {
      debugPrint('[navigateHome] No catalog loaded');
      return;
    }
    _sduiContext.windowManager.clearAll();
    _openHomeWindows(catalog);
    debugPrint('[navigateHome] Reloaded home layout');
  }

  void _openWorkflowViewer({String? workflowId}) {
    _workflowViewerCounter++;
    final id = 'workflow-viewer-$_workflowViewerCounter';
    final props = <String, dynamic>{};
    if (workflowId != null) props['workflowId'] = workflowId;

    _sduiContext.eventBus.publish(
      'system.layout.op',
      EventPayload(type: 'layout.op', data: {
        'op': 'addWindow',
        'id': id,
        'size': 'large',
        'align': 'center',
        'title': 'Workflow',
        'content': {
          'type': 'WorkflowViewer',
          'id': '$id-root',
          'props': props,
          'children': [],
        },
      }),
    );
    debugPrint('[workflow] Opened WorkflowViewer as "$id"');
  }

  void _listenChatActions() {
    _sduiContext.eventBus.subscribe('chat.newSession').listen((event) {
      _chatSessionCounter++;
      final id = 'chat-box-$_chatSessionCounter';
      final sourceId = event.sourceWidgetId;
      _sduiContext.eventBus.publish(
        'system.layout.op',
        EventPayload(type: 'layout.op', data: {
          'op': 'addWindow',
          'id': id,
          'size': 'column',
          'align': 'right',
          'title': 'Chat',
          'placement': 'samePane',
          if (sourceId != null) 'sourceWidgetId': sourceId,
          'content': {
            'type': 'ChatBox',
            'id': '$id-root',
            'props': {},
            'children': [],
          },
        }),
      );
      debugPrint('[chat] Opened new session as "$id"');
    });

    _sduiContext.eventBus.subscribe('chat.showHistory').listen((event) {
      debugPrint('[chat] History requested (not yet implemented)');
      // DEV: show a system message in the chat indicating the event fired
      _sduiContext.eventBus.publish(
        'chat.systemMessage',
        EventPayload(type: 'chat.systemMessage', data: {
          'text': '[DEV] chat.showHistory event fired — History feature not yet wired in.',
        }),
      );
    });
  }

  void _listenWorkflowActions() {
    _sduiContext.eventBus.subscribe('workflow.open').listen((event) {
      _openWorkflowViewer(
        workflowId: event.data['workflowId'] as String?,
      );
    });
  }

  void _listenHeaderIntents() {
    _sduiContext.eventBus.subscribe('header.intent').listen((event) {
      final value = event.data['value'] as String? ??
          event.data['intent'] as String? ??
          '';
      debugPrint('[header] intent: $value');
      switch (value) {
        case 'toggleTheme':
          _toggleTheme();
        case 'navigateHome':
          _navigateHome();
        case 'saveLayout':
          _saveLayout();
        case 'connectLlm':
          debugPrint('[header] connectLlm — not yet implemented');
        case 'taskManager':
          _sduiContext.eventBus.publish(
            'system.intent',
            EventPayload(
              type: 'openTaskMonitor',
              sourceWidgetId: 'header',
              data: {'intent': 'openTaskMonitor'},
            ),
          );
        case 'openWorkflow':
          _openWorkflowViewer(
            workflowId: event.data['workflowId'] as String?,
          );
        case 'signOut':
          debugPrint('[header] signOut — not yet implemented');
      }
    });
  }

  /// Listen for window-level intents that the orchestrator must handle
  /// (e.g. opening external URLs in a new browser tab, creating projects).
  void _listenWindowIntents() {
    _sduiContext.eventBus.subscribe('window.intent').listen((event) {
      // Toolbar actions publish with type='action' and data.intent=<name>.
      final intent =
          event.data['intent'] as String? ?? event.type;
      debugPrint('[window.intent] received: intent=$intent type=${event.type} data=${event.data}');
      switch (intent) {
        case 'openUrl':
          final url = event.data['url'] as String?;
          if (url != null && url.isNotEmpty) {
            debugPrint('[window.intent] openUrl: $url');
            web.window.open(url, '_blank');
          }
        case 'createProject':
          _showCreateProjectPopup(event.data['sourceWindowId'] as String?);
        case 'openTeamManagement':
          _openWidgetAsTab(
            widgetType: 'TeamManager',
            windowId: 'team-manager',
            title: 'Teams',
            sourceWindowId: event.data['sourceWindowId'] as String?,
            placement: event.data['placement'] as String? ?? 'samePane',
          );
        case 'openAuditTrail':
          _openWidgetAsTab(
            widgetType: 'AuditTrail',
            windowId: 'audit-trail',
            title: 'Audit Trail',
            sourceWindowId: event.data['sourceWindowId'] as String?,
            placement: event.data['placement'] as String? ?? 'samePane',
            props: {
              'scopeType': event.data['scopeType'] as String? ?? 'user',
              'scopeId': event.data['scopeId'] as String? ?? '',
            },
          );
      }
    });
  }

  /// Wire audit trail date range controls.
  /// Collects date TextField values and publishes them to the DataSource refresh channel.
  void _listenAuditDateRange() {
    final eb = _sduiContext.eventBus;
    final dateValues = <String, String>{'from': '', 'to': ''};

    // Track date field changes
    eb.subscribe('input.audit-trail-root-date-from.changed').listen((e) {
      dateValues['from'] = (e.data['value'] as String?) ?? '';
    });
    eb.subscribe('input.audit-trail-root-date-to.changed').listen((e) {
      dateValues['to'] = (e.data['value'] as String?) ?? '';
    });

    // Apply button: collect dates and trigger DataSource refresh
    eb.subscribe('audit.audit-trail-root.applyDateRange').listen((_) {
      final from = dateValues['from'] ?? '';
      final to = dateValues['to'] ?? '';

      // Convert YYYY-MM-DD to ISO 8601 for CouchDB range query
      final startDate = from.isNotEmpty ? '${from}T00:00:00.000Z' : '';
      final endDate = to.isNotEmpty ? '${to}T23:59:59.999Z' : '';

      debugPrint('[audit] Apply date range: $startDate → $endDate');
      eb.publish(
        'audit.audit-trail-root.refresh',
        EventPayload(type: 'refresh', data: {
          'startDate': startDate,
          'endDate': endDate,
        }),
      );
    });
  }

  /// Open a widget as a tab in the source pane (or new pane).
  void _openWidgetAsTab({
    required String widgetType,
    required String windowId,
    required String title,
    String? sourceWindowId,
    String placement = 'samePane',
    Map<String, dynamic> props = const {},
  }) {
    _sduiContext.eventBus.publish(
      'system.layout.op',
      EventPayload(type: 'layout.op', data: {
        'op': 'addWindow',
        'id': windowId,
        'size': 'large',
        'align': 'center',
        'title': title,
        'placement': placement,
        'sourceWidgetId': sourceWindowId,
        'content': {
          'type': widgetType,
          'id': '$windowId-root',
          'props': props,
          'children': [],
        },
      }),
    );
    debugPrint('[window.intent] Opened $widgetType as "$windowId" in $placement');
  }

  /// Fetch the user's teams and show a "New Project" form popup.
  Future<void> _showCreateProjectPopup(String? sourceWindowId) async {
    final factory = tercen.ServiceFactory.CURRENT;
    if (factory == null) {
      debugPrint('[createProject] No ServiceFactory — auth not ready');
      return;
    }

    final jwtData = _decodeJwtPayload(_tercenToken)['data']
        as Map<String, dynamic>? ?? {};
    final username = jwtData['u'] as String? ?? '';
    if (username.isEmpty) return;

    // Fetch all teams (paginated scan via findStartKeys on teamByOwner view).
    List<String> teamNames;
    try {
      final svc = factory.teamService;
      final teams = await svc.findTeamByOwner(keys: [username]);
      teamNames = teams.map((t) => t.name).where((n) => n.isNotEmpty).toList();
      debugPrint('[createProject] findTeamByOwner returned ${teamNames.length} team(s): $teamNames');
    } catch (e) {
      debugPrint('[createProject] Failed to fetch teams: $e');
      teamNames = [];
    }

    // Always include the user's own namespace as first option.
    if (!teamNames.contains(username)) {
      teamNames.insert(0, username);
    }

    // Channels for form interactions.
    const submitChannel = 'popup.createProject.submit';
    const cancelChannel = 'popup.createProject.cancel';
    const dialogId = 'new-project-dialog';
    final windowId = sourceWindowId ?? 'home-panel-main';

    // Collect form values as they change via input channels.
    final formValues = <String, dynamic>{
      'owner': username, // default
    };
    final inputSubs = <StreamSubscription<EventPayload>>[];
    for (final fieldId in [
      '$dialogId-name', '$dialogId-owner', '$dialogId-description',
      '$dialogId-public', '$dialogId-gitUrl', '$dialogId-gitBranch',
      '$dialogId-gitTag', '$dialogId-gitToken',
    ]) {
      inputSubs.add(
        _sduiContext.eventBus.subscribe('input.$fieldId.changed').listen((e) {
          final key = fieldId.replaceFirst('$dialogId-', '');
          formValues[key] = e.data['value'];
        }),
      );
    }

    void _closeDialog() {
      for (final sub in inputSubs) { sub.cancel(); }
      _sduiContext.eventBus.publish(
        'window.$windowId.popup.close',
        EventPayload(type: 'popup.close', data: {}),
      );
    }

    // Listen for submit (one-shot with validation).
    late StreamSubscription<EventPayload> submitSub;
    submitSub = _sduiContext.eventBus.subscribe(submitChannel).listen((event) {
      // Validate required fields.
      final name = (formValues['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) {
        _sduiContext.eventBus.publish(
          'system.notification',
          EventPayload(type: 'notification', data: {
            'severity': 'warning',
            'message': 'Project name is required',
          }),
        );
        return; // Don't close, don't cancel — let user fix and retry.
      }
      submitSub.cancel();
      _handleCreateProjectSubmit({'formValues': formValues}, sourceWindowId);
      _closeDialog();
    });

    // Listen for cancel (one-shot).
    late StreamSubscription<EventPayload> cancelSub;
    cancelSub = _sduiContext.eventBus.subscribe(cancelChannel).listen((_) {
      cancelSub.cancel();
      submitSub.cancel();
      _closeDialog();
    });

    // Build the dropdown items for the owner field.
    final ownerItems = teamNames
        .map((t) => {'value': t, 'label': t})
        .toList();

    // Open FormDialog as a popup overlay with SDUI content.
    _sduiContext.eventBus.publish(
      'window.$windowId.popup.open',
      EventPayload(
        type: 'popup.open',
        data: {
          'content': {
          'type': 'FormDialog',
          'id': '$dialogId-root',
          'props': {
            'title': 'New Project',
            'visible': true,
            'modal': true,
          },
          'children': [
            // Project Name
            {
              'type': 'TextField',
              'id': '$dialogId-name',
              'props': {'label': 'Project Name', 'autofocus': true},
              'children': [],
            },
            {'type': 'SizedBox', 'id': '$dialogId-sp1', 'props': {'height': 8}, 'children': []},
            // Owner dropdown
            {
              'type': 'DropdownButton',
              'id': '$dialogId-owner',
              'props': {
                'items': ownerItems,
                'value': username,
                'label': 'Owner',
              },
              'children': [],
            },
            {'type': 'SizedBox', 'id': '$dialogId-sp2', 'props': {'height': 8}, 'children': []},
            // Description
            {
              'type': 'TextField',
              'id': '$dialogId-description',
              'props': {'label': 'Description', 'maxLines': 2},
              'children': [],
            },
            {'type': 'SizedBox', 'id': '$dialogId-sp3', 'props': {'height': 8}, 'children': []},
            // Public switch + Git toggle on same row
            {
              'type': 'Row',
              'id': '$dialogId-options-row',
              'props': {'mainAxisAlignment': 'start'},
              'children': [
                {
                  'type': 'Tooltip',
                  'id': '$dialogId-public-tip',
                  'props': {'message': 'Make this visible to everyone on the server'},
                  'children': [
                    {
                      'type': 'Row',
                      'id': '$dialogId-public-row',
                      'props': {'mainAxisSize': 'min'},
                      'children': [
                        {
                          'type': 'Switch',
                          'id': '$dialogId-public',
                          'props': {'value': false},
                          'children': [],
                        },
                        {
                          'type': 'SizedBox',
                          'id': '$dialogId-sp-pub',
                          'props': {'width': 4},
                          'children': [],
                        },
                        {
                          'type': 'Text',
                          'id': '$dialogId-public-label',
                          'props': {'text': 'Public'},
                          'children': [],
                        },
                      ],
                    },
                  ],
                },
                {
                  'type': 'SizedBox',
                  'id': '$dialogId-sp-gap',
                  'props': {'width': 16},
                  'children': [],
                },
                {
                  'type': 'ToggleButton',
                  'id': '$dialogId-git-state',
                  'props': {
                    'icon': 'account_tree',
                    'value': false,
                    'tooltip': 'Add from Git',
                  },
                  'children': [],
                },
              ],
            },
            // Git fields — hidden by default, shown when git switch is toggled
            {
              'type': 'ReactTo',
              'id': '$dialogId-git-react',
              'props': {'channel': 'input.$dialogId-git-state.changed'},
              'children': [
                {
                  'type': 'Conditional',
                  'id': '$dialogId-git-cond',
                  'props': {'visible': '{{value}}'},
                  'children': [
                    {'type': 'SizedBox', 'id': '$dialogId-sp-git1', 'props': {'height': 8}, 'children': []},
                    {
                      'type': 'TextField',
                      'id': '$dialogId-gitUrl',
                      'props': {'label': 'Repository URL'},
                      'children': [],
                    },
                    {'type': 'SizedBox', 'id': '$dialogId-sp-git2', 'props': {'height': 8}, 'children': []},
                    {
                      'type': 'TextField',
                      'id': '$dialogId-gitBranch',
                      'props': {'label': 'Branch'},
                      'children': [],
                    },
                    {'type': 'SizedBox', 'id': '$dialogId-sp-git3', 'props': {'height': 8}, 'children': []},
                    {
                      'type': 'TextField',
                      'id': '$dialogId-gitTag',
                      'props': {'label': 'Tag'},
                      'children': [],
                    },
                    {'type': 'SizedBox', 'id': '$dialogId-sp-git4', 'props': {'height': 8}, 'children': []},
                    {
                      'type': 'TextField',
                      'id': '$dialogId-gitToken',
                      'props': {'label': 'Git Token'},
                      'children': [],
                    },
                  ],
                },
              ],
            },
            {'type': 'SizedBox', 'id': '$dialogId-sp4', 'props': {'height': 16}, 'children': []},
            // Action buttons
            {
              'type': 'Row',
              'id': '$dialogId-actions',
              'props': {'mainAxisAlignment': 'end'},
              'children': [
                {
                  'type': 'GhostButton',
                  'id': '$dialogId-cancel',
                  'props': {'text': 'Cancel', 'channel': cancelChannel},
                  'children': [],
                },
                {
                  'type': 'SizedBox',
                  'id': '$dialogId-sp-btn',
                  'props': {'width': 8},
                  'children': [],
                },
                {
                  'type': 'PrimaryButton',
                  'id': '$dialogId-submit',
                  'props': {'text': 'Create Project', 'channel': submitChannel},
                  'children': [],
                },
              ],
            },
          ],
        },
      }),
    );
    debugPrint('[createProject] Opened FormDialog with ${teamNames.length} team options');
  }

  /// Handle the form submit from the "New Project" popup.
  Future<void> _handleCreateProjectSubmit(
      Map<String, dynamic> data, String? sourceWindowId) async {
    final factory = tercen.ServiceFactory.CURRENT;
    if (factory == null) return;

    final formValues = data['formValues'] as Map<String, dynamic>? ?? {};
    final name = (formValues['name'] as String?)?.trim() ?? '';
    final owner = (formValues['owner'] as String?)?.trim() ?? '';
    final description = (formValues['description'] as String?)?.trim() ?? '';
    final isPublic = formValues['public'] == true;
    final gitUrl = (formValues['gitUrl'] as String?)?.trim() ?? '';
    final gitBranch = (formValues['gitBranch'] as String?)?.trim() ?? '';
    final gitTag = (formValues['gitTag'] as String?)?.trim() ?? '';
    final gitToken = (formValues['gitToken'] as String?)?.trim() ?? '';
    final isGitClone = gitUrl.isNotEmpty;

    if (name.isEmpty || owner.isEmpty) {
      debugPrint('[createProject] Missing name or owner');
      return;
    }

    try {
      debugPrint('[createProject] Creating project "$name" for owner "$owner"'
          '${isGitClone ? " from git: $gitUrl" : ""}');
      final project = sci.Project()
        ..name = name
        ..description = description
        ..isPublic = isPublic
        ..acl.owner = owner;

      // Store GIT_URL in project meta if cloning from git.
      if (isGitClone) {
        final gitUrlMeta = project.getOrCreateMetaPair('GIT_URL');
        gitUrlMeta.value = gitUrl;
      }

      final created = await factory.projectService.create(project);
      debugPrint('[createProject] Created project: ${created.id}');

      // If cloning from git, create a GitProjectTask to pull the repo.
      if (isGitClone) {
        final task = sci.GitProjectTask()..owner = owner;
        void addMeta(String key, String value) {
          task.meta.add(sci.Pair()..key = key..value = value);
        }
        addMeta('PROJECT_ID', created.id);
        addMeta('PROJECT_REV', created.rev);
        addMeta('GIT_ACTION', 'reset/pull');
        addMeta('GIT_PAT', gitToken);
        addMeta('GIT_URL', gitUrl);
        addMeta('GIT_BRANCH', gitBranch);
        addMeta('GIT_COMMIT', '');
        addMeta('GIT_MESSAGE', '');
        addMeta('GIT_TAG', gitTag);
        await factory.taskService.create(task);
        debugPrint('[createProject] GitProjectTask created for ${created.id}');
      }

      // Open the new project in the same pane.
      _sduiContext.eventBus.publish(
        'window.intent',
        EventPayload(
          type: 'openResource',
          sourceWidgetId: sourceWindowId,
          data: {
            'intent': 'openResource',
            'resourceType': 'project',
            'resourceId': created.id,
            'label': name,
            'placement': 'samePane',
            'sourceWindowId': sourceWindowId,
          },
        ),
      );

      // Show success notification.
      _sduiContext.eventBus.publish(
        'system.notification',
        EventPayload(
          type: 'notification',
          data: {
            'severity': 'info',
            'message': 'Project "$name" created successfully',
          },
        ),
      );
    } catch (e) {
      debugPrint('[createProject] Error: $e');
      _sduiContext.eventBus.publish(
        'system.notification',
        EventPayload(
          type: 'notification',
          data: {
            'severity': 'error',
            'message': 'Failed to create project: $e',
          },
        ),
      );
    }
  }

  Future<void> _startup() async {
    _startTrackingSelections();
    await _bootstrapAuth();
    _initLayoutPersistence();
    _initTaskMonitor();
    // Theme uses compiled-in defaults from SduiTheme.light() — no runtime fetch needed.
    // Token values are baked into the schema at generation time.
    _autoLoadCatalog(); // non-blocking — catalog loads after auth
  }

  void _initTaskMonitor() {
    final monitor = TaskMonitorService(eventBus: _sduiContext.eventBus);
    _taskMonitor = monitor;

    // Wire the provider into SDUI context
    _sduiContext.renderContext.taskStreamProvider = (
      tasks: monitor.tasks,
      cancel: monitor.cancelTask,
      hasRunning: () => monitor.hasRunning,
    );

    // Start polling (needs ServiceFactory to be available)
    monitor.start();
  }

  void _initLayoutPersistence() {
    _layoutPersistence = LayoutPersistenceService(
      windowManager: _sduiContext.windowManager,
      eventBus: _sduiContext.eventBus,
      getUsername: () =>
          (_sduiContext.renderContext.templateResolver.get('username')
              as String?) ??
          '',
      getProjectId: () {
        final selected = _selections['selectedProjectId'] as String?;
        return (selected != null && selected.isNotEmpty)
            ? selected
            : _defaultProjectId;
      },
    );
  }

  /// Auto-load the widget catalog.
  /// In WebSocket mode: fetches from the server's /api/widget-catalog endpoint.
  /// In agent mode: fetches catalog.json directly from GitHub using the
  /// repo/ref configured in orchestrator.config.json (bundled as Flutter asset).
  Future<void> _autoLoadCatalog() async {
    try {
      Map<String, dynamic>? catalog;

      // Try bundled local catalog first (for dev), then server/GitHub
      catalog = await _tryLoadBundledCatalog();

      if (catalog == null && _serverUrl.isNotEmpty) {
        // WebSocket mode — server proxies the catalog
        catalog = await _fetchCatalogFromServer();
      }
      if (catalog == null) {
        // Agent mode — fetch directly from GitHub
        catalog = await _fetchCatalogFromGitHub();
      }

      if (catalog == null) return;

      final widgets = catalog['widgets'] as List? ?? [];
      if (widgets.isNotEmpty) {
        _sduiContext.registry.loadCatalog(catalog);
        _loadedCatalog = catalog;
        debugPrint('[catalog] Loaded ${widgets.length} widget(s)');
        _openHomeWindows(catalog);
      } else {
        debugPrint('[catalog] Empty catalog — no widgets');
      }
    } catch (e) {
      debugPrint('[catalog] Auto-load failed: $e');
    }
  }

  /// Try loading a bundled catalog.json asset (for local dev).
  Future<Map<String, dynamic>?> _tryLoadBundledCatalog() async {
    try {
      final str = await rootBundle.loadString('catalog.json');
      final catalog = jsonDecode(str) as Map<String, dynamic>;
      debugPrint('[catalog] Loaded from bundled asset');
      return catalog;
    } catch (_) {
      return null; // No bundled catalog — fall through
    }
  }

  /// Fetch catalog from the WebSocket server's API.
  Future<Map<String, dynamic>?> _fetchCatalogFromServer() async {
    final httpUrl = _serverUrl
        .replaceFirst('ws://', 'http://')
        .replaceFirst('wss://', 'https://');
    final url = '$httpUrl/api/widget-catalog';

    final httpClient = io_http.HttpBrowserClient();
    final response = await httpClient.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body as String) as Map<String, dynamic>;
    }
    debugPrint('[catalog] Server returned ${response.statusCode}');
    return null;
  }

  /// Fetch catalog.json directly from GitHub using orchestrator.config.json.
  Future<Map<String, dynamic>?> _fetchCatalogFromGitHub() async {
    // Load config asset
    final configStr = await rootBundle.loadString('orchestrator.config.json');
    final config = jsonDecode(configStr) as Map<String, dynamic>;
    final lib = config['widgetLibrary'] as Map<String, dynamic>?;
    if (lib == null) {
      debugPrint('[catalog] No widgetLibrary in config');
      return null;
    }

    final repo = lib['repo'] as String? ?? '';
    final ref = lib['ref'] as String? ?? 'main';
    final catalogFile = lib['catalogFile'] as String? ?? 'catalog.json';
    if (repo.isEmpty) {
      debugPrint('[catalog] No repo URL in config');
      return null;
    }

    // Build raw.githubusercontent.com URL
    final uri = Uri.parse(repo);
    final segments = uri.pathSegments;
    if (segments.length < 2) {
      debugPrint('[catalog] Invalid repo URL: $repo');
      return null;
    }
    final rawUrl = 'https://raw.githubusercontent.com/'
        '${segments[0]}/${segments[1]}/$ref/$catalogFile';
    debugPrint('[catalog] Fetching $rawUrl');

    final httpClient = io_http.HttpBrowserClient();
    final response = await httpClient.get(rawUrl);

    if (response.statusCode == 200) {
      return jsonDecode(response.body as String) as Map<String, dynamic>;
    }
    debugPrint('[catalog] GitHub returned ${response.statusCode}');
    return null;
  }

  /// Open home regions and windows defined in the catalog's "home" key.
  /// Regions are fixed UI areas (e.g., header at top); windows are floating.
  void _openHomeWindows(Map<String, dynamic> catalog) {
    final home = catalog['home'] as Map<String, dynamic>?;
    if (home == null) {
      debugPrint('[home] No home config in catalog');
      return;
    }

    // Process regions (fixed layout areas like header)
    final regions = home['regions'] as List?;
    if (regions != null && regions.isNotEmpty) {
      debugPrint('[home] Processing ${regions.length} region(s)');
      for (final r in regions) {
        final reg = Map<String, dynamic>.from(r as Map);
        final type = reg['type'] as String?;
        final id = reg['id'] as String? ?? 'region-${type?.toLowerCase()}';
        final region = reg['region'] as String? ?? 'top';
        final props =
            reg['props'] != null ? Map<String, dynamic>.from(reg['props'] as Map) : <String, dynamic>{};

        if (type == null) {
          debugPrint('[home] Skipping region with no type: $reg');
          continue;
        }

        if (!_sduiContext.registry.has(type)) {
          debugPrint('[home] Widget type "$type" not found in registry — skipping region');
          continue;
        }

        _sduiContext.eventBus.publish(
          'system.layout.region',
          EventPayload(
            type: 'layout.region',
            data: {
              'region': region,
              'content': {
                'type': type,
                'id': id,
                'props': props,
                'children': [],
              },
            },
          ),
        );
        debugPrint('[home] Set $region region → $type ("$id")');
      }
    }

    // Process floating windows
    final windows = home['windows'] as List?;
    if (windows == null || windows.isEmpty) {
      debugPrint('[home] No floating windows to open');
      return;
    }

    debugPrint('[home] Opening ${windows.length} home window(s)');
    for (final w in windows) {
      final win = Map<String, dynamic>.from(w as Map);
      final type = win['type'] as String?;
      final id = win['id'] as String? ??
          'home-${type?.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}';
      final size = win['size'] as String? ?? 'medium';
      final align = win['align'] as String? ?? 'center';
      final title = win['title'] as String? ?? type ?? 'Window';
      final props = win['props'] as Map<String, dynamic>? ?? {};

      if (type == null) {
        debugPrint('[home] Skipping window with no type: $win');
        continue;
      }

      // Verify the widget type is registered
      if (!_sduiContext.registry.has(type)) {
        debugPrint('[home] Widget type "$type" not found in registry — skipping');
        continue;
      }

      final layoutOp = {
        'op': 'addWindow',
        'id': id,
        'size': size,
        'align': align,
        'title': title,
        'content': {
          'type': type,
          'id': '$id-root',
          'props': props,
          'children': [],
        },
      };

      _sduiContext.eventBus.publish(
        'system.layout.op',
        EventPayload(type: 'layout.op', data: layoutOp),
      );
      debugPrint('[home] Opened $type as "$id" (size=$size, align=$align)');
    }
  }

  /// Register orchestrator-specific widgets as Tier 1 builders.
  void _registerResourceMappings() {
    final wm = _sduiContext.windowManager;
    wm.registerResource('project', const ResourceMapping(
      widgetType: 'ProjectNavigator',
      size: 'medium',
      align: 'center',
      deduplicate: true,
    ));
    wm.registerResource('team', const ResourceMapping(
      widgetType: 'TeamManager',
      size: 'medium',
      align: 'center',
      deduplicate: true,
    ));
  }

  /// Listen for navigator.upload events — open native file picker and upload.
  void _listenFileUpload() {
    _sduiContext.eventBus.subscribe('navigator.upload').listen((event) async {
      final projectId = event.data['projectId']?.toString() ?? '';
      final folderId = event.data['folderId']?.toString() ?? '';
      if (projectId.isEmpty) {
        debugPrint('[upload] No projectId in upload event — ignoring');
        return;
      }

      // Open native file picker
      final input = web.document.createElement('input') as web.HTMLInputElement;
      input.type = 'file';
      input.multiple = true;
      input.click();

      // Listen for file selection — use sync callback, fire async upload inside
      input.addEventListener('change', ((web.Event _) {
        _handleFileUpload(input, projectId, folderId);
      }).toJS);
    });
  }

  /// Transform navigator.typeFilter into boolean flags for each type.
  void _listenTypeFilter() {
    _sduiContext.eventBus.subscribe('navigator.typeFilter').listen((event) {
      final value = event.data['value']?.toString() ?? 'all';
      final flags = <String, dynamic>{
        'showFile': value == 'all' || value == 'file',
        'showDataset': value == 'all' || value == 'dataset',
        'showWorkflow': value == 'all' || value == 'workflow',
        'showFolder': value == 'all',
        'showReadme': value == 'all' || value == 'file',
        'activeFilter': value,
      };
      _sduiContext.eventBus.publish(
        'navigator.typeFilter.resolved',
        EventPayload(type: 'filter', sourceWidgetId: 'type-filter', data: flags),
      );
    });
  }

  /// Relay widget-specific focus events to the generic system.focus channel.
  /// Any widget can publish to system.focus directly, or publish to its own
  /// channel and get relayed here. The focus context is:
  /// - Shown in the ChatBox as "Focus: <label>"
  /// - Sent to the LLM as uiState.focus so it knows what the user is looking at
  void _listenFocusRelay() {
    // Relay navigator.focusChanged → system.focus
    _sduiContext.eventBus.subscribe('navigator.focusChanged').listen((event) {
      final data = event.data;
      final label = data['nodeName']?.toString() ?? '';
      final type = data['nodeType']?.toString() ?? '';
      if (label.isEmpty) return;

      _focusContext = {
        'label': label,
        'type': type,
        'id': data['nodeId']?.toString() ?? '',
        'source': 'ProjectNavigator',
      };

      _sduiContext.eventBus.publish(
        'system.focus',
        EventPayload(
          type: 'focus',
          sourceWidgetId: event.sourceWidgetId,
          data: _focusContext,
        ),
      );
    });

    // Also listen for direct system.focus from future widgets
    _sduiContext.eventBus.subscribe('system.focus').listen((event) {
      final label = event.data['label']?.toString() ?? '';
      if (label.isNotEmpty) {
        _focusContext = Map<String, dynamic>.from(event.data);
      }
    });
  }

  Map<String, dynamic> _focusContext = {};

  /// Relay audit trail selection events to system.selection (for LLM context)
  /// and system.focus (for ChatBox focus indicator).
  void _listenAuditSelectionRelay() {
    _sduiContext.eventBus.subscribePrefix('audit.').listen((event) {
      if (!event.type.contains('selection.changed')) return;
      final selected = event.data['selected'];
      if (selected is! List) return;

      // Relay to system.selection so LLM sees it in uiState
      _sduiContext.eventBus.publish(
        'system.selection.auditTrail',
        EventPayload(
          type: 'selection',
          sourceWidgetId: event.sourceWidgetId,
          data: {'auditEvents': selected, 'count': selected.length},
        ),
      );

      // Publish focus event so ChatBox shows "Focus: Audit selection (N events)"
      final count = selected.length;
      if (count > 0) {
        _focusContext = {
          'label': 'Audit selection ($count event${count == 1 ? '' : 's'})',
          'type': 'auditSelection',
          'count': count,
          'source': 'AuditTrail',
        };
        _sduiContext.eventBus.publish(
          'system.focus',
          EventPayload(
            type: 'focus',
            sourceWidgetId: event.sourceWidgetId,
            data: _focusContext,
          ),
        );
      }
    });
  }

  /// Listen for navigator.downloadFile events — trigger browser download.
  void _listenFileDownload() {
    _sduiContext.eventBus.subscribe('navigator.downloadFile').listen((event) async {
      final nodeId = event.data['nodeId']?.toString() ?? '';
      final nodeName = event.data['nodeName']?.toString() ?? 'download';
      if (nodeId.isEmpty) {
        debugPrint('[download] No nodeId in download event');
        return;
      }

      try {
        final factory = tercen.ServiceFactory.CURRENT;
        if (factory == null) return;

        final dispatcher = ServiceCallDispatcher(factory, authToken: _tercenToken);
        final result = await dispatcher.call('fileService', 'downloadUrl', [nodeId]);
        final url = (result as Map)['url']?.toString() ?? '';
        if (url.isNotEmpty) {
          // Fetch as blob to preserve filename on cross-origin download
          final response = await web.window.fetch(url.toJS).toDart;
          final blob = await response.blob().toDart;
          final blobUrl = web.URL.createObjectURL(blob);
          final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
          anchor.href = blobUrl;
          anchor.download = nodeName;
          anchor.click();
          web.URL.revokeObjectURL(blobUrl);
          debugPrint('[download] Started download: $nodeName');
        }
      } catch (e) {
        debugPrint('[download] Failed: $e');
      }
    });
  }

  /// Handle file upload after native file picker selection.
  Future<void> _handleFileUpload(
      web.HTMLInputElement input, String projectId, String folderId) async {
    final files = input.files;
    if (files == null || files.length == 0) return;

    final factory = tercen.ServiceFactory.CURRENT;
    if (factory == null) return;

    final svcDispatcher = ServiceCallDispatcher(factory, authToken: _tercenToken);

    for (var i = 0; i < files.length; i++) {
      final file = files.item(i);
      if (file == null) continue;

      try {
        // Read file as ArrayBuffer using JS interop
        final arrayBuffer = await file.arrayBuffer().toDart;
        final bytes = arrayBuffer.toDart.asUint8List();

        final uploaded = await svcDispatcher.uploadFile(
          projectId, folderId, file.name, bytes.toList(),
        );
        debugPrint('[upload] Uploaded: ${uploaded['name']} (${uploaded['id']})');
      } catch (e) {
        debugPrint('[upload] Failed: $e');
      }
    }

    // Refresh the navigator tree after upload
    _sduiContext.eventBus.publish(
      'navigator.refreshTree',
      EventPayload(type: 'refresh', sourceWidgetId: 'upload-handler', data: {}),
    );
  }

  /// These are compiled Dart widgets that need access to orchestrator internals
  /// (e.g., OrchestratorClient for chat streaming) and can't be JSON templates.
  void _registerOrchestratorWidgets() {
    _sduiContext.registry.registerScope('ChatStream', buildChatStream,
        metadata: chatStreamMetadata);
    _sduiContext.registry.registerScope('TaskStream', buildTaskStream,
        metadata: taskStreamMetadata);
    debugPrint('[widgets] Registered ChatStream + TaskStream');
  }

  void _toggleTheme() {
    setState(() {
      _isDark = !_isDark;
      _sduiContext.renderContext.theme = _currentTheme;
      _sduiContext.renderContext.templateResolver.set('isDark', _isDark);
    });
  }

  /// Fetch theme tokens from the server API.
  Future<void> _fetchThemeTokens() async {
    try {
      final httpUrl = _serverUrl
          .replaceFirst('ws://', 'http://')
          .replaceFirst('wss://', 'https://');
      final url = '$httpUrl/api/theme-tokens';

      final httpClient = io_http.HttpBrowserClient();
      final response = await httpClient.get(url);

      if (response.statusCode == 200) {
        final tokens = jsonDecode(response.body as String) as Map<String, dynamic>;
        if (tokens.isNotEmpty) {
          setState(() {
            _themeTokens = tokens;
            _sduiContext.renderContext.theme = _currentTheme;
          });
          debugPrint('[theme] Loaded ${tokens.keys.length} token groups from server');
        }
      }
    } catch (e) {
      debugPrint('[theme] Failed to fetch tokens from server: $e — using defaults');
    }
  }

  Future<void> _bootstrapAuth() async {
    if (_tercenToken.isEmpty) {
      setState(() {
        _authReady = true; // No token — run in unauthenticated mode
      });
      debugPrint('[auth] No TERCEN_TOKEN — running without auth');
      return;
    }

    final serviceUri = _serviceUriOverride.isNotEmpty
        ? _serviceUriOverride
        : _parseServiceUriFromToken(_tercenToken);
    if (serviceUri.isEmpty) {
      setState(() {
        _authError = 'Could not extract service URI from token. Check TERCEN_TOKEN.';
      });
      return;
    }

    try {
      debugPrint('[auth] Creating ServiceFactory for $serviceUri');

      // Use explicit browser HTTP client (matches webapp pattern)
      http_api.HttpClient.setCurrent(io_http.HttpBrowserClient());
      final authClient =
          auth_http.HttpAuthClient(_tercenToken, io_http.HttpBrowserClient());

      final factory = sci.ServiceFactory();
      final uri = Uri.parse(serviceUri);
      await factory.initializeWith(
          Uri(scheme: uri.scheme, host: uri.host, port: uri.port), authClient);
      tercen.ServiceFactory.CURRENT = factory;

      final dispatcher = ServiceCallDispatcher(factory, authToken: _tercenToken);
      _sduiContext.renderContext.serviceCaller = dispatcher.call;

      // Set user context from JWT
      _setUserContext();
      debugPrint('[auth] ServiceFactory ready — data widgets enabled');

      // Create AgentClient if no WebSocket backend and API key is available
      if (_wsClient == null && _anthropicApiKey.isNotEmpty) {
        final jwtData = _decodeJwtPayload(_tercenToken)['data']
            as Map<String, dynamic>? ?? {};
        final username = jwtData['u'] as String? ?? '';

        // Get or create a hidden project for agent task execution
        final projectId = await _getOrCreateAgentProject(factory, username);
        _defaultProjectId = projectId;
        debugPrint('[init] Agent project: $projectId');

        // Find or create the agent operator
        final operatorId = await _getOrCreateAgentOperator(factory, username);
        debugPrint('[init] Agent operator: $operatorId');

        _chatBackend = AgentClient(
          factory: factory,
          eventBus: _sduiContext.eventBus,
          agentOperatorId: operatorId,
          anthropicApiKey: _anthropicApiKey,
          projectId: projectId,
          userId: username,
          uiStateCollector: _collectUiState,
        );
        _pipeChatBackend();
        debugPrint('[init] Agent backend ready');
      }

      setState(() {
        _authReady = true;
      });
    } catch (e, st) {
      ErrorReporter.instance.report(e,
        stackTrace: st,
        source: 'auth.bootstrap',
        context: 'creating ServiceFactory for $serviceUri',
      );
      setState(() {
        _authError = e.toString();
      });
    }
  }

  /// Extract user identity from the JWT, expose to templates.
  /// This MUST succeed — if it fails, the app cannot function.
  void _setUserContext() {
    final jwtPayload = _decodeJwtPayload(_tercenToken);
    final jwtData = jwtPayload['data'] as Map<String, dynamic>? ?? {};
    // Tercen JWT: data.u = username, data.d = domain
    final username = jwtData['u'] as String? ?? '';
    debugPrint('[auth] JWT data.u=$username');

    if (username.isEmpty) {
      throw StateError('JWT token has no username (data.u). '
          'Payload keys: ${jwtPayload.keys.toList()}, '
          'data keys: ${jwtData.keys.toList()}');
    }

    // In Tercen, the username IS the userId for CouchDB views
    _sduiContext.renderContext.setUserContext({
      'username': username,
      'userId': username,
      'token': _tercenToken,
      'isDark': _isDark,
    });
    debugPrint('[auth] User context: username=$username');

    // Fetch user object for admin status (JWT doesn't contain roles)
    _fetchUserRoles(username);
  }

  /// Fetch user roles from the Tercen API and update template context.
  /// Non-blocking — header renders without admin menu until this completes.
  Future<void> _fetchUserRoles(String username) async {
    try {
      final factory = tercen.ServiceFactory.CURRENT;
      if (factory == null) return;
      final user = await factory.userService.get(username);
      final isAdmin = user.id == 'admin' ||
          (user.roles as List).contains('admin');
      _sduiContext.renderContext.templateResolver.set('isAdmin', isAdmin);
      debugPrint('[auth] User roles fetched: isAdmin=$isAdmin');
    } catch (e) {
      debugPrint('[auth] Failed to fetch user roles: $e');
      _sduiContext.renderContext.templateResolver.set('isAdmin', false);
    }
  }

  // Track selections from SDUI EventBus for UI state snapshots.
  final Map<String, dynamic> _selections = {};
  StreamSubscription? _selectionSub;

  void _startTrackingSelections() {
    _selectionSub = _sduiContext.eventBus
        .subscribePrefix('system.selection.')
        .listen((payload) {
      payload.data.forEach((key, value) {
        if (!key.startsWith('_')) {
          _selections[key] = value;
        }
      });
    });
  }

  /// Collect a UI state snapshot for the agent.
  /// Uses WindowState.toJson() which includes content tree summary with
  /// DataSource service/method/args so the agent knows what each window shows.
  /// Includes viewport dimensions so the agent can calculate pixel positions
  /// for grid layouts and window rearrangement.
  Map<String, dynamic> _collectUiState() {
    final wm = _sduiContext.windowManager;
    return {
      'viewport': {
        'width': wm.viewportWidth.round(),
        'height': wm.viewportHeight.round(),
      },
      'selections': Map<String, dynamic>.from(_selections),
      'focus': Map<String, dynamic>.from(_focusContext),
      'windows': wm.layoutState, // full toJson() per window
    };
  }

  /// Save the current window layout as a .sdui.json file in Tercen.
  /// If a project is selected, saves there with a prompted name.
  /// Otherwise saves to the agent_internal project with a default name.
  Future<void> _saveLayout() async {
    final factory = tercen.ServiceFactory.CURRENT;
    if (factory == null) {
      ErrorReporter.instance.report('Cannot save layout — not authenticated',
          source: 'layout.save', severity: ErrorSeverity.warning);
      return;
    }

    final wm = _sduiContext.windowManager;
    if (wm.windows.isEmpty) {
      ErrorReporter.instance.report('Nothing to save — no windows open',
          source: 'layout.save', severity: ErrorSeverity.info);
      return;
    }

    // Determine target project
    final selectedProjectId = _selections['selectedProjectId'] as String?;
    final projectId = selectedProjectId ?? _defaultProjectId;
    if (projectId == null || projectId.isEmpty) {
      ErrorReporter.instance.report(
          'Cannot save layout — no project selected and no default project',
          source: 'layout.save', severity: ErrorSeverity.warning);
      return;
    }

    // Prompt for name if project is selected, use default otherwise
    String fileName;
    if (selectedProjectId != null && selectedProjectId.isNotEmpty) {
      final name = await _promptForLayoutName();
      if (name == null || name.isEmpty) return; // user cancelled
      fileName = name.endsWith('.sdui.json') ? name : '$name.sdui.json';
    } else {
      fileName = 'default-layout.sdui.json';
    }

    try {
      final layoutJson = wm.toLayoutJson();
      layoutJson['name'] = fileName;
      layoutJson['savedAt'] = DateTime.now().toUtc().toIso8601String();

      final bytes = utf8.encode(
          const JsonEncoder.withIndent('  ').convert(layoutJson));

      final file = sci.FileDocument()
        ..name = fileName
        ..projectId = projectId
        ..description = 'Saved SDUI layout'
        ..acl.owner = (_sduiContext.renderContext.templateResolver
            .get('username') as String?) ?? '';

      await factory.fileService.upload(
        file,
        Stream.value(bytes),
      );

      debugPrint('[layout] Saved "$fileName" to project $projectId '
          '(${wm.windows.length} windows, ${bytes.length} bytes)');

      ErrorReporter.instance.report('Layout saved: $fileName',
          source: 'layout.save', severity: ErrorSeverity.info);
    } catch (e, st) {
      ErrorReporter.instance.report(e,
          stackTrace: st,
          source: 'layout.save',
          context: 'saving layout to project $projectId');
    }
  }

  /// Show a dialog prompting for a layout name.
  Future<String?> _promptForLayoutName() async {
    final controller = TextEditingController(
      text: 'my-layout-${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
    );
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Layout'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Layout name',
            hintText: 'e.g. analysis-view',
          ),
          autofocus: true,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Load a saved layout from a .sdui.json file.
  Future<void> loadLayoutFromFile(String fileId) async {
    final factory = tercen.ServiceFactory.CURRENT;
    if (factory == null) return;

    try {
      final content = await utf8.decodeStream(
          factory.fileService.download(fileId));
      final layoutJson =
          jsonDecode(content) as Map<String, dynamic>;
      _sduiContext.windowManager.loadLayout(layoutJson);
      debugPrint('[layout] Loaded layout from file $fileId');
    } catch (e, st) {
      ErrorReporter.instance.report(e,
          stackTrace: st,
          source: 'layout.load',
          context: 'loading layout from file $fileId');
    }
  }

  /// Find or create the hidden `agent_internal` project for the user.
  Future<String> _getOrCreateAgentProject(
      sci.ServiceFactory factory, String username) async {
    const projectName = 'agent_internal';
    // Look up by [owner, name]
    final docs = await factory.documentService.findProjectByOwnersAndName(
      startKey: [username, projectName],
      endKey: [username, projectName],
      limit: 1,
      useFactory: true,
    );
    if (docs.isNotEmpty) return docs.first.id;

    // Not found — create it
    final project = sci.Project()
      ..name = projectName
      ..isHidden = true
      ..acl.owner = username;
    final created = await factory.projectService.create(project);
    return created.id;
  }

  /// Find or create the `tercen_agent` operator.
  static const _agentOperatorUrl = 'https://github.com/tercen/tercen_agent';

  Future<String> _getOrCreateAgentOperator(
      sci.ServiceFactory factory, String username) async {
    // Look up by URL
    final docs = await factory.documentService.findOperatorByUrlAndVersion(
      startKey: [_agentOperatorUrl, ''],
      endKey: [_agentOperatorUrl, '\uf000'],
      limit: 1,
      useFactory: true,
    );
    if (docs.isNotEmpty) return docs.first.id;

    // Not found — create it
    debugPrint('[init] Registering tercen_agent operator...');
    final op = sci.DockerOperator()
      ..name = 'tercen_agent'
      ..description = 'Claude AI agent operator'
      ..version = '0.1.1'
      ..container = 'ghcr.io/tercen/tercen_agent:latest'
      ..url.uri = _agentOperatorUrl
      ..acl.owner = username
      ..properties.addAll([
        sci.StringProperty()
          ..name = 'prompt'
          ..defaultValue = '',
        sci.StringProperty()
          ..name = 'ANTHROPIC_API_KEY'
          ..defaultValue = '',
        sci.StringProperty()
          ..name = 'model'
          ..defaultValue = 'claude-sonnet-4-6',
        sci.StringProperty()
          ..name = 'systemPrompt'
          ..defaultValue = '',
        sci.StringProperty()
          ..name = 'maxTurns'
          ..defaultValue = '8',
        sci.StringProperty()
          ..name = 'uiState'
          ..defaultValue = '',
        sci.StringProperty()
          ..name = 'sessionId'
          ..defaultValue = '',
        sci.StringProperty()
          ..name = 'sessionData'
          ..defaultValue = '',
      ]);
    final created = await factory.operatorService.create(op);
    debugPrint('[init] Operator registered: ${created.id}');
    return created.id;
  }

  @override
  void dispose() {
    _taskMonitor?.dispose();
    _layoutPersistence?.dispose();
    _selectionSub?.cancel();
    _chatBridgeSub?.cancel();
    _chatBridge.close();
    _chatBackend.dispose();
    _sduiContext.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Auth error — fatal, show full-screen error
    if (_authError != null) {
      return MaterialApp(
        title: 'Tercen',
        debugShowCheckedModeBanner: false,
        theme: _currentTheme.toMaterialTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48,
                      color: _currentTheme.colors.error),
                  const SizedBox(height: 16),
                  Text('Authentication Failed',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                          color: _currentTheme.colors.onSurface)),
                  const SizedBox(height: 8),
                  Text(_authError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _currentTheme.colors.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Auth still in progress — show loading
    if (!_authReady) {
      return MaterialApp(
        title: 'Tercen',
        debugShowCheckedModeBanner: false,
        theme: _currentTheme.toMaterialTheme(),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return SduiScope(
      sduiContext: _sduiContext,
      child: ThemeController(
        isDark: _isDark,
        onToggle: _toggleTheme,
        child: MaterialApp(
          title: 'Tercen',
          debugShowCheckedModeBanner: false,
          theme: _currentTheme.toMaterialTheme(),
          home: const ShellScreen(),
        ),
      ),
    );
  }
}

/// Provides theme toggle state down the widget tree.
class ThemeController extends InheritedWidget {
  final bool isDark;
  final VoidCallback onToggle;

  const ThemeController({
    super.key,
    required this.isDark,
    required this.onToggle,
    required super.child,
  });

  static ThemeController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ThemeController>();
    assert(scope != null, 'ThemeController not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(ThemeController oldWidget) =>
      isDark != oldWidget.isDark;
}



/// Placeholder backend used before auth completes.
class _PlaceholderBackend extends ChatBackend {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get chatMessages => _controller.stream;
  @override
  void sendChat(String message) {}
  @override
  bool get isConnected => false;
  @override
  bool get isProcessing => false;
  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
