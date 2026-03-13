import '../lib/sdui/renderer/template_resolver.dart';
import '../lib/sdui/renderer/json_path_resolver.dart';

void main() {
  final resolver = TemplateResolver();
  
  final item = {
    'kind': 'Project',
    'id': 'b35d8b128969e6578e7b525a656fc4df',
    'isDeleted': false,
    'description': '',
    'name': 'python_auto_project',
    'acl': {'kind': 'Acl', 'owner': 'test', 'aces': []},
    'createdDate': {'kind': 'Date', 'value': '2026-01-09T19:00:02.248432Z'},
    'lastModifiedDate': {'kind': 'Date', 'value': '2026-01-09T19:00:02.248432Z'},
  };

  final scope = {'item': item};

  print('=== Template Resolver ===');
  print('name: "${resolver.resolveString("{{item.name}}", scope)}"');
  print('id: "${resolver.resolveString("{{item.id}}", scope)}"');
  print('desc: "${resolver.resolveString("{{item.description}}", scope)}"');
  print('owner: "${resolver.resolveString("Owner: {{item.acl.owner}}", scope)}"');
  print('date: "${resolver.resolveString("{{item.lastModifiedDate.value}}", scope)}"');
  
  print('\n=== Props Resolution ===');
  final props = <String, dynamic>{'text': '{{item.name}}', 'fontSize': 16};
  final resolved = resolver.resolveProps(props, scope);
  print('resolved props: $resolved');
  
  print('\n=== JSONPath Direct ===');
  print('name: "${resolveJsonPath(item, "name")}"');
  print('acl.owner: "${resolveJsonPath(item, "acl.owner")}"');
  print('jsonpath name: "${resolveJsonPath(item, r"$.name")}"');
  print('jsonpath acl.owner: "${resolveJsonPath(item, r"$.acl.owner")}"');
  print('jsonpath date: "${resolveJsonPath(item, r"$.lastModifiedDate.value")}"');
  
  print('\n=== Regex Match Test ===');
  final pattern = RegExp(
    r'\{\{(\w+)'
    r'(?:'
      r':(\$[^\}]+)'
      r'|'
      r'\.([.\w]+)'
    r')'
    r'\}\}',
  );
  for (var test in ['{{item.name}}', '{{item.acl.owner}}', '{{item.id}}', r'{{item:$.acl.owner}}']) {
    final match = pattern.firstMatch(test);
    if (match != null) {
      print('  "$test" => scope=${match.group(1)}, jsonPath=${match.group(2)}, dotPath=${match.group(3)}');
    } else {
      print('  "$test" => NO MATCH');
    }
  }
}
