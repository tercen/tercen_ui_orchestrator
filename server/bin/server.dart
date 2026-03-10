import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

/// Connected UI WebSocket sinks — layout operations are pushed here.
final List<dynamic> _uiSinks = [];

void main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  final router = Router();

  // Health check
  router.get('/api/health', (Request req) => Response.ok('ok'));

  // WebSocket: chat channel
  router.all('/ws/chat', webSocketHandler((ws, _) {
    print('[ws/chat] client connected');
    ws.stream.listen(
      (message) {
        print('[ws/chat] received: $message');
        _handleChatMessage(ws.sink, message as String);
      },
      onDone: () => print('[ws/chat] client disconnected'),
    );
  }));

  // WebSocket: UI command channel
  router.all('/ws/ui', webSocketHandler((ws, _) {
    print('[ws/ui] client connected');
    _uiSinks.add(ws.sink);
    ws.stream.listen(
      (message) => print('[ws/ui] received: $message'),
      onDone: () {
        print('[ws/ui] client disconnected');
        _uiSinks.remove(ws.sink);
      },
    );
  }));

  // Static files: serve Flutter web build
  final staticHandler = createStaticHandler(
    '../build/web',
    defaultDocument: 'index.html',
  );

  final cascade = Cascade().add(router.call).add(staticHandler).handler;

  final pipeline =
      Pipeline().addMiddleware(logRequests()).addHandler(cascade);

  final server = await io.serve(pipeline, '0.0.0.0', port);
  print('Server running on http://localhost:${server.port}');
}

/// Handle an incoming chat message. For now, simulate AI responses.
/// Later this will pipe to Claude Code subprocess.
void _handleChatMessage(dynamic chatSink, String raw) {
  chatSink.add(jsonEncode({
    'role': 'assistant',
    'text': 'Here\'s your project list!',
  }));

  final ts = DateTime.now().millisecondsSinceEpoch;

  // Build a project tree using SDUI primitives
  Map<String, dynamic> treeItem(String icon, String name, List<Map<String, dynamic>> children) {
    return {
      'type': 'Column',
      'id': 'tree-$name-$ts',
      'props': {'crossAxisAlignment': 'start'},
      'children': [
        {
          'type': 'Padding',
          'id': 'pad-$name-$ts',
          'props': {'padding': 4},
          'children': [
            {
              'type': 'Row',
              'id': 'row-$name-$ts',
              'children': [
                {
                  'type': 'Text',
                  'id': 'icon-$name-$ts',
                  'props': {'text': icon, 'fontSize': 14, 'color': 'grey'},
                },
                {
                  'type': 'SizedBox',
                  'id': 'sp-$name-$ts',
                  'props': {'width': 6},
                },
                {
                  'type': 'Text',
                  'id': 'txt-$name-$ts',
                  'props': {'text': name, 'fontSize': 14, 'color': 'white'},
                },
              ],
            },
          ],
        },
        if (children.isNotEmpty)
          {
            'type': 'Padding',
            'id': 'indent-$name-$ts',
            'props': {'padding': 0},
            'children': [
              {
                'type': 'Container',
                'id': 'cont-$name-$ts',
                'props': {'padding': 0},
                'children': [
                  {
                    'type': 'Padding',
                    'id': 'left-$name-$ts',
                    'props': {'padding': 16},
                    'children': [
                      {
                        'type': 'Column',
                        'id': 'kids-$name-$ts',
                        'props': {'crossAxisAlignment': 'start'},
                        'children': children,
                      },
                    ],
                  },
                ],
              },
            ],
          },
      ],
    };
  }

  final content = {
    'type': 'ListView',
    'id': 'project-tree-$ts',
    'props': {'padding': 12},
    'children': [
      treeItem('📁', 'My Projects', [
        treeItem('📊', 'RNA-seq Analysis', [
          treeItem('⚙️', 'DESeq2 Workflow', []),
          treeItem('📈', 'Volcano Plot', []),
          treeItem('📄', 'results.csv', []),
        ]),
        treeItem('🧬', 'Single Cell Study', [
          treeItem('⚙️', 'UMAP Pipeline', []),
          treeItem('📊', 'Cluster View', []),
        ]),
        treeItem('📋', 'Proteomics QC', []),
      ]),
      treeItem('👥', 'Shared With Me', [
        treeItem('📊', 'Team Dashboard', []),
        treeItem('🧪', 'Drug Response Screen', [
          treeItem('⚙️', 'Dose-Response Workflow', []),
          treeItem('📈', 'IC50 Curves', []),
        ]),
      ]),
    ],
  };

  final layoutOp = jsonEncode({
    'op': 'addWindow',
    'id': 'win-$ts',
    'size': 'medium',
    'align': 'center',
    'title': 'Projects',
    'content': content,
  });

  for (final sink in _uiSinks) {
    sink.add(layoutOp);
  }
}
