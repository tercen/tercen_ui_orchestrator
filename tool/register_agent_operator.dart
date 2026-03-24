/// One-time script to register the tercen_agent operator in a Tercen instance.
///
/// Usage:
///   dart run tool/register_agent_operator.dart [serviceUri]
///
/// Defaults to http://127.0.0.1:5400. Authenticates as admin/admin.
/// Prints the assigned operator ID on success.

import 'package:sci_http_client/http_client.dart' as http_api;
import 'package:sci_http_client/http_io_client.dart' as io_http;
import 'package:sci_http_client/http_auth_client.dart' as auth_http;
import 'package:sci_tercen_client/sci_client.dart' as sci;

Future<void> main(List<String> args) async {
  final serviceUri = args.isNotEmpty ? args[0] : 'http://127.0.0.1:5400';

  print('Connecting to $serviceUri ...');

  http_api.HttpClient.setCurrent(io_http.HttpIOClient());

  // First authenticate to get a token
  final tempFactory = sci.ServiceFactory();
  final uri = Uri.parse(serviceUri);
  final baseUri = Uri(scheme: uri.scheme, host: uri.host, port: uri.port);
  await tempFactory.initializeWith(baseUri, io_http.HttpIOClient());

  final session = await tempFactory.userService.connect2('', 'admin', 'admin');
  final token = session.token.token;
  print('Authenticated. Token: ${token.substring(0, 20)}...');

  // Re-initialize with auth
  final factory = sci.ServiceFactory();
  await factory.initializeWith(baseUri, auth_http.HttpAuthClient(token, io_http.HttpIOClient()));

  // Create DockerOperator
  final op = sci.DockerOperator()
    ..name = 'tercen_agent'
    ..description = 'Claude AI agent operator — executes prompts using Claude with access to Tercen MCP tools.'
    ..version = '0.1.1'
    ..container = 'ghcr.io/tercen/tercen_agent:latest'
    ..url.uri = 'https://github.com/tercen/tercen_agent'
    ..acl.owner = 'admin'
    ..tags.addAll(['ai', 'agent', 'claude', 'mcp'])
    ..properties.addAll([
      sci.StringProperty()
        ..name = 'prompt'
        ..defaultValue = ''
        ..description = 'The user prompt/task for the agent to execute',
      sci.StringProperty()
        ..name = 'ANTHROPIC_API_KEY'
        ..defaultValue = ''
        ..description = 'Anthropic API key for Claude access',
      sci.StringProperty()
        ..name = 'model'
        ..defaultValue = 'claude-sonnet-4-6'
        ..description = 'Claude model to use',
      sci.StringProperty()
        ..name = 'systemPrompt'
        ..defaultValue = ''
        ..description = 'Optional system prompt override',
      sci.StringProperty()
        ..name = 'maxTurns'
        ..defaultValue = '20'
        ..description = 'Maximum number of agentic turns',
      sci.StringProperty()
        ..name = 'uiState'
        ..defaultValue = ''
        ..description = 'JSON snapshot of current UI state',
    ]);

  final created = await factory.operatorService.create(op);
  print('');
  print('Operator registered successfully!');
  print('  ID:        ${created.id}');
  print('  Name:      ${created.name}');
  print('  Kind:      ${created.kind}');
  print('  Container: ${(created as sci.DockerOperator).container}');
  print('');
  print('Use this ID with the Flutter app:');
  print('  --dart-define=AGENT_OPERATOR_ID=${created.id}');
}
