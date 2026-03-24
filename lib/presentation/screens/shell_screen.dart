import 'package:flutter/material.dart';
import 'package:sdui/sdui.dart';
import 'package:tercen_ui_orchestrator/presentation/widgets/error_bar.dart';
import 'package:tercen_ui_orchestrator/presentation/widgets/workspace_panel.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  void _openChat(BuildContext context) {
    final sdui = SduiScope.of(context);
    sdui.eventBus.publish(
      'system.layout.op',
      EventPayload(type: 'layout.op', data: {
        'op': 'addWindow',
        'id': 'win-chat',
        'size': 'column',
        'align': 'right',
        'title': 'Chat',
        'content': {
          'type': 'ChatPanel',
          'id': 'chat-root',
          'props': {},
          'children': [],
        },
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Column(
        children: [
          Expanded(child: WorkspacePanel()),
          ErrorBar(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openChat(context),
        tooltip: 'Open Chat',
        child: const Icon(Icons.chat_rounded),
      ),
    );
  }
}
