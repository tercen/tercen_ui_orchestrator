import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Compact chip displaying an event type with FA6 icon and colour token.
///
/// Spec Section 5.2: each event type has an icon, label, and colour token.
class EventTypeChip extends StatelessWidget {
  final String eventType;
  final bool compact;

  const EventTypeChip({
    super.key,
    required this.eventType,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = _chipConfig(eventType, isDark);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs + 2 : AppSpacing.sm,
        vertical: compact ? 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            config.icon,
            size: compact ? 10 : 12,
            color: config.fgColor,
          ),
          SizedBox(width: compact ? 3 : AppSpacing.xs),
          Text(
            config.label,
            style: (compact ? AppTextStyles.bodySmall : AppTextStyles.labelSmall)
                .copyWith(color: config.fgColor),
          ),
        ],
      ),
    );
  }
}

class _ChipConfig {
  final IconData icon;
  final String label;
  final Color fgColor;
  final Color bgColor;

  const _ChipConfig({
    required this.icon,
    required this.label,
    required this.fgColor,
    required this.bgColor,
  });
}

_ChipConfig _chipConfig(String eventType, bool isDark) {
  switch (eventType) {
    case 'create':
      return _ChipConfig(
        icon: FontAwesomeIcons.plus,
        label: 'Create',
        fgColor: isDark ? AppColorsDark.success : AppColors.success,
        bgColor: isDark
            ? AppColorsDark.success.withValues(alpha: 0.15)
            : AppColors.successLight,
      );
    case 'update':
      return _ChipConfig(
        icon: FontAwesomeIcons.penToSquare,
        label: 'Update',
        fgColor: isDark ? AppColorsDark.info : AppColors.info,
        bgColor: isDark
            ? AppColorsDark.info.withValues(alpha: 0.15)
            : AppColors.infoLight,
      );
    case 'delete':
      return _ChipConfig(
        icon: FontAwesomeIcons.trash,
        label: 'Delete',
        fgColor: isDark ? AppColorsDark.error : AppColors.error,
        bgColor: isDark
            ? AppColorsDark.error.withValues(alpha: 0.15)
            : AppColors.errorLight,
      );
    case 'run':
      return _ChipConfig(
        icon: FontAwesomeIcons.play,
        label: 'Run',
        fgColor: isDark ? AppColorsDark.info : AppColors.info,
        bgColor: isDark
            ? AppColorsDark.info.withValues(alpha: 0.15)
            : AppColors.infoLight,
      );
    case 'complete':
      return _ChipConfig(
        icon: FontAwesomeIcons.check,
        label: 'Done',
        fgColor: isDark ? AppColorsDark.success : AppColors.success,
        bgColor: isDark
            ? AppColorsDark.success.withValues(alpha: 0.15)
            : AppColors.successLight,
      );
    case 'fail':
      return _ChipConfig(
        icon: FontAwesomeIcons.xmark,
        label: 'Failed',
        fgColor: isDark ? AppColorsDark.error : AppColors.error,
        bgColor: isDark
            ? AppColorsDark.error.withValues(alpha: 0.15)
            : AppColors.errorLight,
      );
    case 'cancel':
      return _ChipConfig(
        icon: FontAwesomeIcons.ban,
        label: 'Cancel',
        fgColor: isDark ? AppColorsDark.warning : AppColors.warning,
        bgColor: isDark
            ? AppColorsDark.warning.withValues(alpha: 0.15)
            : AppColors.warningLight,
      );
    default:
      return _ChipConfig(
        icon: FontAwesomeIcons.circle,
        label: eventType,
        fgColor: isDark ? AppColorsDark.textMuted : AppColors.textMuted,
        bgColor: isDark ? AppColorsDark.neutral700 : AppColors.neutral200,
      );
  }
}
