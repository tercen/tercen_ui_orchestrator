import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../theme/sdui_theme.dart';

/// Data for a single tab in the pane tab strip.
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

/// Production pane chrome: tab strip + content container.
///
/// Visual rules:
/// - Tab strip bg = surface (matches workspace)
/// - Active tab: accent top bar, drop shadow, no bottom border (folder opens into content)
/// - Inactive tabs: normal top/side/bottom borders (sealed off from content)
/// - The empty space to the right of tabs has a bottom border
/// - Pane content has left, right, bottom borders only
class PaneChrome extends StatelessWidget {
  final List<PaneTabData> tabs;
  final int activeIndex;
  final bool isFocused;
  final bool isFloating;
  final SduiTheme theme;
  final ValueChanged<int>? onTabTap;
  final ValueChanged<int>? onTabClose;

  /// Called when a tab is dragged out of this pane (with global position).
  final void Function(PaneTabData tab, Offset globalPosition)? onTabDraggedOut;

  /// Called when an external tab is dropped onto this pane's tab strip.
  final void Function(PaneTabData tab)? onTabDroppedIn;

  /// Called when the pane is dragged from the tab strip empty area.
  final void Function(double dx, double dy)? onPaneDrag;

  /// Called when the pane drag ends (for snap-to-grid).
  final VoidCallback? onPaneDragEnd;

  /// Called when the user clicks "Pop Out" to float the pane.
  final VoidCallback? onPopOut;

  final Widget child;

  const PaneChrome({
    super.key,
    required this.tabs,
    this.activeIndex = 0,
    this.isFocused = true,
    this.isFloating = true,
    required this.theme,
    this.onTabTap,
    this.onTabClose,
    this.onTabDraggedOut,
    this.onTabDroppedIn,
    this.onPaneDrag,
    this.onPaneDragEnd,
    this.onPopOut,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = theme.colors;
    final wt = theme.window;
    final bw = theme.lineWeight.subtle + 0.5; // heavier borders (1.5px)

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tab strip row — tabs + trailing border fill
        GestureDetector(
          onPanUpdate: (details) {
            onPaneDrag?.call(details.delta.dx, details.delta.dy);
          },
          onPanEnd: (_) => onPaneDragEnd?.call(),
          child: DragTarget<PaneTabData>(
            onWillAcceptWithDetails: (details) => true,
            onAcceptWithDetails: (details) {
              onTabDroppedIn?.call(details.data);
            },
            builder: (context, candidateData, rejectedData) {
              final isDropTarget = candidateData.isNotEmpty;
              // Stack: full-width bottom border underneath, tabs on top.
              // The active tab's surface background covers the border beneath it.
              return SizedBox(
                height: wt.tabStripHeight,
                child: Stack(
                  children: [
                    // Full-width bottom border line
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: Container(
                        height: bw,
                        color: colors.borderSubtle,
                      ),
                    ),
                    // Tabs row on top
                    Positioned.fill(
                      child: Container(
                        color: isDropTarget ? colors.primaryBg : Colors.transparent,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(tabs.length, (i) {
                              final tab = tabs[i];
                              return _DraggableTab(
                                data: tab,
                                isActive: i == activeIndex,
                                isFocused: isFocused,
                                isFloating: isFloating,
                                theme: theme,
                                borderWidth: bw,
                                canDragOut: tabs.length > 1,
                                onTap: () => onTabTap?.call(i),
                                onClose: () => onTabClose?.call(i),
                                onPopOut: (i == activeIndex && !isFloating) ? onPopOut : null,
                                onDraggedOut: (globalPos) {
                                  onTabDraggedOut?.call(tab, globalPos);
                                },
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Content area with left, right, bottom borders
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                left: BorderSide(color: colors.borderSubtle, width: bw),
                right: BorderSide(color: colors.borderSubtle, width: bw),
                bottom: BorderSide(color: colors.borderSubtle, width: bw),
              ),
              boxShadow: isFloating
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(theme.opacity.medium),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// A draggable tab in the pane chrome.
class _DraggableTab extends StatefulWidget {
  final PaneTabData data;
  final bool isActive;
  final bool isFocused;
  final bool isFloating;
  final SduiTheme theme;
  final double borderWidth;
  final bool canDragOut;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final VoidCallback? onPopOut;
  final void Function(Offset globalPosition)? onDraggedOut;

  const _DraggableTab({
    required this.data,
    required this.isActive,
    required this.isFocused,
    this.isFloating = false,
    required this.theme,
    required this.borderWidth,
    this.canDragOut = true,
    this.onTap,
    this.onClose,
    this.onPopOut,
    this.onDraggedOut,
  });

  @override
  State<_DraggableTab> createState() => _DraggableTabState();
}

class _DraggableTabState extends State<_DraggableTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.theme.colors;
    final wt = widget.theme.window;
    final bw = widget.borderWidth;

    final fontWeight = !widget.isActive
        ? FontWeight.w400
        : widget.isFocused
            ? FontWeight.w700
            : FontWeight.w500;

    final textColor = widget.isActive
        ? (widget.isFocused ? colors.onSurface : colors.onSurfaceVariant)
        : (_hovered ? colors.onSurfaceVariant : colors.onSurfaceMuted);

    final backgroundColor = widget.isActive
        ? colors.surface
        : (_hovered ? colors.surfaceContainerHigh : Colors.transparent);

    // Active+focused: accent color top bar. Inactive: normal border top.
    final topBorder = (widget.isActive && widget.isFocused)
        ? BorderSide(color: colors.primary, width: widget.theme.lineWeight.emphasis)
        : BorderSide(color: colors.borderSubtle, width: bw);

    // Active tab: drop shadow for raised look
    final tabShadow = (widget.isActive && widget.isFocused)
        ? [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ]
        : null;

    final tabContent = Container(
      constraints: BoxConstraints(
        maxWidth: wt.tabMaxWidth,
        minWidth: 80,
      ),
      height: wt.tabStripHeight,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: topBorder,
          left: BorderSide(color: colors.borderSubtle, width: bw),
          right: BorderSide(color: colors.borderSubtle, width: bw),
          // Active tab: no bottom border (content visible below — folder effect)
          // Inactive tab: bottom border (content hidden behind active tab)
          bottom: widget.isActive
              ? BorderSide.none
              : BorderSide(color: colors.borderSubtle, width: bw),
        ),
        boxShadow: tabShadow,
      ),
      padding: EdgeInsets.symmetric(horizontal: widget.theme.spacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color square
          Container(
            width: wt.tabIconSize,
            height: wt.tabIconSize,
            decoration: BoxDecoration(
              color: widget.data.typeColor,
              borderRadius: BorderRadius.circular(wt.tabIconRadius),
            ),
          ),
          SizedBox(width: widget.theme.spacing.xs),
          // Title
          Flexible(
            child: Text(
              widget.data.title,
              style: TextStyle(
                fontSize: wt.tabFontSize,
                fontWeight: fontWeight,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          SizedBox(width: widget.theme.spacing.xs),
          // Pop-out button (inside active tab, before close)
          if (widget.onPopOut != null)
            _TabActionButton(
              theme: widget.theme,
              icon: FontAwesomeIcons.upRightFromSquare,
              tooltip: 'Pop Out',
              onTap: widget.onPopOut!,
            ),
          // Close button
          _TabActionButton(
            theme: widget.theme,
            icon: FontAwesomeIcons.xmark,
            tooltip: 'Close',
            onTap: widget.onClose ?? () {},
            hoverColor: colors.errorContainer,
            hoverIconColor: colors.error,
          ),
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Draggable<PaneTabData>(
        data: widget.data,
        feedback: Opacity(
          opacity: 0.75,
          child: Material(
            elevation: 8,
            child: Container(
              width: 220,
              height: 140,
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: wt.tabStripHeight,
                    color: colors.surface,
                    padding: EdgeInsets.symmetric(
                        horizontal: widget.theme.spacing.sm),
                    child: Row(
                      children: [
                        Container(
                          width: wt.tabIconSize,
                          height: wt.tabIconSize,
                          decoration: BoxDecoration(
                            color: widget.data.typeColor,
                            borderRadius:
                                BorderRadius.circular(wt.tabIconRadius),
                          ),
                        ),
                        SizedBox(width: widget.theme.spacing.xs),
                        Flexible(
                          child: Text(
                            widget.data.title,
                            style: TextStyle(
                              fontSize: wt.tabFontSize,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: widget.theme.lineWeight.subtle,
                    color: colors.borderSubtle,
                  ),
                  Expanded(
                    child: Container(
                      color: colors.surface,
                      child: Center(
                        child: Icon(
                          Icons.drag_indicator,
                          color: colors.onSurfaceMuted,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: tabContent,
        ),
        onDragEnd: (details) {
          if (!details.wasAccepted && widget.canDragOut) {
            widget.onDraggedOut?.call(details.offset);
          }
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: tabContent,
        ),
      ),
    );
  }
}

/// Reusable small icon button for use inside pane tabs (pop-out, close, etc).
class _TabActionButton extends StatefulWidget {
  final SduiTheme theme;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? hoverColor;
  final Color? hoverIconColor;

  const _TabActionButton({
    required this.theme,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.hoverColor,
    this.hoverIconColor,
  });

  @override
  State<_TabActionButton> createState() => _TabActionButtonState();
}

class _TabActionButtonState extends State<_TabActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.theme.colors;
    final wt = widget.theme.window;
    final defaultHoverBg = colors.surfaceContainerHigh;
    final defaultHoverIcon = colors.onSurface;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: wt.tabButtonSize,
            height: wt.tabButtonSize,
            decoration: BoxDecoration(
              color: _hovered
                  ? (widget.hoverColor ?? defaultHoverBg)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(wt.tabIconRadius),
            ),
            child: Center(
              child: FaIcon(
                widget.icon,
                size: wt.tabButtonIconSize,
                color: _hovered
                    ? (widget.hoverIconColor ?? defaultHoverIcon)
                    : colors.onSurfaceMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
