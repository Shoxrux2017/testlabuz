import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_blitz_create_controller.dart';
import '../application/teacher_blitz_create_state.dart';
import '../application/teacher_session_key.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_form.dart';
import 'teacher_blitz_form_fields.dart';
import 'teacher_homework_form_fields.dart';
import 'teacher_homework_student_picker_dialog.dart';

class TeacherBlitzCreateScreen extends ConsumerStatefulWidget {
  const TeacherBlitzCreateScreen({required this.topicId, super.key});

  final String topicId;

  @override
  ConsumerState<TeacherBlitzCreateScreen> createState() =>
      _TeacherBlitzCreateScreenState();
}

class _TeacherBlitzCreateScreenState
    extends ConsumerState<TeacherBlitzCreateScreen> {
  late final String _topicId;
  late final TeacherBlitzCreateController _routeController;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _durationController = TextEditingController();
  final _focusNodes = TeacherBlitzFormFocusNodes();
  TeacherBlitzFormField? _handledError;
  String? _handledSuccessId;

  @override
  void initState() {
    super.initState();
    _topicId = widget.topicId.toLowerCase();
    _routeController = ref.read(
      teacherBlitzCreateControllerProvider(_topicId).notifier,
    );
    _routeController.enterRoute();
  }

  @override
  void dispose() {
    _routeController.leaveRoute();
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _durationController.dispose();
    _focusNodes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherBlitzCreateControllerProvider(_topicId));
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
        key: const Key('teacherBlitzCreateScreen'),
        appBar: AppBar(
          title: const Text('Create Blitz'),
          leading: IconButton(
            key: const Key('teacherBlitzCreateBackButton'),
            tooltip: 'Back to Topic',
            onPressed: state.isRouteBlocking
                ? null
                : () => _leaveWithGuard(state),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(child: _buildBody(state)),
      ),
    );
  }

  Widget _buildBody(TeacherBlitzCreateState state) {
    return switch (state.status) {
      TeacherBlitzCreateStatus.loading => const Center(
        child: CircularProgressIndicator(
          key: Key('teacherBlitzCreateLoading'),
          semanticsLabel: 'Loading Blitz create form',
        ),
      ),
      TeacherBlitzCreateStatus.initialLoadError => _BlitzCreateInitialLoadError(
        failure: state.initialLoadFailure,
        onRetry: _routeController.retryInitialLoad,
        onBack: _backToTopic,
      ),
      TeacherBlitzCreateStatus.outcomeReview => _BlitzCreateOutcomeReview(
        message: state.formError!,
        onCheckBlitzList: () {
          if (_routeController.checkBlitzList()) {
            context.go(AppRoutePaths.teacherTopicDetailLocation(_topicId));
          }
        },
      ),
      TeacherBlitzCreateStatus.topicNotEditable ||
      TeacherBlitzCreateStatus.unavailable => _BlitzCreateReview(
        message: state.formError ?? 'Blitz creation is unavailable.',
        onBack: () => _leaveWithGuard(state),
      ),
      TeacherBlitzCreateStatus.confirmedSuccess => const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Opening created Blitz',
        ),
      ),
      _ => _buildForm(state),
    };
  }

  Widget _buildForm(TeacherBlitzCreateState state) {
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
                    key: const Key('teacherBlitzCreateFormMessage'),
                    message: state.formError!,
                    isError: true,
                  ),
                  const SizedBox(height: 16),
                ],
                if (state.isBusy) ...[
                  const TeacherHomeworkFormMessage(
                    key: Key('teacherBlitzCreateProgress'),
                    message: 'Creating Blitz',
                    isError: false,
                  ),
                  const SizedBox(height: 16),
                ],
                TeacherHomeworkTopicContextCard(topic: state.topic!),
                const SizedBox(height: 16),
                TeacherBlitzFormFields(
                  enabled: state.canEdit,
                  form: state.form,
                  titleController: _titleController,
                  descriptionController: _descriptionController,
                  instructionsController: _instructionsController,
                  durationController: _durationController,
                  focusNodes: _focusNodes,
                  errorFor: state.errorFor,
                  onTitleChanged: _routeController.updateTitle,
                  onDescriptionChanged: _routeController.updateDescription,
                  onInstructionsChanged:
                      _routeController.updateStudentInstructions,
                  onDurationChanged: _routeController.updateDurationSeconds,
                  onAssignmentModeChanged: (mode) =>
                      _changeAssignmentMode(state, mode),
                  onChooseStudents: _chooseStudents,
                ),
                const SizedBox(height: 16),
                const TeacherBlitzAttemptPolicyCard(
                  normalAttempts:
                      TeacherBlitzAttemptPolicy.requiredNormalAttempts,
                  maxAdditionalExceptionAttempts: TeacherBlitzAttemptPolicy
                      .requiredMaxAdditionalExceptionAttempts,
                ),
                const SizedBox(height: 12),
                const TeacherBlitzTimerModeNote(),
                const SizedBox(height: 12),
                const Card(
                  key: Key('teacherBlitzQuestionsAfterCreateNote'),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Create the Blitz first, then add Questions from Blitz '
                      'detail.',
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
                      key: const Key('teacherBlitzCreateCancelButton'),
                      onPressed: state.isRouteBlocking
                          ? null
                          : () => _leaveWithGuard(state),
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      key: const Key('teacherBlitzCreateSubmitButton'),
                      onPressed: state.canSubmit
                          ? _routeController.submit
                          : null,
                      icon: state.isBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Create draft Blitz'),
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

  Future<void> _changeAssignmentMode(
    TeacherBlitzCreateState state,
    TeacherBlitzAssignmentMode mode,
  ) async {
    if (mode == TeacherBlitzAssignmentMode.group &&
        state.form.selectedStudentIds.isNotEmpty &&
        !await _confirmClearSelection()) {
      return;
    }
    if (mounted) {
      _routeController.updateAssignmentMode(mode);
    }
  }

  Future<bool> _confirmClearSelection() async {
    final owner = _currentSessionOwner();
    if (owner == null) {
      return false;
    }
    final confirmed = await showTeacherBlitzClearSelectionDialog(context);
    return confirmed && _isCurrentSessionOwner(owner);
  }

  Future<void> _chooseStudents() async {
    final launch = _routeController.beginStudentPicker();
    if (launch == null) {
      return;
    }
    final selection = await showTeacherHomeworkStudentPicker(
      context: context,
      target: launch.target,
    );
    if (selection != null && mounted) {
      _routeController.applyStudentSelection(selection, launch.owner);
    } else if (mounted) {
      _routeController.cancelStudentPicker(launch.owner);
    }
  }

  Future<void> _leaveWithGuard(TeacherBlitzCreateState state) async {
    if (state.isRouteBlocking) {
      return;
    }
    if (state.isDirty) {
      final owner = _currentSessionOwner();
      if (owner == null ||
          !await showTeacherBlitzDiscardDialog(context) ||
          !_isCurrentSessionOwner(owner)) {
        return;
      }
    }
    _backToTopic();
  }

  void _backToTopic() {
    _routeController.leaveRoute();
    context.go(AppRoutePaths.teacherTopicDetailLocation(_topicId));
  }

  void _handleEffects(TeacherBlitzCreateState state) {
    final firstError = state.firstErrorField;
    if (firstError != null && firstError != _handledError) {
      _handledError = firstError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNodes.forField(firstError).requestFocus();
        }
      });
    } else if (firstError == null) {
      _handledError = null;
    }

    final blitzId = state.confirmedBlitzId;
    if (blitzId != null && blitzId != _handledSuccessId) {
      _handledSuccessId = blitzId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            ref
                    .read(teacherBlitzCreateControllerProvider(_topicId))
                    .confirmedBlitzId !=
                blitzId) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Blitz created successfully.')),
          );
        _routeController.leaveRoute();
        context.go(AppRoutePaths.teacherBlitzDetailLocation(_topicId, blitzId));
      });
    }
  }

  TeacherSessionKey? _currentSessionOwner() {
    return TeacherSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
    ).eligibleKey;
  }

  bool _isCurrentSessionOwner(TeacherSessionKey owner) {
    return mounted && _currentSessionOwner() == owner;
  }

  void _syncControllers(TeacherBlitzFormValue form) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        syncTeacherBlitzFormText(
          form: form,
          title: _titleController,
          description: _descriptionController,
          instructions: _instructionsController,
          duration: _durationController,
        );
      }
    });
  }
}

class _BlitzCreateOutcomeReview extends StatelessWidget {
  const _BlitzCreateOutcomeReview({
    required this.message,
    required this.onCheckBlitzList,
  });

  final String message;
  final VoidCallback onCheckBlitzList;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Semantics(
            key: const Key('teacherBlitzCreateOutcomeReview'),
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
                    Text(message),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        key: const Key('teacherBlitzCreateCheckListButton'),
                        onPressed: onCheckBlitzList,
                        child: const Text('Check Blitz list'),
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

class _BlitzCreateReview extends StatelessWidget {
  const _BlitzCreateReview({required this.message, required this.onBack});

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
              'Blitz creation unavailable',
              key: const Key('teacherBlitzCreateUnavailable'),
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

class _BlitzCreateInitialLoadError extends StatelessWidget {
  const _BlitzCreateInitialLoadError({
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
              'Unable to load Topic for Blitz creation',
              key: const Key('teacherBlitzCreateInitialLoadError'),
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
                  key: const Key('teacherBlitzCreateInitialLoadRetryButton'),
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
