import 'package:flutter/material.dart';
import '../../core/constants/pane_constants.dart';
import '../../core/theme/app_line_weights.dart';
import '../../core/theme/app_opacity.dart';
import '../../core/theme/pane_colors.dart';
import 'pane_tab_strip.dart';

/// The pane frame: tab strip + content container.
///
/// A pane is a dumb frame. It knows nothing about toolbars, body states,
/// or content structure. Widgets inside provide their own internals.
///
/// Visual principles:
/// - Tab strip blends into workspace (background color)
/// - Active tab connects to content (surface color, no bottom border)
/// - Straight corners (0px radius) for clean stacking
/// - Subtle border (borderSubtle)
/// - No shadow when docked; shadow only when floating
/// - No window-level controls (no maximize/minimize/close)
///
/// Theme-aware: works in both light and dark modes.
class PaneChrome extends StatelessWidget {
  final List<PaneTabData> tabs;
  final int activeIndex;
  final bool isFocused;
  final bool isFloating;
  final ValueChanged<int>? onTabTap;
  final ValueChanged<int>? onTabClose;
  final Widget child;

  const PaneChrome({
    super.key,
    required this.tabs,
    this.activeIndex = 0,
    this.isFocused = true,
    this.isFloating = true,
    this.onTabTap,
    this.onTabClose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = PaneColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(PaneConstants.borderRadius),
        border: Border.all(
          color: c.borderSubtle,
          width: PaneConstants.borderWidth,
        ),
        boxShadow: isFloating
            ? [
                BoxShadow(
                  color: Colors.black.withAlpha(AppOpacity.medium),
                  blurRadius: PaneConstants.shadowBlur,
                  offset: const Offset(0, PaneConstants.shadowOffsetY),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaneTabStrip(
            tabs: tabs,
            activeIndex: activeIndex,
            isFocusedPane: isFocused,
            onTabTap: onTabTap,
            onTabClose: onTabClose,
          ),
          Container(
            height: AppLineWeights.lineSubtle,
            color: c.borderSubtle,
          ),
          Expanded(
            child: Container(
              color: c.surface,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
