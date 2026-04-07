import 'dart:async';

import 'package:flutter/material.dart';

import '../error_reporter.dart';
import '../event_bus/event_bus.dart';
import '../event_bus/event_payload.dart';
import '../theme/sdui_theme.dart';

/// A single toast notification entry.
class _ToastEntry {
  final String id;
  final String message;
  final String? detail;
  final String? source;
  final ErrorSeverity severity;
  final DateTime timestamp;
  Timer? dismissTimer;

  _ToastEntry({
    required this.id,
    required this.message,
    this.detail,
    this.source,
    required this.severity,
  }) : timestamp = DateTime.now();
}

/// Floating toast notification overlay that replaces the old ErrorBar.
///
/// Renders a stack of toast notifications in the bottom-right corner of its
/// parent. Listens to both [ErrorReporter] and the `system.notification`
/// EventBus channel.
class ToastOverlay extends StatefulWidget {
  final EventBus eventBus;
  final SduiTheme theme;
  final Widget child;

  const ToastOverlay({
    super.key,
    required this.eventBus,
    required this.theme,
    required this.child,
  });

  @override
  State<ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<ToastOverlay> {
  final List<_ToastEntry> _toasts = [];
  StreamSubscription<EventPayload>? _notifSub;
  int _nextId = 0;

  static const _maxVisible = 3;

  @override
  void initState() {
    super.initState();
    ErrorReporter.instance.addListener(_onErrorReported);
    _notifSub = widget.eventBus
        .subscribe('system.notification')
        .listen(_onNotification);
  }

  @override
  void dispose() {
    ErrorReporter.instance.removeListener(_onErrorReported);
    _notifSub?.cancel();
    for (final t in _toasts) {
      t.dismissTimer?.cancel();
    }
    super.dispose();
  }

  void _onErrorReported() {
    final report = ErrorReporter.instance.lastError;
    if (report == null) return;
    _addToast(
      message: '${report.error}',
      detail: report.context,
      source: report.source,
      severity: report.severity,
    );
  }

  void _onNotification(EventPayload event) {
    final data = event.data;
    final severityStr = data['severity'] as String? ?? 'info';
    final severity = ErrorSeverity.values.firstWhere(
      (s) => s.name == severityStr,
      orElse: () => ErrorSeverity.info,
    );
    _addToast(
      message: data['message'] as String? ?? '',
      detail: data['detail'] as String?,
      source: data['source'] as String?,
      severity: severity,
    );
  }

  /// Tracks recent messages to suppress duplicates.
  final Map<String, DateTime> _recentMessages = {};
  static const _dedupeWindow = Duration(seconds: 10);

  void _addToast({
    required String message,
    String? detail,
    String? source,
    required ErrorSeverity severity,
  }) {
    if (!mounted) return;

    // Deduplicate: suppress identical messages within the window
    final dedupeKey = '${source ?? ""}:$message';
    final now = DateTime.now();
    final lastSeen = _recentMessages[dedupeKey];
    if (lastSeen != null && now.difference(lastSeen) < _dedupeWindow) {
      return; // suppress duplicate
    }
    _recentMessages[dedupeKey] = now;

    // Prune old entries from dedup map
    _recentMessages.removeWhere((_, ts) => now.difference(ts) > _dedupeWindow);

    final id = 'toast-${_nextId++}';
    final entry = _ToastEntry(
      id: id,
      message: message,
      detail: detail,
      source: source,
      severity: severity,
    );

    // Auto-dismiss after timeout based on severity
    final duration = switch (severity) {
      ErrorSeverity.info => const Duration(seconds: 4),
      ErrorSeverity.warning => const Duration(seconds: 5),
      ErrorSeverity.error => const Duration(seconds: 8),
      ErrorSeverity.fatal => const Duration(seconds: 12),
    };
    entry.dismissTimer = Timer(duration, () {
      _removeToast(id);
    });

    setState(() {
      _toasts.add(entry);
      // Keep bounded
      while (_toasts.length > 20) {
        _toasts.first.dismissTimer?.cancel();
        _toasts.removeAt(0);
      }
    });
  }

  void _removeToast(String id) {
    if (!mounted) return;
    setState(() {
      _toasts.removeWhere((t) {
        if (t.id == id) {
          t.dismissTimer?.cancel();
          return true;
        }
        return false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleToasts = _toasts.length > _maxVisible
        ? _toasts.sublist(_toasts.length - _maxVisible)
        : _toasts;

    return Stack(
      children: [
        widget.child,
        if (visibleToasts.isNotEmpty)
          Positioned(
            right: widget.theme.spacing.md,
            bottom: widget.theme.spacing.md,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: visibleToasts
                  .map((t) => _ToastCard(
                        entry: t,
                        theme: widget.theme,
                        onDismiss: () => _removeToast(t.id),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _ToastCard extends StatelessWidget {
  final _ToastEntry entry;
  final SduiTheme theme;
  final VoidCallback onDismiss;

  const _ToastCard({
    required this.entry,
    required this.theme,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final severityColor = _severityColor(entry.severity, colorScheme);
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    final labelSmall = Theme.of(context).textTheme.labelSmall;

    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.xs),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(theme.radius.md),
        color: colorScheme.surfaceContainerHighest,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360, minWidth: 240),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: severityColor, width: 3),
            ),
          ),
          padding: EdgeInsets.all(theme.spacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _severityIcon(entry.severity),
                color: severityColor,
                size: theme.iconSize.sm,
              ),
              SizedBox(width: theme.spacing.sm),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.source != null)
                      Text(
                        entry.source!,
                        style: labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      entry.message,
                      style: bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.detail != null)
                      Padding(
                        padding: EdgeInsets.only(top: theme.spacing.xs),
                        child: Text(
                          entry.detail!,
                          style: labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: theme.spacing.xs),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(
                  Icons.close,
                  size: theme.iconSize.sm,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _severityColor(ErrorSeverity severity, ColorScheme cs) {
    return switch (severity) {
      ErrorSeverity.info => cs.primary,
      ErrorSeverity.warning => cs.tertiary,
      ErrorSeverity.error => cs.error,
      ErrorSeverity.fatal => cs.error,
    };
  }

  static IconData _severityIcon(ErrorSeverity severity) {
    return switch (severity) {
      ErrorSeverity.info => Icons.info_outline,
      ErrorSeverity.warning => Icons.warning_amber,
      ErrorSeverity.error => Icons.error_outline,
      ErrorSeverity.fatal => Icons.dangerous_outlined,
    };
  }
}
