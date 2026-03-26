import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sdui/sdui.dart';
import 'package:tercen_ui_orchestrator/presentation/widgets/workspace_panel.dart';

/// Minimal shell — SDUI workspace filling the screen + error bar.
/// The header region is rendered above the workspace when the catalog
/// defines a "top" region in home.regions.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  SduiNode? _headerNode;
  StreamSubscription<EventPayload>? _regionSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_regionSub == null) {
      final sdui = SduiScope.of(context);
      _regionSub = sdui.eventBus
          .subscribe('system.layout.region')
          .listen(_onRegionEvent);
    }
  }

  void _onRegionEvent(EventPayload event) {
    final region = event.data['region'] as String?;
    if (region == 'top') {
      final content = event.data['content'] as Map<String, dynamic>?;
      if (content != null) {
        setState(() {
          _headerNode = SduiNode.fromJson(content);
        });
      }
    }
  }

  @override
  void dispose() {
    _regionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sdui = SduiScope.of(context);
    // Subscribe to MaterialApp theme changes so SDUI widgets re-render
    // with updated colors when the user toggles light/dark mode.
    Theme.of(context);

    final bgColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: bgColor,
      body: Padding(
        padding: EdgeInsets.only(
          left: sdui.renderContext.theme.spacing.sm,
          right: sdui.renderContext.theme.spacing.sm,
          top: sdui.renderContext.theme.spacing.xs,
        ),
        child: Column(
          children: [
            if (_headerNode != null)
              SduiRenderer(
                registry: sdui.registry,
                renderContext: sdui.renderContext,
              ).render(_headerNode!),
            Expanded(
              child: ToastOverlay(
                eventBus: sdui.eventBus,
                theme: sdui.renderContext.theme,
                child: PopupOverlay(
                  eventBus: sdui.eventBus,
                  windowManager: sdui.windowManager,
                  theme: sdui.renderContext.theme,
                  child: const WorkspacePanel(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
