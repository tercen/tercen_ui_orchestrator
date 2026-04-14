import 'package:flutter/material.dart';
import '../../core/theme/app_line_weights.dart';
import 'window_toolbar.dart';
import 'window_body.dart';

/// The main layout widget for a Feature Window.
///
/// Structure: Toolbar (48px) + Body (flex fill).
/// The tab layer is rendered by the Frame — not included here.
class WindowShell extends StatelessWidget {
  /// Toolbar action buttons. All left-aligned, no spacer.
  final List<ToolbarAction> toolbarActions;

  /// Whether to show the toolbar. False when hosting an app with its own header.
  final bool showToolbar;

  /// Custom active-state content widget. If null, shows placeholder.
  final Widget? activeContent;

  /// Empty state configuration.
  final IconData emptyIcon;
  final String emptyMessage;
  final String? emptyDetail;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  /// Error state retry callback.
  final VoidCallback? onRetry;

  /// Optional trailing widgets for the toolbar (filter dropdown, search field).
  final List<Widget> toolbarTrailing;

  const WindowShell({
    super.key,
    this.toolbarActions = const [],
    this.showToolbar = true,
    this.activeContent,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyMessage = 'No content',
    this.emptyDetail,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.onRetry,
    this.toolbarTrailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark
          ? const Color(0xFF181A20) // surface dark
          : Colors.white, // surface light
      child: Column(
        children: [
          if (showToolbar)
            WindowToolbar(
              actions: toolbarActions,
              trailing: toolbarTrailing,
            ),
          if (showToolbar)
            Divider(
              height: AppLineWeights.lineSubtle,
              thickness: AppLineWeights.lineSubtle,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          Expanded(
            child: WindowBody(
              activeContent: activeContent,
              emptyIcon: emptyIcon,
              emptyMessage: emptyMessage,
              emptyDetail: emptyDetail,
              emptyActionLabel: emptyActionLabel,
              onEmptyAction: onEmptyAction,
              onRetry: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

/// Button variant per the Tercen style guide.
enum ButtonVariant { primary, secondary, ghost }

/// Describes a single toolbar action button.
class ToolbarAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Visual variant: primary (filled), secondary (outlined), ghost (text-only).
  final ButtonVariant variant;

  /// Optional text label displayed beside the icon.
  final String? label;

  const ToolbarAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.variant = ButtonVariant.ghost,
    this.label,
  });

  /// Convenience getter retained for backward compatibility.
  bool get isPrimary => variant == ButtonVariant.primary;
}
