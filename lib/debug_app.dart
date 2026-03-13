import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sci_http_client/http_auth_client.dart' as auth_http;
import 'package:sci_http_client/http_browser_client.dart' as io_http;
import 'package:sci_http_client/http_client.dart' as http_api;
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sci_tercen_client/sci_client_service_factory.dart' as tercen;

const _tercenToken = String.fromEnvironment('TERCEN_TOKEN', defaultValue: '');

/// Extracts the service URI from the JWT token's `iss` (issuer) field.
String _parseServiceUriFromToken(String token) {
  if (token.isEmpty) return '';
  try {
    final parts = token.split('.');
    if (parts.length != 3) return '';
    // Base64url decode the payload (2nd segment)
    var payload = parts[1];
    // Pad to multiple of 4
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
  runApp(const DebugApp());
}

class DebugApp extends StatelessWidget {
  const DebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tercen Debug',
      theme: ThemeData.dark(),
      home: const DebugScreen(),
    );
  }
}

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final List<String> _logs = [];
  List<Map<String, dynamic>>? _projects;

  @override
  void initState() {
    super.initState();
    _runTest();
  }

  void _log(String msg) {
    debugPrint('[debug] $msg');
    setState(() => _logs.add(msg));
  }

  Future<void> _runTest() async {
    _log('--- Config ---');
    _log('TERCEN_TOKEN: "${_tercenToken.isEmpty ? "(empty)" : "${_tercenToken.substring(0, 20)}..."}"');

    if (_tercenToken.isEmpty) {
      _log('ERROR: Missing TERCEN_TOKEN dart-define');
      return;
    }

    final serviceUri = _parseServiceUriFromToken(_tercenToken);
    _log('Parsed SERVICE_URI from token iss: "$serviceUri"');

    if (serviceUri.isEmpty) {
      _log('ERROR: Could not extract iss (service URI) from token');
      return;
    }

    final uri = Uri.parse(serviceUri);
    _log('Parsed URI: scheme=${uri.scheme} host=${uri.host} port=${uri.port}');

    // Step 1: Create browser HTTP client
    _log('--- Step 1: Create HTTP client ---');
    try {
      http_api.HttpClient.setCurrent(io_http.HttpBrowserClient());
      _log('OK: HttpBrowserClient set as current');
    } catch (e) {
      _log('FAIL: HttpBrowserClient: $e');
      return;
    }

    // Step 2: Create auth client
    _log('--- Step 2: Create auth client ---');
    auth_http.HttpAuthClient authClient;
    try {
      authClient =
          auth_http.HttpAuthClient(_tercenToken, io_http.HttpBrowserClient());
      _log('OK: HttpAuthClient created');
    } catch (e) {
      _log('FAIL: HttpAuthClient: $e');
      return;
    }

    // Step 3: Initialize ServiceFactory
    _log('--- Step 3: Initialize ServiceFactory ---');
    sci.ServiceFactory factory;
    try {
      factory = sci.ServiceFactory();
      _log('OK: ServiceFactory created');

      final baseUri =
          Uri(scheme: uri.scheme, host: uri.host, port: uri.port);
      _log('Calling initializeWith($baseUri, authClient)...');
      await factory.initializeWith(baseUri, authClient);
      tercen.ServiceFactory.CURRENT = factory;
      _log('OK: ServiceFactory initialized');
    } catch (e, st) {
      _log('FAIL: initializeWith: $e');
      _log('Stack: $st');
      return;
    }

    // Step 4: Call projectService.explore
    _log('--- Step 4: Fetch projects ---');
    try {
      _log('Calling projectService.explore("", 0, 10)...');
      final projects = await factory.projectService.explore("", 0, 10);
      _log('OK: Got ${projects.length} projects');

      final projectMaps = <Map<String, dynamic>>[];
      for (final p in projects) {
        final map = factory.projectService.toJson(p);
        _log('  - ${map['name']} (id: ${map['id']})');
        projectMaps.add(Map<String, dynamic>.from(map));
      }
      setState(() => _projects = projectMaps);
    } catch (e, st) {
      _log('FAIL: explore: $e');
      _log('Stack: $st');
    }

    // Step 5: Call findByIsPublicAndLastModifiedDate
    _log('--- Step 5: findByIsPublicAndLastModifiedDate ---');
    try {
      _log('Calling findByIsPublicAndLastModifiedDate(descending: true, limit: 10)...');
      final projects = await factory.projectService.findByIsPublicAndLastModifiedDate(
        startKey: [true, '0000'],
        endKey: [true, '9999'],
        limit: 10,
        descending: true,
      );
      _log('OK: Got ${projects.length} projects via find');
      for (final p in projects) {
        final map = factory.projectService.toJson(p);
        _log('  - ${map['name']} (id: ${map['id']})');
      }
    } catch (e, st) {
      _log('FAIL: findByIsPublicAndLastModifiedDate: $e');
      _log('Stack: $st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tercen Connection Debug')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Logs:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black87,
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (_, i) {
                    final log = _logs[i];
                    final color = log.startsWith('FAIL')
                        ? Colors.red
                        : log.startsWith('OK')
                            ? Colors.green
                            : Colors.white70;
                    return Text(log,
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: color));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
