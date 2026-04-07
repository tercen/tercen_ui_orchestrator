import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../theme/sdui_theme.dart';
import 'window_state.dart';

/// Title bar and controls for a floating window.
class WindowChrome extends StatelessWidget {
  final WindowState state;
  final SduiTheme theme;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onFocus;
  final Widget child;

  const WindowChrome({
    super.key,
    required this.state,
    required this.theme,
    required this.onClose,
    required this.onMinimize,
    required this.onFocus,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: theme.colors.border),
        boxShadow: [
          BoxShadow(
            color: theme.colors.scrim.withAlpha(theme.opacity.medium),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTitleBar(),
          Expanded(
            child: ClipRRect(
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(theme.radius.md)),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar() {
    return GestureDetector(
      onTap: onFocus,
      child: Container(
        height: theme.window.toolbarHeight,
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
        decoration: BoxDecoration(
          color: theme.colors.surfaceVariant,
          borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radius.md)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                state.title ?? state.content.type,
                style: theme.textStyles.bodySmall.toTextStyle(color: theme.colors.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _chromeButton(FontAwesomeIcons.minus, onMinimize),
            SizedBox(width: theme.spacing.xs),
            _chromeButton(FontAwesomeIcons.xmark, onClose),
          ],
        ),
      ),
    );
  }

  Widget _chromeButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.radius.sm),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.xs),
        child: Icon(icon, size: theme.window.toolbarButtonIconSize, color: theme.colors.onSurfaceMuted),
      ),
    );
  }
}
