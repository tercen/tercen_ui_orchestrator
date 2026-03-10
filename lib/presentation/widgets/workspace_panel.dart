import 'package:flutter/material.dart';

import 'package:tercen_ui_orchestrator/sdui/sdui_context.dart';

class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final sdui = SduiScope.of(context);

    return Container(
      color: const Color(0xFF1E1E1E),
      child: ListenableBuilder(
        listenable: sdui.windowManager,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              if (sdui.windowManager.windows.isEmpty) {
                return const Center(
                  child: Text(
                    'Workspace',
                    style: TextStyle(color: Colors.white38, fontSize: 24),
                  ),
                );
              }
              return sdui.windowManager.buildStack(
                constraints.maxWidth,
                constraints.maxHeight,
              );
            },
          );
        },
      ),
    );
  }
}
