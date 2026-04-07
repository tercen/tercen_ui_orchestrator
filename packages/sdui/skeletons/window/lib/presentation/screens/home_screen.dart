import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_line_weights.dart';
import '../../domain/models/content_state.dart';
import '../providers/window_state_provider.dart';
import '../widgets/toolbar_search_field.dart';
import '../widgets/window_shell.dart';
import '../widgets/window_toolbar.dart';

/// Demo screen that wires the WindowShell with placeholder toolbar
/// actions, a search field, and a state-cycle button for testing all
/// four body states.
///
/// Replace this with your window type's screen.
///
/// This demo uses [showToolbar: false] on WindowShell and renders a
/// custom [WindowToolbar] with a trailing [ToolbarSearchField] to
/// demonstrate the search field pattern. In a real window, if you don't
/// need a trailing widget you can use the default WindowShell toolbar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Start in empty state — press "Load" in the toolbar to trigger loading.
  }

  void _cycleState() {
    final provider = context.read<WindowStateProvider>();
    final states = ContentState.values;
    final next =
        states[(provider.contentState.index + 1) % states.length];
    if (next == ContentState.loading) {
      provider.loadData();
    } else {
      provider.setContentState(next);
    }
  }

  List<ToolbarAction> get _toolbarActions => [
        ToolbarAction(
          icon: FontAwesomeIcons.play,
          tooltip: 'Load data',
          isPrimary: true,
          onPressed: () =>
              context.read<WindowStateProvider>().loadData(),
        ),
        ToolbarAction(
          icon: FontAwesomeIcons.stop,
          tooltip: 'Stop',
        ),
        ToolbarAction(
          icon: FontAwesomeIcons.plus,
          tooltip: 'Add item',
        ),
        ToolbarAction(
          icon: FontAwesomeIcons.fileExport,
          tooltip: 'Export',
          label: 'Export',
        ),
        ToolbarAction(
          icon: FontAwesomeIcons.arrowsRotate,
          tooltip: 'Cycle body state',
          onPressed: _cycleState,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: WindowConstants.minWidgetWidth,
        ),
        child: Container(
          color: isDark
              ? const Color(0xFF181A20)
              : Colors.white,
          child: Column(
            children: [
              // Custom toolbar with trailing search field.
              WindowToolbar(
                actions: _toolbarActions,
                trailing: ToolbarSearchField(
                  hintText: 'Search items...',
                  onChanged: (value) {
                    // Demo: search callback — wire to provider in real usage.
                    debugPrint('Search: $value');
                  },
                ),
              ),
              Divider(
                height: AppLineWeights.lineSubtle,
                thickness: AppLineWeights.lineSubtle,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
              // WindowShell with toolbar hidden (we rendered it above).
              Expanded(
                child: WindowShell(
                  showToolbar: false,
                  emptyIcon: FontAwesomeIcons.boxOpen,
                  emptyMessage: 'No content loaded',
                  emptyDetail:
                      'Press the play button in the toolbar to load data',
                  emptyActionLabel: 'Load Data',
                  onEmptyAction: () =>
                      context.read<WindowStateProvider>().loadData(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
