import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/header_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_line_weights.dart';
import '../../core/theme/app_spacing.dart';
import '../providers/header_state_provider.dart';
import '../providers/theme_provider.dart';
import 'identicon_painter.dart';
import 'user_dropdown_menu.dart';

/// Circular avatar showing a generated identicon for the current user.
/// Clicking opens the user dropdown menu via an Overlay.
class UserAvatar extends StatefulWidget {
  const UserAvatar({super.key});

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _toggleDropdown() {
    if (_overlayEntry != null) {
      _removeDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => _DropdownOverlay(
        layerLink: _layerLink,
        onDismiss: _removeDropdown,
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HeaderStateProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final user = provider.userState;
    final ringColor = isDark ? AppColorsDark.primary : AppColors.primary;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: user.displayName,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _toggleDropdown,
            child: Container(
              width: HeaderConstants.avatarSize,
              height: HeaderConstants.avatarSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: ringColor,
                  width: AppLineWeights.lineEmphasis,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: ClipOval(
                  child: CustomPaint(
                    size: Size.square(HeaderConstants.avatarSize - 6.0),
                    painter: IdenticonPainter(
                      identityString: user.identityString,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The overlay that shows the dropdown and a transparent barrier to dismiss.
class _DropdownOverlay extends StatelessWidget {
  final LayerLink layerLink;
  final VoidCallback onDismiss;

  const _DropdownOverlay({
    required this.layerLink,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Transparent barrier to close on outside tap.
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        // Dropdown positioned below the avatar, right-aligned.
        CompositedTransformFollower(
          link: layerLink,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, AppSpacing.xs),
          child: UserDropdownMenu(onDismiss: onDismiss),
        ),
      ],
    );
  }
}
