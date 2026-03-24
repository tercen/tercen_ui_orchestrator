import 'package:flutter/material.dart';
import 'package:tercen_ui_orchestrator/presentation/widgets/error_bar.dart';
import 'package:tercen_ui_orchestrator/presentation/widgets/workspace_panel.dart';

/// Minimal shell — just the SDUI workspace filling the screen + error bar.
/// All panels (header, chat, nav, etc.) are opened as floating windows
/// by the home configuration in catalog.json.
class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        children: [
          Expanded(child: WorkspacePanel()),
          ErrorBar(),
        ],
      ),
    );
  }
}
