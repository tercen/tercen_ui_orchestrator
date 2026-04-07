import 'package:flutter/material.dart';
import '../../core/theme/app_line_weights.dart';
import 'window_body.dart';

/// The main layout widget for a Feature Window.
///
/// Structure: optional divider + Body (flex fill).
/// The tab layer is rendered by the Frame — not included here.
///
/// Note: The Document Editor uses a custom toolbar (DocumentToolbar) rendered
/// in HomeScreen, so this shell is available for composition but the
/// HomeScreen uses DocumentToolbar + WindowBody directly.
class WindowShell extends StatelessWidget {
  /// Whether to show the divider at the top.
  final bool showToolbar;

  /// Error state retry callback.
  final VoidCallback? onRetry;

  const WindowShell({
    super.key,
    this.showToolbar = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark
          ? const Color(0xFF181A20)
          : Colors.white,
      child: Column(
        children: [
          if (showToolbar)
            Divider(
              height: AppLineWeights.lineSubtle,
              thickness: AppLineWeights.lineSubtle,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          Expanded(
            child: WindowBody(
              onRetry: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}
