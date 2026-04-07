import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models/content_state.dart';
import '../providers/document_provider.dart';
import 'body_states/loading_state.dart';
import 'body_states/active_state.dart';
import 'body_states/error_state.dart';

/// Routes to loading, active, or error body state.
///
/// No empty state -- the document editor only opens with a target document.
class WindowBody extends StatelessWidget {
  final VoidCallback? onRetry;

  const WindowBody({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();

    switch (provider.contentState) {
      case ContentState.loading:
        return const LoadingState(message: 'Loading document...');
      case ContentState.empty:
        // Should never happen for document editor, but handle gracefully.
        return const LoadingState(message: 'Loading document...');
      case ContentState.active:
        return const ActiveState();
      case ContentState.error:
        return ErrorState(
          message: provider.errorMessage ?? 'An error occurred',
          onRetry: onRetry,
        );
    }
  }
}
