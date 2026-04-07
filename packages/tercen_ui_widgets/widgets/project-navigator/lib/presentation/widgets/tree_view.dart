import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_line_weights.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/tree_node.dart';
import '../providers/navigator_provider.dart';

/// The scrollable tree view that displays the navigator hierarchy.
class TreeView extends StatefulWidget {
  const TreeView({super.key});

  @override
  State<TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends State<TreeView> {
  final FocusNode _treeFocusNode = FocusNode();

  /// Flat list of visible node IDs for keyboard navigation.
  List<String> _visibleNodeIds = [];
  int _focusedIndex = -1;

  @override
  void dispose() {
    _treeFocusNode.dispose();
    super.dispose();
  }

  void _buildVisibleList(List<TreeNode> nodes, NavigatorProvider provider) {
    _visibleNodeIds = [];
    _collectVisible(nodes, provider);
  }

  void _collectVisible(List<TreeNode> nodes, NavigatorProvider provider) {
    for (final node in nodes) {
      _visibleNodeIds.add(node.id);
      if (node.isBranch && provider.isExpanded(node.id)) {
        _collectVisible(node.children, provider);
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final provider = context.read<NavigatorProvider>();

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_focusedIndex < _visibleNodeIds.length - 1) {
        _focusedIndex++;
        final targetId = _visibleNodeIds[_focusedIndex];
        final targetNode = _findNodeById(targetId, provider.filteredTree);
        if (targetNode != null) {
          provider.selectNode(targetNode);
        }
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_focusedIndex > 0) {
        _focusedIndex--;
        final targetId = _visibleNodeIds[_focusedIndex];
        final targetNode = _findNodeById(targetId, provider.filteredTree);
        if (targetNode != null) {
          provider.selectNode(targetNode);
        }
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_focusedIndex >= 0 && _focusedIndex < _visibleNodeIds.length) {
        final targetId = _visibleNodeIds[_focusedIndex];
        final targetNode = _findNodeById(targetId, provider.filteredTree);
        if (targetNode != null) {
          if (targetNode.isBranch) {
            provider.toggleExpanded(targetNode.id);
          } else {
            provider.openViewer(targetNode);
          }
        }
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  TreeNode? _findNodeById(String id, List<TreeNode> nodes) {
    for (final node in nodes) {
      if (node.id == id) return node;
      if (node.children.isNotEmpty) {
        final found = _findNodeById(id, node.children);
        if (found != null) return found;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NavigatorProvider>();
    final filteredTree = provider.filteredTree;

    _buildVisibleList(filteredTree, provider);

    // Update focused index based on selection
    if (provider.selectedNodeId != null) {
      final idx = _visibleNodeIds.indexOf(provider.selectedNodeId!);
      if (idx >= 0) _focusedIndex = idx;
    }

    return Focus(
      focusNode: _treeFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () => _treeFocusNode.requestFocus(),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          children: [
            for (final node in filteredTree)
              _buildNodeTile(context, node, provider, 0),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeTile(
    BuildContext context,
    TreeNode node,
    NavigatorProvider provider,
    int depth,
  ) {
    final isExpanded = provider.isExpanded(node.id);
    final isSelected = provider.selectedNodeId == node.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _TreeNodeRow(
          node: node,
          depth: depth,
          isExpanded: isExpanded,
          isSelected: isSelected,
          onTap: () {
            // All branch nodes: toggle expand AND set focus
            if (node.isBranch) {
              provider.toggleExpanded(node.id);
            }
            provider.selectNode(node);
          },
          onDoubleTap: node.isLeaf ? () => provider.openViewer(node) : null,
          onChevronTap:
              node.isBranch ? () => provider.toggleExpanded(node.id) : null,
        ),
        if (isExpanded && node.children.isNotEmpty)
          for (final child in node.children)
            _buildNodeTile(context, child, provider, depth + 1),
      ],
    );
  }
}

/// A single row in the tree view.
class _TreeNodeRow extends StatefulWidget {
  final TreeNode node;
  final int depth;
  final bool isExpanded;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onChevronTap;

  const _TreeNodeRow({
    required this.node,
    required this.depth,
    required this.isExpanded,
    required this.isSelected,
    required this.onTap,
    this.onDoubleTap,
    this.onChevronTap,
  });

  @override
  State<_TreeNodeRow> createState() => _TreeNodeRowState();
}

class _TreeNodeRowState extends State<_TreeNodeRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final node = widget.node;

    // Row colours
    Color? bgColor;
    if (widget.isSelected) {
      bgColor = isDark
          ? AppColorsDark.primarySurface.withValues(alpha: 0.3)
          : AppColors.primaryBg;
    } else if (_hovered) {
      bgColor = isDark
          ? AppColorsDark.neutral800.withValues(alpha: 0.5)
          : AppColors.neutral100;
    }

    // Left accent border for selected row
    final leftBorder = widget.isSelected
        ? Border(
            left: BorderSide(
              color: isDark ? AppColorsDark.primary : AppColors.primary,
              width: AppLineWeights.lineEmphasis,
            ),
          )
        : null;

    // Indentation: 20px per depth level + 4px base
    final indent = AppSpacing.xs + (widget.depth * 20.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: leftBorder,
          ),
          padding: EdgeInsets.only(
            left: indent,
            right: AppSpacing.sm,
            top: 3.0,
            bottom: 3.0,
          ),
          child: Row(
            children: [
              // Chevron
              _buildChevron(isDark),
              const SizedBox(width: AppSpacing.xs),
              // Type icon
              _buildTypeIcon(isDark),
              const SizedBox(width: AppSpacing.sm),
              // Name
              Flexible(
                child: Text(
                  node.name,
                  style: AppTextStyles.body.copyWith(
                    color: isDark
                        ? AppColorsDark.textPrimary
                        : AppColors.textPrimary,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              // Status indicators (project only)
              if (node.nodeType == NodeType.project) ...[
                ..._buildProjectIndicators(isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChevron(bool isDark) {
    final node = widget.node;
    if (node.isLeaf) {
      return const SizedBox(width: 16);
    }

    return GestureDetector(
      onTap: widget.onChevronTap,
      child: SizedBox(
        width: 16,
        height: 16,
        child: Icon(
          widget.isExpanded
              ? FontAwesomeIcons.chevronDown
              : FontAwesomeIcons.chevronRight,
          size: 10,
          color: isDark ? AppColorsDark.textMuted : AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildTypeIcon(bool isDark) {
    final node = widget.node;
    final IconData icon;
    final Color color;

    switch (node.nodeType) {
      case NodeType.team:
        icon = FontAwesomeIcons.userGroup;
        color = isDark ? AppColorsDark.primary : AppColors.primary;
        break;
      case NodeType.project:
        icon = FontAwesomeIcons.solidFolder;
        color = isDark ? AppColorsDark.primary : AppColors.primary;
        break;
      case NodeType.folder:
        icon = FontAwesomeIcons.folderOpen;
        color = isDark ? AppColorsDark.primary : AppColors.primary;
        break;
      case NodeType.file:
        switch (node.fileCategory) {
          case FileCategory.zip:
            icon = FontAwesomeIcons.fileZipper;
            break;
          case FileCategory.image:
            icon = FontAwesomeIcons.image;
            break;
          case FileCategory.generic:
            icon = FontAwesomeIcons.file;
            break;
        }
        color = isDark ? AppColorsDark.neutral300 : AppColors.neutral700;
        break;
      case NodeType.dataset:
        icon = FontAwesomeIcons.table;
        color = isDark ? AppColorsDark.warning : AppColors.warning;
        break;
      case NodeType.workflow:
        icon = FontAwesomeIcons.sitemap;
        color = isDark ? AppColorsDark.info : AppColors.info;
        break;
    }

    return FaIcon(icon, size: 14, color: color);
  }

  List<Widget> _buildProjectIndicators(bool isDark) {
    final node = widget.node;
    final indicators = <Widget>[];

    // GitHub chip — FIRST
    if (node.githubUrl != null && node.gitVersion != null) {
      indicators.add(const SizedBox(width: AppSpacing.sm));
      indicators.add(
        Tooltip(
          message: node.githubUrl!,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColorsDark.neutral700
                    : AppColors.neutral200,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(
                    FontAwesomeIcons.github,
                    size: 12,
                    color: isDark
                        ? AppColorsDark.textTertiary
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    node.gitVersion!,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      color: isDark
                          ? AppColorsDark.textTertiary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Public icon — SECOND
    if (node.isPublic) {
      indicators.add(const SizedBox(width: AppSpacing.sm));
      indicators.add(
        Tooltip(
          message: 'Public',
          child: FaIcon(
            FontAwesomeIcons.globe,
            size: 12,
            color: isDark
                ? AppColorsDark.neutral400
                : AppColors.neutral500,
          ),
        ),
      );
    }

    return indicators;
  }
}
