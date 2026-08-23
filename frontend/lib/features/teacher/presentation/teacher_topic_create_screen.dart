import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../../core/time/institution_timezone.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_session_key.dart';
import '../application/teacher_topic_create_controller.dart';
import '../application/teacher_topic_create_state.dart';
import '../application/teacher_topic_group_picker_controller.dart';
import '../application/teacher_topic_group_picker_state.dart';
import '../domain/teacher_group.dart';
import '../domain/teacher_group_list_query.dart';
import '../domain/teacher_topic_mutation.dart';
import 'teacher_topic_form_fields.dart';
import 'teacher_workspace_list_widgets.dart';

class TeacherTopicCreateScreen extends ConsumerStatefulWidget {
  const TeacherTopicCreateScreen({super.key});

  @override
  ConsumerState<TeacherTopicCreateScreen> createState() =>
      _TeacherTopicCreateScreenState();
}

class _TeacherTopicCreateScreenState
    extends ConsumerState<TeacherTopicCreateScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _subjectController;
  late final TextEditingController _instructionsController;
  final _groupFocusNode = FocusNode();
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _subjectFocusNode = FocusNode();
  final _instructionsFocusNode = FocusNode();
  final _lessonAtFocusNode = FocusNode();
  TeacherTopicFormField? _handledError;
  String? _handledSuccessId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _subjectController = TextEditingController();
    _instructionsController = TextEditingController();
    ref.read(teacherTopicCreateControllerProvider.notifier).enterRoute();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    _instructionsController.dispose();
    _groupFocusNode.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _subjectFocusNode.dispose();
    _instructionsFocusNode.dispose();
    _lessonAtFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherTopicCreateControllerProvider);
    final controller = ref.read(teacherTopicCreateControllerProvider.notifier);
    _syncControllers(state.form);
    _handleEffects(state);

    return PopScope(
      canPop: !state.isRouteBlocking,
      child: Scaffold(
        key: const Key('teacherTopicCreateScreen'),
        appBar: AppBar(
          title: const Text('Create Topic'),
          leading: IconButton(
            key: const Key('teacherTopicCreateBackButton'),
            onPressed: state.isRouteBlocking
                ? null
                : () {
                    controller.leaveRoute();
                    context.go(AppRoutePaths.teacher);
                  },
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: state.isUnknown
                      ? _UnknownCreateOutcome(
                          onReviewTopics: () {
                            if (controller.reviewTopics()) {
                              context.go(AppRoutePaths.teacher);
                            }
                          },
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (state.formError != null) ...[
                              TeacherTopicFormMessage(
                                key: const Key('teacherTopicCreateFormMessage'),
                                message: state.formError!,
                                isError: true,
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (state.status ==
                                    TeacherTopicCreateStatus.submitting ||
                                state.status ==
                                    TeacherTopicCreateStatus
                                        .reconcilingUnknown) ...[
                              const TeacherTopicFormMessage(
                                key: Key('teacherTopicCreateProgress'),
                                message: 'Creating Topic',
                                isError: false,
                              ),
                              const SizedBox(height: 16),
                            ],
                            TeacherTopicMetadataFields(
                              enabled: state.canEdit,
                              titleController: _titleController,
                              descriptionController: _descriptionController,
                              subjectController: _subjectController,
                              instructionsController: _instructionsController,
                              titleFocusNode: _titleFocusNode,
                              descriptionFocusNode: _descriptionFocusNode,
                              subjectFocusNode: _subjectFocusNode,
                              instructionsFocusNode: _instructionsFocusNode,
                              lessonAtFocusNode: _lessonAtFocusNode,
                              groupControl: _CreateGroupControl(
                                selectedGroup: state.form.selectedGroup,
                                enabled: state.canEdit,
                                errorText: state.errorFor(
                                  TeacherTopicFormField.groupId,
                                ),
                                focusNode: _groupFocusNode,
                                onChoose: _chooseGroup,
                              ),
                              lessonAt: state.form.lessonAt,
                              errorFor: state.errorFor,
                              onTitleChanged: controller.updateTitle,
                              onDescriptionChanged:
                                  controller.updateDescription,
                              onSubjectChanged: controller.updateSubject,
                              onInstructionsChanged:
                                  controller.updateStudentInstructions,
                              onChooseLessonAt: state.canEdit
                                  ? _chooseLessonAt
                                  : null,
                              onClearLessonAt: () =>
                                  controller.updateLessonAt(null),
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                TextButton(
                                  key: const Key(
                                    'teacherTopicCreateCancelButton',
                                  ),
                                  onPressed: state.isRouteBlocking
                                      ? null
                                      : () {
                                          controller.leaveRoute();
                                          context.go(AppRoutePaths.teacher);
                                        },
                                  child: const Text('Cancel'),
                                ),
                                FilledButton.icon(
                                  key: const Key(
                                    'teacherTopicCreateSubmitButton',
                                  ),
                                  onPressed: state.canSubmit
                                      ? controller.submit
                                      : null,
                                  icon:
                                      state.status ==
                                          TeacherTopicCreateStatus.submitting
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.add),
                                  label: const Text('Create Topic'),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseGroup() async {
    final owner = _currentSessionOwner();
    if (owner == null) {
      return;
    }
    final group = await showDialog<TeacherGroupSummary>(
      context: context,
      builder: (_) => const _TeacherTopicGroupPickerDialog(),
    );
    if (group != null && _isCurrentSessionOwner(owner)) {
      ref
          .read(teacherTopicCreateControllerProvider.notifier)
          .selectGroup(group);
    }
  }

  Future<void> _chooseLessonAt() async {
    final owner = _currentSessionOwner();
    if (owner == null) {
      return;
    }
    final timezone = owner.institutionTimezone;
    if (InstitutionTimezone.tryResolve(timezone) == null) {
      _showTimezoneUnavailable();
      return;
    }
    final current = ref
        .read(teacherTopicCreateControllerProvider)
        .form
        .lessonAt;
    InstitutionWallClock initial;
    try {
      initial =
          current ??
          InstitutionTimezone.instantToWallClock(
            DateTime.now().toUtc(),
            timezone,
          )!;
    } on InstitutionTimezoneException {
      _showTimezoneUnavailable();
      return;
    }
    final date = await showDatePicker(
      context: context,
      initialDate: initial.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted || !_isCurrentSessionOwner(owner)) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (time == null || !mounted || !_isCurrentSessionOwner(owner)) {
      return;
    }
    ref
        .read(teacherTopicCreateControllerProvider.notifier)
        .updateLessonAt(
          InstitutionWallClock(
            year: date.year,
            month: date.month,
            day: date.day,
            hour: time.hour,
            minute: time.minute,
          ),
        );
  }

  void _showTimezoneUnavailable() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('The Institution timezone is unavailable.'),
        ),
      );
  }

  void _handleEffects(TeacherTopicCreateState state) {
    final firstError = state.firstErrorField;
    if (firstError != null && firstError != _handledError) {
      _handledError = firstError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _focusFor(firstError).requestFocus();
      });
    } else if (firstError == null) {
      _handledError = null;
    }
    final topicId = state.confirmedTopicId;
    if (topicId != null && topicId != _handledSuccessId) {
      _handledSuccessId = topicId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            ref.read(teacherTopicCreateControllerProvider).confirmedTopicId !=
                topicId) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Topic created successfully.')),
          );
        context.go(AppRoutePaths.teacherTopicDetailLocation(topicId));
      });
    }
  }

  FocusNode _focusFor(TeacherTopicFormField field) => switch (field) {
    TeacherTopicFormField.groupId => _groupFocusNode,
    TeacherTopicFormField.title => _titleFocusNode,
    TeacherTopicFormField.description => _descriptionFocusNode,
    TeacherTopicFormField.subject => _subjectFocusNode,
    TeacherTopicFormField.studentInstructions => _instructionsFocusNode,
    TeacherTopicFormField.lessonAt => _lessonAtFocusNode,
  };

  TeacherSessionKey? _currentSessionOwner() {
    return TeacherSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
    ).eligibleKey;
  }

  bool _isCurrentSessionOwner(TeacherSessionKey owner) {
    return mounted && _currentSessionOwner() == owner;
  }

  void _syncControllers(TeacherTopicFormValue form) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _setText(_titleController, form.title);
      _setText(_descriptionController, form.description);
      _setText(_subjectController, form.subject);
      _setText(_instructionsController, form.studentInstructions);
    });
  }

  void _setText(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }
}

class _CreateGroupControl extends StatelessWidget {
  const _CreateGroupControl({
    required this.selectedGroup,
    required this.enabled,
    required this.errorText,
    required this.focusNode,
    required this.onChoose,
  });

  final TeacherGroupSummary? selectedGroup;
  final bool enabled;
  final String? errorText;
  final FocusNode focusNode;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Assigned Group',
        errorText: errorText,
        border: const OutlineInputBorder(),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            selectedGroup == null ? 'No Group selected' : selectedGroup!.name,
            key: const Key('teacherTopicCreateSelectedGroup'),
          ),
          OutlinedButton.icon(
            key: const Key('teacherTopicChooseGroupButton'),
            focusNode: focusNode,
            onPressed: enabled ? onChoose : null,
            icon: const Icon(Icons.groups_outlined),
            label: Text(
              selectedGroup == null ? 'Choose Group' : 'Change Group',
            ),
          ),
        ],
      ),
    );
  }
}

class _UnknownCreateOutcome extends StatelessWidget {
  const _UnknownCreateOutcome({required this.onReviewTopics});

  final VoidCallback onReviewTopics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('teacherTopicCreateUnknownOutcome'),
      liveRegion: true,
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Creation outcome unknown',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'The Topic creation request may have succeeded. Review recent Topics before creating another Topic.',
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('teacherTopicCreateReviewTopicsButton'),
                  onPressed: onReviewTopics,
                  child: const Text('Review Topics'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherTopicGroupPickerDialog extends ConsumerStatefulWidget {
  const _TeacherTopicGroupPickerDialog();

  @override
  ConsumerState<_TeacherTopicGroupPickerDialog> createState() =>
      _TeacherTopicGroupPickerDialogState();
}

class _TeacherTopicGroupPickerDialogState
    extends ConsumerState<_TeacherTopicGroupPickerDialog> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherTopicGroupPickerControllerProvider);
    final controller = ref.read(
      teacherTopicGroupPickerControllerProvider.notifier,
    );
    if (_searchController.text != state.searchDraft) {
      _searchController.value = TextEditingValue(
        text: state.searchDraft,
        selection: TextSelection.collapsed(offset: state.searchDraft.length),
      );
    }

    return AlertDialog(
      key: const Key('teacherTopicGroupPickerDialog'),
      title: const Text('Choose assigned Group'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('teacherTopicGroupPickerSearchField'),
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search assigned groups',
                errorText: state.searchErrorText,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              maxLength: TeacherGroupListQuery.maxSearchLength,
              maxLengthEnforcement: MaxLengthEnforcement.none,
              textInputAction: TextInputAction.search,
              onChanged: controller.updateSearchDraft,
              onSubmitted: (_) => controller.commitSearchNow(),
            ),
            const SizedBox(height: 10),
            Flexible(child: _PickerBody(state: state)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('teacherTopicGroupPickerUseButton'),
          onPressed: state.selectedGroup == null || state.isLoading
              ? null
              : () => Navigator.of(context).pop(state.selectedGroup),
          child: const Text('Use Group'),
        ),
      ],
    );
  }
}

class _PickerBody extends ConsumerWidget {
  const _PickerBody({required this.state});

  final TeacherTopicGroupPickerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      teacherTopicGroupPickerControllerProvider.notifier,
    );
    return switch (state.status) {
      TeacherTopicGroupPickerStatus.initial ||
      TeacherTopicGroupPickerStatus.loading => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(
            semanticsLabel: 'Loading assigned Groups',
          ),
        ),
      ),
      TeacherTopicGroupPickerStatus.error => TeacherListError(
        title: 'Unable to load assigned Groups',
        message: 'The assigned Group list could not be loaded.',
        canRetry: state.searchErrorText == null,
        isRetrying: false,
        onRetry: controller.refresh,
      ),
      TeacherTopicGroupPickerStatus.empty => const TeacherListEmpty(
        title: 'No matching assigned Groups',
        message: 'No active assigned Groups match the current search.',
      ),
      TeacherTopicGroupPickerStatus.data => ListView(
        key: const Key('teacherTopicGroupPickerResults'),
        shrinkWrap: true,
        children: [
          for (final group in state.result!.groups)
            ListTile(
              key: ValueKey('teacherTopicPickerGroup${group.id}'),
              selected: state.selectedGroup?.id == group.id,
              title: Text(group.name),
              subtitle: Text(
                [
                  group.level,
                  group.subjectDirection,
                ].whereType<String>().join(' • '),
              ),
              leading: Icon(
                state.selectedGroup?.id == group.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              onTap: () => controller.selectGroup(group),
            ),
          TeacherListPaginationControls(
            pagination: state.result!.pagination,
            canPrevious: state.canPrevious,
            canNext: state.canNext,
            onPrevious: controller.previousPage,
            onNext: controller.nextPage,
          ),
        ],
      ),
    };
  }
}
