import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/window_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_line_weights.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/models/edit_mode.dart';
import '../providers/document_provider.dart';
import 'link_dialog.dart';
import 'image_dialog.dart';
import 'format_popover.dart';
import 'print_helper.dart';

/// Custom toolbar for the document editor.
///
/// Source mode: [Source | Rendered] ... [Save]
/// Rendered mode: [Source | Rendered] | formatting groups | ... [Save]
/// Narrow rendered: [Source | Rendered] [Format] ... [Save]
class DocumentToolbar extends StatelessWidget {
  const DocumentToolbar({super.key});

  /// Threshold width below which formatting buttons collapse into a popover.
  static const double _collapseThreshold = 680.0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doc = provider.document;
    final isMarkdown = doc?.isMarkdown ?? false;
    final isSourceMode = provider.editMode == EditMode.source;

    return Container(
      height: WindowConstants.toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < _collapseThreshold;

          return Row(
            children: [
              // Save button (leading).
              _SaveButton(
                isDirty: provider.isDirty,
                isSaving: provider.isSaving,
                onSave: () => provider.save(),
              ),

              // Mode toggle segmented button (markdown files only).
              if (isMarkdown) ...[
                const SizedBox(width: WindowConstants.toolbarGap),
                _ModeToggle(
                  editMode: provider.editMode,
                  onChanged: (mode) => provider.setEditMode(mode),
                ),
              ],

              // Formatting controls (source mode only, markdown files only).
              if (isSourceMode && isMarkdown) ...[
                if (isNarrow) ...[
                  const SizedBox(width: WindowConstants.toolbarGap),
                  _FormatPopoverButton(provider: provider),
                ] else ...[
                  _ToolbarSeparator(),
                  ..._buildFormattingControls(context, provider, isDark),
                ],
              ],

              const Spacer(),

              // Print button (trailing).
              _FormattingButton(
                icon: FontAwesomeIcons.print,
                tooltip: 'Print',
                onPressed: () {
                  final p = provider;
                  final d = p.document;
                  if (d == null) return;
                  if (d.isMarkdown) {
                    PrintHelper.printMarkdown(p.content, d.name);
                  } else {
                    PrintHelper.printPlainText(p.content, d.name);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildFormattingControls(
    BuildContext context,
    DocumentProvider provider,
    bool isDark,
  ) {
    return [
      // Text group: Bold, Italic, Strikethrough.
      _FormattingButton(
        icon: FontAwesomeIcons.bold,
        tooltip: 'Bold',
        isActive: provider.isBoldActive,
        onPressed: () => provider.wrapSelection('**', '**'),
      ),
      _FormattingButton(
        icon: FontAwesomeIcons.italic,
        tooltip: 'Italic',
        isActive: provider.isItalicActive,
        onPressed: () => provider.wrapSelection('*', '*'),
      ),
      _FormattingButton(
        icon: FontAwesomeIcons.strikethrough,
        tooltip: 'Strikethrough',
        isActive: provider.isStrikethroughActive,
        onPressed: () => provider.wrapSelection('~~', '~~'),
      ),
      _ToolbarSeparator(),

      // Headings group.
      _HeadingButton(
        level: 1,
        isActive: provider.activeHeadingLevel == 1,
        onPressed: () => provider.prefixLine('# '),
      ),
      _HeadingButton(
        level: 2,
        isActive: provider.activeHeadingLevel == 2,
        onPressed: () => provider.prefixLine('## '),
      ),
      _HeadingButton(
        level: 3,
        isActive: provider.activeHeadingLevel == 3,
        onPressed: () => provider.prefixLine('### '),
      ),
      _ToolbarSeparator(),

      // Lists group.
      _FormattingButton(
        icon: FontAwesomeIcons.listUl,
        tooltip: 'Bullet List',
        isActive: provider.isBulletListActive,
        onPressed: () => provider.prefixLine('- '),
      ),
      _FormattingButton(
        icon: FontAwesomeIcons.listOl,
        tooltip: 'Numbered List',
        isActive: provider.isNumberedListActive,
        onPressed: () => provider.prefixLine('1. '),
      ),
      _ToolbarSeparator(),

      // Insert group: Link, Image, Code, Code Block.
      _FormattingButton(
        icon: FontAwesomeIcons.link,
        tooltip: 'Insert Link',
        onPressed: () => _showLinkDialog(context, provider),
      ),
      _FormattingButton(
        icon: FontAwesomeIcons.image,
        tooltip: 'Insert Image',
        onPressed: () => _showImageDialog(context, provider),
      ),
      _FormattingButton(
        icon: FontAwesomeIcons.code,
        tooltip: 'Inline Code',
        onPressed: () => provider.wrapSelection('`', '`'),
      ),
      _ToolbarSeparator(),

      // Divider group.
      _FormattingButton(
        icon: FontAwesomeIcons.minus,
        tooltip: 'Horizontal Rule',
        onPressed: () => provider.insertAtCursor('\n---\n'),
      ),
    ];
  }

  void _showLinkDialog(BuildContext context, DocumentProvider provider) {
    final selectedText = provider.getSelectedText();
    showDialog(
      context: context,
      builder: (ctx) => LinkDialog(
        initialText: selectedText,
        onInsert: (url, text) {
          provider.insertAtCursor('[$text]($url)');
        },
      ),
    );
  }

  void _showImageDialog(BuildContext context, DocumentProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => ImageDialog(
        onInsert: (url, size) {
          final alt = 'image';
          // Size hints as HTML comments for Phase 2 mock.
          final sizeHint = size != 'Medium' ? ' <!-- size: $size -->' : '';
          provider.insertAtCursor('![$alt]($url)$sizeHint');
        },
      ),
    );
  }
}

// ── Mode Toggle ──────────────────────────────────────────────────────────────

/// Custom two-segment toggle built to Tercen style guide specs.
///
/// Exactly `toolbarButtonSize` (32px) tall including border.
/// Selected: primary fill, white icon. Unselected: transparent, primary icon.
class _ModeToggle extends StatefulWidget {
  final EditMode editMode;
  final ValueChanged<EditMode> onChanged;

  const _ModeToggle({required this.editMode, required this.onChanged});

  @override
  State<_ModeToggle> createState() => _ModeToggleState();
}

class _ModeToggleState extends State<_ModeToggle> {
  bool _editHovered = false;
  bool _viewHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final hoverBg = isDark ? AppColorsDark.primarySurface : AppColors.primarySurface;
    final selectedFg = isDark ? Colors.black : Colors.white;
    const double size = WindowConstants.toolbarButtonSize;
    const double iconSize = WindowConstants.toolbarButtonIconSize;
    const double radius = WindowConstants.toolbarButtonRadius;

    final editSelected = widget.editMode == EditMode.source;
    final viewSelected = widget.editMode == EditMode.rendered;

    return Container(
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Edit segment
          _segment(
            icon: FontAwesomeIcons.code,
            tooltip: 'Edit',
            isSelected: editSelected,
            isHovered: _editHovered,
            onTap: () => widget.onChanged(EditMode.source),
            onHover: (h) => setState(() => _editHovered = h),
            primary: primary,
            selectedFg: selectedFg,
            hoverBg: hoverBg,
            iconSize: iconSize,
          ),
          // Divider
          Container(width: 1, color: borderColor),
          // View segment
          _segment(
            icon: FontAwesomeIcons.book,
            tooltip: 'View',
            isSelected: viewSelected,
            isHovered: _viewHovered,
            onTap: () => widget.onChanged(EditMode.rendered),
            onHover: (h) => setState(() => _viewHovered = h),
            primary: primary,
            selectedFg: selectedFg,
            hoverBg: hoverBg,
            iconSize: iconSize,
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required bool isHovered,
    required VoidCallback onTap,
    required ValueChanged<bool> onHover,
    required Color primary,
    required Color selectedFg,
    required Color hoverBg,
    required double iconSize,
  }) {
    final bg = isSelected
        ? primary
        : isHovered
            ? hoverBg
            : Colors.transparent;
    final fg = isSelected ? selectedFg : primary;

    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: bg,
            child: Center(
              child: FaIcon(icon, size: iconSize, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Formatting Button ────────────────────────────────────────────────────────

class _FormattingButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isActive;

  const _FormattingButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.isActive = false,
  });

  @override
  State<_FormattingButton> createState() => _FormattingButtonState();
}

class _FormattingButtonState extends State<_FormattingButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = widget.onPressed == null;

    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final disabledColor =
        isDark ? AppColorsDark.neutral600 : AppColors.neutral400;
    final hoverBg = isDark
        ? AppColorsDark.primarySurface
        : AppColors.primarySurface;

    final isActive = widget.isActive;
    final activeBg = isDark
        ? AppColorsDark.primarySurface
        : AppColors.primarySurface;

    final iconColor = disabled ? disabledColor : primary;
    final bg = isActive
        ? activeBg
        : (!disabled && _hovered)
            ? hoverBg
            : Colors.transparent;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor:
            disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: disabled ? null : (_) => setState(() => _hovered = true),
        onExit: disabled ? null : (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: disabled ? null : widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: WindowConstants.toolbarButtonSize,
            height: WindowConstants.toolbarButtonSize,
            decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  BorderRadius.circular(WindowConstants.toolbarButtonRadius),
            ),
            child: Center(
              child: FaIcon(widget.icon, size: WindowConstants.toolbarButtonIconSize, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Heading Button (icon + level number) ─────────────────────────────────────

class _HeadingButton extends StatefulWidget {
  final int level;
  final VoidCallback? onPressed;
  final bool isActive;

  const _HeadingButton({required this.level, this.onPressed, this.isActive = false});

  @override
  State<_HeadingButton> createState() => _HeadingButtonState();
}

class _HeadingButtonState extends State<_HeadingButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final hoverBg = isDark
        ? AppColorsDark.primarySurface
        : AppColors.primarySurface;
    final activeBg = isDark
        ? AppColorsDark.primarySurface
        : AppColors.primarySurface;
    final bg = widget.isActive
        ? activeBg
        : _hovered
            ? hoverBg
            : Colors.transparent;

    return Tooltip(
      message: 'Heading ${widget.level}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: WindowConstants.toolbarButtonSize,
            height: WindowConstants.toolbarButtonSize,
            decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  BorderRadius.circular(WindowConstants.toolbarButtonRadius),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(FontAwesomeIcons.heading, size: 13, color: primary),
                  Text(
                    '${widget.level}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Toolbar Separator ────────────────────────────────────────────────────────

class _ToolbarSeparator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: AppLineWeights.lineSubtle,
        height: 24,
        color: color,
      ),
    );
  }
}

// ── Format Popover Button (collapsed toolbar for narrow windows) ─────────────

class _FormatPopoverButton extends StatefulWidget {
  final DocumentProvider provider;

  const _FormatPopoverButton({required this.provider});

  @override
  State<_FormatPopoverButton> createState() => _FormatPopoverButtonState();
}

class _FormatPopoverButtonState extends State<_FormatPopoverButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final hoverBg = isDark
        ? AppColorsDark.primarySurface
        : AppColors.primarySurface;
    final borderColor = primary;
    final bg = _hovered ? hoverBg : Colors.transparent;

    return Tooltip(
      message: 'Formatting',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => _showFormatPopover(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: WindowConstants.toolbarButtonSize,
            height: WindowConstants.toolbarButtonSize,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(
                color: borderColor,
                width: AppLineWeights.lineStandard,
              ),
              borderRadius:
                  BorderRadius.circular(WindowConstants.toolbarButtonRadius),
            ),
            child: Center(
              child: FaIcon(
                FontAwesomeIcons.penToSquare,
                size: WindowConstants.toolbarButtonIconSize,
                color: primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFormatPopover(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => FormatPopover(provider: widget.provider),
    );
  }
}

// ── Save Button ──────────────────────────────────────────────────────────────

class _SaveButton extends StatefulWidget {
  final bool isDirty;
  final bool isSaving;
  final VoidCallback onSave;

  const _SaveButton({
    required this.isDirty,
    required this.isSaving,
    required this.onSave,
  });

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = !widget.isDirty || widget.isSaving;

    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final disabledColor =
        isDark ? AppColorsDark.neutral600 : AppColors.neutral400;
    final disabledBorder =
        isDark ? AppColorsDark.neutral600 : AppColors.neutral300;
    final onPrimary = isDark ? Colors.black : Colors.white;
    final hoverPrimaryBg = isDark
        ? AppColorsDark.primary.withValues(alpha: 0.85)
        : AppColors.primary.withValues(alpha: 0.85);

    // When dirty: primary filled button. When clean/disabled: ghost style.
    final isDirtyAndEnabled = !disabled;
    final fg = disabled ? disabledColor : (isDirtyAndEnabled ? onPrimary : primary);
    final border = disabled ? disabledBorder : primary;
    final bg = isDirtyAndEnabled
        ? (_hovered ? hoverPrimaryBg : primary)
        : Colors.transparent;

    return Tooltip(
      message: 'Save',
      child: MouseRegion(
        cursor:
            disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: disabled ? null : (_) => setState(() => _hovered = true),
        onExit: disabled ? null : (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: disabled ? null : widget.onSave,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: WindowConstants.toolbarButtonSize,
            height: WindowConstants.toolbarButtonSize,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(
                color: border,
                width: AppLineWeights.lineStandard,
              ),
              borderRadius:
                  BorderRadius.circular(WindowConstants.toolbarButtonRadius),
            ),
            child: Center(
              child: widget.isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(primary),
                      ),
                    )
                  : FaIcon(
                      FontAwesomeIcons.floppyDisk,
                      size: WindowConstants.toolbarButtonIconSize,
                      color: fg,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
