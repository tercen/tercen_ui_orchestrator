import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/tab_type_icon.dart';
import '../providers/document_provider.dart';
import '../providers/theme_provider.dart';

/// Mock tab strip rendered above the toolbar (DEV only).
///
/// Shows the current document as the focused tab, with inactive tabs for the
/// other two mock documents. Includes a theme toggle on the trailing edge.
/// Clicking an inactive tab loads that document.
class MockTabStrip extends StatelessWidget {
  const MockTabStrip({super.key});

  // Window 4 = indigo from Tercen logo palette.
  static const Color _typeColor = Color(0xFF6366F1);

  static const _docs = [
    _MockDoc('doc-001', 'analysis-report.md'),
    _MockDoc('doc-002', 'notes.txt'),
    _MockDoc('doc-003', 'pipeline-config.md'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<DocumentProvider>();
    final currentDocId = provider.document?.id;

    final stripBg =
        isDark ? AppColorsDark.surfaceElevated : AppColors.neutral200;
    final tabBg = isDark ? AppColorsDark.surface : AppColors.surface;
    final inactiveTabBg = Colors.transparent;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final inactiveTextColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Container(
      height: WindowConstants.tabStripHeight,
      color: stripBg,
      padding: const EdgeInsets.only(left: AppSpacing.sm, top: 4),
      child: Row(
        children: [
          // Document tabs.
          for (final doc in _docs)
            _buildTab(
              context,
              doc: doc,
              isFocused: doc.id == currentDocId,
              tabBg: tabBg,
              inactiveTabBg: inactiveTabBg,
              textColor: textColor,
              inactiveTextColor: inactiveTextColor,
              provider: provider,
            ),
          const Spacer(),
          // Theme toggle.
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm, bottom: 4),
            child: _ThemeToggle(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required _MockDoc doc,
    required bool isFocused,
    required Color tabBg,
    required Color inactiveTabBg,
    required Color textColor,
    required Color inactiveTextColor,
    required DocumentProvider provider,
  }) {
    return GestureDetector(
      onTap: isFocused
          ? null
          : () => provider.loadDocument(doc.id, 'proj-001'),
      child: MouseRegion(
        cursor: isFocused
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: Container(
          height: WindowConstants.tabHeight,
          constraints: const BoxConstraints(maxWidth: WindowConstants.tabMaxWidth),
          margin: const EdgeInsets.only(right: 2),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isFocused ? tabBg : inactiveTabBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(WindowConstants.tabCornerRadius),
              topRight: Radius.circular(WindowConstants.tabCornerRadius),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabTypeIcon(color: _typeColor),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  doc.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: WindowConstants.tabFontSize,
                    fontWeight: isFocused
                        ? WindowConstants.tabWeightFocused
                        : WindowConstants.tabWeightInactive,
                    color: isFocused ? textColor : inactiveTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockDoc {
  final String id;
  final String name;
  const _MockDoc(this.id, this.name);
}

/// Small sun/moon toggle for the tab strip trailing edge.
class _ThemeToggle extends StatefulWidget {
  @override
  State<_ThemeToggle> createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<_ThemeToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final hoverBg =
        isDark ? AppColorsDark.neutral700 : AppColors.neutral200;

    return Tooltip(
      message: isDark ? 'Switch to light' : 'Switch to dark',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => context.read<ThemeProvider>().toggleTheme(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _hovered ? hoverBg : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: FaIcon(
                isDark ? FontAwesomeIcons.sun : FontAwesomeIcons.moon,
                size: 12,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
