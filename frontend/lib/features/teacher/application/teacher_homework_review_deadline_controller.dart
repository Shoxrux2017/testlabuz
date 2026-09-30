import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_homework_repository_impl.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_homework_mutation.dart';
import 'teacher_homework_detail_controller.dart';
import 'teacher_homework_detail_state.dart';
import 'teacher_homework_list_controller.dart';
import 'teacher_homework_review_deadline_state.dart';
import 'teacher_homework_route_mutation_activity.dart';
import 'teacher_homework_route_target.dart';
import 'teacher_session_key.dart';

final teacherHomeworkReviewDeadlineControllerProvider = NotifierProvider
    .autoDispose
    .family<
      TeacherHomeworkReviewDeadlineController,
      TeacherHomeworkReviewDeadlineState,
      TeacherHomeworkRouteTarget
    >(TeacherHomeworkReviewDeadlineController.new);

const _unconfirmedFeedback =
    'The review deadline change could not be confirmed.\nReview the current Homework before trying again.';

/// Sets or clears a Homework's review deadline, a reminder that never changes
/// scores (`S09-D2`), through the dedicated endpoint; desktop only.
class TeacherHomeworkReviewDeadlineController
    extends Notifier<TeacherHomeworkReviewDeadlineState> {
  TeacherHomeworkReviewDeadlineController(this.target);

  final TeacherHomeworkRouteTarget target;
  TeacherSessionKey? _activeSessionKey;
  TeacherHomeworkRouteMutationLease? _activeLease;
  TeacherHomeworkRouteMutationActivityController? _activityController;
  TeacherHomeworkReviewDueAtRequest? _activeRequest;
  var _operationGeneration = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherHomeworkReviewDeadlineState build() {
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
    if (sessionKey == null || sessionKey.surface != AppDeviceSurface.desktop) {
      _clearSession();
      return const TeacherHomeworkReviewDeadlineState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }
    _clearSession();
    _activeSessionKey = sessionKey;
    return const TeacherHomeworkReviewDeadlineState();
  }

  Future<void> submit(TeacherHomeworkReviewDueAtRequest request) async {
    final sessionKey = _activeSessionKey;
    final homework = _confirmedCurrentHomework();
    if (state.isBusy ||
        state.canCheckCurrent ||
        sessionKey == null ||
        homework == null ||
        homework.status == TeacherHomeworkStatus.archived ||
        !_matchesSession(sessionKey)) {
      return;
    }

    final activity = ref.read(
      teacherHomeworkRouteMutationActivityProvider(target).notifier,
    );
    final lease = activity.begin(
      TeacherHomeworkRouteMutationOperation.reviewDeadline,
    );
    if (lease == null) {
      return;
    }
    final generation = ++_operationGeneration;
    _activityController = activity;
    _activeLease = lease;
    _activeRequest = request;
    state = const TeacherHomeworkReviewDeadlineState(
      status: TeacherHomeworkReviewDeadlineStatus.submitting,
    );

    try {
      final returned = await ref
          .read(teacherHomeworkRepositoryProvider)
          .setReviewDueAt(target.homeworkId, request);
      if (!_canPublish(generation, lease)) {
        return;
      }
      if (!_matchesTarget(returned) || !request.matches(returned)) {
        await _reconcile(generation, lease, request);
        return;
      }
      _publishSuccess(returned, lease, request);
    } on TeacherHomeworkMutationOutcomeUnknownException {
      await _reconcile(generation, lease, request);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, lease)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      await _publishDefiniteFailure(generation, lease, exception.failure);
    } catch (_) {
      await _reconcile(generation, lease, request);
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
          _activeRequest = null;
        }
      }
    }
  }

  Future<void> checkCurrentHomework() async {
    final lease = _activeLease;
    final request = _activeRequest;
    if (!state.canCheckCurrent ||
        lease == null ||
        request == null ||
        !_matchesSession(lease.sessionKey) ||
        !(_activityController?.owns(lease) ?? false)) {
      return;
    }
    final generation = ++_operationGeneration;
    await _reconcile(generation, lease, request);
  }

  void consumeFeedback() {
    if (state.status == TeacherHomeworkReviewDeadlineStatus.confirmedSuccess) {
      state = const TeacherHomeworkReviewDeadlineState();
    }
  }

  void invalidateRouteCompletions() {
    _operationGeneration += 1;
  }

  void leaveRoute() {
    invalidateRouteCompletions();
    _releaseLease();
    if (ref.mounted) {
      state = const TeacherHomeworkReviewDeadlineState();
    }
  }

  Future<void> _reconcile(
    int generation,
    TeacherHomeworkRouteMutationLease lease,
    TeacherHomeworkReviewDueAtRequest request,
  ) async {
    if (!_canPublish(generation, lease)) {
      return;
    }
    state = const TeacherHomeworkReviewDeadlineState(
      status: TeacherHomeworkReviewDeadlineStatus.reconciling,
    );
    try {
      final current = await ref
          .read(teacherHomeworkRepositoryProvider)
          .fetchHomework(target.homeworkId);
      if (!_canPublish(generation, lease)) {
        return;
      }
      if (_matchesTarget(current)) {
        _acceptHomework(current, lease.sessionKey);
        if (request.matches(current)) {
          _publishSuccess(current, lease, request);
          return;
        }
      }
      _releaseLease();
      state = const TeacherHomeworkReviewDeadlineState(
        status: TeacherHomeworkReviewDeadlineStatus.outcomeReview,
        feedback: _unconfirmedFeedback,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, lease)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      _publishBlockingOutcomeReview(lease);
    } catch (_) {
      if (_canPublish(generation, lease)) {
        _publishBlockingOutcomeReview(lease);
      }
    }
  }

  void _publishBlockingOutcomeReview(TeacherHomeworkRouteMutationLease lease) {
    _activityController?.markOutcomeReviewBlocking(lease);
    state = const TeacherHomeworkReviewDeadlineState(
      status: TeacherHomeworkReviewDeadlineStatus.outcomeReview,
      feedback: _unconfirmedFeedback,
      requiresCurrentCheck: true,
    );
  }

  void _publishSuccess(
    TeacherHomework homework,
    TeacherHomeworkRouteMutationLease lease,
    TeacherHomeworkReviewDueAtRequest request,
  ) {
    _acceptHomework(homework, lease.sessionKey);
    _releaseLease();
    state = TeacherHomeworkReviewDeadlineState(
      status: TeacherHomeworkReviewDeadlineStatus.confirmedSuccess,
      feedback: request.reviewDueAtUtc == null
          ? 'Review deadline cleared.'
          : 'Review deadline saved.',
    );
  }

  Future<void> _publishDefiniteFailure(
    int generation,
    TeacherHomeworkRouteMutationLease lease,
    ApiFailure failure,
  ) async {
    if (failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound) {
      _markHomeworkUnavailable(lease.sessionKey);
      _releaseLease();
      state = const TeacherHomeworkReviewDeadlineState();
      return;
    }
    if (failure.statusCode == 409) {
      state = const TeacherHomeworkReviewDeadlineState(
        status: TeacherHomeworkReviewDeadlineStatus.reconciling,
      );
      await _refreshAfterConflict(generation, lease);
      if (!_canPublish(generation, lease)) {
        return;
      }
    }

    final message = switch (failure.serverCode) {
      ApiErrorCodes.taskArchived =>
        'This Homework is archived. Its review deadline can no longer be changed.',
      ApiErrorCodes.topicNotEditable =>
        'The Topic is closed or archived. The review deadline can no longer be changed.',
      ApiErrorCodes.validationFailed =>
        'The review deadline could not be validated.\nRefresh and try again.',
      ApiErrorCodes.forbidden =>
        'You do not have permission to change this review deadline.',
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying again.',
      _ => 'The review deadline could not be updated.',
    };
    _releaseLease();
    state = TeacherHomeworkReviewDeadlineState(
      status: TeacherHomeworkReviewDeadlineStatus.definiteFailure,
      feedback: message,
      conflictCode: failure.serverCode,
    );
  }

  Future<void> _refreshAfterConflict(
    int generation,
    TeacherHomeworkRouteMutationLease lease,
  ) async {
    try {
      final homework = await ref
          .read(teacherHomeworkRepositoryProvider)
          .fetchHomework(target.homeworkId);
      if (_canPublish(generation, lease) && _matchesTarget(homework)) {
        _acceptHomework(homework, lease.sessionKey);
      }
    } on ApiRequestException catch (exception) {
      if (_canPublish(generation, lease)) {
        _clearForSessionFailure(exception.failure);
      }
    } catch (_) {
      // The conflict itself remains definite.
    }
  }

  void _acceptHomework(TeacherHomework homework, TeacherSessionKey sessionKey) {
    ref
        .read(teacherHomeworkDetailControllerProvider(target).notifier)
        .acceptAuthoritativeHomework(homework, sessionKey);
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
    state = const TeacherHomeworkReviewDeadlineState();
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
    _activeRequest = null;
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
