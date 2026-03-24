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
import 'package:sdui/sdui.dart';
import 'package:tercen_ui_orchestrator/sdui/service/service_call_dispatcher.dart';
import 'package:tercen_ui_orchestrator/services/agent_client.dart';
import 'package:tercen_ui_orchestrator/services/chat_backend.dart';
import 'package:tercen_ui_orchestrator/presentation/widgets/chat_panel.dart';
import 'package:tercen_ui_orchestrator/services/orchestrator_client.dart';

const _serverUrl = String.fromEnvironment('SERVER_URL', defaultValue: '');
const _agentOperatorId = String.fromEnvironment('AGENT_OPERATOR_ID', defaultValue: '');
const _anthropicApiKey = String.fromEnvironment('ANTHROPIC_API_KEY', defaultValue: '');

const _tercenToken = String.fromEnvironment('TERCEN_TOKEN', defaultValue: '');

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

    // Register ChatPanel as a compiled Tier 1 SDUI widget
    _sduiContext.registry.register(
      'ChatPanel',
      (node, children, resolvedProps) => const ChatPanel(),
    );

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

    _startup();
  }

  Future<void> _startup() async {
    _startTrackingSelections();
    await _bootstrapAuth();
    _fetchThemeTokens(); // non-blocking — theme can load after UI
  }

  void _toggleTheme() {
    setState(() {
      _isDark = !_isDark;
      _sduiContext.renderContext.theme = _currentTheme;
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

      // Create AgentClient if no WebSocket backend
      if (_wsClient == null && _agentOperatorId.isNotEmpty) {
        final jwtData = _decodeJwtPayload(_tercenToken)['data']
            as Map<String, dynamic>? ?? {};
        final username = jwtData['u'] as String? ?? '';

        // Get or create a hidden project for agent task execution
        final projectId = await _getOrCreateAgentProject(factory, username);
        debugPrint('[init] Agent project: $projectId');

        _chatBackend = AgentClient(
          factory: factory,
          eventBus: _sduiContext.eventBus,
          agentOperatorId: _agentOperatorId,
          anthropicApiKey: _anthropicApiKey,
          projectId: projectId,
          userId: username,
          uiStateCollector: _collectUiState,
        );
        debugPrint('[init] Agent backend ready: operator=$_agentOperatorId');
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
    });
    debugPrint('[auth] User context: username=$username');
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
