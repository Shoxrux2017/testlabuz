import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_homework_repository_impl.dart';
import '../data/teacher_topic_result_pair_repository_impl.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_topic_result_pair.dart';
import 'teacher_homework_detail_controller.dart';
import 'teacher_homework_detail_state.dart';
import 'teacher_homework_list_controller.dart';
import 'teacher_homework_route_mutation_activity.dart';
import 'teacher_homework_route_target.dart';
import 'teacher_official_homework_state.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_result_pair_controller.dart';
import 'teacher_topic_result_pair_state.dart';

final teacherOfficialHomeworkControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherOfficialHomeworkController,
      TeacherOfficialHomeworkState,
      TeacherHomeworkRouteTarget
    >(TeacherOfficialHomeworkController.new);

bool canSubmitOfficialHomework({
  required TeacherHomework homework,
  required TeacherTopicResultPairState pairState,
}) {
  if (!pairState.hasConfirmedData ||
      homework.assignmentMode != TeacherHomeworkAssignmentMode.group ||
      (homework.status != TeacherHomeworkStatus.draft &&
          homework.status != TeacherHomeworkStatus.active)) {
    return false;
  }
  final pair = pairState.pair;
  if (pair == null) {
    return true;
  }
  if (pair.homeworkAssessmentId.toLowerCase() == homework.id.toLowerCase()) {
    return false;
  }
  return pair.lockedAt == null && pair.blitzAssessmentId == null;
}

class TeacherOfficialHomeworkController
    extends Notifier<TeacherOfficialHomeworkState> {
  TeacherOfficialHomeworkController(this.target);

  final TeacherHomeworkRouteTarget target;
  TeacherSessionKey? _activeSessionKey;
  TeacherHomeworkRouteMutationLease? _activeLease;
  TeacherHomeworkRouteMutationActivityController? _activityController;
  var _operationGeneration = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherOfficialHomeworkState build() {
    _isDisposed = false;
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() {
        _isDisposed = true;
        _operationGeneration += 1;
        _releaseLease();
      });
    }

    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    ref.watch(teacherHomeworkDetailControllerProvider(target));
    ref.watch(teacherTopicResultPairControllerProvider(target.topicId));
    ref.watch(teacherHomeworkRouteMutationActivityProvider(target));
    if (sessionKey == null || sessionKey.surface != AppDeviceSurface.desktop) {
      _clearSession();
      return const TeacherOfficialHomeworkState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }
    _clearSession();
    _activeSessionKey = sessionKey;
    return const TeacherOfficialHomeworkState();
  }

  Future<void> setOfficial() async {
    final sessionKey = _activeSessionKey;
    final homework = _confirmedCurrentHomework();
    final pairState = ref.read(
      teacherTopicResultPairControllerProvider(target.topicId),
    );
    if (state.isBusy ||
        state.canCheckCurrent ||
        sessionKey == null ||
        homework == null ||
        !canSubmitOfficialHomework(homework: homework, pairState: pairState) ||
        !_matchesSession(sessionKey)) {
      return;
    }

    final activity = ref.read(
      teacherHomeworkRouteMutationActivityProvider(target).notifier,
    );
    final lease = activity.begin(
      TeacherHomeworkRouteMutationOperation.official,
    );
    if (lease == null) {
      return;
    }
    final generation = ++_operationGeneration;
    _activityController = activity;
    _activeLease = lease;
    state = TeacherOfficialHomeworkState(
      status: TeacherOfficialHomeworkStatus.submitting,
      requestedHomeworkId: target.homeworkId,
    );

    try {
      final pair = await ref
          .read(teacherTopicResultPairRepositoryProvider)
          .setOfficialHomework(target.topicId, target.homeworkId);
      if (!_canPublish(generation, lease)) {
        return;
      }
      if (!_matchesRequestedPair(pair)) {
        await _reconcile(generation, lease);
        return;
      }
      _publishSuccess(pair, lease);
    } on TeacherTopicResultPairMutationOutcomeUnknownException {
      await _reconcile(generation, lease);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, lease)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      await _publishDefiniteFailure(generation, lease, exception.failure);
    } catch (_) {
      await _reconcile(generation, lease);
    } finally {
      final remainsBlocking =
          ref.mounted &&
          !_isDisposed &&
          identical(_activeLease, lease) &&
          state.canCheckCurrent;
      if (!remainsBlocking) {
        activity.release(lease);
        if (identical(_activeLease, lease)) {
          _activeLease = null;
          _activityController = null;
        }
      }
    }
  }

  Future<void> checkCurrentOfficialHomework() async {
    final lease = _activeLease;
    if (!state.canCheckCurrent ||
        lease == null ||
        !_matchesSession(lease.sessionKey) ||
        !(_activityController?.owns(lease) ?? false)) {
      return;
    }
    final generation = ++_operationGeneration;
    await _reconcile(generation, lease);
  }

  void consumeFeedback() {
    if (state.status == TeacherOfficialHomeworkStatus.confirmedSuccess) {
      state = const TeacherOfficialHomeworkState();
    }
  }

  void invalidateRouteCompletions() {
    _operationGeneration += 1;
  }

  void leaveRoute() {
    invalidateRouteCompletions();
    _releaseLease();
    if (ref.mounted) {
      state = const TeacherOfficialHomeworkState();
    }
  }

  Future<void> _reconcile(
    int generation,
    TeacherHomeworkRouteMutationLease lease,
  ) async {
    if (!_canPublish(generation, lease)) {
      return;
    }
    state = TeacherOfficialHomeworkState(
      status: TeacherOfficialHomeworkStatus.reconciling,
      requestedHomeworkId: target.homeworkId,
    );
    try {
      final pair = await ref
          .read(teacherTopicResultPairRepositoryProvider)
          .fetchResultPair(target.topicId);
      if (!_canPublish(generation, lease)) {
        return;
      }
      _acceptPairRead(pair, lease.sessionKey);
      if (pair != null && _matchesRequestedPair(pair)) {
        _publishSuccess(pair, lease);
        return;
      }
      _releaseLease();
      state = TeacherOfficialHomeworkState(
        status: TeacherOfficialHomeworkStatus.outcomeReview,
        requestedHomeworkId: target.homeworkId,
        feedback:
            'The official Homework update result could not be confirmed. Review the current official Homework before trying again.',
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, lease)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      ref
          .read(
            teacherTopicResultPairControllerProvider(target.topicId).notifier,
          )
          .acceptReadFailure(exception.failure, lease.sessionKey);
      _publishBlockingOutcomeReview(lease);
    } catch (_) {
      if (_canPublish(generation, lease)) {
        ref
            .read(
              teacherTopicResultPairControllerProvider(target.topicId).notifier,
            )
            .acceptReadFailure(
              ApiFailure.local(
                kind: ApiFailureKind.unknown,
                message: 'The official Homework status could not be checked.',
              ),
              lease.sessionKey,
            );
        _publishBlockingOutcomeReview(lease);
      }
    }
  }

  void _publishBlockingOutcomeReview(TeacherHomeworkRouteMutationLease lease) {
    _activityController?.markOutcomeReviewBlocking(lease);
    state = TeacherOfficialHomeworkState(
      status: TeacherOfficialHomeworkStatus.outcomeReview,
      requestedHomeworkId: target.homeworkId,
      feedback:
          'The official Homework update result could not be confirmed. Review the current official Homework before trying again.',
      requiresCurrentCheck: true,
    );
  }

  void _publishSuccess(
    TeacherTopicResultPair pair,
    TeacherHomeworkRouteMutationLease lease,
  ) {
    _acceptPairRead(pair, lease.sessionKey);
    _releaseLease();
    state = TeacherOfficialHomeworkState(
      status: TeacherOfficialHomeworkStatus.confirmedSuccess,
      requestedHomeworkId: target.homeworkId,
      feedback: 'Official Homework updated successfully.',
    );
  }

  Future<void> _publishDefiniteFailure(
    int generation,
    TeacherHomeworkRouteMutationLease lease,
    ApiFailure failure,
  ) async {
    final shouldRefresh =
        failure.statusCode == 404 || failure.statusCode == 409;
    if (shouldRefresh) {
      state = TeacherOfficialHomeworkState(
        status: TeacherOfficialHomeworkStatus.reconciling,
        requestedHomeworkId: target.homeworkId,
        conflictCode: failure.serverCode,
      );
      await _refreshAfterDefiniteFailure(generation, lease);
      if (!_canPublish(generation, lease)) {
        return;
      }
    }

    final message = switch (failure.serverCode) {
      ApiErrorCodes.officialTaskRequiresGroupAssignment =>
        'Only whole-group Homework can be the official Homework.',
      ApiErrorCodes.resultPairLocked =>
        'Official Homework selection is locked by the current server state.',
      ApiErrorCodes.businessConflict =>
        'This Homework cannot become the official Homework in the current server state.\nReview the current Homework and Topic.',
      ApiErrorCodes.topicNotEditable => 'The Topic is no longer editable.',
      ApiErrorCodes.resourceNotFound =>
        'The requested Homework or Topic is no longer available in your current Teacher workspace.',
      ApiErrorCodes.validationFailed =>
        'The official Homework selection could not be validated.\nRefresh and review the current state.',
      ApiErrorCodes.forbidden =>
        'You do not have permission to update the official Homework.',
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying again.',
      _ => 'The official Homework could not be updated.',
    };
    _releaseLease();
    state = TeacherOfficialHomeworkState(
      status: TeacherOfficialHomeworkStatus.definiteFailure,
      requestedHomeworkId: target.homeworkId,
      feedback: message,
      conflictCode: failure.serverCode,
    );
  }

  Future<void> _refreshAfterDefiniteFailure(
    int generation,
    TeacherHomeworkRouteMutationLease lease,
  ) async {
    try {
      final pair = await ref
          .read(teacherTopicResultPairRepositoryProvider)
          .fetchResultPair(target.topicId);
      if (!_canPublish(generation, lease)) {
        return;
      }
      _acceptPairRead(pair, lease.sessionKey);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, lease)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      ref
          .read(
            teacherTopicResultPairControllerProvider(target.topicId).notifier,
          )
          .acceptReadFailure(exception.failure, lease.sessionKey);
    } catch (_) {
      if (_canPublish(generation, lease)) {
        ref
            .read(
              teacherTopicResultPairControllerProvider(target.topicId).notifier,
            )
            .acceptReadFailure(
              ApiFailure.local(
                kind: ApiFailureKind.unknown,
                message: 'The official Homework status could not be refreshed.',
              ),
              lease.sessionKey,
            );
      }
    }

    if (!_canPublish(generation, lease)) {
      return;
    }
    try {
      final homework = await ref
          .read(teacherHomeworkRepositoryProvider)
          .fetchHomework(target.homeworkId);
      if (!_canPublish(generation, lease)) {
        return;
      }
      if (_matchesTarget(homework)) {
        ref
            .read(teacherHomeworkDetailControllerProvider(target).notifier)
            .acceptAuthoritativeHomework(homework, lease.sessionKey);
      } else {
        _markHomeworkUnavailable(lease.sessionKey);
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, lease)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      if (exception.failure.statusCode == 404 &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        _markHomeworkUnavailable(lease.sessionKey);
      }
    } catch (_) {
      // The original mutation failure remains definite.
    }
  }

  void _acceptPairRead(
    TeacherTopicResultPair? pair,
    TeacherSessionKey sessionKey,
  ) {
    final controller = ref.read(
      teacherTopicResultPairControllerProvider(target.topicId).notifier,
    );
    if (pair == null) {
      controller.acceptNoPair(sessionKey);
    } else if (pair.topicId.toLowerCase() == target.topicId.toLowerCase()) {
      controller.acceptAuthoritativePair(pair, sessionKey);
    }
  }

  TeacherHomework? _confirmedCurrentHomework() {
    final detail = ref.read(teacherHomeworkDetailControllerProvider(target));
    final homework = detail.homework;
    if (detail.status != TeacherHomeworkDetailStatus.data ||
        detail.isStale ||
        homework == null ||
        !_matchesTarget(homework)) {
      return null;
    }
    return homework;
  }

  bool _matchesTarget(TeacherHomework homework) {
    return homework.id.toLowerCase() == target.homeworkId.toLowerCase() &&
        homework.topicId.toLowerCase() == target.topicId.toLowerCase();
  }

  bool _matchesRequestedPair(TeacherTopicResultPair pair) {
    return pair.topicId.toLowerCase() == target.topicId.toLowerCase() &&
        pair.homeworkAssessmentId.toLowerCase() ==
            target.homeworkId.toLowerCase();
  }

  bool _canPublish(int generation, TeacherHomeworkRouteMutationLease lease) {
    return ref.mounted &&
        !_isDisposed &&
        generation == _operationGeneration &&
        identical(_activeLease, lease) &&
        (_activityController?.owns(lease) ?? false) &&
        _matchesSession(lease.sessionKey);
  }

  bool _matchesSession(TeacherSessionKey sessionKey) {
    return ref.mounted &&
        !_isDisposed &&
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
    state = const TeacherOfficialHomeworkState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _markHomeworkUnavailable(TeacherSessionKey sessionKey) {
    ref
        .read(teacherHomeworkDetailControllerProvider(target).notifier)
        .markNotFound(sessionKey);
    final listProvider = teacherHomeworkListControllerProvider(target.topicId);
    if (ref.exists(listProvider)) {
      ref.read(listProvider.notifier).refreshAfterMutation(sessionKey);
    } else {
      ref.invalidate(listProvider);
    }
  }

  void _releaseLease() {
    final lease = _activeLease;
    final activity = _activityController;
    _activeLease = null;
    _activityController = null;
    if (lease != null) {
      activity?.release(lease);
    }
  }

  void _clearSession() {
    _operationGeneration += 1;
    _activeSessionKey = null;
    _releaseLease();
  }
}
