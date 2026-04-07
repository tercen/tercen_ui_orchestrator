import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Result returned from the New Project dialog.
class NewProjectResult {
  final String name;
  final String description;
  final String teamId;
  final bool isPublic;
  final String? gitUrl;
  final String? gitBranch;
  final String? gitCommit;
  final String? gitTag;
  final String? gitToken;

  const NewProjectResult({
    required this.name,
    required this.description,
    required this.teamId,
    required this.isPublic,
    this.gitUrl,
    this.gitBranch,
    this.gitCommit,
    this.gitTag,
    this.gitToken,
  });

  bool get isFromGit => gitUrl != null && gitUrl!.isNotEmpty;
}

/// Shows the New Project dialog and returns a [NewProjectResult] or null.
Future<NewProjectResult?> showNewProjectDialog(
  BuildContext context, {
  required List<String> teams,
}) {
  return showDialog<NewProjectResult>(
    context: context,
    builder: (ctx) => _NewProjectDialog(teams: teams),
  );
}

class _NewProjectDialog extends StatefulWidget {
  final List<String> teams;
  const _NewProjectDialog({required this.teams});

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _teamSearchController = TextEditingController();
  final _gitUrlController = TextEditingController();
  final _gitBranchController = TextEditingController(text: 'main');
  final _gitCommitController = TextEditingController();
  final _gitTagController = TextEditingController();
  final _gitTokenController = TextEditingController();

  late String _selectedTeam;
  bool _isPublic = false;
  bool _showGit = false;
  String? _nameError;
  String? _gitUrlError;
  bool _teamDropdownOpen = false;
  String _teamFilter = '';

  static final _forbiddenChars = RegExp(r'''[:/\\?#\[\]@!$&'()*+,;=]''');

  @override
  void initState() {
    super.initState();
    _selectedTeam = widget.teams.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _teamSearchController.dispose();
    _gitUrlController.dispose();
    _gitBranchController.dispose();
    _gitCommitController.dispose();
    _gitTagController.dispose();
    _gitTokenController.dispose();
    super.dispose();
  }

  List<String> get _filteredTeams {
    if (_teamFilter.isEmpty) return widget.teams;
    final lower = _teamFilter.toLowerCase();
    return widget.teams
        .where((t) => t.toLowerCase().contains(lower))
        .toList();
  }

  void _submit() {
    final name = _nameController.text.trim();
    bool hasError = false;

    if (name.isEmpty) {
      setState(() => _nameError = 'Project name is required');
      hasError = true;
    } else if (_forbiddenChars.hasMatch(name)) {
      setState(() => _nameError =
          'Name cannot contain: : / \\ ? # [ ] @ ! \$ & \' ( ) * + , ; =');
      hasError = true;
    }

    if (_showGit && _gitUrlController.text.trim().isEmpty) {
      setState(() => _gitUrlError = 'Repository URL is required');
      hasError = true;
    }

    if (hasError) return;

    Navigator.of(context).pop(NewProjectResult(
      name: name,
      description: _descriptionController.text.trim(),
      teamId: _selectedTeam,
      isPublic: _isPublic,
      gitUrl: _showGit ? _gitUrlController.text.trim() : null,
      gitBranch: _showGit ? _gitBranchController.text.trim() : null,
      gitCommit: _showGit ? _gitCommitController.text.trim() : null,
      gitTag: _showGit ? _gitTagController.text.trim() : null,
      gitToken: _showGit ? _gitTokenController.text.trim() : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? AppColorsDark.surfaceElevated : AppColors.surface;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final mutedColor =
        isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final borderColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: BorderSide(color: borderColor),
    );
    final focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: BorderSide(color: primary, width: 1.5),
    );
    const inputPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.sm,
    );

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'New Project',
                style: AppTextStyles.h2.copyWith(color: textColor),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Project Name
              _FieldLabel(label: 'Project Name', textColor: textColor),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: AppTextStyles.body.copyWith(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Enter project name',
                  hintStyle: AppTextStyles.body.copyWith(color: mutedColor),
                  errorText: _nameError,
                  contentPadding: inputPadding,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: focusedInputBorder,
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Team (with search)
              _FieldLabel(label: 'Team', textColor: textColor),
              const SizedBox(height: AppSpacing.xs),
              _SearchableTeamDropdown(
                teams: widget.teams,
                selectedTeam: _selectedTeam,
                isOpen: _teamDropdownOpen,
                filteredTeams: _filteredTeams,
                searchController: _teamSearchController,
                onToggle: () =>
                    setState(() => _teamDropdownOpen = !_teamDropdownOpen),
                onSelect: (team) => setState(() {
                  _selectedTeam = team;
                  _teamDropdownOpen = false;
                  _teamFilter = '';
                  _teamSearchController.clear();
                }),
                onFilterChanged: (val) =>
                    setState(() => _teamFilter = val),
              ),
              const SizedBox(height: AppSpacing.md),

              // Description
              _FieldLabel(label: 'Description', textColor: textColor),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _descriptionController,
                style: AppTextStyles.body.copyWith(color: textColor),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Optional description',
                  hintStyle: AppTextStyles.body.copyWith(color: mutedColor),
                  contentPadding: inputPadding,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: focusedInputBorder,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Options row: Public toggle + Git icon button
              Row(
                children: [
                  // Public toggle
                  Tooltip(
                    message:
                        'Make this visible to everyone on the server.',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 40,
                          child: FittedBox(
                            child: Switch(
                              value: _isPublic,
                              activeTrackColor: primary,
                              onChanged: (val) =>
                                  setState(() => _isPublic = val),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Public',
                          style: AppTextStyles.label
                              .copyWith(color: textColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),

                  // Git toggle icon button
                  _GitToggleButton(
                    isActive: _showGit,
                    onTap: () => setState(() => _showGit = !_showGit),
                  ),
                ],
              ),

              // Git fields (expand inline when toggled)
              if (_showGit) ...[
                const SizedBox(height: AppSpacing.md),
                _FieldLabel(
                    label: 'Repository URL', textColor: textColor),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _gitUrlController,
                  style: AppTextStyles.body.copyWith(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'https://github.com/owner/repo',
                    hintStyle:
                        AppTextStyles.body.copyWith(color: mutedColor),
                    errorText: _gitUrlError,
                    contentPadding: inputPadding,
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: focusedInputBorder,
                  ),
                  onChanged: (_) {
                    if (_gitUrlError != null) {
                      setState(() => _gitUrlError = null);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(
                              label: 'Branch', textColor: textColor),
                          const SizedBox(height: AppSpacing.xs),
                          TextField(
                            controller: _gitBranchController,
                            style: AppTextStyles.body
                                .copyWith(color: textColor),
                            decoration: InputDecoration(
                              hintText: 'main',
                              hintStyle: AppTextStyles.body
                                  .copyWith(color: mutedColor),
                              contentPadding: inputPadding,
                              border: inputBorder,
                              enabledBorder: inputBorder,
                              focusedBorder: focusedInputBorder,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(
                              label: 'Tag', textColor: textColor),
                          const SizedBox(height: AppSpacing.xs),
                          TextField(
                            controller: _gitTagController,
                            style: AppTextStyles.body
                                .copyWith(color: textColor),
                            decoration: InputDecoration(
                              hintText: 'e.g. v1.0.0',
                              hintStyle: AppTextStyles.body
                                  .copyWith(color: mutedColor),
                              contentPadding: inputPadding,
                              border: inputBorder,
                              enabledBorder: inputBorder,
                              focusedBorder: focusedInputBorder,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(
                              label: 'Commit', textColor: textColor),
                          const SizedBox(height: AppSpacing.xs),
                          TextField(
                            controller: _gitCommitController,
                            style: AppTextStyles.body
                                .copyWith(color: textColor),
                            decoration: InputDecoration(
                              hintText: 'Commit hash',
                              hintStyle: AppTextStyles.body
                                  .copyWith(color: mutedColor),
                              contentPadding: inputPadding,
                              border: inputBorder,
                              enabledBorder: inputBorder,
                              focusedBorder: focusedInputBorder,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(
                              label: 'Git Token', textColor: textColor),
                          const SizedBox(height: AppSpacing.xs),
                          TextField(
                            controller: _gitTokenController,
                            obscureText: true,
                            style: AppTextStyles.body
                                .copyWith(color: textColor),
                            decoration: InputDecoration(
                              hintText: 'For private repos',
                              hintStyle: AppTextStyles.body
                                  .copyWith(color: mutedColor),
                              contentPadding: inputPadding,
                              border: inputBorder,
                              enabledBorder: inputBorder,
                              focusedBorder: focusedInputBorder,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _GhostButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    child: Text(_showGit
                        ? 'Clone from Git'
                        : 'Create Project'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  final Color textColor;
  const _FieldLabel({required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: AppTextStyles.labelSmall.copyWith(color: textColor));
  }
}

/// Ghost button per Tercen style guide:
/// - Text: primary color
/// - Background: transparent
/// - Hover bg: neutral-200 (light) / neutral-700 (dark)
/// - No border
/// - Height: 36px, padding: 0 16px
class _GhostButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  const _GhostButton({required this.label, required this.onPressed});

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final hoverBg = isDark ? AppColorsDark.neutral700 : AppColors.neutral200;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: AppSpacing.controlHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: _hovered ? hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: AppTextStyles.label.copyWith(color: primary),
          ),
        ),
      ),
    );
  }
}

/// Git toggle icon button — secondary styling (outlined, 36x36 square).
/// Active state fills with primarySurface bg.
class _GitToggleButton extends StatefulWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _GitToggleButton({required this.isActive, required this.onTap});

  @override
  State<_GitToggleButton> createState() => _GitToggleButtonState();
}

class _GitToggleButtonState extends State<_GitToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final primarySurface =
        isDark ? AppColorsDark.primarySurface : AppColors.primarySurface;

    final Color bg;
    if (widget.isActive) {
      bg = primarySurface;
    } else if (_hovered) {
      bg = primarySurface;
    } else {
      bg = Colors.transparent;
    }

    return Tooltip(
      message: widget.isActive ? 'Remove Git source' : 'Add from Git',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: AppSpacing.controlHeight,
            height: AppSpacing.controlHeight,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(
                color: primary,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Center(
              child: FaIcon(
                FontAwesomeIcons.codeBranch,
                size: 16,
                color: primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Searchable team dropdown.
class _SearchableTeamDropdown extends StatelessWidget {
  final List<String> teams;
  final String selectedTeam;
  final bool isOpen;
  final List<String> filteredTeams;
  final TextEditingController searchController;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onFilterChanged;

  const _SearchableTeamDropdown({
    required this.teams,
    required this.selectedTeam,
    required this.isOpen,
    required this.filteredTeams,
    required this.searchController,
    required this.onToggle,
    required this.onSelect,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final mutedColor =
        isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final borderColor =
        isDark ? AppColorsDark.borderSubtle : AppColors.borderSubtle;
    final primary = isDark ? AppColorsDark.primary : AppColors.primary;
    final hoverBg =
        isDark ? AppColorsDark.surfaceElevated : AppColors.neutral50;
    final dropdownBg =
        isDark ? AppColorsDark.surfaceElevated : AppColors.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onToggle,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isOpen ? primary : borderColor,
                  width: isOpen ? 1.5 : 1.0,
                ),
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedTeam,
                      style:
                          AppTextStyles.body.copyWith(color: textColor),
                    ),
                  ),
                  Icon(
                    isOpen
                        ? Icons.arrow_drop_up
                        : Icons.arrow_drop_down,
                    size: 20,
                    color: mutedColor,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isOpen)
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            decoration: BoxDecoration(
              color: dropdownBg,
              border: Border.all(color: borderColor),
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusMd),
              boxShadow: isDark
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x12000000),
                        offset: Offset(0, 4),
                        blurRadius: 6,
                      ),
                    ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Search teams...',
                        hintStyle: AppTextStyles.bodySmall
                            .copyWith(color: mutedColor),
                        prefixIcon: Icon(Icons.search,
                            size: 16, color: mutedColor),
                        prefixIconConstraints:
                            const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd),
                          borderSide:
                              BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd),
                          borderSide:
                              BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd),
                          borderSide: BorderSide(
                              color: primary, width: 1.5),
                        ),
                      ),
                      onChanged: onFilterChanged,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(
                        bottom: AppSpacing.xs),
                    itemCount: filteredTeams.length,
                    itemBuilder: (context, index) {
                      final team = filteredTeams[index];
                      final isSelected = team == selectedTeam;
                      return _TeamOption(
                        team: team,
                        isSelected: isSelected,
                        textColor: textColor,
                        primary: primary,
                        hoverBg: hoverBg,
                        onTap: () => onSelect(team),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TeamOption extends StatefulWidget {
  final String team;
  final bool isSelected;
  final Color textColor;
  final Color primary;
  final Color hoverBg;
  final VoidCallback onTap;

  const _TeamOption({
    required this.team,
    required this.isSelected,
    required this.textColor,
    required this.primary,
    required this.hoverBg,
    required this.onTap,
  });

  @override
  State<_TeamOption> createState() => _TeamOptionState();
}

class _TeamOptionState extends State<_TeamOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs + 2,
          ),
          color: _hovered ? widget.hoverBg : Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.team,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: widget.isSelected
                        ? widget.primary
                        : widget.textColor,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (widget.isSelected)
                Icon(Icons.check, size: 14, color: widget.primary),
            ],
          ),
        ),
      ),
    );
  }
}
