import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/header_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/header_state_provider.dart';
import '../providers/theme_provider.dart';

/// Dropdown menu positioned below the user avatar, right-aligned.
/// Contains account-level actions per spec Section 4.4.
class UserDropdownMenu extends StatelessWidget {
  final VoidCallback? onDismiss;

  const UserDropdownMenu({super.key, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HeaderStateProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final bgColor = isDark ? AppColorsDark.surfaceElevated : AppColors.surface;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final textColor = isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final iconColor = isDark ? AppColorsDark.primary : AppColors.primary;
    final hoverColor = isDark ? AppColorsDark.primarySurface : AppColors.primarySurface;
    final dividerColor = isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;

    return Container(
      width: HeaderConstants.dropdownWidth,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Username (non-interactive header)
          _MenuHeader(
            label: provider.userState.displayName,
            textColor: textColor,
          ),

          Divider(height: 1, color: dividerColor),

          // 2. About
          _MenuItem(
            icon: FontAwesomeIcons.circleInfo,
            label: 'About',
            iconColor: iconColor,
            textColor: textColor,
            hoverColor: hoverColor,
            onTap: () { onDismiss?.call(); },
          ),

          // 3. Save this layout
          _MenuItem(
            icon: FontAwesomeIcons.floppyDisk,
            label: 'Save this layout',
            iconColor: iconColor,
            textColor: textColor,
            hoverColor: hoverColor,
            onTap: () { provider.saveLayout(); onDismiss?.call(); },
          ),

          // 4. Light/Dark Mode toggle
          _MenuItem(
            icon: isDark ? FontAwesomeIcons.sun : FontAwesomeIcons.moon,
            label: isDark ? 'Light Mode' : 'Dark Mode',
            iconColor: iconColor,
            textColor: textColor,
            hoverColor: hoverColor,
            onTap: () {
              provider.toggleTheme(
                isDark: isDark,
                onToggle: () => themeProvider.toggleTheme(),
              );
              onDismiss?.call();
            },
          ),

          // 5. Connect an LLM
          _MenuItem(
            icon: FontAwesomeIcons.brain,
            label: 'Connect an LLM',
            iconColor: iconColor,
            textColor: textColor,
            hoverColor: hoverColor,
            onTap: () { provider.openLlmSettings(); onDismiss?.call(); },
          ),

          // 6. Task Manager
          _MenuItem(
            icon: FontAwesomeIcons.listCheck,
            label: 'Task Manager',
            iconColor: iconColor,
            textColor: textColor,
            hoverColor: hoverColor,
            onTap: () { provider.openTaskManager(); onDismiss?.call(); },
          ),

          // 7. Admin (admin only)
          if (provider.userState.isAdmin) ...[
            Divider(height: 1, color: dividerColor),
            _MenuItem(
              icon: FontAwesomeIcons.userGear,
              label: 'Admin',
              iconColor: iconColor,
              textColor: textColor,
              hoverColor: hoverColor,
              onTap: () { provider.openAdminPanel(); onDismiss?.call(); },
            ),
          ],

          // 8. Sign Out
          Divider(height: 1, color: dividerColor),
          _MenuItem(
            icon: FontAwesomeIcons.rightFromBracket,
            label: 'Sign Out',
            iconColor: iconColor,
            textColor: textColor,
            hoverColor: hoverColor,
            onTap: () { provider.signOut(); onDismiss?.call(); },
          ),
        ],
      ),
    );
  }
}

/// Non-interactive header row showing the username.
class _MenuHeader extends StatelessWidget {
  final String label;
  final Color textColor;

  const _MenuHeader({
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.controlHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(
          color: textColor,
          decoration: TextDecoration.none,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// A single menu item row: icon + gap + label.
class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;
  final Color hoverColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
    required this.hoverColor,
    required this.onTap,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: AppSpacing.controlHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          color: _hovered ? widget.hoverColor : Colors.transparent,
          child: Row(
            children: [
              FaIcon(
                widget.icon,
                size: 16,
                color: widget.iconColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppTextStyles.body.copyWith(
                    color: widget.textColor,
                    decoration: TextDecoration.none,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

