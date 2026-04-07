import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models/content_state.dart';
import '../providers/home_panel_provider.dart';
import 'body_states/loading_state.dart';
import 'body_states/empty_state.dart';
import 'body_states/error_state.dart';

/// Routes to one of four body states based on the provider's content state.
class WindowBody extends StatelessWidget {
  final Widget? activeContent;
  final IconData emptyIcon;
  final String emptyMessage;
  final String? emptyDetail;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final VoidCallback? onRetry;

  const WindowBody({
    super.key,
    this.activeContent,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyMessage = 'No content',
    this.emptyDetail,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomePanelProvider>();

    switch (provider.contentState) {
      case ContentState.loading:
        return const LoadingState(message: 'Loading...');
      case ContentState.empty:
        return EmptyState(
          icon: emptyIcon,
          message: emptyMessage,
          detail: emptyDetail,
          actionLabel: emptyActionLabel,
          onAction: onEmptyAction,
        );
      case ContentState.active:
        return activeContent ?? const SizedBox.shrink();
      case ContentState.error:
        return ErrorState(
          message: provider.errorMessage ?? 'An error occurred',
          onRetry: onRetry ?? () => provider.retry(),
        );
    }
  }
}
