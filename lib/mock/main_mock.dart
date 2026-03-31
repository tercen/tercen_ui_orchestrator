import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sci_http_client/http_browser_client.dart' as io_http;
import 'package:sdui/sdui.dart';

import 'mock_shell.dart';

/// Dart-define: which widget to open initially.
/// Usage: --dart-define=MOCK_WIDGET=ProjectNavigator
const _mockWidget =
    String.fromEnvironment('MOCK_WIDGET', defaultValue: '');

/// Theme tokens URL — fetched from tercen-style repo on GitHub.
const _themeTokensUrl =
    'https://raw.githubusercontent.com/tercen/tercen-style/master/tokens.json';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MockOrchestratorApp());
}

class MockOrchestratorApp extends StatefulWidget {
  const MockOrchestratorApp({super.key});

  @override
  State<MockOrchestratorApp> createState() => _MockOrchestratorAppState();
}

class _MockOrchestratorAppState extends State<MockOrchestratorApp> {
  Map<String, dynamic>? _catalog;
  Map<String, dynamic>? _themeTokens;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    try {
      // Fetch catalog and theme tokens in parallel.
      final results = await Future.wait([
        _fetchCatalog(),
        _fetchThemeTokens(),
      ]);

      setState(() {
        _catalog = results[0];
        _themeTokens = results[1];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      debugPrint('[mock] Failed to load resources: $e');
    }
  }

  /// Load catalog from GitHub using orchestrator.config.json.
  Future<Map<String, dynamic>?> _fetchCatalog() async {
    final configStr = await rootBundle.loadString('orchestrator.config.json');
    final config = jsonDecode(configStr) as Map<String, dynamic>;
    final lib = config['widgetLibrary'] as Map<String, dynamic>?;
    if (lib == null) throw Exception('No widgetLibrary in orchestrator.config.json');

    final repo = lib['repo'] as String? ?? '';
    final ref = lib['ref'] as String? ?? 'main';
    final catalogFile = lib['catalogFile'] as String? ?? 'catalog.json';
    if (repo.isEmpty) throw Exception('No repo URL in config');

    final uri = Uri.parse(repo);
    final segments = uri.pathSegments;
    if (segments.length < 2) throw Exception('Invalid repo URL: $repo');

    final rawUrl = 'https://raw.githubusercontent.com/'
        '${segments[0]}/${segments[1]}/$ref/$catalogFile';
    debugPrint('[mock] Fetching catalog from $rawUrl');

    final httpClient = io_http.HttpBrowserClient();
    final response = await httpClient.get(rawUrl);
    if (response.statusCode != 200) {
      throw Exception('Catalog: GitHub returned ${response.statusCode}');
    }

    final catalog = jsonDecode(response.body as String) as Map<String, dynamic>;
    debugPrint('[mock] Loaded catalog with '
        '${(catalog['widgets'] as List?)?.length ?? 0} widget(s)');
    return catalog;
  }

  /// Fetch theme tokens from tercen-style repo on GitHub.
  Future<Map<String, dynamic>?> _fetchThemeTokens() async {
    try {
      debugPrint('[mock] Fetching theme tokens from $_themeTokensUrl');
      final httpClient = io_http.HttpBrowserClient();
      final response = await httpClient.get(_themeTokensUrl);
      if (response.statusCode == 200) {
        final tokens =
            jsonDecode(response.body as String) as Map<String, dynamic>;
        debugPrint('[mock] Loaded theme tokens (${tokens.keys.length} groups)');
        return tokens;
      }
      debugPrint('[mock] Theme tokens: GitHub returned ${response.statusCode}');
    } catch (e) {
      debugPrint('[mock] Theme tokens fetch failed: $e — using defaults');
    }
    return null;
  }

  SduiTheme get _sduiTheme {
    final tokens = _themeTokens;
    if (tokens != null) {
      return SduiTheme.fromJson(tokens, themeName: 'light');
    }
    return const SduiTheme.light();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _sduiTheme.toMaterialTheme();

    if (_loading) {
      return MaterialApp(
        title: 'SDUI Mock',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return MaterialApp(
        title: 'SDUI Mock',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Failed to load catalog',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'SDUI Mock',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: MockShell(
        initialWidget: _mockWidget.isNotEmpty ? _mockWidget : null,
        catalog: _catalog,
        sduiTheme: _sduiTheme,
      ),
    );
  }
}
