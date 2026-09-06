import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/time/institution_timezone.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_homework_edit_controller.dart';
import '../application/teacher_homework_edit_state.dart';
import '../application/teacher_homework_route_target.dart';
import '../application/teacher_session_key.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_homework_form.dart';
import 'teacher_homework_form_fields.dart';
import 'teacher_homework_formatters.dart';
import 'teacher_homework_student_picker_dialog.dart';

class TeacherHomeworkEditScreen extends ConsumerStatefulWidget {
  const TeacherHomeworkEditScreen({
    required this.topicId,
    required this.homeworkId,
    super.key,
  });

  final String topicId;
  final String homeworkId;

  @override
  ConsumerState<TeacherHomeworkEditScreen> createState() =>
      _TeacherHomeworkEditScreenState();
}

class _TeacherHomeworkEditScreenState
    extends ConsumerState<TeacherHomeworkEditScreen> {
  late final TeacherHomeworkRouteTarget _target;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _instructionsController;
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _instructionsFocusNode = FocusNode();
  final _assignmentFocusNode = FocusNode();
  final _studentPickerFocusNode = FocusNode();
  final _deadlineFocusNode = FocusNode();
  TeacherHomeworkFormField? _handledError;
  var _handledSuccess = false;

  @override
  void initState() {
    super.initState();
    _target = TeacherHomeworkRouteTarget(
      topicId: widget.topicId,
      homeworkId: widget.homeworkId,
    );
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _instructionsController = TextEditingController();
    ref
        .read(teacherHomeworkEditControllerProvider(_target).notifier)
        .enterRoute();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _instructionsFocusNode.dispose();
    _assignmentFocusNode.dispose();
    _studentPickerFocusNode.dispose();
    _deadlineFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = teacherHomeworkEditControllerProvider(_target);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    if (state.form != null) {
      _syncControllers(state.form!);
    }
    _handleEffects(state);

    return PopScope(
      canPop: !state.blocksNavigation,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && mounted && !_routeBlocking(state)) {
          await _leaveWithGuard(state);
        }
      },
      child: Scaffold(
        key: const Key('teacherHomeworkEditScreen'),
        appBar: AppBar(
          title: const Text('Edit Homework'),
          leading: IconButton(
            key: const Key('teacherHomeworkEditBackButton'),
            tooltip: state.status == TeacherHomeworkEditStatus.unavailable
                ? 'Back to Topic'
                : 'Back to Homework',
            onPressed: _routeBlocking(state)
                ? null
                : state.status == TeacherHomeworkEditStatus.unavailable
                ? _backToTopic
                : () => _leaveWithGuard(state),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(child: _buildBody(state, controller)),
      ),
    );
  }

  Widget _buildBody(
    TeacherHomeworkEditState state,
    TeacherHomeworkEditController controller,
  ) {
    if (state.status == TeacherHomeworkEditStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('teacherHomeworkEditLoading'),
          semanticsLabel: 'Loading Homework edit form',
        ),
      );
    }
    if (state.status == TeacherHomeworkEditStatus.initialLoadError) {
      return _HomeworkEditInitialLoadError(
        failure: state.initialLoadFailure,
        onRetry: controller.retryInitialLoad,
        onBack: _reviewHomework,
      );
    }
    if (state.status == TeacherHomeworkEditStatus.confirmedSuccess) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Opening updated Homework',
        ),
      );
    }
    if (state.isReviewOnly) {
      return _HomeworkEditReview(
        state: state,
        controller: controller,
        titleController: _titleController,
        descriptionController: _descriptionController,
        instructionsController: _instructionsController,
        titleFocusNode: _titleFocusNode,
        descriptionFocusNode: _descriptionFocusNode,
        instructionsFocusNode: _instructionsFocusNode,
        assignmentFocusNode: _assignmentFocusNode,
        studentPickerFocusNode: _studentPickerFocusNode,
        deadlineFocusNode: _deadlineFocusNode,
        onBackToHomework: _reviewHomework,
        onBackToTopic: _backToTopic,
      );
    }
    final form = state.form;
    final topic = state.topic;
    final homework = state.homework;
    final timezone = state.institutionTimezone;
    if (form == null || topic == null || homework == null || timezone == null) {
      return _HomeworkEditUnavailable(onBack: _backToTopic);
    }

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.formError != null) ...[
                  TeacherHomeworkFormMessage(
                    key: const Key('teacherHomeworkEditFormMessage'),
                    message: state.formError!,
                    isError: state.formError != 'No changes to save.',
                  ),
                  const SizedBox(height: 16),
                ],
                if (state.isBusy) ...[
                  TeacherHomeworkFormMessage(
                    key: const Key('teacherHomeworkEditProgress'),
                    message:
                        state.status == TeacherHomeworkEditStatus.reconciling
                        ? 'Checking current Homework'
                        : 'Saving Homework',
                    isError: false,
                  ),
                  const SizedBox(height: 16),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      key: const Key('teacherHomeworkEditStatusChip'),
                      label: Text(teacherHomeworkStatusLabel(homework.status)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (homework.status == TeacherHomeworkStatus.active) ...[
                  const Card(
                    key: Key('teacherHomeworkEditActiveNote'),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Some assignment, instruction, or deadline changes '
                        'may be locked after Student activity begins. The '
                        'server will confirm what is still editable.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TeacherHomeworkTopicContextCard(topic: topic),
                const SizedBox(height: 16),
                TeacherHomeworkMetadataFields(
                  enabled: state.canEdit,
                  titleController: _titleController,
                  descriptionController: _descriptionController,
                  instructionsController: _instructionsController,
                  titleFocusNode: _titleFocusNode,
                  descriptionFocusNode: _descriptionFocusNode,
                  instructionsFocusNode: _instructionsFocusNode,
                  assignmentFocusNode: _assignmentFocusNode,
                  studentPickerFocusNode: _studentPickerFocusNode,
                  deadlineFocusNode: _deadlineFocusNode,
                  assignmentMode: form.assignmentMode,
                  selectedStudentCount: form.selectedStudentIds.length,
                  deadlineWallClock: form.deadlineWallClock,
                  institutionTimezone: timezone,
                  errorFor: state.errorFor,
                  onTitleChanged: controller.updateTitle,
                  onDescriptionChanged: controller.updateDescription,
                  onInstructionsChanged: controller.updateStudentInstructions,
                  onAssignmentModeChanged: controller.updateAssignmentMode,
                  onChooseStudents: _chooseStudents,
                  onChooseDeadline: _chooseDeadline,
                  onClearDeadline: () => controller.updateDeadlineAt(null),
                ),
                const SizedBox(height: 16),
                TeacherHomeworkAttemptPolicyCard(
                  normalAttempts: homework.attemptPolicy.normalAttempts,
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    TextButton(
                      key: const Key('teacherHomeworkEditCancelButton'),
                      onPressed: state.isBusy
                          ? null
                          : () => _leaveWithGuard(state),
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      key: const Key('teacherHomeworkEditSubmitButton'),
                      onPressed: state.canSave ? controller.submit : null,
                      icon: state.isBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseStudents() async {
    final controller = ref.read(
      teacherHomeworkEditControllerProvider(_target).notifier,
    );
    final launch = controller.beginStudentPicker();
    if (launch == null) {
      return;
    }
    final selection = await showTeacherHomeworkStudentPicker(
      context: context,
      target: launch.target,
    );
    if (selection != null && mounted) {
      controller.applyStudentSelection(selection, launch.owner);
    } else if (mounted) {
      controller.cancelStudentPicker(launch.owner);
    }
  }

  Future<void> _chooseDeadline() async {
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
        .read(teacherHomeworkEditControllerProvider(_target))
        .form
        ?.deadlineWallClock;
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
        .read(teacherHomeworkEditControllerProvider(_target).notifier)
        .updateDeadlineAt(
          InstitutionWallClock(
            year: date.year,
            month: date.month,
            day: date.day,
            hour: time.hour,
            minute: time.minute,
          ),
        );
  }

  Future<void> _leaveWithGuard(TeacherHomeworkEditState state) async {
    if (_routeBlocking(state)) {
      return;
    }
    if (state.isDirty) {
      final owner = _currentSessionOwner();
      if (owner == null) {
        return;
      }
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved changes?'),
          actions: [
            TextButton(
              key: const Key('teacherHomeworkEditKeepEditingButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              key: const Key('teacherHomeworkEditDiscardButton'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !_isCurrentSessionOwner(owner)) {
        return;
      }
    }
    _reviewHomework();
  }

  bool _routeBlocking(TeacherHomeworkEditState state) {
    return state.isBusy ||
        state.status == TeacherHomeworkEditStatus.outcomeUnknown;
  }

  void _reviewHomework() {
    ref
        .read(teacherHomeworkEditControllerProvider(_target).notifier)
        .leaveRoute();
    context.go(
      AppRoutePaths.teacherHomeworkDetailLocation(
        widget.topicId,
        widget.homeworkId,
      ),
    );
  }

  void _backToTopic() {
    ref
        .read(teacherHomeworkEditControllerProvider(_target).notifier)
        .leaveRoute();
    context.go(AppRoutePaths.teacherTopicDetailLocation(widget.topicId));
  }

  void _handleEffects(TeacherHomeworkEditState state) {
    final firstError = state.firstErrorField;
    if (firstError != null && firstError != _handledError) {
      _handledError = firstError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusFor(firstError).requestFocus();
        }
      });
    } else if (firstError == null) {
      _handledError = null;
    }

    final confirmed = state.confirmedHomework;
    if (confirmed != null && !_handledSuccess) {
      _handledSuccess = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            ref
                    .read(teacherHomeworkEditControllerProvider(_target))
                    .confirmedHomework
                    ?.id !=
                confirmed.id) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Homework updated successfully.')),
          );
        ref
            .read(teacherHomeworkEditControllerProvider(_target).notifier)
            .leaveRoute();
        context.go(
          AppRoutePaths.teacherHomeworkDetailLocation(
            widget.topicId,
            widget.homeworkId,
          ),
        );
      });
    }
  }

  FocusNode _focusFor(TeacherHomeworkFormField field) => switch (field) {
    TeacherHomeworkFormField.title => _titleFocusNode,
    TeacherHomeworkFormField.description => _descriptionFocusNode,
    TeacherHomeworkFormField.studentInstructions => _instructionsFocusNode,
    TeacherHomeworkFormField.assignmentMode => _assignmentFocusNode,
    TeacherHomeworkFormField.studentIds => _studentPickerFocusNode,
    TeacherHomeworkFormField.deadlineAt => _deadlineFocusNode,
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

  void _showTimezoneUnavailable() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('The Institution timezone is unavailable.'),
        ),
      );
  }

  void _syncControllers(TeacherHomeworkFormValue form) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _setText(_titleController, form.title);
      _setText(_descriptionController, form.description);
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

class _HomeworkEditReview extends StatelessWidget {
  const _HomeworkEditReview({
    required this.state,
    required this.controller,
    required this.titleController,
    required this.descriptionController,
    required this.instructionsController,
    required this.titleFocusNode,
    required this.descriptionFocusNode,
    required this.instructionsFocusNode,
    required this.assignmentFocusNode,
    required this.studentPickerFocusNode,
    required this.deadlineFocusNode,
    required this.onBackToHomework,
    required this.onBackToTopic,
  });

  final TeacherHomeworkEditState state;
  final TeacherHomeworkEditController controller;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController instructionsController;
  final FocusNode titleFocusNode;
  final FocusNode descriptionFocusNode;
  final FocusNode instructionsFocusNode;
  final FocusNode assignmentFocusNode;
  final FocusNode studentPickerFocusNode;
  final FocusNode deadlineFocusNode;
  final VoidCallback onBackToHomework;
  final VoidCallback onBackToTopic;

  @override
  Widget build(BuildContext context) {
    final isUnavailable = state.status == TeacherHomeworkEditStatus.unavailable;
    final isOutcomeUnknown =
        state.status == TeacherHomeworkEditStatus.outcomeUnknown;
    final isDirectLifecycleReview =
        (state.status == TeacherHomeworkEditStatus.taskClosed ||
            state.status == TeacherHomeworkEditStatus.taskArchived) &&
        state.pendingRequest == null;
    final attemptedDraft = state.attemptedDraft;
    final timezone = state.institutionTimezone;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TeacherHomeworkFormMessage(
                key: const Key('teacherHomeworkEditReviewMessage'),
                message: state.formError ?? 'This Homework is unavailable.',
                isError: true,
              ),
              if (!isOutcomeUnknown &&
                  state.homework != null &&
                  timezone != null) ...[
                const SizedBox(height: 16),
                TeacherHomeworkCurrentStateCard(
                  homework: state.homework!,
                  institutionTimezone: timezone,
                ),
              ],
              if (attemptedDraft != null &&
                  state.pendingRequest != null &&
                  !state.pendingRequest!.isEmpty &&
                  state.topic != null &&
                  timezone != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    'Attempted changes (read-only)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 10),
                TeacherHomeworkMetadataFields(
                  enabled: false,
                  titleController: titleController,
                  descriptionController: descriptionController,
                  instructionsController: instructionsController,
                  titleFocusNode: titleFocusNode,
                  descriptionFocusNode: descriptionFocusNode,
                  instructionsFocusNode: instructionsFocusNode,
                  assignmentFocusNode: assignmentFocusNode,
                  studentPickerFocusNode: studentPickerFocusNode,
                  deadlineFocusNode: deadlineFocusNode,
                  assignmentMode: attemptedDraft.assignmentMode,
                  selectedStudentCount:
                      attemptedDraft.selectedStudentIds.length,
                  deadlineWallClock: attemptedDraft.deadlineWallClock,
                  institutionTimezone: timezone,
                  errorFor: (_) => null,
                  onTitleChanged: (_) {},
                  onDescriptionChanged: (_) {},
                  onInstructionsChanged: (_) {},
                  onAssignmentModeChanged: (_) {},
                  onChooseStudents: () {},
                  onChooseDeadline: () {},
                  onClearDeadline: () {},
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (isOutcomeUnknown)
                    FilledButton.icon(
                      key: const Key('teacherHomeworkEditCheckCurrentButton'),
                      onPressed: controller.checkCurrentHomework,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check current Homework'),
                    ),
                  if (!isOutcomeUnknown)
                    OutlinedButton(
                      key: Key(
                        isUnavailable
                            ? 'teacherHomeworkEditBackToTopicButton'
                            : isDirectLifecycleReview
                            ? 'teacherHomeworkEditBackToHomeworkButton'
                            : 'teacherHomeworkEditReviewHomeworkButton',
                      ),
                      onPressed: isUnavailable
                          ? onBackToTopic
                          : onBackToHomework,
                      child: Text(
                        isUnavailable
                            ? 'Back to Topic'
                            : isDirectLifecycleReview
                            ? 'Back to Homework'
                            : 'Review Homework',
                      ),
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

class _HomeworkEditUnavailable extends StatelessWidget {
  const _HomeworkEditUnavailable({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Homework unavailable',
              key: const Key('teacherHomeworkEditUnavailable'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onBack, child: const Text('Back to Topic')),
          ],
        ),
      ),
    );
  }
}

class _HomeworkEditInitialLoadError extends StatelessWidget {
  const _HomeworkEditInitialLoadError({
    required this.failure,
    required this.onRetry,
    required this.onBack,
  });

  final ApiFailure? failure;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final message = switch (failure?.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The Homework request timed out.',
      _ => 'The Homework could not be loaded.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Unable to load Homework for editing',
              key: const Key('teacherHomeworkEditInitialLoadError'),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                TextButton(onPressed: onBack, child: const Text('Back')),
                FilledButton.icon(
                  key: const Key('teacherHomeworkEditInitialLoadRetryButton'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
