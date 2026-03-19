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
import 'package:tercen_ui_orchestrator/services/orchestrator_client.dart';

const _serverUrl = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'ws://127.0.0.1:8080',
);

const _tercenToken = String.fromEnvironment('TERCEN_TOKEN', defaultValue: '');

/// Extracts the service URI from the JWT token's `iss` (issuer) field.
String _parseServiceUriFromToken(String token) {
  if (token.isEmpty) return '';
  try {
    final parts = token.split('.');
    if (parts.length != 3) return '';
    var payload = parts[1];
    switch (payload.length % 4) {
      case 2: payload += '=='; break;
      case 3: payload += '='; break;
    }
    final decoded = utf8.decode(base64Url.decode(payload));
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    return json['iss'] as String? ?? '';
  } catch (_) {
    return '';
  }
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
  late final OrchestratorClient _client;
  bool _isDark = false; // Light mode is the default
  Map<String, dynamic>? _themeTokens;

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
    _client = OrchestratorClient(
      baseUrl: _serverUrl,
      eventBus: _sduiContext.eventBus,
    );
    _client.connect();
    _bootstrapAuth();
    _fetchThemeTokens();
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
      debugPrint('[auth] No TERCEN_TOKEN — running without auth');
      return;
    }

    final serviceUri = _parseServiceUriFromToken(_tercenToken);
    if (serviceUri.isEmpty) {
      debugPrint('[auth] Could not extract service URI from token');
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

      final dispatcher = ServiceCallDispatcher(factory);
      _sduiContext.renderContext.serviceCaller = dispatcher.call;
      debugPrint('[auth] ServiceFactory ready — data widgets enabled');
    } catch (e, st) {
      ErrorReporter.instance.report(e,
        stackTrace: st,
        source: 'auth.bootstrap',
        context: 'creating ServiceFactory for $serviceUri',
      );
    }
  }

  @override
  void dispose() {
    _client.dispose();
    _sduiContext.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SduiScope(
      sduiContext: _sduiContext,
      child: OrchestratorClientScope(
        client: _client,
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

/// Makes the OrchestratorClient available down the widget tree.
class OrchestratorClientScope extends InheritedWidget {
  final OrchestratorClient client;

  const OrchestratorClientScope({
    super.key,
    required this.client,
    required super.child,
  });

  static OrchestratorClient of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<OrchestratorClientScope>();
    assert(scope != null, 'OrchestratorClientScope not found');
    return scope!.client;
  }

  @override
  bool updateShouldNotify(OrchestratorClientScope oldWidget) =>
      client != oldWidget.client;
}
