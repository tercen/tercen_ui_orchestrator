import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/pane_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/pane_chrome.dart';
import '../widgets/pane_tab_strip.dart';

/// Demo screen showing panes in light and dark modes side by side.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade400,
      body: Row(
        children: [
          // Light mode
          Expanded(
            child: Theme(
              data: AppTheme.light,
              child: const _PaneDemo(label: 'Light Mode'),
            ),
          ),
          const SizedBox(width: 2),
          // Dark mode
          Expanded(
            child: Theme(
              data: AppTheme.dark,
              child: const _PaneDemo(label: 'Dark Mode'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaneDemo extends StatefulWidget {
  final String label;

  const _PaneDemo({required this.label});

  @override
  State<_PaneDemo> createState() => _PaneDemoState();
}

class _PaneDemoState extends State<_PaneDemo> {
  // Widget type colors (from Tercen logo palette)
  static const _chatColor = Color(0xFF1E40AF);
  static const _dataColor = Color(0xFF047857);
  static const _workflowColor = Color(0xFFB45309);
  static const _docColor = Color(0xFF7C3AED);
  static const _auditColor = Color(0xFF0E7490);

  int _focusedPaneIndex = 0;
  int _multiTabActive = 0;
  int _dockedLeftActive = 0;

  @override
  Widget build(BuildContext context) {
    final c = PaneColors.of(context);

    return Container(
      color: c.surface, // workspace uses surface, not background
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Floating panes
          Text(
            'FLOATING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                // Single tab
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _focusedPaneIndex = 0),
                    child: PaneChrome(
                      tabs: const [
                        PaneTabData(id: 'chat', typeColor: _chatColor, title: 'Chat'),
                      ],
                      isFocused: _focusedPaneIndex == 0,
                      isFloating: true,
                      child: _Placeholder(label: _focusedPaneIndex == 0 ? 'Focused' : 'Blurred'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Multi tab
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => setState(() => _focusedPaneIndex = 1),
                    child: PaneChrome(
                      tabs: const [
                        PaneTabData(id: 'data', typeColor: _dataColor, title: 'kinase_data.csv'),
                        PaneTabData(id: 'wf', typeColor: _workflowColor, title: 'Pipeline'),
                        PaneTabData(id: 'audit', typeColor: _auditColor, title: 'Audit Trail'),
                      ],
                      activeIndex: _multiTabActive,
                      isFocused: _focusedPaneIndex == 1,
                      isFloating: true,
                      onTabTap: (i) => setState(() => _multiTabActive = i),
                      onTabClose: (i) => debugPrint('Close tab $i'),
                      child: _Placeholder(label: _focusedPaneIndex == 1 ? 'Focused' : 'Blurred'),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Docked panes
          Text(
            'DOCKED (no shadow, shared borders)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _focusedPaneIndex = 2),
                    child: PaneChrome(
                      tabs: const [
                        PaneTabData(id: 'home', typeColor: _chatColor, title: 'Home'),
                        PaneTabData(id: 'doc', typeColor: _docColor, title: 'README.md'),
                      ],
                      activeIndex: _dockedLeftActive,
                      isFocused: _focusedPaneIndex == 2,
                      isFloating: false,
                      onTabTap: (i) => setState(() => _dockedLeftActive = i),
                      child: _Placeholder(label: _focusedPaneIndex == 2 ? 'Focused' : 'Blurred'),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _focusedPaneIndex = 3),
                    child: PaneChrome(
                      tabs: const [
                        PaneTabData(id: 'chat2', typeColor: _chatColor, title: 'Chat'),
                      ],
                      isFocused: _focusedPaneIndex == 3,
                      isFloating: false,
                      child: _Placeholder(label: _focusedPaneIndex == 3 ? 'Focused' : 'Blurred'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String label;
  const _Placeholder({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = PaneColors.of(context);
    return Center(
      child: Text(label, style: TextStyle(fontSize: 12, color: c.textMuted)),
    );
  }
}
