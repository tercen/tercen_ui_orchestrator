import 'dart:convert';
import 'dart:io';

import 'package:sci_http_client/http_auth_client.dart' as auth_http;
import 'package:sci_http_client/http_client.dart' as http_api;
import 'package:sci_http_client/http_io_client.dart' as io_http;
import 'package:sci_tercen_client/sci_client.dart' as sci;

void main(List<String> args) async {
  final token = args[0];
  final payload = _decodeJwt(token);
  final jwtData = payload['data'] as Map<String, dynamic>? ?? {};
  final username = jwtData['u'] as String? ?? '';
  final serviceUri = payload['iss'] as String? ?? '';
  print('user: $username, service: $serviceUri');

  http_api.HttpClient.setCurrent(io_http.HttpIOClient());
  final authClient = auth_http.HttpAuthClient(token, io_http.HttpIOClient());
  final factory = sci.ServiceFactory();
  final uri = Uri.parse(serviceUri);
  await factory.initializeWith(
      Uri(scheme: uri.scheme, host: uri.host, port: uri.port), authClient);

  // 1. recentProjects
  print('\n=== projectService.recentProjects("$username") ===');
  try {
    final recent = await factory.projectService.recentProjects(username);
    print('Count: ${recent.length}');
    for (final p in recent) {
      print('  name="${p.name}" owner=${p.acl.owner} id=${p.id}');
    }
    if (recent.isNotEmpty) {
      print('\n=== First project — all date fields ===');
      final j = recent[0].toJson();
      for (final e in j.entries) {
        if (e.key.toLowerCase().contains('date') || e.key.toLowerCase().contains('modified') || e.key.toLowerCase().contains('created') || e.key.toLowerCase().contains('time')) {
          print('  ${e.key} = ${e.value}');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }

  print('\n=== documentService.findProjectByOwnersAndCreatedDate (20, descending) ===');
  try {
    final result = await factory.documentService.findProjectByOwnersAndCreatedDate(
      startKey: [username, '\uf000'],
      endKey: [username, ''],
      limit: 20,
      descending: true,
    );
    print('Count: ${result.length}');
    for (final d in result) {
      final j = d.toJson();
      print('  name="${d.name}" lastModified=${j['lastModifiedDate'] ?? j['createdDate'] ?? '?'}');
    }
  } catch (e) {
    print('Error: $e');
  }

  // 4. activityService
  print('\n=== activityService.findByUserAndDate ===');
  try {
    final result = await factory.activityService.findByUserAndDate(
      startKey: [username, ''],
      endKey: [username, '\uf000'],
      limit: 10,
      descending: true,
    );
    print('Count: ${result.length}');
    for (final a in result) {
      final j = a.toJson();
      print('  type=${j['type'] ?? '?'} desc=${(j['description'] ?? '?').toString().take60()}');
    }
  } catch (e) {
    print('Error: $e');
  }

  exit(0);
}

extension on String {
  String take60() => length > 60 ? substring(0, 60) : this;
}

Map<String, dynamic> _decodeJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) throw FormatException('Invalid JWT');
  var payload = parts[1];
  while (payload.length % 4 != 0) payload += '=';
  return jsonDecode(utf8.decode(base64Url.decode(payload))) as Map<String, dynamic>;
}
