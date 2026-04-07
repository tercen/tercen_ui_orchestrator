import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../domain/models/edit_mode.dart';
import '../../providers/document_provider.dart';
import '../source_editor.dart';
import '../rendered_editor.dart';

/// Active body state: routes to source or rendered editor based on edit mode.
///
/// Overlays transient feedback banners for save success and save error.
class ActiveState extends StatelessWidget {
  const ActiveState({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();

    return Column(
      children: [
        // Inline save error banner (auto-dismiss after 5 s handled by widget).
        if (provider.saveError != null)
          _SaveErrorBanner(message: provider.saveError!),
        // Inline save success banner (auto-clears via provider timer).
        if (provider.saveSuccess) const _SaveSuccessBanner(),
        Expanded(
          child: provider.editMode == EditMode.source
              ? const SourceEditor()
              : const RenderedEditor(),
        ),
      ],
    );
  }
}

/// Inline success banner shown briefly after a successful save.
class _SaveSuccessBanner extends StatelessWidget {
  const _SaveSuccessBanner();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final successBg =
        isDark ? const Color(0xFF052E16) : AppColors.successLight;
    final successFg = isDark ? AppColorsDark.success : AppColors.success;

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: successBg,
        child: Row(
          children: [
            FaIcon(FontAwesomeIcons.circleCheck, size: 14, color: successFg),
            const SizedBox(width: 8),
            Text(
              'Document saved',
              style: TextStyle(fontSize: 12, color: successFg),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline error banner for save failures.
class _SaveErrorBanner extends StatelessWidget {
  final String message;

  const _SaveErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorBg = isDark ? const Color(0xFF3B1111) : const Color(0xFFFEE2E2);
    final errorFg = isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: errorBg,
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: errorFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: errorFg),
            ),
          ),
        ],
      ),
    );
  }
}
