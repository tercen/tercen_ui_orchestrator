import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/models/chat_session.dart';
import '../providers/chat_provider.dart';

/// History popover button that shows a dropdown of past chat sessions
/// with a search field at the top for filtering.
///
/// Uses a custom overlay instead of PopupMenuButton to support
/// the pinned search field inside the dropdown.
class HistoryPopoverButton extends StatefulWidget {
  const HistoryPopoverButton({super.key});

  @override
  State<HistoryPopoverButton> createState() => _HistoryPopoverButtonState();
}

class _HistoryPopoverButtonState extends State<HistoryPopoverButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    _overlayEntry = _buildOverlay();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _close() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  OverlayEntry _buildOverlay() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismiss on tap outside
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
          // The dropdown itself, anchored below the button
          CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 4),
            child: _HistoryDropdown(
              onSelect: (sessionId) {
                _close();
                context.read<ChatProvider>().switchSession(sessionId);
              },
              onDismiss: _close,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColorsDark.primary : AppColors.primary;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: 'Chat History',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: primaryColor, width: 1.5),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Center(
                child: FaIcon(
                  FontAwesomeIcons.comments,
                  size: 16,
                  color: primaryColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dropdown content: search field + scrollable session list.
class _HistoryDropdown extends StatefulWidget {
  final void Function(String sessionId) onSelect;
  final VoidCallback onDismiss;

  const _HistoryDropdown({required this.onSelect, required this.onDismiss});

  @override
  State<_HistoryDropdown> createState() => _HistoryDropdownState();
}

class _HistoryDropdownState extends State<_HistoryDropdown> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<ChatProvider>();
    final currentId = provider.currentSession?.id;
    final bgColor = isDark ? AppColorsDark.surface : AppColors.surface;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final hintColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final dividerColor = isDark
        ? AppColorsDark.borderSubtle.withValues(alpha: 0.5)
        : AppColors.borderSubtle.withValues(alpha: 0.5);

    // Sort by most recent first, then filter by search query
    final sorted = List<ChatSession>.from(provider.sessions)
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    final filtered = _query.isEmpty
        ? sorted
        : sorted
            .where((s) => s.title.toLowerCase().contains(_query))
            .toList();

    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        width: 300,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search field
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: AppTextStyles.body.copyWith(
                    color: isDark
                        ? AppColorsDark.textPrimary
                        : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search sessions...',
                    hintStyle:
                        AppTextStyles.bodySmall.copyWith(color: hintColor),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 4),
                      child: FaIcon(
                        FontAwesomeIcons.magnifyingGlass,
                        size: 16,
                        color: hintColor,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 0,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColorsDark.surfaceElevated
                        : AppColors.panelBackground,
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      borderSide: BorderSide(color: borderColor, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColorsDark.primary
                            : AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              // Divider
              Container(height: 1, color: dividerColor),
              // Session list
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    _query.isEmpty ? 'No chat history' : 'No matching sessions',
                    style: AppTextStyles.bodySmall.copyWith(color: hintColor),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final session = filtered[index];
                      final isActive = session.id == currentId;
                      return _SessionItem(
                        session: session,
                        isActive: isActive,
                        isDark: isDark,
                        onTap: () => widget.onSelect(session.id),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single session row in the history dropdown.
class _SessionItem extends StatefulWidget {
  final ChatSession session;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _SessionItem({
    required this.session,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SessionItem> createState() => _SessionItemState();
}

class _SessionItemState extends State<_SessionItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark
        ? AppColorsDark.textPrimary
        : AppColors.textPrimary;
    final mutedColor = widget.isDark
        ? AppColorsDark.textMuted
        : AppColors.textMuted;
    final activeBg = widget.isDark
        ? AppColorsDark.primaryBg
        : AppColors.primaryBg;
    final hoverBg = widget.isDark
        ? AppColorsDark.surfaceElevated
        : AppColors.panelBackground;

    Color? bg;
    if (widget.isActive) {
      bg = activeBg;
    } else if (_hovered) {
      bg = hoverBg;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.sm + AppSpacing.xs,
          ),
          color: bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.session.title,
                style: AppTextStyles.body.copyWith(
                  color: textColor,
                  fontWeight:
                      widget.isActive ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _relativeTime(widget.session.lastMessageAt),
                style: AppTextStyles.bodySmall.copyWith(
                  color: mutedColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
