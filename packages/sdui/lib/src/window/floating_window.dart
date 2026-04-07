import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../renderer/sdui_render_context.dart';
import '../renderer/sdui_renderer.dart';
import '../registry/widget_registry.dart';
import 'window_chrome.dart';
import 'window_state.dart';

class FloatingWindow extends StatelessWidget {
  final WindowState state;
  final WidgetRegistry registry;
  final SduiRenderContext renderContext;
  final void Function(String windowId) onClose;
  final void Function(String windowId) onMinimize;
  final void Function(String windowId) onFocus;
  final void Function(String windowId, double dx, double dy) onDrag;
  final void Function(String windowId, double dw, double dh) onResize;

  const FloatingWindow({
    super.key,
    required this.state,
    required this.registry,
    required this.renderContext,
    required this.onClose,
    required this.onMinimize,
    required this.onFocus,
    required this.onDrag,
    required this.onResize,
  });

  @override
  Widget build(BuildContext context) {
    if (state.minimized) return const SizedBox.shrink();

    return Positioned(
      left: state.x,
      top: state.y,
      width: state.width,
      height: state.height,
      child: GestureDetector(
        onTap: () => onFocus(state.id),
        child: Stack(
          children: [
            _DraggableWindow(
              windowId: state.id,
              onDrag: onDrag,
              child: WindowChrome(
                state: state,
                theme: renderContext.theme,
                onClose: () => onClose(state.id),
                onMinimize: () => onMinimize(state.id),
                onFocus: () => onFocus(state.id),
                child: _buildContent(),
              ),
            ),
            // Resize handle (bottom-right corner)
            Positioned(
              right: 0,
              bottom: 0,
              child: _ResizeHandle(
                windowId: state.id,
                onResize: onResize,
                handleColor: renderContext.theme.colors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final Set<String> _loggedWindows = {};

  Widget _buildContent() {
    final renderer = SduiRenderer(
      registry: registry,
      renderContext: renderContext,
    );
    final type = state.content.type;
    if (!_loggedWindows.contains(state.id)) {
      _loggedWindows.add(state.id);
      final hasTemplate = registry.getTemplate(type) != null;
      final hasBuilder = registry.getBuilder(type) != null;
      final hasScopeBuilder = registry.getScopeBuilder(type) != null;
      debugPrint('[FloatingWindow] rendering "${state.id}" content type="$type" '
          'template=$hasTemplate builder=$hasBuilder scope=$hasScopeBuilder '
          'props=${state.content.props.keys.toList()} children=${state.content.children.length}');
    }
    return renderer.render(state.content);
  }
}

class _DraggableWindow extends StatefulWidget {
  final String windowId;
  final void Function(String windowId, double dx, double dy) onDrag;
  final Widget child;

  const _DraggableWindow({
    required this.windowId,
    required this.onDrag,
    required this.child,
  });

  @override
  State<_DraggableWindow> createState() => _DraggableWindowState();
}

class _DraggableWindowState extends State<_DraggableWindow> {
  Offset? _dragStart;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => _dragStart = details.globalPosition,
      onPanUpdate: (details) {
        if (_dragStart != null) {
          final delta = details.globalPosition - _dragStart!;
          _dragStart = details.globalPosition;
          widget.onDrag(widget.windowId, delta.dx, delta.dy);
        }
      },
      onPanEnd: (_) => _dragStart = null,
      child: widget.child,
    );
  }
}

class _ResizeHandle extends StatefulWidget {
  final String windowId;
  final void Function(String windowId, double dw, double dh) onResize;
  final Color handleColor;

  const _ResizeHandle({
    required this.windowId,
    required this.onResize,
    required this.handleColor,
  });

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  Offset? _dragStart;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => _dragStart = details.globalPosition,
      onPanUpdate: (details) {
        if (_dragStart != null) {
          final delta = details.globalPosition - _dragStart!;
          _dragStart = details.globalPosition;
          widget.onResize(widget.windowId, delta.dx, delta.dy);
        }
      },
      onPanEnd: (_) => _dragStart = null,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeDownRight,
        child: SizedBox(
          width: 16,
          height: 16,
          child: Align(
            alignment: Alignment.bottomRight,
            child: Icon(FontAwesomeIcons.gripLines, size: 12, color: widget.handleColor),
          ),
        ),
      ),
    );
  }
}
