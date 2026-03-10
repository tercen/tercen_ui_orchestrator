import 'package:flutter/material.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String nodeId;

  const ErrorBoundary({super.key, required this.child, required this.nodeId});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorFallback();
    }

    return _ErrorCatcher(
      onError: (error) => setState(() => _error = error),
      child: widget.child,
    );
  }

  Widget _buildErrorFallback() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(25),
        border: Border.all(color: Colors.red.withAlpha(76)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Error in widget "${widget.nodeId}"',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _error.toString(),
            style: TextStyle(color: Colors.red.withAlpha(178), fontSize: 11),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ErrorCatcher extends StatelessWidget {
  final Widget child;
  final void Function(Object error) onError;

  const _ErrorCatcher({required this.child, required this.onError});

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (details) {
      onError(details.exception);
      return const SizedBox.shrink();
    };
    return child;
  }
}
