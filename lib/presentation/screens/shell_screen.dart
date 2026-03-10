import 'package:flutter/material.dart';
import 'package:tercen_ui_orchestrator/presentation/widgets/chat_panel.dart';
import 'package:tercen_ui_orchestrator/presentation/widgets/workspace_panel.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: WorkspacePanel(),
          ),
          VerticalDivider(width: 1, thickness: 1),
          Expanded(
            flex: 2,
            child: ChatPanel(),
          ),
        ],
      ),
    );
  }
}
