import 'dart:convert';
import 'dart:io';
import 'package:sci_http_client/http_auth_client.dart' as auth_http;
import 'package:sci_http_client/http_client.dart' as http_api;
import 'package:sci_http_client/http_io_client.dart' as io_http;
import 'package:sci_tercen_client/sci_client.dart' as sci;

void main() async {
  final token = Platform.environment['TOKEN']!;
  http_api.HttpClient.setCurrent(io_http.HttpIOClient());
  final authClient = auth_http.HttpAuthClient(token, io_http.HttpIOClient());
  final factory = sci.ServiceFactory();
  await factory.initializeWith(Uri.parse('https://stage.tercen.com'), authClient);

  // 1. documentService.search — full-text search across all accessible docs
  print('=== documentService.search("volcano", limit=10) ===');
  try {
    final result = await factory.documentService.search('volcano', 10, false, '');
    final j = result.toJson();
    final docs = j['result'] ?? j['docs'] ?? j;
    print('Type: ${result.runtimeType}');
    print('Keys: ${j.keys.toList()}');
    if (j['result'] is List) {
      for (final d in (j['result'] as List).take(5)) {
        print('  name=${d['name']} kind=${d['kind']} subKind=${d['subKind']} owner=${d['acl']?['owner']}');
      }
    }
  } catch (e) { print('Error: $e'); }

  // 2. Get user's teams
  print('\n=== teamService.findTeamByOwner(martin.english) ===');
  try {
    final teams = await factory.teamService.findKeys('teamByOwner', keys: ['martin.english']);
    print('Teams: ${teams.length}');
    for (final t in teams) {
      print('  name=${t.name} id=${t.id}');
    }
  } catch (e) { print('Error: $e'); }

  // 3. findProjectByOwnersAndName — search by name prefix
  print('\n=== documentService.findProjectByOwnersAndName("martin.english", "vol") ===');
  try {
    final result = await factory.documentService.findProjectByOwnersAndName(
      startKey: ['martin.english', 'Vol'],
      endKey: ['martin.english', 'Vol\uf000'],
      limit: 10,
      descending: false,
    );
    print('Count: ${result.length}');
    for (final d in result) { print('  name=${d.name}'); }
  } catch (e) { print('Error: $e'); }

  // 4. findProjectByOwnersAndCreatedDate for all user's projects
  print('\n=== documentService.findProjectByOwnersAndCreatedDate (all) ===');
  try {
    final result = await factory.documentService.findProjectByOwnersAndCreatedDate(
      startKey: ['martin.english', '\uf000'],
      endKey: ['martin.english', ''],
      limit: 50,
      descending: true,
    );
    print('User projects: ${result.length}');
  } catch (e) { print('Error: $e'); }

  // 5. Check if there's a team-based project finder
  print('\n=== projectService.findByTeamAndIsPublicAndLastModifiedDate ===');
  try {
    final result = await factory.projectService.findByTeamAndIsPublicAndLastModifiedDate(
      startKey: ['test', true, '\uf000'],
      endKey: ['test', true, ''],
      limit: 10,
      descending: true,
    );
    print('Team "test" projects: ${result.length}');
    for (final p in result.take(5)) {
      print('  name=${p.name} owner=${p.acl.owner}');
    }
  } catch (e) { print('Error: $e'); }

  exit(0);
}
