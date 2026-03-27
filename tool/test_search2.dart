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

  // 1. Full-text search
  print('=== documentService.search("flow", 10) ===');
  final sr = await factory.documentService.search('flow', 10, false, '');
  final j = sr.toJson();
  print('total_rows: ${j['total_rows']}');
  for (final d in ((j['rows'] as List?) ?? []).take(5)) {
    if (d is Map) print('  name=${d['name']} subKind=${d['subKind']} owner=${d['acl']?['owner']}');
  }

  // 2. Team projects (try each team)
  final teams = await factory.teamService.findKeys('teamByOwner', keys: ['martin.english']);
  for (final t in teams) {
    final projs = await factory.documentService.findProjectByOwnersAndCreatedDate(
      startKey: [t.name, '\uf000'],
      endKey: [t.name, ''],
      limit: 5,
      descending: true,
    );
    print('\n=== Team "${t.name}" projects: ${projs.length} ===');
    for (final p in projs.take(3)) { print('  ${p.name}'); }
  }

  // 3. findProjectByOwnersAndName with prefix search
  print('\n=== findProjectByOwnersAndName("martin.english", "Flow") ===');
  final named = await factory.documentService.findProjectByOwnersAndName(
    startKey: ['martin.english', 'Flow'],
    endKey: ['martin.english', 'Flow\uf000'],
    limit: 10,
    descending: false,
  );
  print('Count: ${named.length}');
  for (final d in named.take(5)) { print('  ${d.name}'); }

  exit(0);
}
