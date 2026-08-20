import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/institution_assessment_settings_controller.dart';
import '../application/institution_assessment_settings_state.dart';
import '../domain/institution_assessment_settings.dart';
import 'institution_understanding_categories_section.dart';

const _settingsSpacing = 16.0;
const _settingsPadding = 24.0;
const _settingsMaxWidth = 1000.0;
const _configurationRequiredText = 'Configuration required';
const _megabyteExplanation = '1 MB = 1,048,576 bytes';

class InstitutionAdminSettingsScreen extends ConsumerStatefulWidget {
  const InstitutionAdminSettingsScreen({required this.routePath, super.key});

  final String routePath;

  @override
  ConsumerState<InstitutionAdminSettingsScreen> createState() =>
      _InstitutionAdminSettingsScreenState();
}

class _InstitutionAdminSettingsScreenState
    extends ConsumerState<InstitutionAdminSettingsScreen> {
  final _scoreController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _learningLimitController = TextEditingController();
  final _submissionLimitController = TextEditingController();
  final _scoreFocus = FocusNode();
  final _timerFocus = FocusNode();
  final _studentReleaseFocus = FocusNode();
  final _parentReleaseFocus = FocusNode();
  final _timezoneFocus = FocusNode();
  final _learningLimitFocus = FocusNode();
  final _submissionLimitFocus = FocusNode();
  final _editFocus = FocusNode();
  InstitutionAssessmentSettingsStatus? _lastFocusStatus;
  InstitutionAssessmentSettingsField? _lastFocusField;

  @override
  void dispose() {
    _scoreController.dispose();
    _timezoneController.dispose();
    _learningLimitController.dispose();
    _submissionLimitController.dispose();
    _scoreFocus.dispose();
    _timerFocus.dispose();
    _studentReleaseFocus.dispose();
    _parentReleaseFocus.dispose();
    _timezoneFocus.dispose();
    _learningLimitFocus.dispose();
    _submissionLimitFocus.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionControllerProvider);
    final surface = ref.watch(appDeviceSurfaceProvider);
    final key = InstitutionAssessmentSettingsSessionSnapshot.from(
      session: session,
      surface: surface,
    ).eligibleKeyFor(widget.routePath);
    if (key == null) {
      return const SizedBox.shrink();
    }

    final provider = institutionAssessmentSettingsControllerProvider(key);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    _synchronizeControllers(state.draft);
    _scheduleInvalidFieldFocus(state);

    return _SettingsSurface(
      children: [
        _SettingsHeading(actions: _actions(context, state, controller)),
        if (state.status == InstitutionAssessmentSettingsStatus.refreshing) ...[
          const SizedBox(height: _settingsSpacing),
          const _SettingsProgress('Refreshing assessment settings…'),
        ] else if (state.status ==
            InstitutionAssessmentSettingsStatus.submitting) ...[
          const SizedBox(height: _settingsSpacing),
          const _SettingsProgress('Saving assessment settings…'),
        ] else if (state.status ==
            InstitutionAssessmentSettingsStatus.reconcilingCurrentState) ...[
          const SizedBox(height: _settingsSpacing),
          const _SettingsProgress('Checking current server settings…'),
        ],
        if (state.notice != null) ...[
          const SizedBox(height: _settingsSpacing),
          _SettingsNotice(state.notice!),
        ],
        if (state.formError != null) ...[
          const SizedBox(height: _settingsSpacing),
          _SettingsError(state.formError!),
        ],
        const SizedBox(height: _settingsSpacing),
        if (state.status == InstitutionAssessmentSettingsStatus.initial ||
            state.status == InstitutionAssessmentSettingsStatus.initialLoading)
          const _SettingsLoading()
        else if (state.status == InstitutionAssessmentSettingsStatus.loadError)
          _SettingsLoadError(onRetry: controller.retry)
        else if (state.isEditing ||
            state.status == InstitutionAssessmentSettingsStatus.submitting ||
            state.status ==
                InstitutionAssessmentSettingsStatus.reconcilingCurrentState)
          _SettingsForm(
            state: state,
            scoreController: _scoreController,
            timezoneController: _timezoneController,
            learningLimitController: _learningLimitController,
            submissionLimitController: _submissionLimitController,
            scoreFocus: _scoreFocus,
            timerFocus: _timerFocus,
            studentReleaseFocus: _studentReleaseFocus,
            parentReleaseFocus: _parentReleaseFocus,
            timezoneFocus: _timezoneFocus,
            learningLimitFocus: _learningLimitFocus,
            submissionLimitFocus: _submissionLimitFocus,
            onChanged: controller.updateField,
          )
        else if (state.settings != null)
          _SettingsSummary(settings: state.settings!),
        const SizedBox(height: _settingsSpacing),
        InstitutionUnderstandingCategoriesSection(routePath: widget.routePath),
      ],
    );
  }

  List<Widget> _actions(
    BuildContext context,
    InstitutionAssessmentSettingsState state,
    InstitutionAssessmentSettingsController controller,
  ) {
    if (state.status ==
        InstitutionAssessmentSettingsStatus.unconfirmedWithoutCurrentState) {
      return [
        OutlinedButton.icon(
          key: const Key('assessmentSettingsRefreshButton'),
          onPressed: controller.reloadUnconfirmedCurrentState,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ];
    }
    if (state.settings == null ||
        state.status == InstitutionAssessmentSettingsStatus.loadError) {
      return const [];
    }
    if (state.isEditing ||
        state.status == InstitutionAssessmentSettingsStatus.submitting ||
        state.status ==
            InstitutionAssessmentSettingsStatus.reconcilingCurrentState) {
      final busy = state.isBusy;
      return [
        OutlinedButton.icon(
          key: const Key('assessmentSettingsEditRefreshButton'),
          onPressed: busy
              ? null
              : () => _refreshFromEdit(context, state, controller),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
        TextButton(
          key: const Key('assessmentSettingsResetButton'),
          onPressed: busy ? null : controller.resetDraft,
          child: const Text('Reset'),
        ),
        OutlinedButton(
          key: const Key('assessmentSettingsCancelButton'),
          onPressed: busy
              ? null
              : () => _cancelEditingAndRestoreFocus(controller),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('assessmentSettingsSaveButton'),
          onPressed: busy ? null : controller.submit,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(busy ? 'Saving' : 'Save settings'),
        ),
      ];
    }
    return [
      OutlinedButton.icon(
        key: const Key('assessmentSettingsRefreshButton'),
        onPressed: state.isBusy ? null : () => controller.refresh(),
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
      FilledButton.icon(
        key: const Key('assessmentSettingsEditButton'),
        focusNode: _editFocus,
        onPressed: state.isBusy ? null : controller.beginEditing,
        icon: const Icon(Icons.edit_outlined),
        label: Text(
          state.settings!.educationalPolicyConfigured
              ? 'Edit settings'
              : 'Configure settings',
        ),
      ),
    ];
  }

  void _cancelEditingAndRestoreFocus(
    InstitutionAssessmentSettingsController controller,
  ) {
    controller.cancelEditing();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editFocus.canRequestFocus) {
        _editFocus.requestFocus();
      }
    });
  }

  Future<void> _refreshFromEdit(
    BuildContext context,
    InstitutionAssessmentSettingsState state,
    InstitutionAssessmentSettingsController controller,
  ) async {
    if (!state.isDirty) {
      await controller.refresh(discardDirty: true);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'Refreshing loads the current server settings and discards this local draft.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard and refresh'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      await controller.refresh(discardDirty: true);
    }
  }

  void _synchronizeControllers(InstitutionAssessmentSettingsDraft? draft) {
    if (draft == null) return;
    _setText(_scoreController, draft.acceptableScoreDifference);
    _setText(_timezoneController, draft.timezone);
    _setText(_learningLimitController, draft.learningMaterialMaxMb);
    _setText(_submissionLimitController, draft.studentSubmissionMaxMb);
  }

  void _scheduleInvalidFieldFocus(InstitutionAssessmentSettingsState state) {
    final field = state.focusField;
    if (field == null) {
      _lastFocusField = null;
      _lastFocusStatus = null;
      return;
    }
    if (_lastFocusStatus == state.status && _lastFocusField == field) return;
    _lastFocusStatus = state.status;
    _lastFocusField = field;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusFor(field).requestFocus();
    });
  }

  FocusNode _focusFor(InstitutionAssessmentSettingsField field) =>
      switch (field) {
        InstitutionAssessmentSettingsField.acceptableScoreDifference =>
          _scoreFocus,
        InstitutionAssessmentSettingsField.blitzTimerStartMode => _timerFocus,
        InstitutionAssessmentSettingsField.studentResultReleaseMode =>
          _studentReleaseFocus,
        InstitutionAssessmentSettingsField.parentResultReleaseMode =>
          _parentReleaseFocus,
        InstitutionAssessmentSettingsField.timezone => _timezoneFocus,
        InstitutionAssessmentSettingsField.learningMaterialMaxMb =>
          _learningLimitFocus,
        InstitutionAssessmentSettingsField.studentSubmissionMaxMb =>
          _submissionLimitFocus,
      };
}

void _setText(TextEditingController controller, String value) {
  if (controller.text != value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class _SettingsSurface extends StatelessWidget {
  const _SettingsSurface({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const Key('institutionAssessmentSettingsScreen'),
    padding: const EdgeInsets.all(_settingsPadding),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _settingsMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading({required this.actions});
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 12,
    children: [
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assessment settings',
            key: Key('assessmentSettingsHeading'),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text('Institution-wide assessment policy and upload limits.'),
        ],
      ),
      Wrap(spacing: 8, runSpacing: 8, children: actions),
    ],
  );
}

class _SettingsLoading extends StatelessWidget {
  const _SettingsLoading();
  @override
  Widget build(BuildContext context) => Center(
    key: const Key('assessmentSettingsLoading'),
    child: Semantics(
      liveRegion: true,
      label: 'Loading assessment settings',
      child: const CircularProgressIndicator(),
    ),
  );
}

class _SettingsProgress extends StatelessWidget {
  const _SettingsProgress(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: message,
    child: Row(
      key: const Key('assessmentSettingsProgress'),
      children: [
        const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class _SettingsLoadError extends StatelessWidget {
  const _SettingsLoadError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    key: const Key('assessmentSettingsLoadError'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('Assessment settings could not be loaded.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class _SettingsNotice extends StatelessWidget {
  const _SettingsNotice(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, key: const Key('assessmentSettingsNotice')),
      ),
    ),
  );
}

class _SettingsError extends StatelessWidget {
  const _SettingsError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, key: const Key('assessmentSettingsFormError')),
      ),
    ),
  );
}

class _SettingsSummary extends StatelessWidget {
  const _SettingsSummary({required this.settings});
  final InstitutionAssessmentSettings settings;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('assessmentSettingsSummary'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        color: settings.educationalPolicyConfigured
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            settings.educationalPolicyConfigured
                ? 'Educational policy status: Configured.'
                : 'Educational policy status: Not configured. Dependent assessment operations remain blocked until all required values are saved.',
          ),
        ),
      ),
      _SettingsCard(
        title: 'Assessment policy',
        children: [
          _SummaryRow(
            'Acceptable Homework–Blitz score difference',
            settings.acceptableScoreDifference?.canonical ??
                _configurationRequiredText,
          ),
          _SummaryRow(
            'Blitz timer start',
            _modeSummary(
              settings.blitzTimerStartMode?.label,
              settings.blitzTimerStartMode?.description,
            ),
          ),
          _SummaryRow(
            'Student result release',
            _modeSummary(
              settings.studentResultReleaseMode?.label,
              settings.studentResultReleaseMode?.description,
            ),
          ),
          _SummaryRow(
            'Parent result visibility',
            _modeSummary(
              settings.parentResultReleaseMode?.label,
              settings.parentResultReleaseMode?.description,
            ),
          ),
          _SummaryRow('Institution timezone', settings.timezone),
        ],
      ),
      const SizedBox(height: _settingsSpacing),
      _SettingsCard(
        title: 'File limits',
        children: [
          _SummaryRow(
            'Learning material maximum',
            '${settings.learningMaterialMaxMb} MB per file',
          ),
          _SummaryRow(
            'Student submission maximum',
            '${settings.studentSubmissionMaxMb} MB per file',
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(_megabyteExplanation),
          ),
        ],
      ),
      const SizedBox(height: _settingsSpacing),
      const _SettingsChangeExplanations(),
      const SizedBox(height: _settingsSpacing),
      _FixedAttemptFacts(settings: settings),
    ],
  );
}

class _SettingsForm extends StatelessWidget {
  const _SettingsForm({
    required this.state,
    required this.scoreController,
    required this.timezoneController,
    required this.learningLimitController,
    required this.submissionLimitController,
    required this.scoreFocus,
    required this.timerFocus,
    required this.studentReleaseFocus,
    required this.parentReleaseFocus,
    required this.timezoneFocus,
    required this.learningLimitFocus,
    required this.submissionLimitFocus,
    required this.onChanged,
  });

  final InstitutionAssessmentSettingsState state;
  final TextEditingController scoreController;
  final TextEditingController timezoneController;
  final TextEditingController learningLimitController;
  final TextEditingController submissionLimitController;
  final FocusNode scoreFocus;
  final FocusNode timerFocus;
  final FocusNode studentReleaseFocus;
  final FocusNode parentReleaseFocus;
  final FocusNode timezoneFocus;
  final FocusNode learningLimitFocus;
  final FocusNode submissionLimitFocus;
  final void Function(InstitutionAssessmentSettingsField, Object?) onChanged;

  @override
  Widget build(BuildContext context) {
    final draft = state.draft!;
    final settings = state.settings!;
    final disabled = state.isBusy;
    String? error(InstitutionAssessmentSettingsField field) =>
        state.fieldErrors[field];

    return Column(
      key: const Key('assessmentSettingsForm'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsCard(
          title: 'Assessment policy',
          children: [
            const Text(
              'Saving sends all seven assessment settings together as one complete replacement.',
            ),
            const SizedBox(height: _settingsSpacing),
            TextFormField(
              key: const Key('assessmentSettingsScoreDifferenceField'),
              controller: scoreController,
              focusNode: scoreFocus,
              enabled: !disabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Acceptable Homework–Blitz score difference',
                helperText: draft.acceptableScoreDifference.isEmpty
                    ? _configurationRequiredText
                    : '0 to 100, with up to 8 decimal places.',
                errorText: error(
                  InstitutionAssessmentSettingsField.acceptableScoreDifference,
                ),
              ),
              onChanged: (value) => onChanged(
                InstitutionAssessmentSettingsField.acceptableScoreDifference,
                value,
              ),
            ),
            const SizedBox(height: _settingsSpacing),
            _ModeDropdown<BlitzTimerStartMode>(
              fieldKey: const Key('assessmentSettingsTimerModeField'),
              label: 'Blitz timer start mode',
              value: draft.blitzTimerStartMode,
              values: BlitzTimerStartMode.values,
              labelFor: (value) => value.label,
              description: draft.blitzTimerStartMode?.description,
              errorText: error(
                InstitutionAssessmentSettingsField.blitzTimerStartMode,
              ),
              focusNode: timerFocus,
              enabled: !disabled,
              onChanged: (value) => onChanged(
                InstitutionAssessmentSettingsField.blitzTimerStartMode,
                value,
              ),
            ),
            const SizedBox(height: _settingsSpacing),
            _ModeDropdown<StudentResultReleaseMode>(
              fieldKey: const Key('assessmentSettingsStudentReleaseField'),
              label: 'Student result release',
              value: draft.studentResultReleaseMode,
              values: StudentResultReleaseMode.values,
              labelFor: (value) => value.label,
              description: draft.studentResultReleaseMode?.description,
              errorText: error(
                InstitutionAssessmentSettingsField.studentResultReleaseMode,
              ),
              focusNode: studentReleaseFocus,
              enabled: !disabled,
              onChanged: (value) => onChanged(
                InstitutionAssessmentSettingsField.studentResultReleaseMode,
                value,
              ),
            ),
            const SizedBox(height: _settingsSpacing),
            _ModeDropdown<ParentResultReleaseMode>(
              fieldKey: const Key('assessmentSettingsParentReleaseField'),
              label: 'Parent result visibility',
              value: draft.parentResultReleaseMode,
              values: ParentResultReleaseMode.values,
              labelFor: (value) => value.label,
              description: draft.parentResultReleaseMode?.description,
              errorText: error(
                InstitutionAssessmentSettingsField.parentResultReleaseMode,
              ),
              focusNode: parentReleaseFocus,
              enabled: !disabled,
              onChanged: (value) => onChanged(
                InstitutionAssessmentSettingsField.parentResultReleaseMode,
                value,
              ),
            ),
            const SizedBox(height: _settingsSpacing),
            TextFormField(
              key: const Key('assessmentSettingsTimezoneField'),
              controller: timezoneController,
              focusNode: timezoneFocus,
              enabled: !disabled,
              decoration: InputDecoration(
                labelText: 'Institution timezone',
                helperText:
                    'Use an IANA identifier such as Asia/Tashkent. Changing the timezone does not rewrite already stored absolute timestamps.',
                errorText: error(InstitutionAssessmentSettingsField.timezone),
              ),
              onChanged: (value) =>
                  onChanged(InstitutionAssessmentSettingsField.timezone, value),
            ),
          ],
        ),
        const SizedBox(height: _settingsSpacing),
        _SettingsCard(
          title: 'File limits',
          children: [
            const Text(_megabyteExplanation),
            const SizedBox(height: _settingsSpacing),
            TextFormField(
              key: const Key('assessmentSettingsLearningLimitField'),
              controller: learningLimitController,
              focusNode: learningLimitFocus,
              enabled: !disabled,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Learning material maximum (MB per file)',
                helperText:
                    'May not exceed the platform maximum of ${settings.platformLearningMaterialMaxMb} MB.',
                errorText: error(
                  InstitutionAssessmentSettingsField.learningMaterialMaxMb,
                ),
              ),
              onChanged: (value) => onChanged(
                InstitutionAssessmentSettingsField.learningMaterialMaxMb,
                value,
              ),
            ),
            const SizedBox(height: _settingsSpacing),
            TextFormField(
              key: const Key('assessmentSettingsSubmissionLimitField'),
              controller: submissionLimitController,
              focusNode: submissionLimitFocus,
              enabled: !disabled,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Student submission maximum (MB per file)',
                helperText:
                    'May not exceed the platform maximum of ${settings.platformStudentSubmissionMaxMb} MB.',
                errorText: error(
                  InstitutionAssessmentSettingsField.studentSubmissionMaxMb,
                ),
              ),
              onChanged: (value) => onChanged(
                InstitutionAssessmentSettingsField.studentSubmissionMaxMb,
                value,
              ),
            ),
          ],
        ),
        const SizedBox(height: _settingsSpacing),
        const _SettingsChangeExplanations(),
        const SizedBox(height: _settingsSpacing),
        _FixedAttemptFacts(settings: settings),
      ],
    );
  }
}

class _ModeDropdown<T> extends StatelessWidget {
  const _ModeDropdown({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.description,
    required this.errorText,
    required this.focusNode,
    required this.enabled,
    required this.onChanged,
  });
  final Key fieldKey;
  final String label;
  final T? value;
  final List<T> values;
  final String Function(T) labelFor;
  final String? description;
  final String? errorText;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: fieldKey,
    child: DropdownButtonFormField<T>(
      key: ValueKey<T?>(value),
      initialValue: value,
      focusNode: focusNode,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: description ?? _configurationRequiredText,
        errorText: errorText,
      ),
      items: values
          .map(
            (item) =>
                DropdownMenuItem<T>(value: item, child: Text(labelFor(item))),
          )
          .toList(growable: false),
      onChanged: enabled ? onChanged : null,
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Divider(height: 24),
          ...children,
        ],
      ),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value),
      ],
    ),
  );
}

String _modeSummary(String? label, String? description) {
  if (label == null || description == null) {
    return _configurationRequiredText;
  }
  return '$label — $description';
}

class _FixedAttemptFacts extends StatelessWidget {
  const _FixedAttemptFacts({required this.settings});
  final InstitutionAssessmentSettings settings;
  @override
  Widget build(BuildContext context) => _SettingsCard(
    title: 'Read-only server facts',
    children: [
      _SummaryRow(
        'Homework normal attempts',
        '${settings.homeworkNormalAttempts}',
      ),
      _SummaryRow('Blitz normal attempts', '${settings.blitzNormalAttempts}'),
      _SummaryRow(
        'Maximum additional exception attempts per Student and Blitz',
        '${settings.blitzMaxAdditionalExceptionAttempts}',
      ),
      _SummaryRow(
        'Platform maximum learning material size',
        '${settings.platformLearningMaterialMaxMb} MB',
      ),
      _SummaryRow(
        'Platform maximum student submission size',
        '${settings.platformStudentSubmissionMaxMb} MB',
      ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Fixed attempt rules and platform upload maxima are read-only server facts.',
        ),
      ),
    ],
  );
}

class _SettingsChangeExplanations extends StatelessWidget {
  const _SettingsChangeExplanations();

  @override
  Widget build(BuildContext context) => _SettingsCard(
    title: 'How changes take effect',
    children: [
      const Text(
        '• These settings control future dependent behavior according to backend rules.',
      ),
      const SizedBox(height: 8),
      const Text(
        '• Changing timezone does not rewrite already stored absolute timestamps.',
      ),
      const SizedBox(height: 8),
      const Text(
        '• Changing timer/release/threshold settings does not rewrite active snapshots, calculated/closed results, release history, or category snapshots.',
      ),
      const SizedBox(height: 8),
      const Text('• Parent visibility never precedes Student visibility.'),
      const SizedBox(height: 8),
      const Text(
        '• Lowering upload limits affects future uploads only. Existing files are not revalidated or deleted.',
      ),
      const SizedBox(height: 8),
      const Text(
        '• This screen manages Institution assessment settings only. Learning, Homework, Blitz, results, files, and categories apply them through their own workflows.',
      ),
    ],
  );
}
