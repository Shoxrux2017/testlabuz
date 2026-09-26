import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_blitz_repository_impl.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_form.dart';
import '../domain/teacher_question.dart';
import '../domain/teacher_question_authoring.dart';
import '../domain/teacher_question_mutation.dart';
import 'teacher_blitz_detail_controller.dart';
import 'teacher_blitz_detail_state.dart';
import 'teacher_blitz_question_builder_controller.dart';
import 'teacher_blitz_question_editor_target.dart';
import 'teacher_blitz_route_mutation_activity.dart';
import 'teacher_question_draft_commands.dart';
import 'teacher_question_editor_state.dart';
import 'teacher_question_mutation_activity.dart';
import 'teacher_question_server_validation.dart';
import 'teacher_session_key.dart';

final teacherBlitzQuestionEditorControllerProvider = NotifierProvider
    .autoDispose
    .family<
      TeacherBlitzQuestionEditorController,
      TeacherQuestionEditorState,
      TeacherBlitzQuestionEditorTarget
    >(TeacherBlitzQuestionEditorController.new);

class TeacherBlitzQuestionEditorController
    extends Notifier<TeacherQuestionEditorState>
    with TeacherQuestionDraftCommands {
  TeacherBlitzQuestionEditorController(this.target);

  final TeacherBlitzQuestionEditorTarget target;
  final TeacherQuestionLocalIdSequence _localIds =
      TeacherQuestionLocalIdSequence();
  TeacherSessionKey? _activeSessionKey;
  var _operationGeneration = 0;
  var _initialized = false;

  @override
  TeacherQuestionLocalIdSequence get draftLocalIds => _localIds;

  @override
  TeacherQuestionEditorState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final detail = ref.watch(
      teacherBlitzDetailControllerProvider(target.routeTarget),
    );
    final builder = ref.watch(
      teacherBlitzQuestionBuilderControllerProvider(target.routeTarget),
    );
    ref.watch(teacherQuestionMutationActivityProvider(target.routeTarget));

    if (sessionKey == null || sessionKey.surface != AppDeviceSurface.desktop) {
      final shouldClose = _initialized;
      _clearSession();
      return TeacherQuestionEditorState(
        status: shouldClose
            ? TeacherQuestionEditorStatus.closeForReview
            : TeacherQuestionEditorStatus.unavailable,
        formError: 'Question editing is unavailable.',
      );
    }
    if (_activeSessionKey != sessionKey) {
      _clearSession();
      _activeSessionKey = sessionKey;
    }
    if (_initialized &&
        !_builder.isCurrentRouteOwner(
          sessionKey,
          ownerGeneration: target.routeOwnerGeneration,
        )) {
      _operationGeneration += 1;
      return state.copyWith(
        status: TeacherQuestionEditorStatus.closeForReview,
        pendingOperation: null,
      );
    }

    if (_initialized &&
        (state.isBusy ||
            state.status == TeacherQuestionEditorStatus.outcomeReview ||
            state.shouldClose)) {
      return state;
    }
    if (detail.status == TeacherBlitzDetailStatus.notFound) {
      _initialized = true;
      return TeacherQuestionEditorState(
        status: TeacherQuestionEditorStatus.unavailable,
        formError: 'This Blitz is no longer available.',
      );
    }
    final blitz =
        detail.status == TeacherBlitzDetailStatus.data && !detail.isStale
        ? detail.blitz
        : null;
    if (blitz == null || !_matchesTarget(blitz)) {
      return _initialized ? state : TeacherQuestionEditorState();
    }
    if (!isTeacherBlitzAuthoringStatus(blitz.status)) {
      final retainedDraft = _initialized ? state.draft : null;
      final retainedInitialDraft = _initialized ? state.initialDraft : null;
      _initialized = true;
      return TeacherQuestionEditorState(
        status: TeacherQuestionEditorStatus.lockedReview,
        draft: retainedDraft,
        initialDraft: retainedInitialDraft,
        formError: _lifecycleLockMessage(blitz.status),
      );
    }
    if (builder.serverLocked) {
      final retainedDraft = _initialized ? state.draft : null;
      final retainedInitialDraft = _initialized ? state.initialDraft : null;
      _initialized = true;
      return TeacherQuestionEditorState(
        status: TeacherQuestionEditorStatus.lockedReview,
        draft: retainedDraft,
        initialDraft: retainedInitialDraft,
        formError: 'Question editing is locked by the current server state.',
      );
    }

    final question = target.mode == TeacherQuestionEditorMode.edit
        ? _findQuestion(blitz, target.questionId!)
        : null;
    if (target.mode == TeacherQuestionEditorMode.edit && question == null) {
      _initialized = true;
      return TeacherQuestionEditorState(
        status: TeacherQuestionEditorStatus.unavailable,
        formError: 'This Question is no longer available.',
      );
    }

    if (!_initialized || state.draft == null || state.initialDraft == null) {
      final draft = target.mode == TeacherQuestionEditorMode.add
          ? TeacherQuestionDraft.forAdd(nextLocalId: _localIds.next)
          : TeacherQuestionDraft.fromQuestion(
              question!,
              nextLocalId: _localIds.next,
            );
      _initialized = true;
      return TeacherQuestionEditorState(
        status: TeacherQuestionEditorStatus.editing,
        draft: draft,
        initialDraft: draft,
        formError:
            target.mode == TeacherQuestionEditorMode.add &&
                blitz.questions.length >=
                    TeacherQuestionAuthoringLimits.maxQuestionsPerAssessment
            ? 'Maximum 100 Questions.'
            : null,
      );
    }

    if (state.status == TeacherQuestionEditorStatus.lockedReview) {
      return state;
    }
    if (state.isDirty) {
      return state;
    }
    final refreshedDraft = target.mode == TeacherQuestionEditorMode.add
        ? state.draft!
        : TeacherQuestionDraft.fromQuestion(
            question!,
            nextLocalId: _localIds.next,
          );
    if (refreshedDraft.semanticallyEqualsDraft(state.draft!)) {
      return state;
    }
    return TeacherQuestionEditorState(
      status: TeacherQuestionEditorStatus.editing,
      draft: refreshedDraft,
      initialDraft: refreshedDraft,
    );
  }

  Future<void> submit() async {
    final draft = state.draft;
    final sessionKey = _activeSessionKey;
    final detail = ref.read(
      teacherBlitzDetailControllerProvider(target.routeTarget),
    );
    final blitz =
        detail.status == TeacherBlitzDetailStatus.data && !detail.isStale
        ? detail.blitz
        : null;
    if (!state.canSubmit ||
        state.pendingOperation != null ||
        draft == null ||
        sessionKey == null ||
        blitz == null ||
        !_canMutate(blitz, sessionKey)) {
      return;
    }

    final validation = draft.validate();
    final validated = validation.validatedDraft;
    if (validated == null) {
      state = state.copyWith(
        status: TeacherQuestionEditorStatus.localValidationFailure,
        fieldErrors: validation.errors,
        formError: null,
      );
      return;
    }

    final operation = target.mode == TeacherQuestionEditorMode.add
        ? TeacherQuestionMutationOperation.add
        : TeacherQuestionMutationOperation.update;
    TeacherQuestionCreateRequest? createRequest;
    TeacherQuestionEditRequest? editRequest;
    String? questionId;
    if (operation == TeacherQuestionMutationOperation.add) {
      if (blitz.questions.length >=
          TeacherQuestionAuthoringLimits.maxQuestionsPerAssessment) {
        state = state.copyWith(
          status: TeacherQuestionEditorStatus.definiteFailure,
          formError: 'Maximum 100 Questions.',
        );
        return;
      }
      createRequest = TeacherQuestionCreateRequest.fromValidated(
        validatedDraft: validated,
        position: blitz.questions.length + 1,
      );
    } else {
      questionId = target.questionId!;
      final currentQuestion = _findQuestion(blitz, questionId);
      if (currentQuestion == null) {
        state = state.copyWith(
          status: TeacherQuestionEditorStatus.unavailable,
          formError: 'This Question is no longer available.',
        );
        return;
      }
      editRequest = TeacherQuestionEditRequest.fromValidated(
        validatedDraft: validated,
        initial: TeacherQuestionEditSnapshot.fromQuestion(currentQuestion),
      );
      if (editRequest.isEmpty) {
        state = state.copyWith(
          status: TeacherQuestionEditorStatus.editing,
          formError: 'No changes to save.',
          fieldErrors: const {},
        );
        return;
      }
    }

    final activity = ref.read(
      teacherQuestionMutationActivityProvider(target.routeTarget).notifier,
    );
    final lease = activity.begin(operation);
    if (lease == null) {
      return;
    }
    final pending = TeacherQuestionEditorPendingOperation(
      lease: lease,
      authorityStateAtStart: detail,
      createRequest: createRequest,
      editRequest: editRequest,
      questionId: questionId,
    );
    final generation = ++_operationGeneration;
    state = state.copyWith(
      status: TeacherQuestionEditorStatus.submitting,
      fieldErrors: const {},
      formError: null,
      pendingOperation: pending,
    );
    try {
      final returned = operation == TeacherQuestionMutationOperation.add
          ? await ref
                .read(teacherBlitzRepositoryProvider)
                .addQuestion(target.routeTarget.blitzId, createRequest!)
          : await ref
                .read(teacherBlitzRepositoryProvider)
                .updateQuestion(questionId!, editRequest!);
      if (!_canPublish(pending, generation)) {
        return;
      }
      if (!_matchesTarget(returned)) {
        await _reconcile(pending, generation);
        return;
      }
      if (!_detailAuthorityUnchanged(pending)) {
        await _reconcile(pending.withConfirmedTransport(), generation);
        return;
      }
      _publishConfirmed(returned, pending);
    } on TeacherQuestionMutationOutcomeUnknownException {
      await _reconcile(pending, generation);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(pending, generation)) {
        return;
      }
      await _handleDefiniteFailure(exception.failure, pending, generation);
    } catch (_) {
      await _reconcile(pending, generation);
    } finally {
      _releaseIfAbandoned(pending, generation, activity);
    }
  }

  Future<void> checkCurrentBlitz() async {
    final pending = state.pendingOperation;
    if (state.status != TeacherQuestionEditorStatus.outcomeReview ||
        pending == null) {
      return;
    }
    await _reconcile(pending, _operationGeneration);
  }

  Future<void> _handleDefiniteFailure(
    ApiFailure failure,
    TeacherQuestionEditorPendingOperation pending,
    int generation,
  ) async {
    if (_isSessionFailure(failure)) {
      _release(pending);
      _clearForSessionFailure(failure);
      return;
    }
    if (failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound) {
      await _reconcile(
        pending.withConflictCode(ApiErrorCodes.resourceNotFound),
        generation,
      );
      return;
    }
    if (failure.statusCode == 422 &&
        failure.serverCode == ApiErrorCodes.validationFailed) {
      _release(pending);
      _publishServerValidation(failure);
      return;
    }
    if (failure.statusCode == 409 && _isQuestionConflict(failure.serverCode)) {
      await _reconcile(
        pending.withConflictCode(failure.serverCode!),
        generation,
      );
      return;
    }

    _release(pending);
    state = state.copyWith(
      status: TeacherQuestionEditorStatus.definiteFailure,
      formError: switch (failure.serverCode) {
        ApiErrorCodes.rateLimited =>
          'Too many requests. Wait before trying again.',
        ApiErrorCodes.forbidden =>
          'You do not have permission to change this Question.',
        _ => 'The Question could not be saved.',
      },
      pendingOperation: null,
    );
  }

  Future<void> _reconcile(
    TeacherQuestionEditorPendingOperation pending,
    int generation,
  ) async {
    if (!_canPublish(pending, generation)) {
      return;
    }
    state = state.copyWith(
      status: TeacherQuestionEditorStatus.reconciling,
      pendingOperation: pending,
    );
    try {
      final current = await ref
          .read(teacherBlitzRepositoryProvider)
          .fetchBlitz(target.routeTarget.blitzId);
      if (!_canPublish(pending, generation)) {
        return;
      }
      if (!_matchesTarget(current)) {
        _release(pending);
        _builder.markEditorTargetUnavailable(
          pending.lease.sessionKey,
          ownerGeneration: target.routeOwnerGeneration,
        );
        state = state.copyWith(
          status: TeacherQuestionEditorStatus.closeForReview,
          formError: 'This Blitz is no longer available.',
          pendingOperation: null,
        );
        return;
      }

      final conflictCode = pending.conflictCode;
      if (conflictCode != null) {
        if (conflictCode == ApiErrorCodes.resourceNotFound) {
          final message =
              pending.operation == TeacherQuestionMutationOperation.add
              ? 'The Question could not be created because the target is no longer available. Review the current Blitz.'
              : 'This Question is no longer available. Review the current Blitz.';
          _builder.acceptEditorAuthoritativeBlitz(
            blitz: current,
            sessionKey: pending.lease.sessionKey,
            ownerGeneration: target.routeOwnerGeneration,
            notice: message,
          );
          _release(pending);
          state = state.copyWith(
            status: TeacherQuestionEditorStatus.closeForReview,
            formError: message,
            pendingOperation: null,
          );
          return;
        }
        final locked = conflictCode == ApiErrorCodes.businessConflict;
        final topicNotEditable = conflictCode == ApiErrorCodes.topicNotEditable;
        final message = _editorConflictMessage(conflictCode);
        _builder.acceptEditorAuthoritativeBlitz(
          blitz: current,
          sessionKey: pending.lease.sessionKey,
          ownerGeneration: target.routeOwnerGeneration,
          notice: message,
          serverLocked: locked,
          topicNotEditable: topicNotEditable,
        );
        _release(pending);
        state = state.copyWith(
          status: TeacherQuestionEditorStatus.lockedReview,
          formError: message,
          pendingOperation: null,
        );
        return;
      }

      if (pending.transportConfirmed) {
        _publishConfirmed(current, pending);
        return;
      }

      if (pending.operation == TeacherQuestionMutationOperation.add) {
        const message =
            'The Question creation result could not be confirmed. Review the current Question list before adding another Question.';
        _builder.acceptEditorAuthoritativeBlitz(
          blitz: current,
          sessionKey: pending.lease.sessionKey,
          ownerGeneration: target.routeOwnerGeneration,
          notice: message,
        );
        _release(pending);
        state = state.copyWith(
          status: TeacherQuestionEditorStatus.closeForReview,
          formError: message,
          pendingOperation: null,
        );
        return;
      }

      final currentQuestion = _findQuestion(current, pending.questionId!);
      if (currentQuestion != null &&
          pending.editRequest!.matches(currentQuestion)) {
        _publishConfirmed(current, pending);
        return;
      }
      final message = currentQuestion == null
          ? 'This Question is no longer available. Review the current Blitz.'
          : 'The Question update result could not be confirmed. Review the current Question before editing again.';
      _builder.acceptEditorAuthoritativeBlitz(
        blitz: current,
        sessionKey: pending.lease.sessionKey,
        ownerGeneration: target.routeOwnerGeneration,
        notice: message,
      );
      _release(pending);
      state = state.copyWith(
        status: TeacherQuestionEditorStatus.closeForReview,
        formError: message,
        pendingOperation: null,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(pending, generation)) {
        return;
      }
      if (_isSessionFailure(exception.failure)) {
        _release(pending);
        _clearForSessionFailure(exception.failure);
        return;
      }
      if (exception.failure.statusCode == 404 &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        _release(pending);
        _builder.markEditorTargetUnavailable(
          pending.lease.sessionKey,
          ownerGeneration: target.routeOwnerGeneration,
        );
        state = state.copyWith(
          status: TeacherQuestionEditorStatus.closeForReview,
          formError: 'This Blitz is no longer available.',
          pendingOperation: null,
        );
        return;
      }
      _publishBlockingReview(pending);
    } catch (_) {
      if (_canPublish(pending, generation)) {
        _publishBlockingReview(pending);
      }
    }
  }

  void _publishConfirmed(
    TeacherBlitz blitz,
    TeacherQuestionEditorPendingOperation pending,
  ) {
    final message = pending.operation == TeacherQuestionMutationOperation.add
        ? 'Question created successfully.'
        : 'Question updated successfully.';
    _builder.acceptEditorAuthoritativeBlitz(
      blitz: blitz,
      sessionKey: pending.lease.sessionKey,
      ownerGeneration: target.routeOwnerGeneration,
      notice: message,
    );
    _release(pending);
    state = state.copyWith(
      status: TeacherQuestionEditorStatus.confirmedSuccess,
      formError: null,
      pendingOperation: null,
    );
  }

  void _publishBlockingReview(TeacherQuestionEditorPendingOperation pending) {
    ref
        .read(
          teacherQuestionMutationActivityProvider(target.routeTarget).notifier,
        )
        .markOutcomeReviewBlocking(pending.lease);
    state = state.copyWith(
      status: TeacherQuestionEditorStatus.outcomeReview,
      formError:
          'The current Blitz could not be confirmed. Check the current Blitz before taking another action.',
      pendingOperation: pending,
    );
  }

  void _publishServerValidation(ApiFailure failure) {
    final errors = <TeacherQuestionDraftField, String>{};
    var hasUnknown = failure.fieldErrors.isEmpty;
    for (final key in failure.fieldErrors.keys) {
      final field = teacherQuestionDraftFieldForServerKey(key);
      if (field == null) {
        hasUnknown = true;
      } else {
        errors[field] = teacherQuestionServerValidationMessage(field);
      }
    }
    state = state.copyWith(
      status: TeacherQuestionEditorStatus.serverValidationFailure,
      fieldErrors: errors,
      formError: hasUnknown ? 'The Question could not be saved.' : null,
      pendingOperation: null,
    );
  }

  bool _canMutate(TeacherBlitz blitz, TeacherSessionKey sessionKey) {
    final builderState = ref.read(
      teacherBlitzQuestionBuilderControllerProvider(target.routeTarget),
    );
    return _builder.isCurrentRouteOwner(
          sessionKey,
          ownerGeneration: target.routeOwnerGeneration,
        ) &&
        _matchesTarget(blitz) &&
        isTeacherBlitzAuthoringStatus(blitz.status) &&
        !builderState.serverLocked &&
        !builderState.topicNotEditable &&
        !builderState.authoritativeReloadPending &&
        !builderState.orderDirty &&
        !builderState.isBusy &&
        !builderState.hasBlockingOutcome &&
        !ref
            .read(teacherQuestionMutationActivityProvider(target.routeTarget))
            .isActive &&
        !isTeacherBlitzRouteMutationActive(ref, target.routeTarget);
  }

  bool _canPublish(
    TeacherQuestionEditorPendingOperation pending,
    int generation,
  ) {
    return ref.mounted &&
        generation == _operationGeneration &&
        identical(state.pendingOperation?.lease, pending.lease) &&
        ref
            .read(
              teacherQuestionMutationActivityProvider(
                target.routeTarget,
              ).notifier,
            )
            .owns(pending.lease) &&
        _activeSessionKey == pending.lease.sessionKey &&
        _builder.isCurrentRouteOwner(
          pending.lease.sessionKey,
          ownerGeneration: target.routeOwnerGeneration,
        );
  }

  void _release(TeacherQuestionEditorPendingOperation pending) {
    ref
        .read(
          teacherQuestionMutationActivityProvider(target.routeTarget).notifier,
        )
        .release(pending.lease);
  }

  void _releaseIfAbandoned(
    TeacherQuestionEditorPendingOperation pending,
    int generation,
    TeacherQuestionMutationActivityController activity,
  ) {
    final remainsBlocking =
        ref.mounted &&
        _canPublish(pending, generation) &&
        state.status == TeacherQuestionEditorStatus.outcomeReview;
    if (!remainsBlocking) {
      activity.release(pending.lease);
    }
  }

  TeacherBlitzQuestionBuilderController get _builder => ref.read(
    teacherBlitzQuestionBuilderControllerProvider(target.routeTarget).notifier,
  );

  bool _matchesTarget(TeacherBlitz blitz) {
    return blitz.id.toLowerCase() == target.routeTarget.blitzId.toLowerCase() &&
        blitz.topicId.toLowerCase() == target.routeTarget.topicId.toLowerCase();
  }

  bool _detailAuthorityUnchanged(
    TeacherQuestionEditorPendingOperation pending,
  ) {
    return identical(
      ref.read(teacherBlitzDetailControllerProvider(target.routeTarget)),
      pending.authorityStateAtStart,
    );
  }

  void _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    _clearSession();
    state = TeacherQuestionEditorState(
      status: TeacherQuestionEditorStatus.unavailable,
    );
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
  }

  bool _isSessionFailure(ApiFailure failure) {
    return failure.serverCode == ApiErrorCodes.authenticationRequired ||
        failure.serverCode == ApiErrorCodes.passwordChangeRequired ||
        failure.serverCode == ApiErrorCodes.userInactive ||
        failure.serverCode == ApiErrorCodes.institutionInactive;
  }

  void _clearSession() {
    _activeSessionKey = null;
    _operationGeneration += 1;
    _initialized = false;
  }
}

TeacherQuestion? _findQuestion(TeacherBlitz blitz, String questionId) {
  for (final question in blitz.questions) {
    if (question.id.toLowerCase() == questionId.toLowerCase()) {
      return question;
    }
  }
  return null;
}

// `result_pair_locked` and `assessment_has_no_scoreable_points` are
// Homework-only; a Draft/Scheduled official Blitz stays authorable.
bool _isQuestionConflict(String? code) {
  return code == ApiErrorCodes.topicNotEditable ||
      code == ApiErrorCodes.taskClosed ||
      code == ApiErrorCodes.taskArchived ||
      code == ApiErrorCodes.businessConflict;
}

String _editorConflictMessage(String code) {
  return switch (code) {
    ApiErrorCodes.businessConflict =>
      'Question editing is locked by the current server state. Review the current Blitz before continuing.',
    ApiErrorCodes.taskClosed => 'This Blitz is closed.',
    ApiErrorCodes.taskArchived => 'This Blitz is archived.',
    ApiErrorCodes.topicNotEditable => 'The Topic is no longer editable.',
    _ => 'The Question could not be saved.',
  };
}

String _lifecycleLockMessage(TeacherBlitzStatus status) {
  return switch (status) {
    TeacherBlitzStatus.closed => 'This Blitz is closed.',
    TeacherBlitzStatus.archived => 'This Blitz is archived.',
    _ => 'Question editing is no longer available for this Blitz.',
  };
}
