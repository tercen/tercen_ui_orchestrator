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
    final theme = Theme.of(context);
    final bodySmall = theme.textTheme.bodySmall;
    final labelSmall = theme.textTheme.labelSmall;
    final sduiTheme = SduiScope.of(context).renderContext.theme;
    final iconSm = sduiTheme.iconSize.sm;
    final spacingSm = sduiTheme.spacing.sm;

    return Container(
      color: theme.colorScheme.errorContainer,
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
              padding: EdgeInsets.symmetric(horizontal: sduiTheme.spacing.md, vertical: sduiTheme.spacing.xs),
              child: Row(
                children: [
                  Icon(
                    _severityIcon(_lastSeen!.severity),
                    color: _severityColor(_lastSeen!.severity),
                    size: iconSm,
                  ),
                  SizedBox(width: spacingSm),
                  Expanded(
                    child: Text(
                      '[${_lastSeen!.source}] ${_lastSeen!.error}',
                      style: bodySmall?.copyWith(
                        color: _severityColor(_lastSeen!.severity),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (errors.length > 1) ...[
                    SizedBox(width: spacingSm),
                    Text(
                      '${errors.length} errors',
                      style: labelSmall?.copyWith(color: theme.hintColor),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.hintColor,
                      size: iconSm,
                    ),
                  ],
                  SizedBox(width: sduiTheme.spacing.xs),
                  IconButton(
                    icon: Icon(Icons.close, size: iconSm),
                    color: theme.hintColor,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: sduiTheme.controlHeight.sm,
                      minHeight: sduiTheme.controlHeight.sm,
                    ),
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
                    padding: EdgeInsets.symmetric(horizontal: sduiTheme.spacing.md, vertical: 2),
                    child: Text(
                      '[${report.source}] ${report.error}',
                      style: labelSmall?.copyWith(
                        color: _severityColor(report.severity).withAlpha(178),
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
    final colorScheme = Theme.of(context).colorScheme;
    return switch (severity) {
      ErrorSeverity.info => colorScheme.primary,
      ErrorSeverity.warning => colorScheme.tertiary,
      ErrorSeverity.error => colorScheme.error,
      ErrorSeverity.fatal => colorScheme.error,
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
