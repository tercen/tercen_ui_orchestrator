import 'package:flutter/material.dart';
import 'package:sdui/sdui.dart';

/// A bottom bar that shows the latest error from [ErrorReporter].
///
/// Listens to [ErrorReporter.instance] and slides in when a new error arrives.
/// The user can dismiss it or expand to see the full list.
class ErrorBar extends StatefulWidget {
  const ErrorBar({super.key});

  @override
  State<ErrorBar> createState() => _ErrorBarState();
}

class _ErrorBarState extends State<ErrorBar> {
  ErrorReport? _lastSeen;
  bool _dismissed = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    ErrorReporter.instance.addListener(_onError);
  }

  void _onError() {
    final latest = ErrorReporter.instance.lastError;
    if (latest != null && latest != _lastSeen) {
      setState(() {
        _lastSeen = latest;
        _dismissed = false;
        _expanded = false;
      });
    }
  }

  @override
  void dispose() {
    ErrorReporter.instance.removeListener(_onError);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _lastSeen == null) return const SizedBox.shrink();

    final errors = ErrorReporter.instance.errors;

    return Container(
      color: const Color(0xFF2D1010),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row: latest error + controls
          InkWell(
            onTap: errors.length > 1
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    _severityIcon(_lastSeen!.severity),
                    color: _severityColor(_lastSeen!.severity),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '[${_lastSeen!.source}] ${_lastSeen!.error}',
                      style: TextStyle(
                        color: _severityColor(_lastSeen!.severity),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (errors.length > 1) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${errors.length} errors',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white38,
                      size: 16,
                    ),
                  ],
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    color: Colors.white38,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () => setState(() => _dismissed = true),
                    tooltip: 'Dismiss',
                  ),
                ],
              ),
            ),
          ),
          // Expanded error list
          if (_expanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.builder(
                shrinkWrap: true,
                reverse: true,
                itemCount: errors.length - 1, // skip last (already shown above)
                itemBuilder: (context, index) {
                  final report = errors[errors.length - 2 - index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: Text(
                      '[${report.source}] ${report.error}',
                      style: TextStyle(
                        color: _severityColor(report.severity).withAlpha(178),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Color _severityColor(ErrorSeverity severity) {
    return switch (severity) {
      ErrorSeverity.info => Colors.blue.shade300,
      ErrorSeverity.warning => Colors.orange.shade300,
      ErrorSeverity.error => Colors.red.shade300,
      ErrorSeverity.fatal => Colors.red.shade200,
    };
  }

  IconData _severityIcon(ErrorSeverity severity) {
    return switch (severity) {
      ErrorSeverity.info => Icons.info_outline,
      ErrorSeverity.warning => Icons.warning_amber,
      ErrorSeverity.error => Icons.error_outline,
      ErrorSeverity.fatal => Icons.dangerous_outlined,
    };
  }
}
