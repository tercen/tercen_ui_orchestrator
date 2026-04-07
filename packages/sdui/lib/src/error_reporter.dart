import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Severity levels for reported errors.
enum ErrorSeverity { info, warning, error, fatal }

/// A single error report with context.
class ErrorReport {
  final Object error;
  final StackTrace? stackTrace;
  final String source;
  final String? context;
  final ErrorSeverity severity;
  final DateTime timestamp;

  ErrorReport({
    required this.error,
    this.stackTrace,
    required this.source,
    this.context,
    this.severity = ErrorSeverity.error,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    final buf = StringBuffer()
      ..write('[${severity.name}] ($source)')
      ..write(context != null ? ' $context: ' : ': ')
      ..write(error);
    if (stackTrace != null) {
      buf
        ..writeln()
        ..write(stackTrace);
    }
    return buf.toString();
  }
}

/// Centralized error handler for the orchestrator.
///
/// Every error — build, async, data, conversion — routes through here.
/// Logs to console and notifies listeners (e.g., for UI display).
///
/// Usage:
///   ErrorReporter.instance.report(error, stackTrace, source: 'renderer', context: 'Card id=foo');
///   ErrorReporter.instance.addListener(() => /* update UI */);
class ErrorReporter extends ChangeNotifier {
  static final ErrorReporter instance = ErrorReporter._();
  ErrorReporter._();

  final List<ErrorReport> _errors = [];
  bool _isNotifying = false;
  bool _notifyScheduled = false;

  /// All reported errors (most recent last).
  List<ErrorReport> get errors => List.unmodifiable(_errors);

  /// Most recent error, or null.
  ErrorReport? get lastError => _errors.isEmpty ? null : _errors.last;

  /// Report an error. Always logs to console and notifies listeners.
  ///
  /// Notification is deferred to a post-frame callback to avoid triggering
  /// setState during build, which causes an infinite error cascade.
  void report(
    Object error, {
    StackTrace? stackTrace,
    required String source,
    String? context,
    ErrorSeverity severity = ErrorSeverity.error,
  }) {
    final report = ErrorReport(
      error: error,
      stackTrace: stackTrace,
      source: source,
      context: context,
      severity: severity,
    );
    _errors.add(report);
    // Keep bounded — don't leak memory on long sessions
    if (_errors.length > 200) _errors.removeRange(0, _errors.length - 200);

    // Log to both Flutter debug console and browser/stdout console
    final msg = '[orchestrator] $report';
    debugPrint(msg);

    // Defer notification to avoid setState-during-build loops.
    // Multiple errors in the same frame coalesce into one notification.
    if (!_notifyScheduled && !_isNotifying) {
      _notifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        _isNotifying = true;
        try {
          notifyListeners();
        } finally {
          _isNotifying = false;
        }
      });
    }
  }

  /// Clear all errors.
  void clear() {
    _errors.clear();
    notifyListeners();
  }
}
