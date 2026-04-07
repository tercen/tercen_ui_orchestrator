import 'package:flutter/material.dart';
import '../../core/constants/pane_constants.dart';
import '../../core/theme/pane_colors.dart';
import 'pane_tab.dart';

/// Tab data for a single tab in a pane.
class PaneTabData {
  final String id;
  final Color typeColor;
  final String title;

  const PaneTabData({
    required this.id,
    required this.typeColor,
    required this.title,
  });
}

/// The tab strip rendered at the top of a pane.
///
/// Contains tabs + empty drag area. No window controls.
/// Background matches workspace (blends in). Active tab background
/// matches content area (surface) for seamless visual connection.
class PaneTabStrip extends StatelessWidget {
  final List<PaneTabData> tabs;
  final int activeIndex;
  final bool isFocusedPane;
  final ValueChanged<int>? onTabTap;
  final ValueChanged<int>? onTabClose;

  const PaneTabStrip({
    super.key,
    required this.tabs,
    this.activeIndex = 0,
    this.isFocusedPane = true,
    this.onTabTap,
    this.onTabClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = PaneColors.of(context);

    return Container(
      height: PaneConstants.tabStripHeight,
      color: c.surface, // matches workspace (surface, not background)
      padding: const EdgeInsets.only(top: 4), // 4px top padding (32 - 28 = 4)
      child: Row(
        children: [
          // Tabs (scrollable if many)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(tabs.length, (i) {
                  final tab = tabs[i];
                  return PaneTab(
                    typeColor: tab.typeColor,
                    title: tab.title,
                    isActive: i == activeIndex,
                    isFocusedPane: isFocusedPane,
                    onTap: () => onTabTap?.call(i),
                    onClose: () => onTabClose?.call(i),
                  );
                }),
              ),
            ),
          ),
          // Empty area is implicit drag handle for the pane
        ],
      ),
    );
  }
}
