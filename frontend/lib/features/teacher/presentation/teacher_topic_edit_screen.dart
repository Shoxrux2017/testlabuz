import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/time/institution_timezone.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_session_key.dart';
import '../application/teacher_topic_edit_controller.dart';
import '../application/teacher_topic_edit_state.dart';
import '../domain/teacher_topic_mutation.dart';
import 'teacher_topic_form_fields.dart';

class TeacherTopicEditScreen extends ConsumerStatefulWidget {
  const TeacherTopicEditScreen({required this.topicId, super.key});

  final String topicId;

  @override
  ConsumerState<TeacherTopicEditScreen> createState() =>
      _TeacherTopicEditScreenState();
}

class _TeacherTopicEditScreenState
    extends ConsumerState<TeacherTopicEditScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _subjectController;
  late final TextEditingController _instructionsController;
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _subjectFocusNode = FocusNode();
  final _instructionsFocusNode = FocusNode();
  final _lessonAtFocusNode = FocusNode();
  TeacherTopicFormField? _handledError;
  var _handledSuccess = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _subjectController = TextEditingController();
    _instructionsController = TextEditingController();
    ref
        .read(teacherTopicEditControllerProvider(widget.topicId).notifier)
        .enterRoute();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    _instructionsController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _subjectFocusNode.dispose();
    _instructionsFocusNode.dispose();
    _lessonAtFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = teacherTopicEditControllerProvider(widget.topicId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    if (state.form != null) {
      _syncControllers(state.form!);
    }
    _handleEffects(state);

    return PopScope(
      canPop: !state.blocksNavigation,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && mounted && !state.isBusy) {
          await _leaveWithGuard(state);
        }
      },
      child: Scaffold(
        key: const Key('teacherTopicEditScreen'),
        appBar: AppBar(
          title: const Text('Edit Topic'),
          leading: IconButton(
            key: const Key('teacherTopicEditBackButton'),
            onPressed: state.isBusy ? null : () => _leaveWithGuard(state),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: state.status == TeacherTopicEditStatus.loading
              ? const Center(
                  child: CircularProgressIndicator(
                    key: Key('teacherTopicEditLoading'),
                    semanticsLabel: 'Loading Topic edit form',
                  ),
                )
              : state.status == TeacherTopicEditStatus.initialLoadError
              ? _TeacherTopicEditInitialLoadError(
                  failure: state.initialLoadFailure!,
                  onRetry: controller.retryInitialLoad,
                  onBack: () {
                    controller.leaveRoute();
                    context.go(AppRoutePaths.teacher);
                  },
                )
              : FocusTraversalGroup(
                  policy: WidgetOrderTraversalPolicy(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (state.formError != null) ...[
                              TeacherTopicFormMessage(
                                key: const Key('teacherTopicEditFormMessage'),
                                message: state.formError!,
                                isError:
                                    state.formError != 'No changes to save.',
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (state.isBusy) ...[
                              TeacherTopicFormMessage(
                                key: const Key('teacherTopicEditProgress'),
                                message:
                                    state.status ==
                                        TeacherTopicEditStatus.reconciling
                                    ? 'Checking current Topic'
                                    : 'Saving Topic',
                                isError: false,
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (state.form != null)
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
                                groupControl: InputDecorator(
                                  key: const Key(
                                    'teacherTopicEditReadOnlyGroup',
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Group (read-only)',
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(
                                    state.topic?.group.name ??
                                        'Current Group unavailable',
                                  ),
                                ),
                                lessonAt: state.form!.lessonAt,
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
                                if (state.status ==
                                    TeacherTopicEditStatus.outcomeUnknown)
                                  FilledButton(
                                    key: const Key(
                                      'teacherTopicEditCheckCurrentButton',
                                    ),
                                    onPressed: controller.checkCurrentTopic,
                                    child: const Text('Check current Topic'),
                                  ),
                                if (state.isReviewOnly)
                                  FilledButton(
                                    key: const Key(
                                      'teacherTopicEditReviewTopicButton',
                                    ),
                                    onPressed: _reviewTopic,
                                    child: const Text('Review Topic'),
                                  )
                                else ...[
                                  TextButton(
                                    key: const Key(
                                      'teacherTopicEditCancelButton',
                                    ),
                                    onPressed: state.isBusy
                                        ? null
                                        : () => _leaveWithGuard(state),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton.icon(
                                    key: const Key(
                                      'teacherTopicEditSaveButton',
                                    ),
                                    onPressed: state.canSave
                                        ? controller.submit
                                        : null,
                                    icon: state.isBusy
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.save_outlined),
                                    label: const Text('Save'),
                                  ),
                                ],
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

  Future<void> _leaveWithGuard(TeacherTopicEditState state) async {
    if (state.isBusy) {
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
          title: const Text('Discard unsaved Topic changes?'),
          actions: [
            TextButton(
              key: const Key('teacherTopicKeepEditingButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              key: const Key('teacherTopicDiscardChangesButton'),
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
    _reviewTopic();
  }

  void _reviewTopic() {
    ref
        .read(teacherTopicEditControllerProvider(widget.topicId).notifier)
        .leaveRoute();
    context.go(AppRoutePaths.teacherTopicDetailLocation(widget.topicId));
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
        .read(teacherTopicEditControllerProvider(widget.topicId))
        .form!
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
        .read(teacherTopicEditControllerProvider(widget.topicId).notifier)
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

  void _handleEffects(TeacherTopicEditState state) {
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
    if (state.status == TeacherTopicEditStatus.confirmedSuccess &&
        !_handledSuccess) {
      _handledSuccess = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            ref
                    .read(teacherTopicEditControllerProvider(widget.topicId))
                    .status !=
                TeacherTopicEditStatus.confirmedSuccess) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Topic updated successfully.')),
          );
        _reviewTopic();
      });
    }
  }

  FocusNode _focusFor(TeacherTopicFormField field) => switch (field) {
    TeacherTopicFormField.title => _titleFocusNode,
    TeacherTopicFormField.description => _descriptionFocusNode,
    TeacherTopicFormField.subject => _subjectFocusNode,
    TeacherTopicFormField.studentInstructions => _instructionsFocusNode,
    TeacherTopicFormField.lessonAt => _lessonAtFocusNode,
    TeacherTopicFormField.groupId => _instructionsFocusNode,
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

class _TeacherTopicEditInitialLoadError extends StatelessWidget {
  const _TeacherTopicEditInitialLoadError({
    required this.failure,
    required this.onRetry,
    required this.onBack,
  });

  final ApiFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final message = switch (failure.kind) {
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
              'Unable to load Topic for editing',
              key: const Key('teacherTopicEditInitialLoadError'),
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
                  key: const Key('teacherTopicEditInitialLoadRetryButton'),
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
