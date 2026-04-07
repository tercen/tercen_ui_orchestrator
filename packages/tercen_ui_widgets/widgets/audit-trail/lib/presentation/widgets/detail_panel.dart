import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_line_weights.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/audit_event.dart';
import '../providers/audit_trail_provider.dart';
import 'event_type_chip.dart';

/// Detail panel occupying the right ~45% of the active body.
///
/// Spec Section 6: shows full metadata for the selected event.
/// Different layout for Activity vs Task events.
class DetailPanel extends StatelessWidget {
  const DetailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuditTrailProvider>();
    final event = provider.selectedEvent;

    if (event == null) {
      return _buildNoSelection(context);
    }

    return _DetailContent(event: event);
  }

  Widget _buildNoSelection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;

    return Center(
      child: Text(
        'Select an event to view details',
        style: AppTextStyles.body.copyWith(color: mutedColor),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final AuditEvent event;
  static final DateFormat _fullFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  const _DetailContent({required this.event});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.read<AuditTrailProvider>();
    final borderColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: type chip + full timestamp
          _buildSection(
            context,
            children: [
              Row(
                children: [
                  EventTypeChip(eventType: event.eventType),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _fullFmt.format(event.timestamp),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColorsDark.textMuted
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _divider(borderColor),

          // User
          _buildLabelValue(context, 'User', event.userId),
          _divider(borderColor),

          // Scope: Team > Project (as navigation links)
          _buildSection(context, children: [
            _buildLabel(context, 'Scope'),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                _navLink(context, event.teamId, () {
                  debugPrint(
                      '[EventBus] openProject: team=${event.teamId}');
                }),
                Text(
                  '  >  ',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColorsDark.textMuted
                        : AppColors.textMuted,
                  ),
                ),
                Expanded(
                  child: _navLink(context, event.projectName, () {
                    provider.navigateToTarget(AuditEvent(
                      id: '',
                      source: event.source,
                      timestamp: event.timestamp,
                      eventType: 'create',
                      objectKind: 'Project',
                      userId: event.userId,
                      teamId: event.teamId,
                      projectId: event.projectId,
                      projectName: event.projectName,
                      targetId: event.projectId,
                      targetName: event.projectName,
                    ));
                  }),
                ),
              ],
            ),
          ]),
          _divider(borderColor),

          // Action
          _buildLabelValue(context, 'Action', event.actionSummary),
          _divider(borderColor),

          // Target with navigation link
          _buildSection(context, children: [
            _buildLabel(context, 'Target'),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _navLink(context, event.targetName, () {
                    provider.navigateToTarget(event);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '(${event.objectKind})',
              style: AppTextStyles.bodySmall.copyWith(
                color:
                    isDark ? AppColorsDark.textMuted : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            SelectableText(
              'ID: ${event.targetId}',
              style: AppTextStyles.bodySmall.copyWith(
                color:
                    isDark ? AppColorsDark.textTertiary : AppColors.textTertiary,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ]),
          _divider(borderColor),

          // Task-specific sections
          if (event.source == EventSource.task) ...[
            _buildTaskDetails(context),
            _divider(borderColor),
          ],

          // Properties / Details
          _buildSection(context, children: [
            _buildLabel(
                context,
                event.source == EventSource.activity
                    ? 'Properties'
                    : 'Metadata'),
            const SizedBox(height: AppSpacing.sm),
            ...event.details.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: SelectableText(
                        entry.key,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColorsDark.textMuted
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        entry.value,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColorsDark.textPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
          _divider(borderColor),

          // Metadata footer
          _buildSection(context, children: [
            _buildLabel(context, 'Record Info'),
            const SizedBox(height: AppSpacing.xs),
            _metaRow(context, 'Source', event.source.name),
            _metaRow(context, 'Public', event.isPublic ? 'Yes' : 'No'),
            _metaRow(context, 'Record ID', event.id),
          ]),
        ],
      ),
    );
  }

  Widget _buildTaskDetails(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final details = event.details;

    return _buildSection(context, children: [
      _buildLabel(context, 'Task Timing'),
      const SizedBox(height: AppSpacing.sm),
      if (details.containsKey('createdDate'))
        _metaRow(context, 'Created', details['createdDate']!),
      if (details.containsKey('runDate'))
        _metaRow(context, 'Run', details['runDate']!),
      if (details.containsKey('completedDate'))
        _metaRow(context, 'Completed', details['completedDate']!),
      if (details.containsKey('duration'))
        _metaRow(context, 'Duration', _formatDuration(details['duration']!)),
      if (details.containsKey('error')) ...[
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: isDark
                ? AppColorsDark.error.withValues(alpha: 0.1)
                : AppColors.errorLight,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: SelectableText(
            details['error']!,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? AppColorsDark.error : AppColors.error,
            ),
          ),
        ),
      ],
    ]);
  }

  String _formatDuration(String seconds) {
    final secs = double.tryParse(seconds) ?? 0;
    final mins = (secs / 60).floor();
    final remainSecs = (secs % 60).floor();
    if (mins > 0) {
      return '${mins}m ${remainSecs}s';
    }
    return '${remainSecs}s';
  }

  Widget _buildSection(BuildContext context,
      {required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: AppTextStyles.sectionHeader.copyWith(
        color: isDark ? AppColorsDark.textMuted : AppColors.textMuted,
      ),
    );
  }

  Widget _buildLabelValue(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildSection(context, children: [
      _buildLabel(context, label),
      const SizedBox(height: AppSpacing.xs),
      SelectableText(
        value,
        style: AppTextStyles.body.copyWith(
          color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
        ),
      ),
    ]);
  }

  Widget _metaRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColorsDark.textMuted : AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark
                    ? AppColorsDark.textPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navLink(BuildContext context, String text, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linkColor = isDark ? AppColorsDark.link : AppColors.link;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          style: AppTextStyles.body.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _divider(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Divider(
        height: AppLineWeights.lineSubtle,
        thickness: AppLineWeights.lineSubtle,
        color: color,
      ),
    );
  }
}
