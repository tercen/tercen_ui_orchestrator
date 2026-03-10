import 'package:flutter/material.dart';
import 'package:tercen_ui_orchestrator/presentation/screens/shell_screen.dart';
import 'package:tercen_ui_orchestrator/sdui/sdui_context.dart';
import 'package:tercen_ui_orchestrator/services/orchestrator_client.dart';

const _serverUrl = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'ws://localhost:8080',
);

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
