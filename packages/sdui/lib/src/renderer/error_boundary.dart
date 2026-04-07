import 'package:flutter/material.dart';

import '../error_reporter.dart';

// Error display constants — should match SduiOpacityTokens
const int _opacitySubtle = 25;
const int _opacityLight = 76;
const int _opacityStrong = 204;

// Error display font sizes — should match SduiTextStyleTokens
const double _fontSizeMicro = 8.0;
const double _fontSizeSmall = 12.0;

/// Wraps a child widget and displays an inline error fallback if the child
/// fails to build. Routes all errors through [ErrorReporter].
///
/// Does NOT override [ErrorWidget.builder] — that global is left to
/// [FlutterError.onError] set up in main.dart.
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String nodeId;

  const ErrorBoundary({super.key, required this.child, required this.nodeId});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorFallback();
    }

    // If the child itself was built with an error already caught upstream
    // (e.g., renderer try/catch called reportAndBuildError), the child
    // will be an error widget — no further wrapping needed.
    return widget.child;
  }

  /// Called by the renderer when it catches a build error for this node.
  void catchError(Object error, StackTrace? stackTrace) {
    ErrorReporter.instance.report(
      error,
      stackTrace: stackTrace,
      source: 'sdui.renderer',
      context: 'widget "${widget.nodeId}"',
    );
    if (mounted) {
      setState(() {
        _error = error;
        _stackTrace = stackTrace;
      });
    }
  }

  Widget _buildErrorFallback() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(_opacitySubtle),
        border: Border.all(color: Colors.red.withAlpha(_opacityLight)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Error in "${widget.nodeId}"',
            style: TextStyle(
              color: Colors.red,
              fontSize: _fontSizeSmall,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _error.toString(),
            style: TextStyle(color: Colors.red.withAlpha(_opacityStrong), fontSize: _fontSizeSmall),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (_stackTrace != null) ...[
            const SizedBox(height: 4),
            Text(
              _stackTrace.toString(),
              style: TextStyle(color: Colors.red.withAlpha(_opacityLight), fontSize: _fontSizeMicro),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
