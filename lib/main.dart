import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sci_http_client/http_auth_client.dart' as auth_http;
import 'package:sci_http_client/http_browser_client.dart' as io_http;
import 'package:sci_http_client/http_client.dart' as http_api;
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sci_tercen_client/sci_client_service_factory.dart' as tercen;
import 'package:tercen_ui_orchestrator/presentation/screens/shell_screen.dart';
import 'package:tercen_ui_orchestrator/presentation/widgets/chat_panel.dart';
import 'package:sdui/sdui.dart';
import 'package:tercen_ui_orchestrator/sdui/service/service_call_dispatcher.dart';
import 'package:tercen_ui_orchestrator/services/agent_client.dart';
import 'package:tercen_ui_orchestrator/services/chat_backend.dart';
import 'package:tercen_ui_orchestrator/services/orchestrator_client.dart';

// Compile-time defaults, overridable via URL query parameters:
//   ?token=eyJ...    → TERCEN_TOKEN
//   ?server=ws://... → SERVER_URL
final String _serverUrl = Uri.base.queryParameters['server'] ??
    const String.fromEnvironment('SERVER_URL', defaultValue: '');
final String _anthropicApiKey =
    const String.fromEnvironment('ANTHROPIC_API_KEY', defaultValue: '');
final String _tercenToken = Uri.base.queryParameters['token'] ??
    const String.fromEnvironment('TERCEN_TOKEN', defaultValue: '');

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
    _registerOrchestratorWidgets();
    _listenHeaderIntents();

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

    // Wire chat backend into SDUI for the ChatStream behavior widget.
    _sduiContext.renderContext.chatStreamProvider = (
      messages: _chatBackend.chatMessages,
      send: _chatBackend.sendChat,
      isConnected: () => _chatBackend.isConnected,
    );

    _startup();
  }

  /// Listen for header menu actions (theme toggle, etc.)
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
          debugPrint('[header] navigateHome — not yet implemented');
        case 'saveLayout':
          debugPrint('[header] saveLayout — not yet implemented');
        case 'connectLlm':
          debugPrint('[header] connectLlm — not yet implemented');
        case 'taskManager':
          debugPrint('[header] taskManager — not yet implemented');
        case 'signOut':
          debugPrint('[header] signOut — not yet implemented');
      }
    });
  }

  Future<void> _startup() async {
    _startTrackingSelections();
    await _bootstrapAuth();
    _fetchThemeTokens(); // non-blocking — theme can load after UI
    _autoLoadCatalog(); // non-blocking — catalog loads after auth
  }

  /// Auto-load the widget catalog from the server.
  /// The server fetches it from the configured widgetLibraryUrl on startup.
  Future<void> _autoLoadCatalog() async {
    try {
      final httpUrl = _serverUrl
          .replaceFirst('ws://', 'http://')
          .replaceFirst('wss://', 'https://');
      final url = '$httpUrl/api/widget-catalog';

      final httpClient = io_http.HttpBrowserClient();
      final response = await httpClient.get(url);

      if (response.statusCode == 200) {
        final catalog =
            jsonDecode(response.body as String) as Map<String, dynamic>;
        final widgets = catalog['widgets'] as List? ?? [];
        if (widgets.isNotEmpty) {
          _sduiContext.registry.loadCatalog(catalog);
          debugPrint('[catalog] Auto-loaded ${widgets.length} widget(s)');

          // Open home windows if defined in catalog
          _openHomeWindows(catalog);
        } else {
          debugPrint('[catalog] Server returned empty catalog');
        }
      } else {
        debugPrint('[catalog] Server returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[catalog] Auto-load failed: $e');
    }
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
  /// These are compiled Dart widgets that need access to orchestrator internals
  /// (e.g., OrchestratorClient for chat streaming) and can't be JSON templates.
  void _registerOrchestratorWidgets() {
    _sduiContext.registry.register('ChatPanel', buildChatPanel,
        metadata: chatPanelMetadata);
    debugPrint('[widgets] Registered ChatPanel Tier 1 primitive');
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

    final serviceUri = _parseServiceUriFromToken(_tercenToken);
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
        // Re-wire SDUI chat provider to the real backend.
        _sduiContext.renderContext.chatStreamProvider = (
          messages: _chatBackend.chatMessages,
          send: _chatBackend.sendChat,
          isConnected: () => _chatBackend.isConnected,
        );
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

  /// Collect a minimal UI state snapshot for the agent.
  Map<String, dynamic> _collectUiState() {
    final wm = _sduiContext.windowManager;
    final windows = wm.windows.map((ws) => {
      'id': ws.id,
      'title': ws.title ?? '',
      'type': ws.content.type,
    }).toList();

    return {
      'selections': Map<String, dynamic>.from(_selections),
      'windows': windows,
    };
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
    _selectionSub?.cancel();
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
      child: ChatBackendScope(
        backend: _chatBackend,
        wsClient: _wsClient,
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

/// Makes the chat backend available down the widget tree.
///
/// [backend] is the active ChatBackend (either OrchestratorClient or AgentClient).
/// [wsClient] is optionally set when using WebSocket mode, for features that
/// need direct WebSocket access (e.g. toolbar widget catalog loading).
class ChatBackendScope extends InheritedWidget {
  final ChatBackend backend;
  final OrchestratorClient? wsClient;

  const ChatBackendScope({
    super.key,
    required this.backend,
    this.wsClient,
    required super.child,
  });

  static ChatBackend of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ChatBackendScope>();
    assert(scope != null, 'ChatBackendScope not found');
    return scope!.backend;
  }

  /// Returns the WebSocket client if available (dev mode only).
  static OrchestratorClient? wsClientOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ChatBackendScope>();
    return scope?.wsClient;
  }

  @override
  bool updateShouldNotify(ChatBackendScope oldWidget) =>
      backend != oldWidget.backend || wsClient != oldWidget.wsClient;
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
