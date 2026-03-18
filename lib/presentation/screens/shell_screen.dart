import 'package:flutter/material.dart';
import 'package:tercen_ui_orchestrator/presentation/widgets/chat_panel.dart';
import 'package:tercen_ui_orchestrator/presentation/widgets/error_bar.dart';
import 'package:tercen_ui_orchestrator/presentation/widgets/toolbar.dart';
import 'package:tercen_ui_orchestrator/presentation/widgets/workspace_panel.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Toolbar(),
          Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor),
          const Expanded(
            child: Row(
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
          ),
          const ErrorBar(),
        ],
      ),
    );
  }
}
