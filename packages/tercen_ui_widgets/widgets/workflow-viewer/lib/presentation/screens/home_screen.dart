import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/workflow_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/mock_tab_strip.dart';
import '../widgets/toolbar_search_field.dart';
import '../widgets/flowchart_view.dart';
import '../../core/constants/window_constants.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/window_shell.dart';

/// The main screen for the Workflow Viewer window.
///
/// Wires the toolbar with the stateful action button and search field.
/// Passes the FlowchartView as active content.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkflowProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final actionConfig = provider.actionButtonConfig;

    // Choose icon for the action button
    IconData actionIcon;
    switch (actionConfig.action) {
      case ActionButtonAction.runWorkflow:
      case ActionButtonAction.runStep:
        actionIcon = FontAwesomeIcons.play;
        break;
      case ActionButtonAction.stopWorkflow:
      case ActionButtonAction.stopStep:
        actionIcon = FontAwesomeIcons.stop;
        break;
      case ActionButtonAction.resetWorkflow:
      case ActionButtonAction.resetStep:
        actionIcon = FontAwesomeIcons.rotateLeft;
        break;
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final effectiveWidth =
              constraints.maxWidth < WindowConstants.minWidgetWidth
                  ? WindowConstants.minWidgetWidth
                  : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: effectiveWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  const MockTabStrip(),
                  Expanded(
                    child: WindowShell(
                      toolbarActions: [
                        ToolbarAction(
                          icon: actionIcon,
                          tooltip: actionConfig.tooltip,
                          label: actionConfig.label,
                          variant: ToolbarButtonVariant.primary,
                          onPressed: () => provider.executeAction(),
                        ),
                        ToolbarAction(
                          icon: FontAwesomeIcons.magnifyingGlassMinus,
                          tooltip: 'Zoom out',
                          variant: ToolbarButtonVariant.secondary,
                          onPressed: () => provider.zoomOut(),
                        ),
                        ToolbarAction(
                          icon: FontAwesomeIcons.magnifyingGlassPlus,
                          tooltip: 'Zoom in',
                          variant: ToolbarButtonVariant.secondary,
                          onPressed: () => provider.zoomIn(),
                        ),
                        ToolbarAction(
                          icon: FontAwesomeIcons.expand,
                          tooltip: 'Fit to window',
                          variant: ToolbarButtonVariant.secondary,
                          onPressed: () {
                            final box =
                                context.findRenderObject() as RenderBox?;
                            if (box != null) {
                              provider.zoomToFit(
                                  box.size.width, box.size.height);
                            }
                          },
                        ),
                      ],
                      toolbarTrailing: [
                        ToolbarSearchField(
                          hintText: 'Search steps...',
                          onChanged: (value) =>
                              provider.setSearchText(value),
                        ),
                      ],
                      activeContent: const FlowchartView(),
                      emptyIcon: FontAwesomeIcons.diagramProject,
                      emptyMessage: 'No workflow selected',
                      emptyDetail:
                          'Select a workflow in the Navigator',
                      onRetry: () => provider.loadWorkflow(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      // DEV controls (mock only)
      floatingActionButton: Opacity(
        opacity: 0.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Notification demo buttons
            _DevDot(
              color: const Color(0xFF047857),
              tooltip: 'Success notification',
              onTap: () => showAppSnackbar(
                context,
                type: SnackbarType.success,
                title: 'Step completed',
                message: 'PhenoGraph clustering finished successfully.',
              ),
            ),
            const SizedBox(height: 4),
            _DevDot(
              color: const Color(0xFF0E7490),
              tooltip: 'Info notification',
              onTap: () => showAppSnackbar(
                context,
                type: SnackbarType.info,
                title: 'Workflow loaded',
                message: 'Run - 2026-03-05 15.56 (65 steps)',
              ),
            ),
            const SizedBox(height: 4),
            _DevDot(
              color: const Color(0xFFB45309),
              tooltip: 'Warning notification',
              onTap: () => showAppSnackbar(
                context,
                type: SnackbarType.warning,
                title: 'Long running step',
                message: 'UMAP has been running for 5 minutes.',
              ),
            ),
            const SizedBox(height: 4),
            _DevDot(
              color: const Color(0xFFB91C1C),
              tooltip: 'Error notification',
              onTap: () => showAppSnackbar(
                context,
                type: SnackbarType.error,
                title: 'Step failed',
                message:
                    'Compensate failed: missing compensation matrix.',
              ),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              onPressed: () => themeProvider.toggleTheme(),
              tooltip: 'Toggle theme (DEV)',
              child: Icon(
                themeProvider.isDarkMode
                    ? FontAwesomeIcons.sun
                    : FontAwesomeIcons.moon,
                size: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'DEV',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white38
                    : Colors.black26,
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

/// Small coloured dot button for triggering mock notifications (DEV only).
class _DevDot extends StatelessWidget {
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _DevDot({
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
