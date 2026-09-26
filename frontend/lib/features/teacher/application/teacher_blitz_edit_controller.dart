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
import '../domain/teacher_blitz_mutation.dart';
import 'teacher_blitz_detail_controller.dart';
import 'teacher_blitz_detail_state.dart';
import 'teacher_blitz_edit_state.dart';
import 'teacher_blitz_list_controller.dart';
import 'teacher_blitz_route_mutation_activity.dart';
import 'teacher_blitz_route_target.dart';
import 'teacher_blitz_server_validation.dart';
import 'teacher_homework_student_picker_target.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_detail_controller.dart';
import 'teacher_topic_result_pair_controller.dart';
import 'teacher_topic_result_pair_state.dart';

final teacherBlitzEditControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherBlitzEditController,
      TeacherBlitzEditState,
      TeacherBlitzRouteTarget
    >(TeacherBlitzEditController.new);

const _editingUnavailableMessage = 'Blitz editing is no longer available.';
const _blitzUnavailableMessage =
    'This Blitz is no longer available in your current Teacher workspace.';
const _officialInconsistentMessage =
    'The current official Blitz assignment is inconsistent. Refresh the '
    'Blitz before editing.';
const _outcomeReviewMessage =
    'The current Blitz could not be confirmed. Check the current Blitz '
    'before taking another action.';
const _unconfirmedCurrentStateMessage =
    'The server state differs from the attempted changes. Review the current '
    'Blitz before saving again.';

class TeacherBlitzEditController extends Notifier<TeacherBlitzEditState> {
  TeacherBlitzEditController(this.target);

  final TeacherBlitzRouteTarget target;
  TeacherSessionKey? _activeSessionKey;
  TeacherBlitzEditRequest? _activeRequest;
  TeacherHomeworkStudentPickerOwner? _activePickerOwner;
  int _operationGeneration = 0;
  int _routeGeneration = 0;
  int _studentPickerGeneration = 0;
  var _ownsRoute = false;
  var _initialized = false;

  String get _topicKey => target.topicId.toLowerCase();

  @override
  TeacherBlitzEditState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null || sessionKey.surface != AppDeviceSurface.desktop) {
      _clearSession();
      return TeacherBlitzEditState.loading();
    }
    final detail = ref.watch(teacherBlitzDetailControllerProvider(target));
    final pairState = ref.watch(
      teacherTopicResultPairControllerProvider(_topicKey),
    );
    if (_activeSessionKey != sessionKey) {
      _clearSession();
      _activeSessionKey = sessionKey;
    }
    if (_initialized) {
      // A refresh keeps the last confirmed designation instead of flickering.
      final officialLocked =
          pairState.status == TeacherTopicResultPairStatus.refreshing
          ? state.officialAssignmentLocked
          : _isConfirmedOfficial(pairState);
      return _reconcileInitializedDetail(
        detail,
        officialLocked,
        pairConfirmed: pairState.hasConfirmedData,
      );
    }
    final officialLocked = _isConfirmedOfficial(pairState);

    if (detail.status == TeacherBlitzDetailStatus.notFound) {
      _initialized = true;
      return _unavailable();
    }
    final blitz = detail.blitz;
    if (detail.status == TeacherBlitzDetailStatus.error) {
      return TeacherBlitzEditState.initialLoadError(
        detail.failure ??
            ApiFailure.local(
              kind: ApiFailureKind.unknown,
              message: 'Unexpected Teacher Blitz authoring detail failure.',
            ),
      );
    }
    if (detail.status != TeacherBlitzDetailStatus.data ||
        detail.isStale ||
        blitz == null ||
        !_matchesTarget(blitz)) {
      return TeacherBlitzEditState.loading();
    }

    _initialized = true;
    return _stateFromAuthoritativeBlitz(blitz, officialLocked);
  }

  TeacherBlitzEditState _reconcileInitializedDetail(
    TeacherBlitzDetailState detail,
    bool officialLocked, {
    required bool pairConfirmed,
  }) {
    final preservesUnresolvedMutation =
        state.isBusy ||
        state.status == TeacherBlitzEditStatus.outcomeReview ||
        state.status == TeacherBlitzEditStatus.confirmedSuccess;
    if (preservesUnresolvedMutation) {
      return state;
    }
    if (detail.status == TeacherBlitzDetailStatus.notFound) {
      _invalidateOperation();
      return _unavailable(attemptedDraft: state.form, initial: state.initial);
    }

    final current = detail.blitz;
    if (detail.status != TeacherBlitzDetailStatus.data ||
        detail.isStale ||
        current == null) {
      return state;
    }
    if (!_matchesTarget(current)) {
      _invalidateOperation();
      return _unavailable(attemptedDraft: state.form, initial: state.initial);
    }
    if (state.status == TeacherBlitzEditStatus.officialInconsistent) {
      // Only a confirmed pair may resolve the contradiction it revealed.
      return pairConfirmed
          ? _stateFromAuthoritativeBlitz(current, officialLocked)
          : state;
    }
    if (state.isReviewOnly) {
      return state;
    }
    if (!isTeacherBlitzAuthoringStatus(current.status)) {
      // A lifecycle change retires the draft; it is never sent to finish up.
      _invalidateOperation();
      return TeacherBlitzEditState.review(
        status: TeacherBlitzEditStatus.lifecycleUnavailable,
        blitz: current,
        attemptedDraft: state.form,
        initial: state.initial,
        officialAssignmentLocked: officialLocked,
        formError: _editingUnavailableMessage,
      );
    }
    if (_isOfficiallyInconsistent(current, officialLocked)) {
      _invalidateOperation();
      return _officialInconsistent(
        current,
        attemptedDraft: state.form,
        initial: state.initial,
      );
    }
    if (state.isDirty) {
      return state.withAuthoritativeContext(
        blitz: current,
        officialAssignmentLocked: officialLocked,
      );
    }
    return TeacherBlitzEditState.fromBlitz(
      current,
      officialAssignmentLocked: officialLocked,
    );
  }

  TeacherBlitzEditState _stateFromAuthoritativeBlitz(
    TeacherBlitz blitz,
    bool officialLocked,
  ) {
    if (!isTeacherBlitzAuthoringStatus(blitz.status)) {
      return TeacherBlitzEditState.review(
        status: TeacherBlitzEditStatus.lifecycleUnavailable,
        blitz: blitz,
        attemptedDraft: null,
        initial: null,
        officialAssignmentLocked: officialLocked,
        formError: _editingUnavailableMessage,
      );
    }
    if (_isOfficiallyInconsistent(blitz, officialLocked)) {
      return _officialInconsistent(blitz, attemptedDraft: null, initial: null);
    }
    return TeacherBlitzEditState.fromBlitz(
      blitz,
      officialAssignmentLocked: officialLocked,
    );
  }

  void enterRoute() {
    if (!_ownsRoute) {
      _ownsRoute = true;
      _routeGeneration += 1;
    }
  }

  void leaveRoute() {
    _ownsRoute = false;
    _routeGeneration += 1;
    _invalidateOperation();
  }

  void retryInitialLoad() {
    final sessionKey = _activeSessionKey;
    if (state.status != TeacherBlitzEditStatus.initialLoadError ||
        sessionKey == null ||
        !_ownsRoute ||
        !_matchesSession(sessionKey)) {
      return;
    }
    ref.read(teacherBlitzDetailControllerProvider(target).notifier).retry();
  }

  /// Re-reads the Blitz and its official designation after a contradiction.
  void refreshAuthoritativeState() {
    final sessionKey = _activeSessionKey;
    if (state.status != TeacherBlitzEditStatus.officialInconsistent ||
        sessionKey == null ||
        !_ownsRoute ||
        !_matchesSession(sessionKey)) {
      return;
    }
    ref.read(teacherBlitzDetailControllerProvider(target).notifier).refresh();
    unawaited(
      ref
          .read(teacherTopicResultPairControllerProvider(_topicKey).notifier)
          .refreshAfterMutation(sessionKey),
    );
  }

  void updateTitle(String value) {
    final form = state.form;
    if (form != null) {
      _update(form.copyWith(title: value), const {TeacherBlitzFormField.title});
    }
  }

  void updateDescription(String value) {
    final form = state.form;
    if (form != null) {
      _update(form.copyWith(description: value), const {
        TeacherBlitzFormField.description,
      });
    }
  }

  void updateStudentInstructions(String value) {
    final form = state.form;
    if (form != null) {
      _update(form.copyWith(studentInstructions: value), const {
        TeacherBlitzFormField.studentInstructions,
      });
    }
  }

  void updateDurationSeconds(String value) {
    final form = state.form;
    if (form != null) {
      _update(form.copyWith(durationSecondsText: value), const {
        TeacherBlitzFormField.durationSeconds,
      });
    }
  }

  /// The screen confirms before this clears a non-empty selection.
  void updateAssignmentMode(TeacherBlitzAssignmentMode mode) {
    final form = state.form;
    if (form == null ||
        form.assignmentMode == mode ||
        (state.officialAssignmentLocked &&
            mode != TeacherBlitzAssignmentMode.group)) {
      return;
    }
    _update(
      form.copyWith(assignmentMode: mode, selectedStudentIds: const {}),
      const {
        TeacherBlitzFormField.assignmentMode,
        TeacherBlitzFormField.studentIds,
      },
    );
  }

  TeacherHomeworkStudentPickerLaunch? beginStudentPicker() {
    final sessionKey = _activeSessionKey;
    final form = state.form;
    final blitz = state.blitz;
    if (!_ownsRoute ||
        !state.canEdit ||
        state.officialAssignmentLocked ||
        form == null ||
        blitz == null ||
        form.assignmentMode != TeacherBlitzAssignmentMode.selectedStudents ||
        sessionKey == null ||
        !_matchesSession(sessionKey)) {
      return null;
    }
    final owner = (
      sessionKey: sessionKey,
      groupId: blitz.groupId,
      routeGeneration: _routeGeneration,
      pickerGeneration: ++_studentPickerGeneration,
    );
    _activePickerOwner = owner;
    return (
      target: TeacherHomeworkStudentPickerTarget(
        groupId: blitz.groupId,
        initialSelectedIds: form.selectedStudentIds,
      ),
      owner: owner,
    );
  }

  void cancelStudentPicker(TeacherHomeworkStudentPickerOwner owner) {
    if (_activePickerOwner == owner) {
      _activePickerOwner = null;
    }
  }

  void applyStudentSelection(
    Set<String> studentIds,
    TeacherHomeworkStudentPickerOwner owner,
  ) {
    final form = state.form;
    final blitz = state.blitz;
    if (_activePickerOwner != owner ||
        owner.routeGeneration != _routeGeneration ||
        owner.pickerGeneration != _studentPickerGeneration ||
        form == null ||
        blitz == null ||
        state.officialAssignmentLocked ||
        blitz.groupId.toLowerCase() != owner.groupId.toLowerCase() ||
        form.assignmentMode != TeacherBlitzAssignmentMode.selectedStudents ||
        !_matchesSession(owner.sessionKey)) {
      return;
    }
    _activePickerOwner = null;
    try {
      _update(form.copyWith(selectedStudentIds: studentIds), const {
        TeacherBlitzFormField.studentIds,
      });
    } on ArgumentError {
      return;
    }
  }

  Future<void> submit() async {
    final sessionKey = _activeSessionKey;
    final blitz = state.blitz;
    final form = state.form;
    final initial = state.initial;
    final officialLocked = state.officialAssignmentLocked;
    if (!state.canEdit ||
        !_ownsRoute ||
        sessionKey == null ||
        blitz == null ||
        form == null ||
        initial == null ||
        isTeacherBlitzRouteMutationActive(ref, target) ||
        !_matchesSession(sessionKey)) {
      return;
    }

    final errors = form.validate();
    if (errors.isNotEmpty) {
      state = TeacherBlitzEditState.editing(
        status: TeacherBlitzEditStatus.localValidationFailure,
        blitz: blitz,
        form: form,
        initial: initial,
        officialAssignmentLocked: officialLocked,
        fieldErrors: errors,
        formError: 'Review the highlighted fields.',
      );
      return;
    }

    final request = TeacherBlitzEditRequest.fromForm(
      form: form,
      initial: initial,
    );
    if (request.isEmpty) {
      state = TeacherBlitzEditState.editing(
        blitz: blitz,
        form: form,
        initial: initial,
        officialAssignmentLocked: officialLocked,
        formError: 'No changes to save.',
      );
      return;
    }

    final operation = _EditOperation(
      generation: ++_operationGeneration,
      routeGeneration: _routeGeneration,
      sessionKey: sessionKey,
      request: request,
      blitz: blitz,
      form: form,
      initial: initial,
      officialLocked: officialLocked,
    );
    _activeRequest = request;
    _activePickerOwner = null;
    state = TeacherBlitzEditState.busy(
      status: TeacherBlitzEditStatus.submitting,
      blitz: blitz,
      form: form,
      initial: initial,
      officialAssignmentLocked: officialLocked,
      request: request,
    );
    try {
      final updated = await ref
          .read(teacherBlitzRepositoryProvider)
          .updateBlitz(target.blitzId, request);
      if (!_canPublish(operation)) {
        return;
      }
      if (!_matchesTarget(updated)) {
        await _reconcile(operation);
        return;
      }
      _publishSuccess(updated, sessionKey);
    } on TeacherBlitzMutationOutcomeUnknownException {
      await _reconcile(operation);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      final conflictCode = _recognizedConflictCode(exception.failure);
      if (conflictCode != null) {
        await _reconcile(operation, conflictCode: conflictCode);
        return;
      }
      _activeRequest = null;
      _publishDefiniteFailure(operation, exception.failure);
    } catch (_) {
      await _reconcile(operation);
    }
  }

  /// Reads the exact current Blitz for an unresolved save; never replays it.
  Future<void> checkCurrentBlitz() async {
    final sessionKey = _activeSessionKey;
    final request = state.pendingRequest;
    final blitz = state.blitz;
    final form = state.form;
    final initial = state.initial;
    if (state.status != TeacherBlitzEditStatus.outcomeReview ||
        sessionKey == null ||
        request == null ||
        blitz == null ||
        form == null ||
        initial == null ||
        !_ownsRoute ||
        !_matchesSession(sessionKey)) {
      return;
    }
    final operation = _EditOperation(
      generation: ++_operationGeneration,
      routeGeneration: _routeGeneration,
      sessionKey: sessionKey,
      request: request,
      blitz: blitz,
      form: form,
      initial: initial,
      officialLocked: state.officialAssignmentLocked,
    );
    _activeRequest = request;
    await _reconcile(operation, conflictCode: state.reconciliationConflictCode);
  }

  Future<void> _reconcile(
    _EditOperation operation, {
    String? conflictCode,
  }) async {
    if (!_canPublish(operation)) {
      return;
    }
    state = TeacherBlitzEditState.busy(
      status: TeacherBlitzEditStatus.reconciling,
      blitz: operation.blitz,
      form: operation.form,
      initial: operation.initial,
      officialAssignmentLocked: operation.officialLocked,
      request: operation.request,
      conflictCode: conflictCode,
    );
    if (conflictCode != null) {
      _refreshConflictContext(conflictCode, operation.sessionKey);
    }
    try {
      final current = await ref
          .read(teacherBlitzRepositoryProvider)
          .fetchBlitz(target.blitzId);
      if (!_canPublish(operation)) {
        return;
      }
      if (!_matchesTarget(current)) {
        _publishUnavailableAfterMutation(operation);
        return;
      }
      if (conflictCode != null) {
        _acceptReconciledBlitz(current, operation.sessionKey);
        state = TeacherBlitzEditState.review(
          status: TeacherBlitzEditStatus.conflictReview,
          blitz: current,
          attemptedDraft: operation.form,
          initial: operation.initial,
          officialAssignmentLocked: operation.officialLocked,
          request: operation.request,
          conflictCode: conflictCode,
          formError: _conflictMessage(conflictCode),
        );
      } else if (operation.request.matches(current)) {
        _publishSuccess(current, operation.sessionKey);
      } else {
        // The detail shows server truth; the form keeps the attempted draft
        // until the Teacher explicitly reviews the current Blitz.
        _acceptReconciledBlitz(current, operation.sessionKey);
        state = TeacherBlitzEditState.review(
          status: TeacherBlitzEditStatus.unconfirmedCurrentState,
          blitz: current,
          attemptedDraft: operation.form,
          initial: operation.initial,
          officialAssignmentLocked: operation.officialLocked,
          request: operation.request,
          formError: _unconfirmedCurrentStateMessage,
        );
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      if (exception.failure.statusCode == 404 &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        _publishUnavailableAfterMutation(operation);
        return;
      }
      _publishOutcomeReview(operation, conflictCode);
    } catch (_) {
      if (_canPublish(operation)) {
        _publishOutcomeReview(operation, conflictCode);
      }
    }
  }

  void _refreshConflictContext(
    String conflictCode,
    TeacherSessionKey sessionKey,
  ) {
    if (conflictCode == ApiErrorCodes.officialTaskRequiresGroupAssignment) {
      unawaited(
        ref
            .read(teacherTopicResultPairControllerProvider(_topicKey).notifier)
            .refreshAfterMutation(sessionKey),
      );
    } else if (conflictCode == ApiErrorCodes.topicNotEditable) {
      final topicProvider = teacherTopicDetailControllerProvider(_topicKey);
      if (ref.exists(topicProvider)) {
        ref.read(topicProvider.notifier).refresh();
      }
    }
  }

  void _publishOutcomeReview(_EditOperation operation, String? conflictCode) {
    _activeRequest = null;
    state = TeacherBlitzEditState.review(
      status: TeacherBlitzEditStatus.outcomeReview,
      blitz: operation.blitz,
      attemptedDraft: operation.form,
      initial: operation.initial,
      officialAssignmentLocked: operation.officialLocked,
      request: operation.request,
      conflictCode: conflictCode,
      formError: _outcomeReviewMessage,
    );
  }

  void _publishSuccess(TeacherBlitz blitz, TeacherSessionKey sessionKey) {
    _activeRequest = null;
    ref
        .read(teacherBlitzDetailControllerProvider(target).notifier)
        .acceptAuthoritativeBlitz(blitz, sessionKey);
    _refreshBlitzList(sessionKey);
    state = TeacherBlitzEditState.success(blitz);
  }

  void _acceptReconciledBlitz(
    TeacherBlitz blitz,
    TeacherSessionKey sessionKey,
  ) {
    _activeRequest = null;
    ref
        .read(teacherBlitzDetailControllerProvider(target).notifier)
        .acceptAuthoritativeBlitz(blitz, sessionKey);
    _refreshBlitzList(sessionKey);
  }

  void _publishDefiniteFailure(_EditOperation operation, ApiFailure failure) {
    if (failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound) {
      _publishUnavailableAfterMutation(operation);
      return;
    }
    if (failure.statusCode == 422 &&
        failure.serverCode == ApiErrorCodes.validationFailed) {
      final errors = <TeacherBlitzFormField, String>{};
      var hasUnknown = failure.fieldErrors.isEmpty;
      for (final key in failure.fieldErrors.keys) {
        final field = TeacherBlitzFormField.fromRequestKey(key);
        if (field == null) {
          hasUnknown = true;
        } else {
          errors[field] = teacherBlitzServerValidationMessage(field);
        }
      }
      state = TeacherBlitzEditState.editing(
        status: TeacherBlitzEditStatus.serverValidationFailure,
        blitz: operation.blitz,
        form: operation.form,
        initial: operation.initial,
        officialAssignmentLocked: operation.officialLocked,
        fieldErrors: errors,
        formError: hasUnknown ? 'The Blitz could not be updated.' : null,
      );
      return;
    }
    state = TeacherBlitzEditState.editing(
      status: TeacherBlitzEditStatus.definiteFailure,
      blitz: operation.blitz,
      form: operation.form,
      initial: operation.initial,
      officialAssignmentLocked: operation.officialLocked,
      formError: switch (failure.serverCode) {
        ApiErrorCodes.forbidden =>
          'You do not have permission to update this Blitz.',
        ApiErrorCodes.rateLimited =>
          'Too many requests. Wait before trying again.',
        _ => 'The Blitz could not be updated.',
      },
    );
  }

  void _publishUnavailableAfterMutation(_EditOperation operation) {
    _activeRequest = null;
    ref
        .read(teacherBlitzDetailControllerProvider(target).notifier)
        .markNotFound(operation.sessionKey);
    _refreshBlitzList(operation.sessionKey);
    state = _unavailable(
      attemptedDraft: operation.form,
      initial: operation.initial,
    );
  }

  TeacherBlitzEditState _unavailable({
    TeacherBlitzFormValue? attemptedDraft,
    TeacherBlitzEditSnapshot? initial,
  }) {
    return TeacherBlitzEditState.review(
      status: TeacherBlitzEditStatus.unavailable,
      blitz: null,
      attemptedDraft: attemptedDraft,
      initial: initial,
      officialAssignmentLocked: false,
      formError: _blitzUnavailableMessage,
    );
  }

  TeacherBlitzEditState _officialInconsistent(
    TeacherBlitz blitz, {
    required TeacherBlitzFormValue? attemptedDraft,
    required TeacherBlitzEditSnapshot? initial,
  }) {
    return TeacherBlitzEditState.review(
      status: TeacherBlitzEditStatus.officialInconsistent,
      blitz: blitz,
      attemptedDraft: attemptedDraft,
      initial: initial,
      officialAssignmentLocked: true,
      formError: _officialInconsistentMessage,
    );
  }

  void _update(
    TeacherBlitzFormValue form,
    Set<TeacherBlitzFormField> clearErrors,
  ) {
    final sessionKey = _activeSessionKey;
    if (_ownsRoute &&
        sessionKey != null &&
        _matchesSession(sessionKey) &&
        state.canEdit) {
      state = state.withForm(form, clearErrors: clearErrors);
    }
  }

  bool _isConfirmedOfficial(TeacherTopicResultPairState pairState) {
    return pairState.hasConfirmedData &&
        pairState.pair?.blitzAssessmentId?.toLowerCase() ==
            target.blitzId.toLowerCase();
  }

  bool _isOfficiallyInconsistent(TeacherBlitz blitz, bool officialLocked) {
    return officialLocked &&
        blitz.assignmentMode != TeacherBlitzAssignmentMode.group;
  }

  bool _matchesTarget(TeacherBlitz blitz) {
    return blitz.id.toLowerCase() == target.blitzId.toLowerCase() &&
        blitz.topicId.toLowerCase() == target.topicId.toLowerCase();
  }

  void _refreshBlitzList(TeacherSessionKey sessionKey) {
    final provider = teacherBlitzListControllerProvider(_topicKey);
    if (ref.exists(provider)) {
      ref.read(provider.notifier).refreshAfterMutation(sessionKey);
    } else {
      ref.invalidate(provider);
    }
  }

  bool _canPublish(_EditOperation operation) {
    return ref.mounted &&
        _ownsRoute &&
        operation.generation == _operationGeneration &&
        operation.routeGeneration == _routeGeneration &&
        identical(_activeRequest, operation.request) &&
        _matchesSession(operation.sessionKey);
  }

  bool _matchesSession(TeacherSessionKey sessionKey) {
    return ref.mounted &&
        _activeSessionKey == sessionKey &&
        sessionKey.surface == AppDeviceSurface.desktop &&
        TeacherSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            sessionKey;
  }

  bool _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code != ApiErrorCodes.authenticationRequired &&
        code != ApiErrorCodes.passwordChangeRequired &&
        code != ApiErrorCodes.userInactive &&
        code != ApiErrorCodes.institutionInactive) {
      return false;
    }
    _clearSession();
    state = TeacherBlitzEditState.loading();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _clearSession() {
    _activeSessionKey = null;
    _initialized = false;
    _invalidateOperation();
  }

  void _invalidateOperation() {
    _operationGeneration += 1;
    _studentPickerGeneration += 1;
    _activeRequest = null;
    _activePickerOwner = null;
  }
}

/// The immutable context one save or reconciliation started from.
class _EditOperation {
  const _EditOperation({
    required this.generation,
    required this.routeGeneration,
    required this.sessionKey,
    required this.request,
    required this.blitz,
    required this.form,
    required this.initial,
    required this.officialLocked,
  });

  final int generation;
  final int routeGeneration;
  final TeacherSessionKey sessionKey;
  final TeacherBlitzEditRequest request;
  final TeacherBlitz blitz;
  final TeacherBlitzFormValue form;
  final TeacherBlitzEditSnapshot initial;
  final bool officialLocked;
}

String? _recognizedConflictCode(ApiFailure failure) {
  if (failure.statusCode != 409) {
    return null;
  }
  return switch (failure.serverCode) {
    ApiErrorCodes.topicNotEditable ||
    ApiErrorCodes.taskClosed ||
    ApiErrorCodes.taskArchived ||
    ApiErrorCodes.businessConflict ||
    ApiErrorCodes.officialTaskRequiresGroupAssignment => failure.serverCode,
    _ => null,
  };
}

String _conflictMessage(String conflictCode) {
  return switch (conflictCode) {
    ApiErrorCodes.taskClosed => 'This Blitz is closed and cannot be edited.',
    ApiErrorCodes.taskArchived =>
      'This Blitz is archived and cannot be edited.',
    ApiErrorCodes.topicNotEditable => 'The Topic is no longer editable.',
    ApiErrorCodes.businessConflict =>
      'Some Blitz settings are locked by current server state. Review the '
          'current Blitz before making another change.',
    ApiErrorCodes.officialTaskRequiresGroupAssignment =>
      'The official Blitz must remain assigned to the whole group.',
    _ => 'The Blitz could not be updated.',
  };
}
