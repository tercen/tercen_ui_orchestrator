import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import '../providers/navigator_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/mock_tab_strip.dart';
import '../widgets/search_field.dart';
import '../widgets/tree_view.dart';
import '../widgets/type_filter_button.dart';
import '../../core/constants/window_constants.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/window_shell.dart';

/// The main screen for the File Navigator window.
///
/// Wires the toolbar with upload/download/team buttons, type filter,
/// and search field. Passes the TreeView as active content.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _handleUpload(BuildContext context) {
    final input = web.HTMLInputElement();
    input.type = 'file';
    input.accept = '*/*';
    input.click();

    input.onChange.listen((event) {
      final files = input.files;
      if (files != null && files.length > 0) {
        final file = files.item(0);
        if (file != null) {
          context.read<NavigatorProvider>().uploadFile(file.name);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NavigatorProvider>();
    final themeProvider = context.watch<ThemeProvider>();

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
                          icon: FontAwesomeIcons.upload,
                          tooltip: 'Upload',
                          variant: ButtonVariant.primary,
                          onPressed: provider.canUpload
                              ? () => _handleUpload(context)
                              : null,
                        ),
                        ToolbarAction(
                          icon: FontAwesomeIcons.download,
                          tooltip: 'Download',
                          variant: ButtonVariant.primary,
                          onPressed: provider.canDownload
                              ? () => provider.triggerDownload()
                              : null,
                        ),
                        ToolbarAction(
                          icon: FontAwesomeIcons.userGroup,
                          tooltip: 'Teams',
                          variant: ButtonVariant.secondary,
                          onPressed: provider.canOpenTeam
                              ? () => provider.triggerTeamWidget()
                              : null,
                        ),
                      ],
                      toolbarTrailing: const [
                        TypeFilterButton(),
                        SizedBox(width: 8),
                        ToolbarSearchField(),
                      ],
                      activeContent: const TreeView(),
                      emptyIcon: FontAwesomeIcons.folderOpen,
                      emptyMessage: 'No projects yet',
                      emptyDetail: 'Ask the AI to create a project',
                      onRetry: () => provider.loadTree(),
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
                title: 'Upload complete',
                message: 'experiment_data.csv uploaded successfully.',
              ),
            ),
            const SizedBox(height: 4),
            _DevDot(
              color: const Color(0xFF0E7490),
              tooltip: 'Info notification',
              onTap: () => showAppSnackbar(
                context,
                type: SnackbarType.info,
                title: 'Sync started',
                message: 'Pulling latest changes from GitHub...',
              ),
            ),
            const SizedBox(height: 4),
            _DevDot(
              color: const Color(0xFFB45309),
              tooltip: 'Warning notification',
              onTap: () => showAppSnackbar(
                context,
                type: SnackbarType.warning,
                title: 'Large file',
                message: 'dataset.parquet exceeds 100 MB. Upload may be slow.',
              ),
            ),
            const SizedBox(height: 4),
            _DevDot(
              color: const Color(0xFFB91C1C),
              tooltip: 'Error notification',
              onTap: () => showAppSnackbar(
                context,
                type: SnackbarType.error,
                title: 'Upload failed',
                message: 'Permission denied. You do not have write access.',
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
