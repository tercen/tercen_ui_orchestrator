/// Quick test script for Tercen REST API calls.
/// Uses dart:io HttpClient directly — no SDK dependencies needed.
///
/// Usage:
///   dart run bin/test_api.dart <jwt-token>
///     → decodes JWT, fetches user, lists teams & projects
///
///   dart run bin/test_api.dart <jwt-token> GET /api/v1/user/test
///     → raw GET request
///
///   dart run bin/test_api.dart <jwt-token> POST /api/v1/team/teamByOwner '["userId"]'
///     → raw POST request with JSON body (findKeys call)
///
///   dart run bin/test_api.dart <jwt-token> POST /api/v1/project/findByIsPublicAndLastModifiedDate '{"startKey":[false,""],"endKey":[true,"\uf000"],"limit":5}'
///     → raw POST request (findStartKeys call)

import 'dart:convert';
import 'dart:io';

late String _baseUrl;
late String _token;

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run bin/test_api.dart <jwt-token> [GET|POST path [body]]');
    exit(1);
  }

  _token = args[0];

  // Decode JWT
  final payload = _decodeJwt(_token);
  print('=== JWT Payload ===');
  print(const JsonEncoder.withIndent('  ').convert(payload));
  print('');

  final jwtData = payload['data'] as Map<String, dynamic>? ?? {};
  final username = jwtData['u'] as String? ?? '(none)';
  _baseUrl = payload['iss'] as String? ?? '';
  print('Username (data.u): $username');
  print('Base URL (iss):    $_baseUrl');
  print('');

  if (_baseUrl.isEmpty) {
    print('ERROR: No "iss" in JWT');
    exit(1);
  }

  // Custom raw call
  if (args.length >= 3) {
    final method = args[1].toUpperCase();
    final path = args[2];
    final body = args.length > 3 ? args[3] : null;
    await _rawCall(method, path, body);
    exit(0);
  }

  // Default test sequence
  // Note: Tercen REST API uses TSON encoding, not JSON.
  // GET requests return JSON, but POST requests expect TSON.
  // This script can only do GET requests reliably.

  print('=== 1. GET user "$username" (by username as ID) ===');
  var userJson = await _get('/api/v1/user/$username');
  String userId = username;
  if (userJson != null) {
    userId = userJson['id'] as String? ?? username;
    print('  id:    $userId');
    print('  name:  ${userJson['name']}');
    print('  email: ${userJson['email']}');
  } else {
    print('  GET /api/v1/user/$username returned 404');
    print('  In Tercen, user IDs are UUIDs, not usernames.');
    print('  Using username "$username" as userId for remaining tests.');
    print('  NOTE: POST endpoints use TSON encoding (binary), not JSON.');
    print('  Use the Flutter app to test findKeys/findStartKeys calls.');
  }
  print('');

  print('=== 2. findTeamByOwner(keys: ["$userId"]) ===');
  final teams = await _post('/api/v1/team/teamByOwner', jsonEncode([userId]));
  if (teams is List) {
    print('  Found ${teams.length} team(s)');
    for (final t in teams) {
      print('    - ${t['name']} (id: ${t['id']})');
    }
  }
  print('');

  print('=== 3. findTeamByOwner(keys: ["$username"]) — should this work? ===');
  final teams2 = await _post('/api/v1/team/teamByOwner', jsonEncode([username]));
  if (teams2 is List) {
    print('  Found ${teams2.length} team(s)');
    for (final t in teams2) {
      print('    - ${t['name']} (id: ${t['id']})');
    }
  }
  print('');

  print('=== 4. findByIsPublicAndLastModifiedDate (projects) ===');
  final projects = await _post(
      '/api/v1/project/findByIsPublicAndLastModifiedDate',
      jsonEncode({
        'startKey': [false, ''],
        'endKey': [true, '\uf000'],
        'limit': 5,
        'descending': true,
      }));
  if (projects is List) {
    print('  Found ${projects.length} project(s)');
    for (final p in projects) {
      print('    - ${p['name']} (id: ${p['id']}, owner: ${_tryPath(p, 'acl.owner')})');
    }
  }
  print('');

  print('=== 5. findByTeamAndIsPublicAndLastModifiedDate (if teams found) ===');
  if (teams is List && teams.isNotEmpty) {
    final teamId = teams[0]['id'] as String;
    final teamProjects = await _post(
        '/api/v1/project/findByTeamAndIsPublicAndLastModifiedDate',
        jsonEncode({
          'startKey': [teamId, false, ''],
          'endKey': [teamId, true, '\uf000'],
          'limit': 5,
          'descending': true,
        }));
    if (teamProjects is List) {
      print('  Found ${teamProjects.length} project(s) in team "${teams[0]['name']}"');
      for (final p in teamProjects) {
        print('    - ${p['name']} (id: ${p['id']})');
      }
    }
  } else {
    print('  Skipped — no teams found');
  }

  exit(0);
}

Future<Map<String, dynamic>?> _get(String path) async {
  try {
    final client = HttpClient();
    final uri = Uri.parse('$_baseUrl$path');
    final request = await client.getUrl(uri);
    request.headers.set('authorization', _token);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode != 200) {
      print('  HTTP ${response.statusCode}: $body');
      return null;
    }
    return jsonDecode(body) as Map<String, dynamic>;
  } catch (e) {
    print('  ERROR: $e');
    return null;
  }
}

Future<dynamic> _post(String path, String body) async {
  try {
    final client = HttpClient();
    final uri = Uri.parse('$_baseUrl$path');
    final request = await client.postUrl(uri);
    request.headers.set('authorization', _token);
    request.headers.contentType = ContentType.json;
    request.write(body);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode != 200) {
      print('  HTTP ${response.statusCode}: $responseBody');
      return null;
    }
    return jsonDecode(responseBody);
  } catch (e) {
    print('  ERROR: $e');
    return null;
  }
}

Future<void> _rawCall(String method, String path, String? body) async {
  print('=== $method $path ===');
  if (body != null) print('Body: $body');
  print('');

  try {
    final client = HttpClient();
    final uri = Uri.parse('$_baseUrl$path');
    final HttpClientRequest request;
    if (method == 'POST') {
      request = await client.postUrl(uri);
      request.headers.set('authorization', _token);
      request.headers.contentType = ContentType.json;
      if (body != null) request.write(body);
    } else {
      request = await client.getUrl(uri);
      request.headers.set('authorization', _token);
    }

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    client.close();

    print('Status: ${response.statusCode}');
    try {
      final parsed = jsonDecode(responseBody);
      print(const JsonEncoder.withIndent('  ').convert(parsed));
    } catch (_) {
      print(responseBody);
    }
  } catch (e) {
    print('ERROR: $e');
  }
}

Map<String, dynamic> _decodeJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return {};
  var payload = parts[1];
  switch (payload.length % 4) {
    case 2: payload += '=='; break;
    case 3: payload += '='; break;
  }
  return jsonDecode(utf8.decode(base64Url.decode(payload))) as Map<String, dynamic>;
}

String _tryPath(dynamic obj, String path) {
  if (obj is! Map) return '';
  dynamic current = obj;
  for (final part in path.split('.')) {
    if (current is Map) {
      current = current[part];
    } else {
      return '';
    }
  }
  return current?.toString() ?? '';
}
