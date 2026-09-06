import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/time/institution_timezone.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_homework_create_controller.dart';
import '../application/teacher_homework_create_state.dart';
import '../application/teacher_session_key.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_homework_form.dart';
import 'teacher_homework_form_fields.dart';
import 'teacher_homework_student_picker_dialog.dart';

class TeacherHomeworkCreateScreen extends ConsumerStatefulWidget {
  const TeacherHomeworkCreateScreen({required this.topicId, super.key});

  final String topicId;

  @override
  ConsumerState<TeacherHomeworkCreateScreen> createState() =>
      _TeacherHomeworkCreateScreenState();
}

class _TeacherHomeworkCreateScreenState
    extends ConsumerState<TeacherHomeworkCreateScreen> {
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
  String? _handledSuccessId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _instructionsController = TextEditingController();
    ref
        .read(teacherHomeworkCreateControllerProvider(widget.topicId).notifier)
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
    final provider = teacherHomeworkCreateControllerProvider(widget.topicId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    _syncControllers(state.form);
    _handleEffects(state);

    return PopScope(
      canPop: !state.blocksNavigation,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && mounted && !state.isRouteBlocking) {
          await _leaveWithGuard(state);
        }
      },
      child: Scaffold(
        key: const Key('teacherHomeworkCreateScreen'),
        appBar: AppBar(
          title: const Text('Create Homework'),
          leading: IconButton(
            key: const Key('teacherHomeworkCreateBackButton'),
            tooltip: 'Back to Topic',
            onPressed: state.isRouteBlocking
                ? null
                : () => _leaveWithGuard(state),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: _buildBody(
            state,
            controller,
            sessionKey?.institutionTimezone ?? 'Unavailable',
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    TeacherHomeworkCreateState state,
    TeacherHomeworkCreateController controller,
    String institutionTimezone,
  ) {
    return switch (state.status) {
      TeacherHomeworkCreateStatus.loading => const Center(
        child: CircularProgressIndicator(
          key: Key('teacherHomeworkCreateLoading'),
          semanticsLabel: 'Loading Homework create form',
        ),
      ),
      TeacherHomeworkCreateStatus.initialLoadError =>
        _HomeworkCreateInitialLoadError(
          failure: state.initialLoadFailure,
          onRetry: controller.retryInitialLoad,
          onBack: _backToTopic,
        ),
      TeacherHomeworkCreateStatus.outcomeUnknown => _UnknownCreateOutcome(
        onReviewHomework: () {
          if (controller.reviewHomework()) {
            context.go(
              AppRoutePaths.teacherTopicDetailLocation(widget.topicId),
            );
          }
        },
      ),
      TeacherHomeworkCreateStatus.topicNotEditable ||
      TeacherHomeworkCreateStatus.unavailable => _HomeworkCreateReview(
        message:
            state.formError ?? 'Homework cannot be created for this Topic.',
        onBack: () => _leaveWithGuard(state),
      ),
      TeacherHomeworkCreateStatus.confirmedSuccess => const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Opening created Homework',
        ),
      ),
      _ => _HomeworkCreateForm(
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
        institutionTimezone: institutionTimezone,
        onChooseStudents: _chooseStudents,
        onChooseDeadline: _chooseDeadline,
        onCancel: () => _leaveWithGuard(state),
      ),
    };
  }

  Future<void> _chooseStudents() async {
    final controller = ref.read(
      teacherHomeworkCreateControllerProvider(widget.topicId).notifier,
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
        .read(teacherHomeworkCreateControllerProvider(widget.topicId))
        .form
        .deadlineWallClock;
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
        .read(teacherHomeworkCreateControllerProvider(widget.topicId).notifier)
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

  Future<void> _leaveWithGuard(TeacherHomeworkCreateState state) async {
    if (state.isRouteBlocking) {
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
              key: const Key('teacherHomeworkCreateKeepEditingButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              key: const Key('teacherHomeworkCreateDiscardButton'),
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
    _backToTopic();
  }

  void _backToTopic() {
    ref
        .read(teacherHomeworkCreateControllerProvider(widget.topicId).notifier)
        .leaveRoute();
    context.go(AppRoutePaths.teacherTopicDetailLocation(widget.topicId));
  }

  void _handleEffects(TeacherHomeworkCreateState state) {
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

    final homeworkId = state.confirmedHomeworkId;
    if (homeworkId != null && homeworkId != _handledSuccessId) {
      _handledSuccessId = homeworkId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            ref
                    .read(
                      teacherHomeworkCreateControllerProvider(widget.topicId),
                    )
                    .confirmedHomeworkId !=
                homeworkId) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Homework created successfully.')),
          );
        ref
            .read(
              teacherHomeworkCreateControllerProvider(widget.topicId).notifier,
            )
            .leaveRoute();
        context.go(
          AppRoutePaths.teacherHomeworkDetailLocation(
            widget.topicId,
            homeworkId,
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

class _HomeworkCreateForm extends StatelessWidget {
  const _HomeworkCreateForm({
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
    required this.institutionTimezone,
    required this.onChooseStudents,
    required this.onChooseDeadline,
    required this.onCancel,
  });

  final TeacherHomeworkCreateState state;
  final TeacherHomeworkCreateController controller;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController instructionsController;
  final FocusNode titleFocusNode;
  final FocusNode descriptionFocusNode;
  final FocusNode instructionsFocusNode;
  final FocusNode assignmentFocusNode;
  final FocusNode studentPickerFocusNode;
  final FocusNode deadlineFocusNode;
  final String institutionTimezone;
  final VoidCallback onChooseStudents;
  final VoidCallback onChooseDeadline;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final topic = state.topic!;

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
                    key: const Key('teacherHomeworkCreateFormMessage'),
                    message: state.formError!,
                    isError: true,
                  ),
                  const SizedBox(height: 16),
                ],
                if (state.isBusy) ...[
                  const TeacherHomeworkFormMessage(
                    key: Key('teacherHomeworkCreateProgress'),
                    message: 'Creating Homework',
                    isError: false,
                  ),
                  const SizedBox(height: 16),
                ],
                TeacherHomeworkTopicContextCard(topic: topic),
                const SizedBox(height: 16),
                TeacherHomeworkMetadataFields(
                  enabled: state.canEdit,
                  titleController: titleController,
                  descriptionController: descriptionController,
                  instructionsController: instructionsController,
                  titleFocusNode: titleFocusNode,
                  descriptionFocusNode: descriptionFocusNode,
                  instructionsFocusNode: instructionsFocusNode,
                  assignmentFocusNode: assignmentFocusNode,
                  studentPickerFocusNode: studentPickerFocusNode,
                  deadlineFocusNode: deadlineFocusNode,
                  assignmentMode: state.form.assignmentMode,
                  selectedStudentCount: state.form.selectedStudentIds.length,
                  deadlineWallClock: state.form.deadlineWallClock,
                  institutionTimezone: institutionTimezone,
                  errorFor: state.errorFor,
                  onTitleChanged: controller.updateTitle,
                  onDescriptionChanged: controller.updateDescription,
                  onInstructionsChanged: controller.updateStudentInstructions,
                  onAssignmentModeChanged: controller.updateAssignmentMode,
                  onChooseStudents: onChooseStudents,
                  onChooseDeadline: onChooseDeadline,
                  onClearDeadline: () => controller.updateDeadlineAt(null),
                ),
                const SizedBox(height: 16),
                const TeacherHomeworkAttemptPolicyCard(
                  normalAttempts:
                      TeacherHomeworkAttemptPolicy.requiredNormalAttempts,
                ),
                const SizedBox(height: 12),
                const Card(
                  key: Key('teacherHomeworkQuestionsAfterCreateNote'),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Questions can be added after the draft is created.',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    TextButton(
                      key: const Key('teacherHomeworkCreateCancelButton'),
                      onPressed: state.isRouteBlocking ? null : onCancel,
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      key: const Key('teacherHomeworkCreateSubmitButton'),
                      onPressed: state.canSubmit ? controller.submit : null,
                      icon: state.isBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Create draft Homework'),
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
}

class _UnknownCreateOutcome extends StatelessWidget {
  const _UnknownCreateOutcome({required this.onReviewHomework});

  final VoidCallback onReviewHomework;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Semantics(
            key: const Key('teacherHomeworkCreateUnknownOutcome'),
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
                      'The Homework creation request may have succeeded. '
                      "Review this Topic's Homework before creating another "
                      'Homework.',
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        key: const Key(
                          'teacherHomeworkCreateReviewHomeworkButton',
                        ),
                        onPressed: onReviewHomework,
                        child: const Text('Review Homework'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeworkCreateReview extends StatelessWidget {
  const _HomeworkCreateReview({required this.message, required this.onBack});

  final String message;
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
              'Homework creation unavailable',
              key: const Key('teacherHomeworkCreateUnavailable'),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onBack, child: const Text('Back to Topic')),
          ],
        ),
      ),
    );
  }
}

class _HomeworkCreateInitialLoadError extends StatelessWidget {
  const _HomeworkCreateInitialLoadError({
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
      ApiFailureKind.timeout => 'The Topic request timed out.',
      _ => 'The Topic could not be loaded.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Unable to load Topic for Homework creation',
              key: const Key('teacherHomeworkCreateInitialLoadError'),
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
                  key: const Key('teacherHomeworkCreateInitialLoadRetryButton'),
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
