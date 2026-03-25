import 'package:flutter/material.dart';

import 'package:sdui/sdui.dart';

class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final sdui = SduiScope.of(context);

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListenableBuilder(
        listenable: sdui.windowManager,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              if (sdui.windowManager.windows.isEmpty) {
                return Center(
                  child: Text(
                    'Workspace',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 24,
                    ),
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
