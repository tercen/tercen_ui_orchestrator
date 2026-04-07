import 'dart:async';

import 'package:flutter/material.dart';

import '../event_bus/event_bus.dart';
import '../event_bus/event_payload.dart';
import '../schema/sdui_node.dart';
import '../renderer/sdui_render_context.dart';
import '../renderer/sdui_renderer.dart';
import '../registry/widget_registry.dart';
import '../theme/sdui_theme.dart';
import '../window/window_manager.dart';

/// Global overlay that renders popups above the workspace.
///
/// Listens to `window.{id}.popup.open` / `popup.close` events.
///
/// Two modes:
/// - **SDUI content mode**: event data contains a `content` key with an SDUI
///   node tree. The tree is rendered through [SduiRenderer] so all primitives
///   use approved styling. Use a [FormDialog] node as the root for dialog
///   framing (title, scroll, card).
/// - **Confirm mode** (legacy): event data contains `title`, `message`, and
///   `actions` — rendered as a simple confirm dialog.
class PopupOverlay extends StatefulWidget {
  final EventBus eventBus;
  final WindowManager windowManager;
  final WidgetRegistry registry;
  final SduiRenderContext renderContext;
  final SduiTheme theme;
  final Widget child;

  const PopupOverlay({
    super.key,
    required this.eventBus,
    required this.windowManager,
    required this.registry,
    required this.renderContext,
    required this.theme,
    required this.child,
  });

  @override
  State<PopupOverlay> createState() => _PopupOverlayState();
}

class _PopupOverlayState extends State<PopupOverlay> {
  /// Active SDUI content node (rendered via SduiRenderer).
  SduiNode? _activeContent;

  /// Active confirm popup (legacy simple mode).
  _ConfirmEntry? _activeConfirm;

  StreamSubscription<EventPayload>? _openSub;
  StreamSubscription<EventPayload>? _closeSub;

  @override
  void initState() {
    super.initState();
    _openSub = widget.eventBus
        .subscribePrefix('window.')
        .where((e) => e.type == 'popup.open')
        .listen(_onOpen);
    _closeSub = widget.eventBus
        .subscribePrefix('window.')
        .where((e) => e.type == 'popup.close')
        .listen(_onClose);
  }

  @override
  void dispose() {
    _openSub?.cancel();
    _closeSub?.cancel();
    super.dispose();
  }

  void _onOpen(EventPayload event) {
    final data = event.data;

    // SDUI content mode: data has a 'content' SDUI node tree.
    if (data['content'] is Map) {
      final contentJson = Map<String, dynamic>.from(data['content'] as Map);
      setState(() {
        _activeContent = SduiNode.fromJson(contentJson);
        _activeConfirm = null;
      });
      return;
    }

    // Legacy confirm mode: title + message + actions.
    final windowId = data['windowId'] as String?;
    if (windowId == null) return;
    final actions = (data['actions'] as List<dynamic>?)
            ?.map((a) {
              final m = a as Map<String, dynamic>;
              return _ConfirmAction(
                label: m['label'] as String? ?? 'OK',
                channel: m['channel'] as String?,
                payload: m['payload'] as Map<String, dynamic>?,
              );
            })
            .toList() ??
        [const _ConfirmAction(label: 'OK')];

    setState(() {
      _activeContent = null;
      _activeConfirm = _ConfirmEntry(
        windowId: windowId,
        title: data['title'] as String?,
        message: data['message'] as String?,
        actions: actions,
        modal: data['modal'] as bool? ?? false,
      );
    });
  }

  void _onClose(EventPayload event) {
    setState(() {
      _activeContent = null;
      _activeConfirm = null;
    });
  }

  void _dismiss() {
    setState(() {
      _activeContent = null;
      _activeConfirm = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPopup = _activeContent != null || _activeConfirm != null;

    // Always return Stack so widget.child stays in the same tree position
    // and doesn't get rebuilt when popup state changes.
    return Stack(
      children: [
        widget.child,
        if (hasPopup) ...[
          // Scrim
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                color: Colors.black.withAlpha(
                  Theme.of(context).brightness == Brightness.dark ? 100 : 40,
                ),
              ),
            ),
          ),
          // Content
          if (_activeContent != null)
            Positioned.fill(
              child: SduiRenderer(
                registry: widget.registry,
                renderContext: widget.renderContext,
              ).render(_activeContent!),
            ),
          if (_activeConfirm != null)
            _buildConfirm(context, _activeConfirm!),
        ],
      ],
    );
  }

  // -- Legacy confirm popup --------------------------------------------------

  Widget _buildConfirm(BuildContext context, _ConfirmEntry confirm) {
    final colorScheme = Theme.of(context).colorScheme;
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    final titleSmall = Theme.of(context).textTheme.titleSmall;
    const popupWidth = 280.0;
    final size = MediaQuery.of(context).size;

    final windowRect = _windowRect(confirm.windowId);
    double left;
    double top;
    if (windowRect != null) {
      left = windowRect.left + (windowRect.width - popupWidth) / 2;
      top = windowRect.top + windowRect.height * 0.3;
    } else {
      left = (size.width - popupWidth) / 2;
      top = size.height * 0.3;
    }
    left = left.clamp(8.0, size.width - popupWidth - 8);
    top = top.clamp(8.0, size.height - 200);

    return Positioned(
      left: left,
      top: top,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(widget.theme.radius.md),
        color: colorScheme.surfaceContainerHigh,
        child: Container(
          width: popupWidth,
          padding: EdgeInsets.all(widget.theme.spacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (confirm.title != null)
                Padding(
                  padding: EdgeInsets.only(bottom: widget.theme.spacing.sm),
                  child: Text(confirm.title!,
                      style: titleSmall?.copyWith(color: colorScheme.onSurface)),
                ),
              if (confirm.message != null)
                Padding(
                  padding: EdgeInsets.only(bottom: widget.theme.spacing.md),
                  child: Text(confirm.message!,
                      style: bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: confirm.actions.map((a) {
                  return Padding(
                    padding: EdgeInsets.only(left: widget.theme.spacing.sm),
                    child: TextButton(
                      onPressed: () {
                        if (a.channel != null) {
                          widget.eventBus.publish(
                            a.channel!,
                            EventPayload(
                              type: 'popup.action',
                              data: a.payload ?? {},
                            ),
                          );
                        }
                        _dismiss();
                      },
                      child: Text(a.label),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Rect? _windowRect(String windowId) {
    final windows = widget.windowManager.windows;
    try {
      final w = windows.firstWhere((w) => w.id == windowId);
      return Rect.fromLTWH(w.x, w.y, w.width, w.height);
    } catch (_) {
      return null;
    }
  }
}

// -- Legacy confirm data classes ---------------------------------------------

class _ConfirmEntry {
  final String windowId;
  final String? title;
  final String? message;
  final List<_ConfirmAction> actions;
  final bool modal;

  const _ConfirmEntry({
    required this.windowId,
    this.title,
    this.message,
    this.actions = const [],
    this.modal = false,
  });
}

class _ConfirmAction {
  final String label;
  final String? channel;
  final Map<String, dynamic>? payload;

  const _ConfirmAction({
    required this.label,
    this.channel,
    this.payload,
  });
}
