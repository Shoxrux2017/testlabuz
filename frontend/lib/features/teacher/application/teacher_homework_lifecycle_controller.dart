import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_homework_repository_impl.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_homework_lifecycle.dart';
import '../domain/teacher_homework_mutation.dart';
import 'teacher_homework_detail_controller.dart';
import 'teacher_homework_detail_state.dart';
import 'teacher_homework_lifecycle_state.dart';
import 'teacher_homework_list_controller.dart';
import 'teacher_homework_route_mutation_activity.dart';
import 'teacher_homework_route_target.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_result_pair_controller.dart';
import 'teacher_topic_result_pair_state.dart';

final teacherHomeworkLifecycleControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherHomeworkLifecycleController,
      TeacherHomeworkLifecycleState,
      TeacherHomeworkRouteTarget
    >(TeacherHomeworkLifecycleController.new);

class TeacherHomeworkLifecycleController
    extends Notifier<TeacherHomeworkLifecycleState> {
  TeacherHomeworkLifecycleController(this.target);

  final TeacherHomeworkRouteTarget target;
  TeacherSessionKey? _activeSessionKey;
  TeacherHomeworkLifecycleAction? _activeAction;
  TeacherHomeworkRouteMutationLease? _activeLease;
  var _operationGeneration = 0;

  @override
  TeacherHomeworkLifecycleState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null || sessionKey.surface != AppDeviceSurface.desktop) {
      _clearSession();
      return const TeacherHomeworkLifecycleState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearSession();
    _activeSessionKey = sessionKey;
    return const TeacherHomeworkLifecycleState();
  }

  Future<void> perform(TeacherHomeworkLifecycleAction action) async {
    final sessionKey = _activeSessionKey;
    final detail = ref.read(teacherHomeworkDetailControllerProvider(target));
    final homework = _confirmedHomework(detail);
    if (sessionKey == null ||
        homework == null ||
        state.blocksMutations ||
        !teacherHomeworkLifecycleActions(homework).contains(action) ||
        _isConfirmedOfficialDraftArchive(homework, action) ||
        !_matchesSession(sessionKey)) {
      return;
    }

    final activity = ref.read(
      teacherHomeworkRouteMutationActivityProvider(target).notifier,
    );
    final lease = activity.begin(
      TeacherHomeworkRouteMutationOperation.lifecycle,
    );
    if (lease == null) {
      return;
    }

    final generation = ++_operationGeneration;
    _activeAction = action;
    _activeLease = lease;
    state = TeacherHomeworkLifecycleState(
      status: TeacherHomeworkLifecycleStatus.submitting,
      action: action,
    );
    try {
      final returned = await ref
          .read(teacherHomeworkRepositoryProvider)
          .performLifecycleAction(target.homeworkId, action);
      if (!_canPublish(generation, lease, action)) {
        return;
      }
      if (!_matchesTarget(returned) ||
          returned.status != action.expectedStatus) {
        await _reconcileUnknown(generation, lease, action);
        return;
      }
      _publishSuccess(returned, lease, action);
    } on TeacherHomeworkMutationOutcomeUnknownException {
      await _reconcileUnknown(generation, lease, action);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, lease, action)) {
        return;
      }
      if (_isSessionFailure(exception.failure)) {
        _clearForSessionFailure(exception.failure);
        return;
      }
      if (_isNotFound(exception.failure)) {
        _publishUnavailable(lease, action);
        return;
      }
      if (exception.failure.statusCode == 409) {
        await _publishConflictAfterRefresh(
          generation,
          lease,
          action,
          exception.failure.serverCode,
        );
        return;
      }
      _publishDefiniteFailure(
        lease,
        action,
        conflictCode: exception.failure.serverCode,
        notice: _definiteFailureMessage(exception.failure),
      );
    } catch (_) {
      await _reconcileUnknown(generation, lease, action);
    } finally {
      _releaseIfAbandoned(activity, lease);
    }
  }

  Future<void> checkCurrentHomework() async {
    final action = _activeAction;
    final lease = _activeLease;
    if (!state.canCheckCurrent ||
        action == null ||
        lease == null ||
        !_matchesSession(lease.sessionKey)) {
      return;
    }

    final generation = ++_operationGeneration;
    final activity = ref.read(
      teacherHomeworkRouteMutationActivityProvider(target).notifier,
    );
    try {
      await _reconcileUnknown(generation, lease, action);
    } finally {
      _releaseIfAbandoned(activity, lease);
    }
  }

  void consumeFeedback() {
    if (state.feedback != null) {
      state = state.withoutFeedback();
    }
  }

  void clearNotice() {
    if (state.isBusy || state.hasBlockingOutcome || state.notice == null) {
      return;
    }
    state = const TeacherHomeworkLifecycleState();
  }

  void invalidateRouteCompletions() {
    _operationGeneration += 1;
  }

  void leaveRoute() {
    invalidateRouteCompletions();
    final lease = _activeLease;
    _activeAction = null;
    _activeLease = null;
    if (lease != null && ref.mounted) {
      ref
          .read(teacherHomeworkRouteMutationActivityProvider(target).notifier)
          .release(lease);
    }
    if (ref.mounted) {
      state = const TeacherHomeworkLifecycleState();
    }
  }

  Future<void> _reconcileUnknown(
    int generation,
    TeacherHomeworkRouteMutationLease lease,
    TeacherHomeworkLifecycleAction action,
  ) async {
    if (!_canPublish(generation, lease, action)) {
      return;
    }
    state = TeacherHomeworkLifecycleState(
      status: TeacherHomeworkLifecycleStatus.reconciling,
      action: action,
    );
    try {
      final current = await ref
          .read(teacherHomeworkRepositoryProvider)
          .fetchHomework(target.homeworkId);
      if (!_canPublish(generation, lease, action)) {
        return;
      }
      if (!_matchesTarget(current)) {
        _publishBlockingOutcomeReview(lease, action);
        return;
      }
      _acceptAuthoritativeHomework(current, lease.sessionKey);
      if (current.status == action.expectedStatus) {
        _publishSuccess(current, lease, action);
        return;
      }

      _finishOperation(lease);
      state = TeacherHomeworkLifecycleState(
        status: TeacherHomeworkLifecycleStatus.outcomeReview,
        action: action,
        notice:
            'The lifecycle result could not be confirmed.\nReview the current Homework state before taking another action.',
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, lease, action)) {
        return;
      }
      if (_isSessionFailure(exception.failure)) {
        _clearForSessionFailure(exception.failure);
        return;
      }
      if (_isNotFound(exception.failure)) {
        _publishUnavailable(lease, action);
        return;
      }
      _publishBlockingOutcomeReview(lease, action);
    } catch (_) {
      if (_canPublish(generation, lease, action)) {
        _publishBlockingOutcomeReview(lease, action);
      }
    }
  }

  Future<void> _publishConflictAfterRefresh(
    int generation,
    TeacherHomeworkRouteMutationLease lease,
    TeacherHomeworkLifecycleAction action,
    String? conflictCode,
  ) async {
    if (conflictCode == ApiErrorCodes.resultPairLocked) {
      _refreshResultPairIfMounted(lease.sessionKey);
    }
    state = TeacherHomeworkLifecycleState(
      status: TeacherHomeworkLifecycleStatus.reconciling,
      action: action,
    );

    TeacherHomework? current;
    try {
      final fetched = await ref
          .read(teacherHomeworkRepositoryProvider)
          .fetchHomework(target.homeworkId);
      if (_canPublish(generation, lease, action) && _matchesTarget(fetched)) {
        current = fetched;
        _acceptAuthoritativeHomework(fetched, lease.sessionKey);
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, lease, action)) {
        return;
      }
      if (_isSessionFailure(exception.failure)) {
        _clearForSessionFailure(exception.failure);
        return;
      }
      if (_isNotFound(exception.failure)) {
        _publishUnavailable(lease, action);
        return;
      }
      // The mutation failure is already definite. Other best-effort read
      // failures must not turn it into an unknown outcome or cause a replay.
    } catch (_) {
      // The mutation failure is already definite. A best-effort read failure
      // must not turn it into an unknown outcome or cause a POST replay.
    }
    if (!_canPublish(generation, lease, action)) {
      return;
    }

    _publishDefiniteFailure(
      lease,
      action,
      conflictCode: conflictCode,
      notice: _conflictMessage(
        action,
        conflictCode,
        current,
        current != null && _isConfirmedOfficialDraft(current),
      ),
    );
  }

  void _publishSuccess(
    TeacherHomework homework,
    TeacherHomeworkRouteMutationLease lease,
    TeacherHomeworkLifecycleAction action,
  ) {
    if (!_matchesTarget(homework) || homework.status != action.expectedStatus) {
      return;
    }
    _acceptAuthoritativeHomework(homework, lease.sessionKey);
    _refreshHomeworkList(lease.sessionKey);
    if (action == TeacherHomeworkLifecycleAction.activate) {
      _refreshResultPairIfMounted(lease.sessionKey);
    }
    _finishOperation(lease);
    state = TeacherHomeworkLifecycleState(
      status: TeacherHomeworkLifecycleStatus.confirmedSuccess,
      action: action,
      feedback: action.successMessage,
    );
  }

  void _publishDefiniteFailure(
    TeacherHomeworkRouteMutationLease lease,
    TeacherHomeworkLifecycleAction action, {
    required String? conflictCode,
    required String notice,
  }) {
    _finishOperation(lease);
    state = TeacherHomeworkLifecycleState(
      status: TeacherHomeworkLifecycleStatus.definiteFailure,
      action: action,
      notice: notice,
      conflictCode: conflictCode,
    );
  }

  void _publishBlockingOutcomeReview(
    TeacherHomeworkRouteMutationLease lease,
    TeacherHomeworkLifecycleAction action,
  ) {
    ref
        .read(teacherHomeworkRouteMutationActivityProvider(target).notifier)
        .markOutcomeReviewBlocking(lease);
    state = TeacherHomeworkLifecycleState(
      status: TeacherHomeworkLifecycleStatus.outcomeReview,
      action: action,
      notice:
          'The lifecycle result could not be confirmed.\nReview the current Homework state before taking another action.',
      requiresCheckCurrent: true,
    );
  }

  void _publishUnavailable(
    TeacherHomeworkRouteMutationLease lease,
    TeacherHomeworkLifecycleAction action,
  ) {
    ref
        .read(teacherHomeworkDetailControllerProvider(target).notifier)
        .markNotFound(lease.sessionKey);
    _refreshHomeworkList(lease.sessionKey);
    _finishOperation(lease);
    state = TeacherHomeworkLifecycleState(
      status: TeacherHomeworkLifecycleStatus.unavailable,
      action: action,
      notice: 'This Homework is no longer available.',
    );
  }

  void _acceptAuthoritativeHomework(
    TeacherHomework homework,
    TeacherSessionKey sessionKey,
  ) {
    ref
        .read(teacherHomeworkDetailControllerProvider(target).notifier)
        .acceptAuthoritativeHomework(homework, sessionKey);
  }

  void _refreshHomeworkList(TeacherSessionKey sessionKey) {
    final provider = teacherHomeworkListControllerProvider(target.topicId);
    if (ref.exists(provider)) {
      ref.read(provider.notifier).refreshAfterMutation(sessionKey);
    } else {
      ref.invalidate(provider);
    }
  }

  void _refreshResultPairIfMounted(TeacherSessionKey sessionKey) {
    final provider = teacherTopicResultPairControllerProvider(target.topicId);
    if (ref.exists(provider)) {
      unawaited(ref.read(provider.notifier).refreshAfterMutation(sessionKey));
    }
  }

  bool _isConfirmedOfficialDraftArchive(
    TeacherHomework homework,
    TeacherHomeworkLifecycleAction action,
  ) {
    if (action != TeacherHomeworkLifecycleAction.archive ||
        homework.status != TeacherHomeworkStatus.draft) {
      return false;
    }
    return _isConfirmedOfficialDraft(homework);
  }

  bool _isConfirmedOfficialDraft(TeacherHomework homework) {
    if (homework.status != TeacherHomeworkStatus.draft) {
      return false;
    }
    final provider = teacherTopicResultPairControllerProvider(target.topicId);
    if (!ref.exists(provider)) {
      return false;
    }
    final pairState = ref.read(provider);
    return pairState.status == TeacherTopicResultPairStatus.data &&
        pairState.pair?.homeworkAssessmentId.toLowerCase() ==
            homework.id.toLowerCase();
  }

  TeacherHomework? _confirmedHomework(TeacherHomeworkDetailState detail) {
    final homework =
        detail.status == TeacherHomeworkDetailStatus.data && !detail.isStale
        ? detail.homework
        : null;
    return homework != null && _matchesTarget(homework) ? homework : null;
  }

  bool _matchesTarget(TeacherHomework homework) {
    return homework.id.toLowerCase() == target.homeworkId.toLowerCase() &&
        homework.topicId.toLowerCase() == target.topicId.toLowerCase();
  }

  bool _canPublish(
    int generation,
    TeacherHomeworkRouteMutationLease lease,
    TeacherHomeworkLifecycleAction action,
  ) {
    return ref.mounted &&
        generation == _operationGeneration &&
        identical(_activeLease, lease) &&
        _activeAction == action &&
        ref
            .read(teacherHomeworkRouteMutationActivityProvider(target).notifier)
            .owns(lease) &&
        _matchesSession(lease.sessionKey);
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

  bool _isSessionFailure(ApiFailure failure) {
    return failure.serverCode == ApiErrorCodes.authenticationRequired ||
        failure.serverCode == ApiErrorCodes.passwordChangeRequired ||
        failure.serverCode == ApiErrorCodes.userInactive ||
        failure.serverCode == ApiErrorCodes.institutionInactive;
  }

  bool _isNotFound(ApiFailure failure) {
    return failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound;
  }

  void _clearForSessionFailure(ApiFailure failure) {
    _clearSession();
    state = const TeacherHomeworkLifecycleState();
    if (failure.serverCode != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
  }

  void _finishOperation(TeacherHomeworkRouteMutationLease lease) {
    if (identical(_activeLease, lease)) {
      _activeAction = null;
      _activeLease = null;
    }
    ref
        .read(teacherHomeworkRouteMutationActivityProvider(target).notifier)
        .release(lease);
  }

  void _releaseIfAbandoned(
    TeacherHomeworkRouteMutationActivityController activity,
    TeacherHomeworkRouteMutationLease lease,
  ) {
    final remainsBlocking =
        ref.mounted &&
        identical(_activeLease, lease) &&
        state.hasBlockingOutcome &&
        activity.owns(lease);
    if (!remainsBlocking) {
      activity.release(lease);
    }
  }

  void _clearSession() {
    _operationGeneration += 1;
    final lease = _activeLease;
    _activeSessionKey = null;
    _activeAction = null;
    _activeLease = null;
    if (lease != null && ref.mounted) {
      ref
          .read(teacherHomeworkRouteMutationActivityProvider(target).notifier)
          .release(lease);
    }
  }
}

String _definiteFailureMessage(ApiFailure failure) {
  return switch (failure.serverCode) {
    ApiErrorCodes.forbidden =>
      'You do not have permission to change this Homework.',
    ApiErrorCodes.validationFailed =>
      'The Homework lifecycle change could not be validated. Refresh and review the current state.',
    ApiErrorCodes.rateLimited => 'Too many requests. Wait before trying again.',
    _ => 'The Homework lifecycle action could not be completed.',
  };
}

String _conflictMessage(
  TeacherHomeworkLifecycleAction action,
  String? code,
  TeacherHomework? current,
  bool isConfirmedOfficialDraft,
) {
  if (action == TeacherHomeworkLifecycleAction.archive &&
      code == ApiErrorCodes.businessConflict) {
    if (current?.status == TeacherHomeworkStatus.active) {
      return 'Close the active Homework before archiving it.';
    }
    if (current?.status == TeacherHomeworkStatus.draft &&
        isConfirmedOfficialDraft) {
      return 'Replace the official Homework before archiving this draft.';
    }
    return 'This Homework cannot be archived in the current server state.';
  }

  return switch (code) {
    ApiErrorCodes.assessmentHasNoScoreablePoints =>
      'This Homework needs at least one scoreable Question before activation.\nReview the Questions and points.',
    ApiErrorCodes.assessmentNotAssigned =>
      'Review the Homework assignment.\nThe server could not confirm an eligible recipient set.',
    ApiErrorCodes.deadlinePassed =>
      'The Homework deadline has already passed.\nUpdate the deadline before activation.',
    ApiErrorCodes.topicNotEditable
        when action == TeacherHomeworkLifecycleAction.activate =>
      'The Topic is not in a state that allows this Homework to be activated.\nReview the current Topic.',
    ApiErrorCodes.topicNotEditable =>
      'The Topic is not in a state that allows this Homework action.\nReview the current Topic.',
    ApiErrorCodes.resultPairLocked =>
      'Official Homework activation is locked by the current server state.\nReview the current official Homework status before taking another action.',
    ApiErrorCodes.taskNotActive =>
      'This Homework is not active.\nReview its current state.',
    ApiErrorCodes.taskClosed => 'This Homework is closed.',
    ApiErrorCodes.taskArchived => 'This Homework is archived.',
    ApiErrorCodes.businessConflict
        when action == TeacherHomeworkLifecycleAction.activate =>
      'The Homework cannot be activated in the current server state.\nRefresh and review its configuration.',
    ApiErrorCodes.businessConflict
        when action == TeacherHomeworkLifecycleAction.close =>
      'This Homework cannot be closed in the current server state.\nReview the current Homework before trying again.',
    ApiErrorCodes.businessConflict =>
      'This Homework cannot be archived in the current server state.',
    _ => 'The Homework lifecycle action could not be completed.',
  };
}
