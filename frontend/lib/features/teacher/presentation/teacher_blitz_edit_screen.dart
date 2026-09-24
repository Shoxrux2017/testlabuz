import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_blitz_edit_controller.dart';
import '../application/teacher_blitz_edit_state.dart';
import '../application/teacher_blitz_route_target.dart';
import '../application/teacher_session_key.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_form.dart';
import 'teacher_blitz_form_fields.dart';
import 'teacher_blitz_formatters.dart';
import 'teacher_homework_form_fields.dart';
import 'teacher_homework_student_picker_dialog.dart';

class TeacherBlitzEditScreen extends ConsumerStatefulWidget {
  const TeacherBlitzEditScreen({
    required this.topicId,
    required this.blitzId,
    super.key,
  });

  final String topicId;
  final String blitzId;

  @override
  ConsumerState<TeacherBlitzEditScreen> createState() =>
      _TeacherBlitzEditScreenState();
}

class _TeacherBlitzEditScreenState
    extends ConsumerState<TeacherBlitzEditScreen> {
  late final TeacherBlitzRouteTarget _target;
  late final TeacherBlitzEditController _routeController;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _durationController = TextEditingController();
  final _focusNodes = TeacherBlitzFormFocusNodes();
  TeacherBlitzFormField? _handledError;
  var _handledSuccess = false;

  @override
  void initState() {
    super.initState();
    _target = TeacherBlitzRouteTarget(
      topicId: widget.topicId,
      blitzId: widget.blitzId,
    );
    _routeController = ref.read(
      teacherBlitzEditControllerProvider(_target).notifier,
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
    final state = ref.watch(teacherBlitzEditControllerProvider(_target));
    final form = state.form;
    if (form != null) {
      _syncControllers(form);
    }
    _handleEffects(state);
    final isUnavailable = state.status == TeacherBlitzEditStatus.unavailable;

    return PopScope(
      canPop: !state.blocksNavigation,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && mounted && !state.isRouteBlocking) {
          await _leaveWithGuard(state);
        }
      },
      child: Scaffold(
        key: const Key('teacherBlitzEditScreen'),
        appBar: AppBar(
          title: const Text('Edit Blitz'),
          leading: IconButton(
            key: const Key('teacherBlitzEditBackButton'),
            tooltip: isUnavailable ? 'Back to Topic' : 'Back to Blitz',
            onPressed: state.isRouteBlocking
                ? null
                : isUnavailable
                ? _backToTopic
                : () => _leaveWithGuard(state),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(child: _buildBody(state)),
      ),
    );
  }

  Widget _buildBody(TeacherBlitzEditState state) {
    if (state.status == TeacherBlitzEditStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('teacherBlitzEditLoading'),
          semanticsLabel: 'Loading Blitz edit form',
        ),
      );
    }
    if (state.status == TeacherBlitzEditStatus.initialLoadError) {
      return _BlitzEditInitialLoadError(
        failure: state.initialLoadFailure,
        onRetry: _routeController.retryInitialLoad,
        onBack: _backToBlitz,
      );
    }
    if (state.status == TeacherBlitzEditStatus.confirmedSuccess) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Opening updated Blitz',
        ),
      );
    }
    if (state.isReviewOnly) {
      return _BlitzEditReview(
        state: state,
        onCheckCurrent: _routeController.checkCurrentBlitz,
        onRefresh: _routeController.refreshAuthoritativeState,
        onBackToBlitz: _backToBlitz,
        onBackToTopic: _backToTopic,
      );
    }
    final form = state.form;
    final blitz = state.blitz;
    if (form == null || blitz == null) {
      return _BlitzEditReview(
        state: state,
        onCheckCurrent: _routeController.checkCurrentBlitz,
        onRefresh: _routeController.refreshAuthoritativeState,
        onBackToBlitz: _backToBlitz,
        onBackToTopic: _backToTopic,
      );
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
                    key: const Key('teacherBlitzEditFormMessage'),
                    message: state.formError!,
                    isError: state.formError != 'No changes to save.',
                  ),
                  const SizedBox(height: 16),
                ],
                if (state.isBusy) ...[
                  TeacherHomeworkFormMessage(
                    key: const Key('teacherBlitzEditProgress'),
                    message: state.status == TeacherBlitzEditStatus.reconciling
                        ? 'Checking current Blitz'
                        : 'Saving Blitz',
                    isError: false,
                  ),
                  const SizedBox(height: 16),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      key: const Key('teacherBlitzEditStatusChip'),
                      label: Text(teacherBlitzStatusLabel(blitz.status)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TeacherBlitzFormFields(
                  enabled: state.canEdit,
                  form: form,
                  titleController: _titleController,
                  descriptionController: _descriptionController,
                  instructionsController: _instructionsController,
                  durationController: _durationController,
                  focusNodes: _focusNodes,
                  errorFor: state.errorFor,
                  officialAssignmentLocked: state.officialAssignmentLocked,
                  onTitleChanged: _routeController.updateTitle,
                  onDescriptionChanged: _routeController.updateDescription,
                  onInstructionsChanged:
                      _routeController.updateStudentInstructions,
                  onDurationChanged: _routeController.updateDurationSeconds,
                  onAssignmentModeChanged: (mode) =>
                      _changeAssignmentMode(form, mode),
                  onChooseStudents: _chooseStudents,
                ),
                const SizedBox(height: 16),
                TeacherBlitzAttemptPolicyCard(
                  normalAttempts: blitz.attemptPolicy.normalAttempts,
                  maxAdditionalExceptionAttempts:
                      blitz.attemptPolicy.maxAdditionalExceptionAttempts,
                ),
                const SizedBox(height: 12),
                const TeacherBlitzTimerModeNote(),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    TextButton(
                      key: const Key('teacherBlitzEditCancelButton'),
                      onPressed: state.isRouteBlocking
                          ? null
                          : () => _leaveWithGuard(state),
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      key: const Key('teacherBlitzEditSubmitButton'),
                      onPressed: state.canEdit ? _routeController.submit : null,
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

  Future<void> _changeAssignmentMode(
    TeacherBlitzFormValue form,
    TeacherBlitzAssignmentMode mode,
  ) async {
    if (mode == TeacherBlitzAssignmentMode.group &&
        form.selectedStudentIds.isNotEmpty) {
      final owner = _currentSessionOwner();
      if (owner == null ||
          !await showTeacherBlitzClearSelectionDialog(context) ||
          !_isCurrentSessionOwner(owner)) {
        return;
      }
    }
    if (mounted) {
      _routeController.updateAssignmentMode(mode);
    }
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

  Future<void> _leaveWithGuard(TeacherBlitzEditState state) async {
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
    _backToBlitz();
  }

  void _backToBlitz() {
    _routeController.leaveRoute();
    context.go(
      AppRoutePaths.teacherBlitzDetailLocation(
        _target.topicId,
        _target.blitzId,
      ),
    );
  }

  void _backToTopic() {
    _routeController.leaveRoute();
    context.go(AppRoutePaths.teacherTopicDetailLocation(_target.topicId));
  }

  void _handleEffects(TeacherBlitzEditState state) {
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

    if (state.status == TeacherBlitzEditStatus.confirmedSuccess &&
        !_handledSuccess) {
      _handledSuccess = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            ref.read(teacherBlitzEditControllerProvider(_target)).status !=
                TeacherBlitzEditStatus.confirmedSuccess) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Blitz updated successfully.')),
          );
        _backToBlitz();
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

class _BlitzEditReview extends StatelessWidget {
  const _BlitzEditReview({
    required this.state,
    required this.onCheckCurrent,
    required this.onRefresh,
    required this.onBackToBlitz,
    required this.onBackToTopic,
  });

  final TeacherBlitzEditState state;
  final VoidCallback onCheckCurrent;
  final VoidCallback onRefresh;
  final VoidCallback onBackToBlitz;
  final VoidCallback onBackToTopic;

  @override
  Widget build(BuildContext context) {
    final isUnavailable = state.status == TeacherBlitzEditStatus.unavailable;
    final isOutcomeReview =
        state.status == TeacherBlitzEditStatus.outcomeReview;
    final blitz = state.blitz;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TeacherHomeworkFormMessage(
                key: const Key('teacherBlitzEditReviewMessage'),
                message: state.formError ?? 'This Blitz is unavailable.',
                isError: true,
              ),
              if (!isOutcomeReview && blitz != null) ...[
                const SizedBox(height: 16),
                _BlitzCurrentStateCard(blitz: blitz),
              ],
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (isOutcomeReview)
                    FilledButton.icon(
                      key: const Key('teacherBlitzEditCheckCurrentButton'),
                      onPressed: state.isBusy ? null : onCheckCurrent,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check current Blitz'),
                    ),
                  if (state.status ==
                      TeacherBlitzEditStatus.officialInconsistent)
                    FilledButton.icon(
                      key: const Key('teacherBlitzEditRefreshButton'),
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Blitz'),
                    ),
                  if (!isOutcomeReview)
                    OutlinedButton(
                      key: Key(
                        isUnavailable
                            ? 'teacherBlitzEditBackToTopicButton'
                            : 'teacherBlitzEditBackToBlitzButton',
                      ),
                      onPressed: isUnavailable ? onBackToTopic : onBackToBlitz,
                      child: Text(
                        isUnavailable ? 'Back to Topic' : 'Back to Blitz',
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

class _BlitzCurrentStateCard extends StatelessWidget {
  const _BlitzCurrentStateCard({required this.blitz});

  final TeacherBlitz blitz;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('teacherBlitzEditCurrentServerState'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Current server state',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 10),
            Text('Title: ${blitz.title}'),
            Text('Status: ${teacherBlitzStatusLabel(blitz.status)}'),
            Text(
              'Assignment: ${teacherBlitzAssignmentLabel(blitz.assignmentMode)}',
            ),
            Text(
              'Duration: ${formatTeacherBlitzDuration(blitz.durationSeconds)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _BlitzEditInitialLoadError extends StatelessWidget {
  const _BlitzEditInitialLoadError({
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
      ApiFailureKind.timeout => 'The Blitz request timed out.',
      _ => 'The Blitz could not be loaded.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Unable to load Blitz for editing',
              key: const Key('teacherBlitzEditInitialLoadError'),
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
                  key: const Key('teacherBlitzEditInitialLoadRetryButton'),
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
