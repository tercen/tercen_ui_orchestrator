import 'package:flutter/material.dart' hide StepState;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_line_weights.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/layout_node.dart';
import '../../domain/models/workflow_models.dart';
import '../providers/workflow_provider.dart';

/// Renders a single step node in the flowchart.
///
/// Handles shape rendering, state colour, focus highlight, search highlight,
/// click interactions, hover tooltips, and inline rename.
class FlowchartNode extends StatefulWidget {
  final LayoutNode node;
  final GlobalKey? shapeKey;

  const FlowchartNode({super.key, required this.node, this.shapeKey});

  @override
  State<FlowchartNode> createState() => _FlowchartNodeState();
}

class _FlowchartNodeState extends State<FlowchartNode> {
  bool _hovered = false;
  bool _dragging = false;
  DateTime? _lastClickTime;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkflowProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final node = widget.node;

    final isFocused = provider.focusedNodeId == node.id;
    final isSearchMatch = provider.searchMatches.contains(node.id);
    final isEditing = provider.editingNodeId == node.id;

    // State-based icon colour
    final iconColor = _iconColorForState(node.state, isDark);

    // Shape styling
    final shapeFill = isDark
        ? AppColorsDark.surfaceElevated
        : AppColors.neutral100;
    final shapeBorder = isFocused
        ? (isDark ? AppColorsDark.primary : AppColors.primary)
        : (isDark ? AppColorsDark.border : AppColors.border);
    final shapeBorderWidth = isFocused
        ? AppLineWeights.lineEmphasis
        : AppLineWeights.lineStandard;

    // Search highlight
    final searchHighlightColor = isSearchMatch
        ? (isDark
            ? AppColorsDark.warning.withValues(alpha: 0.3)
            : AppColors.warningLight)
        : null;

    // Hover highlight
    final hoverColor = _hovered && !isFocused
        ? (isDark
            ? AppColorsDark.neutral700
            : AppColors.neutral200)
        : null;

    final effectiveFill =
        searchHighlightColor ?? hoverColor ?? shapeFill;

    Widget shapeWidget;

    switch (node.shape) {
      case NodeShape.circleBadge:
        shapeWidget = _buildCircleBadge(
          iconColor: iconColor,
          fill: effectiveFill,
          borderColor: shapeBorder,
          borderWidth: shapeBorderWidth,
          node: node,
        );
        break;
      case NodeShape.roundedRect:
        shapeWidget = _buildRoundedRect(
          iconColor: iconColor,
          fill: effectiveFill,
          borderColor: shapeBorder,
          borderWidth: shapeBorderWidth,
          node: node,
          isDark: isDark,
          isEditing: isEditing,
          provider: provider,
        );
        break;
      case NodeShape.roundedSquare:
        shapeWidget = _buildRoundedSquare(
          iconColor: iconColor,
          fill: effectiveFill,
          borderColor: shapeBorder,
          borderWidth: shapeBorderWidth,
          node: node,
        );
        break;
      case NodeShape.hexagon90:
        shapeWidget = _buildHexagon(
          iconColor: iconColor,
          fill: effectiveFill,
          borderColor: shapeBorder,
          borderWidth: shapeBorderWidth,
          node: node,
          isDark: isDark,
        );
        break;
    }

    // Wrap shape with measurement key if provided
    if (widget.shapeKey != null) {
      shapeWidget = KeyedSubtree(key: widget.shapeKey!, child: shapeWidget);
    }

    // Wrap with label for icon display style
    Widget result;
    if (node.displayStyle == DisplayStyle.icon &&
        node.nameDisplay == NameDisplay.labelOutside) {
      final isWorkflowRoot = node.kind == StepKind.workflow ||
          node.kind == StepKind.groupStep;
      final textColor = isDark
          ? (isWorkflowRoot
              ? AppColorsDark.textPrimary
              : AppColorsDark.textSecondary)
          : (isWorkflowRoot
              ? AppColors.textPrimary
              : AppColors.textSecondary);
      final textStyle = isWorkflowRoot
          ? AppTextStyles.h3.copyWith(
              color: textColor,
              fontWeight: isFocused ? FontWeight.w700 : FontWeight.w600,
            )
          : AppTextStyles.bodySmall.copyWith(
              color: textColor,
              fontWeight: isFocused ? FontWeight.w600 : FontWeight.w400,
            );

      // All labelOutside steps: label to the right of shape
      result = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          shapeWidget,
          const SizedBox(width: 6),
          if (isEditing)
            _buildInlineEditor(node, provider, isDark)
          else
            Text(
              node.name,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
        ],
      );
    } else {
      result = shapeWidget;
    }

    // Tooltip when name may be truncated (box display with constrained width)
    // or for any labelOutside that could overflow
    final needsTooltip = node.nameDisplay == NameDisplay.hoverOnly ||
        (node.displayStyle == DisplayStyle.box &&
            node.shape == NodeShape.roundedRect &&
            node.name.length > 18) ||
        (node.displayStyle == DisplayStyle.box &&
            node.shape == NodeShape.hexagon90 &&
            node.name.length > 30);
    if (needsTooltip) {
      result = Tooltip(
        message: node.name,
        child: result,
      );
    }

    return MouseRegion(
      cursor: _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _handleTap(provider, node),
        onDoubleTap: () => provider.openStepViewer(node.id),
        onPanStart: (_) {
          setState(() => _dragging = true);
          provider.startDrag(node.id);
        },
        onPanUpdate: (details) {
          // Scale delta by inverse of current zoom so movement matches cursor
          final scale = provider.currentScale;
          provider.updateDrag(
            node.id,
            details.delta.dx / scale,
            details.delta.dy / scale,
          );
        },
        onPanEnd: (_) {
          setState(() => _dragging = false);
          provider.commitDrag(node.id);
        },
        child: result,
      ),
    );
  }

  void _handleTap(WorkflowProvider provider, LayoutNode node) {
    final now = DateTime.now();

    // Slow double-click detection for inline rename
    if (provider.focusedNodeId == node.id &&
        node.editableName &&
        _lastClickTime != null) {
      final elapsed = now.difference(_lastClickTime!).inMilliseconds;
      // Slow double-click: 500-2000ms between clicks
      if (elapsed > 500 && elapsed < 2000) {
        provider.startEditing(node.id);
        _lastClickTime = null;
        return;
      }
    }

    _lastClickTime = now;
    provider.focusNode(node.id);
  }

  Widget _buildInlineEditor(
      LayoutNode node, WorkflowProvider provider, bool isDark) {
    final controller = TextEditingController(text: node.name);
    controller.selection =
        TextSelection(baseOffset: 0, extentOffset: node.name.length);
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;

    return SizedBox(
      width: 140,
      height: 24,
      child: TextField(
        controller: controller,
        autofocus: true,
        style: AppTextStyles.body.copyWith(
          color: textColor,
          height: 1.0,
        ),
        decoration: InputDecoration(
          isDense: true,
          isCollapsed: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: BorderSide(
              color: isDark ? AppColorsDark.primary : AppColors.primary,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: BorderSide(
              color: isDark ? AppColorsDark.primary : AppColors.primary,
              width: 2,
            ),
          ),
        ),
        onSubmitted: (value) =>
            provider.confirmRename(node.id, value),
        onTapOutside: (_) => provider.cancelEditing(),
      ),
    );
  }

  Widget _buildCircleBadge({
    required Color iconColor,
    required Color fill,
    required Color borderColor,
    required double borderWidth,
    required LayoutNode node,
  }) {
    final icon = _iconForKind(node.kind);
    final isRunning = node.state == StepState.running ||
        node.state == StepState.runningDependent;
    // Header (workflow) badge is 48px; all others are 36px
    final isHeader = node.kind == StepKind.workflow;
    final size = isHeader ? 48.0 : 36.0;
    final iconSize = isHeader ? 18.0 : 14.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Center(
        child: isRunning
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: AppLineWeights.lineEmphasis,
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              )
            : FaIcon(icon, size: iconSize, color: iconColor),
      ),
    );
  }

  Widget _buildRoundedRect({
    required Color iconColor,
    required Color fill,
    required Color borderColor,
    required double borderWidth,
    required LayoutNode node,
    required bool isDark,
    required bool isEditing,
    required WorkflowProvider provider,
  }) {
    final icon = _iconForKind(node.kind);
    final isRunning = node.state == StepState.running ||
        node.state == StepState.runningDependent;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;

    return Container(
      height: 36,
      constraints: const BoxConstraints(minWidth: 80, maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRunning)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: AppLineWeights.lineEmphasis,
                valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              ),
            )
          else
            FaIcon(icon, size: 14, color: iconColor),
          const SizedBox(width: AppSpacing.xs),
          if (isEditing)
            Flexible(
              child: _buildInlineEditor(node, provider, isDark),
            )
          else if (node.nameDisplay == NameDisplay.alwaysVisible)
            Flexible(
              child: Text(
                node.name,
                style: AppTextStyles.bodySmall.copyWith(
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoundedSquare({
    required Color iconColor,
    required Color fill,
    required Color borderColor,
    required double borderWidth,
    required LayoutNode node,
  }) {
    final icon = _iconForKind(node.kind);
    final isRunning = node.state == StepState.running ||
        node.state == StepState.runningDependent;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Center(
        child: isRunning
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: AppLineWeights.lineEmphasis,
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              )
            : FaIcon(icon, size: 14, color: iconColor),
      ),
    );
  }

  Widget _buildHexagon({
    required Color iconColor,
    required Color fill,
    required Color borderColor,
    required double borderWidth,
    required LayoutNode node,
    required bool isDark,
  }) {
    final icon = _iconForKind(node.kind);
    final isRunning = node.state == StepState.running ||
        node.state == StepState.runningDependent;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;

    // For box display style (MeltStep), show name inside
    final showName = node.displayStyle == DisplayStyle.box &&
        node.nameDisplay == NameDisplay.alwaysVisible;

    return SizedBox(
      height: 36,
      child: IntrinsicWidth(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: showName ? 60 : 36,
          ),
          child: CustomPaint(
            painter: _HexagonFillPainter(
              fill: fill,
              borderColor: borderColor,
              borderWidth: borderWidth,
            ),
            child: ClipPath(
              clipper: _Hexagon90Clipper(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: showName ? 14.0 : 4.0,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isRunning)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: AppLineWeights.lineEmphasis,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(iconColor),
                          ),
                        )
                      else
                        FaIcon(icon, size: 14, color: iconColor),
                      if (showName) ...[
                        const SizedBox(width: 4),
                        Text(
                          node.name,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: textColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -- Icon mapping --

  IconData _iconForKind(StepKind kind) {
    switch (kind) {
      case StepKind.workflow:
        return FontAwesomeIcons.sitemap;
      case StepKind.groupStep:
        return FontAwesomeIcons.sitemap;
      case StepKind.tableStep:
        return FontAwesomeIcons.table;
      case StepKind.joinStep:
        return FontAwesomeIcons.codeMerge;
      case StepKind.dataStep:
        return FontAwesomeIcons.cubes;
      case StepKind.viewStep:
        return FontAwesomeIcons.eye;
      case StepKind.inStep:
        return FontAwesomeIcons.rightToBracket;
      case StepKind.outStep:
        return FontAwesomeIcons.rightFromBracket;
      case StepKind.meltStep:
        return FontAwesomeIcons.shuffle;
      case StepKind.exportStep:
        return FontAwesomeIcons.file;
      case StepKind.wizardStep:
        return FontAwesomeIcons.wandMagicSparkles;
    }
  }

  Color _iconColorForState(StepState state, bool isDark) {
    switch (state) {
      case StepState.init:
      case StepState.pending:
        return isDark ? AppColorsDark.neutral400 : AppColors.neutral600;
      case StepState.runningDependent:
        return isDark ? AppColorsDark.warning : AppColors.warning;
      case StepState.running:
        return isDark ? AppColorsDark.info : AppColors.info;
      case StepState.done:
        return isDark ? AppColorsDark.success : AppColors.success;
      case StepState.failed:
        return isDark ? AppColorsDark.error : AppColors.error;
      case StepState.canceled:
        return isDark ? AppColorsDark.neutral500 : AppColors.neutral500;
    }
  }
}

/// Clips content to a hexagon rotated 90 degrees (points N and S).
class _Hexagon90Clipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final pointOffset = h * 0.25;

    return Path()
      ..moveTo(w / 2, 0) // top point (N)
      ..lineTo(w, pointOffset) // top-right
      ..lineTo(w, h - pointOffset) // bottom-right
      ..lineTo(w / 2, h) // bottom point (S)
      ..lineTo(0, h - pointOffset) // bottom-left
      ..lineTo(0, pointOffset) // top-left
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Paints a hexagon with fill and border (avoids ClipPath bleed on web).
class _HexagonFillPainter extends CustomPainter {
  final Color fill;
  final Color borderColor;
  final double borderWidth;

  _HexagonFillPainter({
    required this.fill,
    required this.borderColor,
    required this.borderWidth,
  });

  Path _hexPath(Size size) {
    final w = size.width;
    final h = size.height;
    final pointOffset = h * 0.25;
    return Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, pointOffset)
      ..lineTo(w, h - pointOffset)
      ..lineTo(w / 2, h)
      ..lineTo(0, h - pointOffset)
      ..lineTo(0, pointOffset)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _hexPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..strokeWidth = borderWidth
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_HexagonFillPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth;
}
