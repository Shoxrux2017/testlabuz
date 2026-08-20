import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/institution_understanding_categories_controller.dart';
import '../application/institution_understanding_categories_state.dart';
import '../domain/institution_understanding_categories.dart';

const _categorySpacing = 16.0;
const _validCoverageSummary =
    'All integer scores from 0 through 100 are covered exactly once.';

class InstitutionUnderstandingCategoriesSection extends ConsumerStatefulWidget {
  const InstitutionUnderstandingCategoriesSection({
    required this.routePath,
    super.key,
  });

  final String routePath;

  @override
  ConsumerState<InstitutionUnderstandingCategoriesSection> createState() =>
      _InstitutionUnderstandingCategoriesSectionState();
}

class _InstitutionUnderstandingCategoriesSectionState
    extends ConsumerState<InstitutionUnderstandingCategoriesSection> {
  final _textControllers =
      <InstitutionUnderstandingCategoryField, TextEditingController>{
        for (final field in InstitutionUnderstandingCategoryField.values)
          field: TextEditingController(),
      };
  final _focusNodes = <InstitutionUnderstandingCategoryField, FocusNode>{
    for (final field in InstitutionUnderstandingCategoryField.values)
      field: FocusNode(),
  };
  final _editFocus = FocusNode();
  InstitutionUnderstandingCategoriesStatus? _lastFocusStatus;
  InstitutionUnderstandingCategoryField? _lastFocusField;

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _editFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionControllerProvider);
    final surface = ref.watch(appDeviceSurfaceProvider);
    final key = InstitutionUnderstandingCategoriesSessionSnapshot.from(
      session: session,
      surface: surface,
    ).eligibleKeyFor(widget.routePath);
    if (key == null) return const SizedBox.shrink();

    final provider = institutionUnderstandingCategoriesControllerProvider(key);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    _synchronizeControllers(state.draft);
    _scheduleInvalidFieldFocus(state);

    return Column(
      key: const Key('understandingCategoriesSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryHeading(actions: _actions(context, state, controller)),
        if (state.status ==
            InstitutionUnderstandingCategoriesStatus.refreshing) ...[
          const SizedBox(height: _categorySpacing),
          const _CategoryProgress('Refreshing understanding categories…'),
        ] else if (state.status ==
            InstitutionUnderstandingCategoriesStatus.submitting) ...[
          const SizedBox(height: _categorySpacing),
          const _CategoryProgress('Saving understanding categories…'),
        ] else if (state.status ==
            InstitutionUnderstandingCategoriesStatus
                .reconcilingCurrentState) ...[
          const SizedBox(height: _categorySpacing),
          const _CategoryProgress('Checking current server categories…'),
        ],
        if (state.notice != null) ...[
          const SizedBox(height: _categorySpacing),
          _CategoryNotice(state.notice!),
        ],
        if (state.formError != null) ...[
          const SizedBox(height: _categorySpacing),
          _CategoryError(state.formError!),
        ],
        const SizedBox(height: _categorySpacing),
        if (state.status == InstitutionUnderstandingCategoriesStatus.initial ||
            state.status ==
                InstitutionUnderstandingCategoriesStatus.initialLoading)
          const _CategoryLoading()
        else if (state.status ==
            InstitutionUnderstandingCategoriesStatus.loadError)
          _CategoryLoadError(onRetry: controller.retry)
        else if (state.isEditing ||
            state.status ==
                InstitutionUnderstandingCategoriesStatus.submitting ||
            state.status ==
                InstitutionUnderstandingCategoriesStatus
                    .reconcilingCurrentState)
          _CategoryEditor(
            state: state,
            textControllers: _textControllers,
            focusNodes: _focusNodes,
            onChanged: controller.updateField,
          )
        else if (state.configuration != null)
          _CategorySummary(configuration: state.configuration!),
      ],
    );
  }

  List<Widget> _actions(
    BuildContext context,
    InstitutionUnderstandingCategoriesState state,
    InstitutionUnderstandingCategoriesController controller,
  ) {
    if (state.status ==
        InstitutionUnderstandingCategoriesStatus
            .unconfirmedWithoutCurrentState) {
      return [
        OutlinedButton.icon(
          key: const Key('understandingCategoriesRefreshButton'),
          onPressed: controller.reloadUnconfirmedCurrentState,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ];
    }
    if (state.configuration == null ||
        state.status == InstitutionUnderstandingCategoriesStatus.loadError) {
      return const [];
    }
    if (state.isEditing ||
        state.status == InstitutionUnderstandingCategoriesStatus.submitting ||
        state.status ==
            InstitutionUnderstandingCategoriesStatus.reconcilingCurrentState) {
      final busy = state.isBusy;
      return [
        OutlinedButton.icon(
          key: const Key('understandingCategoriesEditRefreshButton'),
          onPressed: busy
              ? null
              : () => _refreshFromEdit(context, state, controller),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
        TextButton(
          key: const Key('understandingCategoriesResetButton'),
          onPressed: busy ? null : controller.resetDraft,
          child: const Text('Reset'),
        ),
        OutlinedButton(
          key: const Key('understandingCategoriesCancelButton'),
          onPressed: busy
              ? null
              : () => _cancelEditingAndRestoreFocus(controller),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('understandingCategoriesSaveButton'),
          onPressed: busy ? null : controller.submit,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(busy ? 'Saving' : 'Save categories'),
        ),
      ];
    }
    return [
      OutlinedButton.icon(
        key: const Key('understandingCategoriesRefreshButton'),
        onPressed: state.isBusy ? null : () => controller.refresh(),
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
      FilledButton.icon(
        key: const Key('understandingCategoriesEditButton'),
        focusNode: _editFocus,
        onPressed: state.isBusy ? null : controller.beginEditing,
        icon: const Icon(Icons.edit_outlined),
        label: Text(
          state.configuration!.configured
              ? 'Edit categories'
              : 'Configure categories',
        ),
      ),
    ];
  }

  void _cancelEditingAndRestoreFocus(
    InstitutionUnderstandingCategoriesController controller,
  ) {
    controller.cancelEditing();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editFocus.canRequestFocus) _editFocus.requestFocus();
    });
  }

  Future<void> _refreshFromEdit(
    BuildContext context,
    InstitutionUnderstandingCategoriesState state,
    InstitutionUnderstandingCategoriesController controller,
  ) async {
    if (!state.isDirty) {
      await controller.refresh(discardDirty: true);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard category changes?'),
        content: const Text(
          'Refreshing loads current server categories and discards only this category draft.',
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

  void _synchronizeControllers(InstitutionUnderstandingCategoryDraft? draft) {
    if (draft == null) return;
    for (final field in InstitutionUnderstandingCategoryField.values) {
      final controller = _textControllers[field]!;
      final value = draft.valueFor(field);
      if (controller.text != value) {
        controller.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    }
  }

  void _scheduleInvalidFieldFocus(
    InstitutionUnderstandingCategoriesState state,
  ) {
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
      if (mounted) _focusNodes[field]!.requestFocus();
    });
  }
}

class _CategoryHeading extends StatelessWidget {
  const _CategoryHeading({required this.actions});
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
            'Understanding categories',
            key: Key('understandingCategoriesHeading'),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text('Fixed meanings with Institution-specific integer ranges.'),
        ],
      ),
      Wrap(spacing: 8, runSpacing: 8, children: actions),
    ],
  );
}

class _CategoryLoading extends StatelessWidget {
  const _CategoryLoading();
  @override
  Widget build(BuildContext context) => Center(
    key: const Key('understandingCategoriesLoading'),
    child: Semantics(
      liveRegion: true,
      label: 'Loading understanding categories',
      child: const CircularProgressIndicator(),
    ),
  );
}

class _CategoryProgress extends StatelessWidget {
  const _CategoryProgress(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: message,
    child: Row(
      key: const Key('understandingCategoriesProgress'),
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

class _CategoryLoadError extends StatelessWidget {
  const _CategoryLoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('understandingCategoriesLoadError'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('Understanding categories could not be loaded.'),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('understandingCategoriesRetryButton'),
            onPressed: onRetry,
            child: const Text('Retry categories'),
          ),
        ],
      ),
    ),
  );
}

class _CategoryNotice extends StatelessWidget {
  const _CategoryNotice(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, key: const Key('understandingCategoriesNotice')),
      ),
    ),
  );
}

class _CategoryError extends StatelessWidget {
  const _CategoryError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          key: const Key('understandingCategoriesFormError'),
        ),
      ),
    ),
  );
}

class _CategorySummary extends StatelessWidget {
  const _CategorySummary({required this.configuration});
  final InstitutionUnderstandingCategoryConfiguration configuration;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('understandingCategoriesSummary'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        color: configuration.configured
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            configuration.configured
                ? 'Understanding category status: Configured.'
                : 'Understanding category status: Configuration required.',
          ),
        ),
      ),
      for (final definition in UnderstandingCategoryDefinition.values) ...[
        const SizedBox(height: 8),
        _CategoryIdentityCard(
          definition: definition,
          range: _rangeText(configuration, definition),
        ),
      ],
      const SizedBox(height: _categorySpacing),
      if (configuration.configured)
        const _CoverageSummary(valid: true, message: _validCoverageSummary),
      const SizedBox(height: _categorySpacing),
      const _CategoryMeaning(),
    ],
  );
}

class _CategoryEditor extends StatelessWidget {
  const _CategoryEditor({
    required this.state,
    required this.textControllers,
    required this.focusNodes,
    required this.onChanged,
  });

  final InstitutionUnderstandingCategoriesState state;
  final Map<InstitutionUnderstandingCategoryField, TextEditingController>
  textControllers;
  final Map<InstitutionUnderstandingCategoryField, FocusNode> focusNodes;
  final void Function(InstitutionUnderstandingCategoryField, String) onChanged;

  @override
  Widget build(BuildContext context) {
    final draft = state.draft!;
    final preview = draft.validate();
    final coverageMessage = preview.isValid
        ? _validCoverageSummary
        : state.setError ??
              'Enter one complete high-to-low partition of every integer score from 0 through 100.';

    return Column(
      key: const Key('understandingCategoriesForm'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Saving sends all five fixed categories together as one complete replacement. Only the first four inclusive integer ranges are editable.',
        ),
        const SizedBox(height: _categorySpacing),
        for (final definition in UnderstandingCategoryDefinition.values) ...[
          _CategoryEditorCard(
            definition: definition,
            draft: draft,
            disabled: state.isBusy,
            fieldErrors: state.fieldErrors,
            textControllers: textControllers,
            focusNodes: focusNodes,
            onChanged: onChanged,
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        _CoverageSummary(valid: preview.isValid, message: coverageMessage),
        const SizedBox(height: _categorySpacing),
        const _CategoryMeaning(),
      ],
    );
  }
}

class _CategoryEditorCard extends StatelessWidget {
  const _CategoryEditorCard({
    required this.definition,
    required this.draft,
    required this.disabled,
    required this.fieldErrors,
    required this.textControllers,
    required this.focusNodes,
    required this.onChanged,
  });

  final UnderstandingCategoryDefinition definition;
  final InstitutionUnderstandingCategoryDraft draft;
  final bool disabled;
  final Map<InstitutionUnderstandingCategoryField, String> fieldErrors;
  final Map<InstitutionUnderstandingCategoryField, TextEditingController>
  textControllers;
  final Map<InstitutionUnderstandingCategoryField, FocusNode> focusNodes;
  final void Function(InstitutionUnderstandingCategoryField, String) onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CategoryIdentity(definition: definition),
          const SizedBox(height: 12),
          if (!definition.numeric)
            Semantics(
              label: 'Not completed has no numeric range and is read only',
              child: Text(
                'Non-numeric and read-only: min_score = null, max_score = null.',
                key: Key('understandingCategoryNotCompletedReadOnly'),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final fieldWidth = constraints.maxWidth >= 520
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: _CategoryScoreField(
                        field: _minimumField(definition),
                        label: '${definition.label} minimum inclusive score',
                        controller: textControllers[_minimumField(definition)]!,
                        focusNode: focusNodes[_minimumField(definition)]!,
                        enabled: !disabled,
                        errorText: fieldErrors[_minimumField(definition)],
                        onChanged: onChanged,
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _CategoryScoreField(
                        field: _maximumField(definition),
                        label: '${definition.label} maximum inclusive score',
                        controller: textControllers[_maximumField(definition)]!,
                        focusNode: focusNodes[_maximumField(definition)]!,
                        enabled: !disabled,
                        errorText: fieldErrors[_maximumField(definition)],
                        onChanged: onChanged,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    ),
  );
}

class _CategoryScoreField extends StatelessWidget {
  const _CategoryScoreField({
    required this.field,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
  });

  final InstitutionUnderstandingCategoryField field;
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String? errorText;
  final void Function(InstitutionUnderstandingCategoryField, String) onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: Key('understandingCategory${field.name}Field'),
    controller: controller,
    focusNode: focusNode,
    enabled: enabled,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: label,
      helperText: 'Required integer from 0 to 100.',
      errorText: errorText,
    ),
    onChanged: (value) => onChanged(field, value),
  );
}

class _CategoryIdentityCard extends StatelessWidget {
  const _CategoryIdentityCard({required this.definition, required this.range});
  final UnderstandingCategoryDefinition definition;
  final String range;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CategoryIdentity(definition: definition),
          const SizedBox(height: 8),
          Text(range),
        ],
      ),
    ),
  );
}

class _CategoryIdentity extends StatelessWidget {
  const _CategoryIdentity({required this.definition});
  final UnderstandingCategoryDefinition definition;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        '${definition.sortOrder}. ${definition.label}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text(definition.code, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _CoverageSummary extends StatelessWidget {
  const _CoverageSummary({required this.valid, required this.message});
  final bool valid;
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: message,
    child: Card(
      key: const Key('understandingCategoriesCoverageSummary'),
      color: valid
          ? Theme.of(context).colorScheme.secondaryContainer
          : Theme.of(context).colorScheme.errorContainer,
      child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
    ),
  );
}

class _CategoryMeaning extends StatelessWidget {
  const _CategoryMeaning();

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('understandingCategoriesMeaning'),
    child: const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How category ranges are used',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'The backend derives an integer category_score from the unrounded final score: fractional parts .0 through .5 round down, while values greater than .5 round up. This editor does not calculate it.',
          ),
          SizedBox(height: 8),
          Text(
            'Not completed means required work can no longer validly be completed. It is not a low score, waiting for Teacher review, or an unreleased result.',
          ),
          SizedBox(height: 8),
          Text(
            'Range changes apply to future or explicitly recalculated eligible open results. They never silently rewrite calculated or closed category snapshots.',
          ),
        ],
      ),
    ),
  );
}

String _rangeText(
  InstitutionUnderstandingCategoryConfiguration configuration,
  UnderstandingCategoryDefinition definition,
) {
  if (!definition.numeric) return 'No numeric range (null / null).';
  if (!configuration.configured) return 'Range: Configuration required.';
  final category = configuration.categoryFor(definition);
  return 'Inclusive range: ${category.minScore}–${category.maxScore}.';
}

InstitutionUnderstandingCategoryField _minimumField(
  UnderstandingCategoryDefinition definition,
) => switch (definition) {
  UnderstandingCategoryDefinition.understoodWell =>
    InstitutionUnderstandingCategoryField.understoodWellMin,
  UnderstandingCategoryDefinition.partiallyUnderstood =>
    InstitutionUnderstandingCategoryField.partiallyUnderstoodMin,
  UnderstandingCategoryDefinition.needsRevision =>
    InstitutionUnderstandingCategoryField.needsRevisionMin,
  UnderstandingCategoryDefinition.needsTeacherSupport =>
    InstitutionUnderstandingCategoryField.needsTeacherSupportMin,
  UnderstandingCategoryDefinition.notCompleted => throw ArgumentError.value(
    definition,
    'definition',
  ),
};

InstitutionUnderstandingCategoryField _maximumField(
  UnderstandingCategoryDefinition definition,
) => switch (definition) {
  UnderstandingCategoryDefinition.understoodWell =>
    InstitutionUnderstandingCategoryField.understoodWellMax,
  UnderstandingCategoryDefinition.partiallyUnderstood =>
    InstitutionUnderstandingCategoryField.partiallyUnderstoodMax,
  UnderstandingCategoryDefinition.needsRevision =>
    InstitutionUnderstandingCategoryField.needsRevisionMax,
  UnderstandingCategoryDefinition.needsTeacherSupport =>
    InstitutionUnderstandingCategoryField.needsTeacherSupportMax,
  UnderstandingCategoryDefinition.notCompleted => throw ArgumentError.value(
    definition,
    'definition',
  ),
};
