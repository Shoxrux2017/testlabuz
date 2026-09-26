import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_blitz_repository_impl.dart';
import '../data/teacher_topic_result_pair_repository_impl.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_form.dart';
import '../domain/teacher_topic_result_pair.dart';
import 'teacher_blitz_detail_controller.dart';
import 'teacher_blitz_detail_state.dart';
import 'teacher_blitz_list_controller.dart';
import 'teacher_blitz_route_mutation_activity.dart';
import 'teacher_blitz_route_target.dart';
import 'teacher_official_blitz_state.dart';
import 'teacher_question_mutation_activity.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_result_pair_controller.dart';
import 'teacher_topic_result_pair_state.dart';

final teacherOfficialBlitzControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherOfficialBlitzController,
      TeacherOfficialBlitzState,
      TeacherBlitzRouteTarget
    >(TeacherOfficialBlitzController.new);

/// How official designation presents for a Blitz; a UX hint only.
enum TeacherOfficialBlitzOption {
  /// The result pair is loading, failed or otherwise unconfirmed.
  unconfirmed,

  /// No pair exists; the official Homework must be chosen first.
  requiresOfficialHomework,

  /// The confirmed pair already designates this Blitz.
  official,

  /// The pair has no Blitz side and is unlocked.
  set,

  /// The pair has no Blitz side but is locked; the fill is still allowed.
  fillLocked,

  /// Another Blitz is official and the pair is still unlocked.
  replace,

  /// Another Blitz is official and the pair is locked.
  lockedByOther,

  selectedStudents,

  /// Active/Closed/Archived Blitz that is not already official.
  notCandidate,
}

TeacherOfficialBlitzOption teacherOfficialBlitzOption({
  required TeacherBlitz blitz,
  required TeacherTopicResultPairState pairState,
}) {
  if (!pairState.hasConfirmedData) {
    return TeacherOfficialBlitzOption.unconfirmed;
  }
  final pair = pairState.pair;
  final officialBlitzId = pair?.blitzAssessmentId;
  if (officialBlitzId?.toLowerCase() == blitz.id.toLowerCase()) {
    return TeacherOfficialBlitzOption.official;
  }
  if (!isTeacherBlitzAuthoringStatus(blitz.status)) {
    return TeacherOfficialBlitzOption.notCandidate;
  }
  if (blitz.assignmentMode != TeacherBlitzAssignmentMode.group) {
    return TeacherOfficialBlitzOption.selectedStudents;
  }
  if (pair == null) {
    return TeacherOfficialBlitzOption.requiresOfficialHomework;
  }
  if (officialBlitzId == null) {
    // A locked partial pair may still fill its missing Blitz side once.
    return pair.lockedAt == null
        ? TeacherOfficialBlitzOption.set
        : TeacherOfficialBlitzOption.fillLocked;
  }
  return pair.lockedAt == null
      ? TeacherOfficialBlitzOption.replace
      : TeacherOfficialBlitzOption.lockedByOther;
}

bool canSubmitOfficialBlitz({
  required TeacherBlitz blitz,
  required TeacherTopicResultPairState pairState,
}) {
  return switch (teacherOfficialBlitzOption(
    blitz: blitz,
    pairState: pairState,
  )) {
    TeacherOfficialBlitzOption.set ||
    TeacherOfficialBlitzOption.fillLocked ||
    TeacherOfficialBlitzOption.replace => true,
    _ => false,
  };
}

const _unconfirmedDesignation =
    'The official Blitz update could not be confirmed.\nReview the current '
    'official Homework and Blitz before trying again.';

class TeacherOfficialBlitzController
    extends Notifier<TeacherOfficialBlitzState> {
  TeacherOfficialBlitzController(this.target);

  final TeacherBlitzRouteTarget target;
  TeacherSessionKey? _activeSessionKey;
  _OfficialOperation? _activeOperation;
  String? _reviewedHomeworkId;
  var _operationGeneration = 0;

  String get _topicKey => target.topicId.toLowerCase();

  @override
  TeacherOfficialBlitzState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null || sessionKey.surface != AppDeviceSurface.desktop) {
      _clearSession();
      return const TeacherOfficialBlitzState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }
    _clearSession();
    _activeSessionKey = sessionKey;
    return const TeacherOfficialBlitzState();
  }

  Future<void> setOfficial() async {
    final sessionKey = _activeSessionKey;
    final blitz = _confirmedCurrentBlitz();
    final pairState = ref.read(
      teacherTopicResultPairControllerProvider(_topicKey),
    );
    final homeworkId = pairState.pair?.homeworkAssessmentId;
    if (state.isBusy ||
        state.hasBlockingOutcome ||
        sessionKey == null ||
        blitz == null ||
        homeworkId == null ||
        !canSubmitOfficialBlitz(blitz: blitz, pairState: pairState) ||
        _questionMutationActive() ||
        !_matchesSession(sessionKey)) {
      return;
    }

    final lease = _activity.begin(TeacherBlitzRouteMutationOperation.official);
    if (lease == null) {
      return;
    }
    final operation = _OfficialOperation(
      lease: lease,
      generation: ++_operationGeneration,
      homeworkId: homeworkId,
    );
    _activeOperation = operation;
    _reviewedHomeworkId = null;
    state = const TeacherOfficialBlitzState(
      status: TeacherOfficialBlitzStatus.submitting,
    );

    try {
      final pair = await ref
          .read(teacherTopicResultPairRepositoryProvider)
          .setOfficialBlitz(
            target.topicId,
            homeworkId: homeworkId,
            blitzId: target.blitzId,
          );
      if (!_canPublish(operation)) {
        return;
      }
      if (_matchesRequestedPair(pair, operation)) {
        _publishSuccess(pair, operation);
      } else {
        await _reconcile(operation);
      }
    } on TeacherTopicResultPairMutationOutcomeUnknownException {
      await _reconcile(operation);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      await _publishDefiniteFailure(operation, exception.failure);
    } catch (_) {
      await _reconcile(operation);
    } finally {
      _releaseIfAbandoned(lease);
    }
  }

  /// Reads the exact current pair for an unresolved designation.
  Future<void> checkCurrentOfficialPair() async {
    final homeworkId = _reviewedHomeworkId;
    final sessionKey = _activeSessionKey;
    if (!state.canCheckCurrent ||
        homeworkId == null ||
        sessionKey == null ||
        !_matchesSession(sessionKey)) {
      return;
    }
    var lease = _activeOperation?.lease;
    if (lease == null || !_activity.owns(lease)) {
      if (_questionMutationActive()) {
        return;
      }
      lease = _activity.begin(TeacherBlitzRouteMutationOperation.official);
      if (lease == null) {
        return;
      }
    }
    final operation = _OfficialOperation(
      lease: lease,
      generation: ++_operationGeneration,
      homeworkId: homeworkId,
    );
    _activeOperation = operation;
    try {
      await _reconcile(operation);
    } finally {
      _releaseIfAbandoned(lease);
    }
  }

  void consumeFeedback() {
    if (state.feedback != null) {
      state = state.withoutFeedback();
    }
  }

  /// Clears a settled notice; outcome reviews stay until they are resolved.
  void clearNotice() {
    if (state.isBusy || state.canCheckCurrent || state.notice == null) {
      return;
    }
    state = const TeacherOfficialBlitzState();
  }

  void invalidateRouteCompletions() {
    _operationGeneration += 1;
  }

  void leaveRoute() {
    invalidateRouteCompletions();
    _releaseActiveLease();
    if (ref.mounted) {
      state = const TeacherOfficialBlitzState();
    }
  }

  Future<void> _reconcile(_OfficialOperation operation) async {
    if (!_canPublish(operation)) {
      return;
    }
    state = const TeacherOfficialBlitzState(
      status: TeacherOfficialBlitzStatus.reconciling,
    );
    try {
      final pair = await ref
          .read(teacherTopicResultPairRepositoryProvider)
          .fetchResultPair(target.topicId);
      if (!_canPublish(operation)) {
        return;
      }
      _acceptPairRead(pair, operation.lease.sessionKey);
      if (pair != null && _matchesRequestedPair(pair, operation)) {
        _publishSuccess(pair, operation);
        return;
      }
      _finishOperation(operation);
      _reviewedHomeworkId = operation.homeworkId;
      state = const TeacherOfficialBlitzState(
        status: TeacherOfficialBlitzStatus.outcomeReview,
        notice: _unconfirmedDesignation,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      _pairController.acceptReadFailure(
        exception.failure,
        operation.lease.sessionKey,
      );
      _publishBlockingReview(operation);
    } catch (_) {
      if (_canPublish(operation)) {
        _pairController.acceptReadFailure(
          ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'The official Blitz status could not be checked.',
          ),
          operation.lease.sessionKey,
        );
        _publishBlockingReview(operation);
      }
    }
  }

  void _publishBlockingReview(_OfficialOperation operation) {
    // The lease stays held until the Teacher checks the current pair.
    _reviewedHomeworkId = operation.homeworkId;
    state = const TeacherOfficialBlitzState(
      status: TeacherOfficialBlitzStatus.outcomeReview,
      notice: _unconfirmedDesignation,
      requiresCurrentCheck: true,
    );
  }

  void _publishSuccess(
    TeacherTopicResultPair pair,
    _OfficialOperation operation,
  ) {
    _acceptPairRead(pair, operation.lease.sessionKey);
    _finishOperation(operation);
    state = const TeacherOfficialBlitzState(
      status: TeacherOfficialBlitzStatus.confirmedSuccess,
      feedback: 'Official Blitz updated successfully.',
    );
  }

  Future<void> _publishDefiniteFailure(
    _OfficialOperation operation,
    ApiFailure failure,
  ) async {
    if (failure.statusCode == 404 || failure.statusCode == 409) {
      state = TeacherOfficialBlitzState(
        status: TeacherOfficialBlitzStatus.reconciling,
        conflictCode: failure.serverCode,
      );
      await _refreshAfterDefiniteFailure(operation);
      if (!_canPublish(operation)) {
        return;
      }
    }
    _finishOperation(operation);
    state = TeacherOfficialBlitzState(
      status: TeacherOfficialBlitzStatus.definiteFailure,
      notice: _failureMessage(failure),
      conflictCode: failure.serverCode,
    );
  }

  Future<void> _refreshAfterDefiniteFailure(
    _OfficialOperation operation,
  ) async {
    final sessionKey = operation.lease.sessionKey;
    try {
      final pair = await ref
          .read(teacherTopicResultPairRepositoryProvider)
          .fetchResultPair(target.topicId);
      if (!_canPublish(operation)) {
        return;
      }
      _acceptPairRead(pair, sessionKey);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      _pairController.acceptReadFailure(exception.failure, sessionKey);
    } catch (_) {
      // The designation failure is already definite.
    }
    if (!_canPublish(operation)) {
      return;
    }
    try {
      final blitz = await ref
          .read(teacherBlitzRepositoryProvider)
          .fetchBlitz(target.blitzId);
      if (!_canPublish(operation)) {
        return;
      }
      if (_matchesTarget(blitz)) {
        ref
            .read(teacherBlitzDetailControllerProvider(target).notifier)
            .acceptAuthoritativeBlitz(blitz, sessionKey);
      } else {
        _markBlitzUnavailable(sessionKey);
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      if (exception.failure.statusCode == 404 &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        _markBlitzUnavailable(sessionKey);
      }
    } catch (_) {
      // The designation failure is already definite.
    }
  }

  void _acceptPairRead(
    TeacherTopicResultPair? pair,
    TeacherSessionKey sessionKey,
  ) {
    if (pair == null) {
      _pairController.acceptNoPair(sessionKey);
    } else if (pair.topicId.toLowerCase() == _topicKey) {
      _pairController.acceptAuthoritativePair(pair, sessionKey);
    }
  }

  void _markBlitzUnavailable(TeacherSessionKey sessionKey) {
    ref
        .read(teacherBlitzDetailControllerProvider(target).notifier)
        .markNotFound(sessionKey);
    final listProvider = teacherBlitzListControllerProvider(_topicKey);
    if (ref.exists(listProvider)) {
      ref.read(listProvider.notifier).refreshAfterMutation(sessionKey);
    } else {
      ref.invalidate(listProvider);
    }
  }

  TeacherBlitz? _confirmedCurrentBlitz() {
    final detail = ref.read(teacherBlitzDetailControllerProvider(target));
    final blitz = detail.blitz;
    if (detail.status != TeacherBlitzDetailStatus.data ||
        detail.isStale ||
        blitz == null ||
        !_matchesTarget(blitz)) {
      return null;
    }
    return blitz;
  }

  bool _questionMutationActive() {
    final provider = teacherQuestionMutationActivityProvider(target);
    if (!ref.exists(provider)) {
      return false;
    }
    return ref.read(provider).isActive;
  }

  bool _matchesTarget(TeacherBlitz blitz) {
    return blitz.id.toLowerCase() == target.blitzId.toLowerCase() &&
        blitz.topicId.toLowerCase() == _topicKey;
  }

  bool _matchesRequestedPair(
    TeacherTopicResultPair pair,
    _OfficialOperation operation,
  ) {
    return pair.topicId.toLowerCase() == _topicKey &&
        pair.homeworkAssessmentId.toLowerCase() ==
            operation.homeworkId.toLowerCase() &&
        pair.blitzAssessmentId?.toLowerCase() == target.blitzId.toLowerCase();
  }

  TeacherBlitzRouteMutationActivityController get _activity =>
      ref.read(teacherBlitzRouteMutationActivityProvider(target).notifier);

  TeacherTopicResultPairController get _pairController =>
      ref.read(teacherTopicResultPairControllerProvider(_topicKey).notifier);

  bool _canPublish(_OfficialOperation operation) {
    return ref.mounted &&
        operation.generation == _operationGeneration &&
        identical(_activeOperation, operation) &&
        _activity.owns(operation.lease) &&
        _matchesSession(operation.lease.sessionKey);
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
    state = const TeacherOfficialBlitzState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _finishOperation(_OfficialOperation operation) {
    if (identical(_activeOperation, operation)) {
      _activeOperation = null;
    }
    _activity.release(operation.lease);
  }

  void _releaseIfAbandoned(TeacherBlitzRouteMutationLease lease) {
    final remainsBlocking =
        ref.mounted &&
        identical(_activeOperation?.lease, lease) &&
        state.hasBlockingOutcome &&
        _activity.owns(lease);
    if (!remainsBlocking && ref.mounted) {
      _activity.release(lease);
    }
  }

  void _releaseActiveLease() {
    final lease = _activeOperation?.lease;
    _activeOperation = null;
    _reviewedHomeworkId = null;
    if (lease != null && ref.mounted) {
      _activity.release(lease);
    }
  }

  void _clearSession() {
    _operationGeneration += 1;
    _activeSessionKey = null;
    _releaseActiveLease();
  }
}

class _OfficialOperation {
  const _OfficialOperation({
    required this.lease,
    required this.generation,
    required this.homeworkId,
  });

  final TeacherBlitzRouteMutationLease lease;
  final int generation;

  /// The confirmed official Homework preserved by this designation.
  final String homeworkId;
}

String _failureMessage(ApiFailure failure) {
  return switch (failure.serverCode) {
    ApiErrorCodes.officialTaskRequiresGroupAssignment =>
      'Only a whole-group Blitz can be the official Blitz.',
    ApiErrorCodes.resultPairLocked =>
      'Official Blitz selection is locked by the current server state.',
    ApiErrorCodes.businessConflict =>
      'This Blitz cannot become the official Blitz in the current server '
          'state.\nRefresh the Blitz and official pair before trying again.',
    ApiErrorCodes.topicNotEditable => 'The Topic is no longer editable.',
    ApiErrorCodes.resourceNotFound =>
      'The requested Blitz or Topic is no longer available in your current '
          'Teacher workspace.',
    ApiErrorCodes.validationFailed =>
      'The official Blitz selection could not be validated.\nRefresh and '
          'review the current state.',
    ApiErrorCodes.forbidden =>
      'You do not have permission to update the official Blitz.',
    ApiErrorCodes.rateLimited => 'Too many requests. Wait before trying again.',
    _ => 'The official Blitz could not be updated.',
  };
}
