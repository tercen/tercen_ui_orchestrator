import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// The four notification types from the Tercen style guide.
enum SnackbarType { success, info, warning, error }

/// Shows a styled snackbar following the Tercen toast notification spec.
///
/// Uses bold/inverted style: solid coloured background with white text.
/// Call from any widget with access to a BuildContext.
///
/// EventBus wiring for real notifications is deferred to Phase 3.
void showAppSnackbar(
  BuildContext context, {
  required SnackbarType type,
  required String message,
  String? title,
  Duration duration = const Duration(seconds: 4),
}) {
  final config = _configForType(type);

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: duration,
      backgroundColor: config.background,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: AppSpacing.md,
      ),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      elevation: 8,
      content: Row(
        children: [
          // Icon badge
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(
              left: AppSpacing.sm,
              top: AppSpacing.sm,
              bottom: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Center(
              child: FaIcon(
                config.icon,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Text content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title,
                      style: AppTextStyles.label.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    message,
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // Dismiss button
          IconButton(
            icon: const FaIcon(
              FontAwesomeIcons.xmark,
              size: 14,
              color: Colors.white70,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
            splashRadius: 16,
            padding: const EdgeInsets.all(AppSpacing.sm),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    ),
  );
}

class _SnackbarConfig {
  final Color background;
  final IconData icon;

  const _SnackbarConfig({required this.background, required this.icon});
}

_SnackbarConfig _configForType(SnackbarType type) {
  switch (type) {
    case SnackbarType.success:
      return const _SnackbarConfig(
        background: Color(0xFF047857), // green
        icon: FontAwesomeIcons.check,
      );
    case SnackbarType.info:
      return const _SnackbarConfig(
        background: Color(0xFF0E7490), // teal
        icon: FontAwesomeIcons.circleInfo,
      );
    case SnackbarType.warning:
      return const _SnackbarConfig(
        background: Color(0xFFB45309), // amber
        icon: FontAwesomeIcons.triangleExclamation,
      );
    case SnackbarType.error:
      return const _SnackbarConfig(
        background: Color(0xFFB91C1C), // red
        icon: FontAwesomeIcons.circleExclamation,
      );
  }
}
