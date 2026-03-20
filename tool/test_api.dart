/// Test script for Tercen API calls via ServiceCallDispatcher.
/// Runs through the Flutter project (has sci_tercen_client dependency).
///
/// Usage:
///   flutter run -d chrome tool/test_api.dart  — NOT supported (Flutter needs a widget)
///
/// Instead, run as a Dart VM script with the Flutter project's packages:
///   dart run tool/test_api.dart <jwt-token>
///   dart run tool/test_api.dart <jwt-token> <service> <method> <args...>
///
/// Examples:
///   dart run tool/test_api.dart <jwt>
///     → decodes JWT, fetches teams, lists projects
///
///   dart run tool/test_api.dart <jwt> teamService findTeamByOwner '["test"]'
///     → calls teamService.findTeamByOwner with keys: ["test"]

import 'dart:convert';
import 'dart:io';

import 'package:sci_http_client/http_auth_client.dart' as auth_http;
import 'package:sci_http_client/http_client.dart' as http_api;
import 'package:sci_http_client/http_io_client.dart' as io_http;
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sci_tercen_client/sci_client_service_factory.dart' as tercen;
import 'package:tercen_ui_orchestrator/sdui/service/service_call_dispatcher.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run tool/test_api.dart <jwt-token> [service method args...]');
    exit(1);
  }

  final token = args[0];

  // Decode JWT
  final payload = _decodeJwt(token);
  print('=== JWT ===');
  final jwtData = payload['data'] as Map<String, dynamic>? ?? {};
  final username = jwtData['u'] as String? ?? '(none)';
  final serviceUri = payload['iss'] as String? ?? '';
  print('username: $username');
  print('serviceUri: $serviceUri');

  if (serviceUri.isEmpty) {
    print('ERROR: No "iss" in JWT');
    exit(1);
  }

  // Create ServiceFactory (same as main.dart but with IO client for Dart VM)
  print('\n=== Connecting ===');
  http_api.HttpClient.setCurrent(io_http.HttpIOClient());
  final authClient = auth_http.HttpAuthClient(token, io_http.HttpIOClient());
  final factory = sci.ServiceFactory();
  final uri = Uri.parse(serviceUri);
  await factory.initializeWith(
      Uri(scheme: uri.scheme, host: uri.host, port: uri.port), authClient);
  tercen.ServiceFactory.CURRENT = factory;
  final dispatcher = ServiceCallDispatcher(factory);
  print('Connected.');

  // Custom call
  if (args.length >= 3) {
    final service = args[1];
    final method = args[2];
    final callArgs = <dynamic>[];
    for (int i = 3; i < args.length; i++) {
      try {
        callArgs.add(jsonDecode(args[i]));
      } on FormatException {
        callArgs.add(args[i]);
      }
    }

    print('\n=== $service.$method(${callArgs.map(_fmt).join(', ')}) ===');
    try {
      final result = await dispatcher.call(service, method, callArgs);
      _printResult(result);
    } catch (e) {
      print('ERROR: $e');
    }
    exit(0);
  }

  // Default test sequence
  print('\n=== 1. teamService.findTeamByOwner(keys: ["$username"]) ===');
  try {
    final result = await dispatcher.call('teamService', 'findTeamByOwner', [[username]]);
    _printResult(result);
  } catch (e) {
    print('ERROR: $e');
  }

  print('\n=== 2. projectService.findByIsPublicAndLastModifiedDate ===');
  try {
    final result = await dispatcher.call(
        'projectService', 'findByIsPublicAndLastModifiedDate',
        [[false, ''], [true, '\uf000'], 5]);
    _printResult(result);
  } catch (e) {
    print('ERROR: $e');
  }

  print('\n=== 3. userService.findUserByEmail(keys: ["$username"]) ===');
  try {
    final result = await dispatcher.call('userService', 'findUserByEmail', [[username]]);
    _printResult(result);
  } catch (e) {
    print('ERROR: $e');
  }

  exit(0);
}

void _printResult(dynamic result) {
  if (result is List) {
    print('Got ${result.length} result(s)');
    for (final r in result) {
      if (r is Map) {
        final m = Map<String, dynamic>.from(r);
        print('  - ${m['name'] ?? m['id'] ?? m}');
      } else {
        print('  - $r');
      }
    }
  } else if (result is Map) {
    print(const JsonEncoder.withIndent('  ').convert(
        Map<String, dynamic>.from(result)));
  } else {
    print(result);
  }
}

String _fmt(dynamic v) => v is String ? '"$v"' : '$v';

Map<String, dynamic> _decodeJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return {};
  var p = parts[1];
  switch (p.length % 4) {
    case 2: p += '=='; break;
    case 3: p += '='; break;
  }
  return jsonDecode(utf8.decode(base64Url.decode(p))) as Map<String, dynamic>;
}
