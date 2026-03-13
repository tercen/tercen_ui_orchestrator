import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sci_http_client/http_auth_client.dart' as auth_http;
import 'package:sci_http_client/http_browser_client.dart' as io_http;
import 'package:sci_http_client/http_client.dart' as http_api;
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sci_tercen_client/sci_client_service_factory.dart' as tercen;
import 'package:tercen_ui_orchestrator/presentation/screens/shell_screen.dart';
import 'package:tercen_ui_orchestrator/sdui/sdui_context.dart';
import 'package:tercen_ui_orchestrator/sdui/service/service_call_dispatcher.dart';
import 'package:tercen_ui_orchestrator/services/orchestrator_client.dart';

const _serverUrl = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'ws://localhost:8080',
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

  @override
  void initState() {
    super.initState();
    _sduiContext = SduiContext.create();
    _client = OrchestratorClient(
      baseUrl: _serverUrl,
      eventBus: _sduiContext.eventBus,
    );
    _client.connect();
    _bootstrapAuth();
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
      debugPrint('[auth] Failed to create ServiceFactory: $e\n$st');
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
        child: MaterialApp(
          title: 'Tercen',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: const ColorScheme.dark(
              surface: Color(0xFF1E1E1E),
              primary: Colors.blue,
            ),
            scaffoldBackgroundColor: const Color(0xFF1E1E1E),
            useMaterial3: true,
          ),
          home: const ShellScreen(),
        ),
      ),
    );
  }
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
