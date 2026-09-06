import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_homework_repository_impl.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_question_mutation.dart';
import 'teacher_homework_detail_controller.dart';
import 'teacher_homework_detail_state.dart';
import 'teacher_homework_list_controller.dart';
import 'teacher_homework_route_target.dart';
import 'teacher_question_builder_state.dart';
import 'teacher_question_mutation_activity.dart';
import 'teacher_session_key.dart';

final teacherQuestionBuilderControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherQuestionBuilderController,
      TeacherQuestionBuilderState,
      TeacherHomeworkRouteTarget
    >(TeacherQuestionBuilderController.new);

class TeacherQuestionBuilderController
    extends Notifier<TeacherQuestionBuilderState> {
  TeacherQuestionBuilderController(this.target);

  final TeacherHomeworkRouteTarget target;
  TeacherSessionKey? _activeSessionKey;
  var _routeGeneration = 0;
  var _editorGeneration = 0;
  var _ownsRoute = false;
  var _initialized = false;
  var _routeReloadRequired = false;
  var _routeReloadNeedsStart = false;
  var _routeReloadScheduled = false;
  var _routeReloadInFlight = false;
  var _routeReloadOnNextEnter = false;

  @override
  TeacherQuestionBuilderState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final detail = ref.watch(teacherHomeworkDetailControllerProvider(target));
    final activity = ref.watch(teacherQuestionMutationActivityProvider(target));

    if (sessionKey == null || sessionKey.surface != AppDeviceSurface.desktop) {
      _clearSession();
      return TeacherQuestionBuilderState(
        status: TeacherQuestionBuilderStatus.unavailable,
        sharedMutationActive: activity.isActive,
      );
    }
    if (_activeSessionKey != sessionKey) {
      _clearSession();
      _activeSessionKey = sessionKey;
    }

    _synchronizeRouteReload(detail, activity);

    if (_initialized &&
        state.pendingOperation != null &&
        (state.isLocalBusy || state.hasBlockingOutcome)) {
      return state.copyWith(sharedMutationActive: activity.isActive);
    }

    if (detail.status == TeacherHomeworkDetailStatus.notFound) {
      final retainedServerLock = _initialized ? state.serverLocked : false;
      _initialized = true;
      return TeacherQuestionBuilderState(
        status: TeacherQuestionBuilderStatus.unavailable,
        serverLocked: retainedServerLock,
        authoritativeReloadPending: false,
        sharedMutationActive: activity.isActive,
        notice: 'This Homework is no longer available.',
      );
    }

    final homework =
        detail.status == TeacherHomeworkDetailStatus.data && !detail.isStale
        ? detail.homework
        : null;
    if (homework == null || !_matchesTarget(homework)) {
      return _initialized
          ? state.copyWith(
              authoritativeReloadPending: _routeReloadRequired,
              sharedMutationActive: activity.isActive,
            )
          : TeacherQuestionBuilderState(
              sharedMutationActive: activity.isActive,
            );
    }

    final currentOrder = _questionOrder(homework);
    if (!_initialized || !state.orderInitialized) {
      final retainedServerLock = _initialized ? state.serverLocked : false;
      final retainedTopicNotEditable = _initialized
          ? state.topicNotEditable
          : false;
      _initialized = true;
      return TeacherQuestionBuilderState(
        authoritativeOrderIds: currentOrder,
        draftOrderIds: currentOrder,
        orderInitialized: true,
        serverLocked: retainedServerLock,
        topicNotEditable: retainedTopicNotEditable,
        authoritativeReloadPending: _routeReloadRequired,
        sharedMutationActive: activity.isActive,
      );
    }

    final authoritativeChanged = !_sameOrder(
      state.authoritativeOrderIds,
      currentOrder,
    );
    if (authoritativeChanged && state.orderDirty && !state.isBusy) {
      return state.copyWith(
        status: TeacherQuestionBuilderStatus.ready,
        authoritativeOrderIds: currentOrder,
        draftOrderIds: currentOrder,
        authoritativeReloadPending: _routeReloadRequired,
        sharedMutationActive: activity.isActive,
        notice:
            'The Question list changed on the server. Review the current order before reordering again.',
        pendingOperation: null,
      );
    }
    if (authoritativeChanged && !state.isBusy && !state.hasBlockingOutcome) {
      return state.copyWith(
        authoritativeOrderIds: currentOrder,
        draftOrderIds: currentOrder,
        authoritativeReloadPending: _routeReloadRequired,
        sharedMutationActive: activity.isActive,
      );
    }
    if (state.sharedMutationActive != activity.isActive ||
        state.authoritativeReloadPending != _routeReloadRequired) {
      return state.copyWith(
        authoritativeReloadPending: _routeReloadRequired,
        sharedMutationActive: activity.isActive,
      );
    }
    return state;
  }

  int enterRoute() {
    final replacingRoute = _ownsRoute;
    final activityController = ref.mounted
        ? ref.read(teacherQuestionMutationActivityProvider(target).notifier)
        : null;
    var activity = ref.mounted
        ? ref.read(teacherQuestionMutationActivityProvider(target))
        : const TeacherQuestionMutationActivityState();
    if (ref.mounted &&
        (activity.isActive ||
            activity.authoritativeReloadRequired ||
            _routeReloadOnNextEnter)) {
      activityController?.requireAuthoritativeReload(activity.lease);
      activity = ref.read(teacherQuestionMutationActivityProvider(target));
    }
    final requiresAuthoritativeReload =
        activity.isActive ||
        activity.authoritativeReloadRequired ||
        _routeReloadOnNextEnter;
    if (activity.outcomeReviewBlocking &&
        activity.lease != null &&
        ref.mounted) {
      activityController?.release(activity.lease!);
      activity = ref.read(teacherQuestionMutationActivityProvider(target));
    }
    _ownsRoute = true;
    final ownerGeneration = ++_routeGeneration;
    _routeReloadRequired = requiresAuthoritativeReload;
    _routeReloadNeedsStart = _routeReloadRequired;
    _routeReloadScheduled = false;
    _routeReloadInFlight = false;
    _routeReloadOnNextEnter = false;
    if ((replacingRoute || _routeReloadRequired) && ref.mounted) {
      state = _clearedRouteInstanceState(
        authoritativeReloadPending: _routeReloadRequired,
        sharedMutationActive: activity.isActive,
      );
      _synchronizeRouteReload(
        ref.read(teacherHomeworkDetailControllerProvider(target)),
        activity,
      );
    }
    return ownerGeneration;
  }

  bool isCurrentRouteOwner(
    TeacherSessionKey sessionKey, {
    required int ownerGeneration,
  }) {
    return _canUseRoute(sessionKey, ownerGeneration: ownerGeneration);
  }

  bool ownsRouteGeneration(int ownerGeneration) {
    return ref.mounted && _ownsRoute && ownerGeneration == _routeGeneration;
  }

  int nextEditorGeneration() => ++_editorGeneration;

  void leaveRoute([int? ownerGeneration]) {
    if (ownerGeneration != null &&
        (!_ownsRoute || ownerGeneration != _routeGeneration)) {
      return;
    }
    var activity = ref.mounted
        ? ref.read(teacherQuestionMutationActivityProvider(target))
        : const TeacherQuestionMutationActivityState();
    if (ref.mounted &&
        (activity.isActive ||
            activity.authoritativeReloadRequired ||
            _routeReloadRequired)) {
      final activityController = ref.read(
        teacherQuestionMutationActivityProvider(target).notifier,
      );
      activityController.requireAuthoritativeReload(activity.lease);
      activity = ref.read(teacherQuestionMutationActivityProvider(target));
    }
    _routeReloadOnNextEnter =
        _routeReloadOnNextEnter ||
        activity.isActive ||
        activity.authoritativeReloadRequired ||
        _routeReloadRequired;
    _ownsRoute = false;
    _routeGeneration += 1;
    _routeReloadRequired = false;
    _routeReloadNeedsStart = false;
    _routeReloadScheduled = false;
    _routeReloadInFlight = false;
    if (ref.mounted) {
      if (activity.outcomeReviewBlocking && activity.lease != null) {
        ref
            .read(teacherQuestionMutationActivityProvider(target).notifier)
            .release(activity.lease!);
        activity = ref.read(teacherQuestionMutationActivityProvider(target));
      }
      state = _clearedRouteInstanceState(
        sharedMutationActive: activity.isActive,
      );
    }
  }

  TeacherQuestionBuilderState _clearedRouteInstanceState({
    bool authoritativeReloadPending = false,
    bool sharedMutationActive = false,
  }) {
    return state.copyWith(
      status: TeacherQuestionBuilderStatus.ready,
      draftOrderIds: state.authoritativeOrderIds,
      serverLocked: false,
      topicNotEditable: false,
      authoritativeReloadPending: authoritativeReloadPending,
      sharedMutationActive: sharedMutationActive,
      notice: null,
      pendingOperation: null,
    );
  }

  void _synchronizeRouteReload(
    TeacherHomeworkDetailState detail,
    TeacherQuestionMutationActivityState activity,
  ) {
    if (!_routeReloadRequired) {
      return;
    }
    if (_routeReloadInFlight) {
      if (detail.status == TeacherHomeworkDetailStatus.data &&
          !detail.isStale &&
          detail.homework != null &&
          _matchesTarget(detail.homework!)) {
        _routeReloadRequired = false;
        _routeReloadInFlight = false;
        final sessionKey = _activeSessionKey;
        if (sessionKey != null) {
          _scheduleRouteReloadResolution(sessionKey);
        }
      } else if (detail.status == TeacherHomeworkDetailStatus.error ||
          detail.status == TeacherHomeworkDetailStatus.notFound) {
        _routeReloadInFlight = false;
        if (detail.status == TeacherHomeworkDetailStatus.notFound) {
          _routeReloadRequired = false;
          final sessionKey = _activeSessionKey;
          if (sessionKey != null) {
            _scheduleRouteReloadResolution(sessionKey);
          }
        }
      }
    }
    if (!_routeReloadRequired ||
        !_routeReloadNeedsStart ||
        _routeReloadScheduled ||
        _routeReloadInFlight ||
        activity.isActive ||
        detail.status == TeacherHomeworkDetailStatus.loading ||
        detail.status == TeacherHomeworkDetailStatus.refreshing) {
      return;
    }

    _routeReloadNeedsStart = false;
    _routeReloadScheduled = true;
    final ownerGeneration = _routeGeneration;
    scheduleMicrotask(() {
      _routeReloadScheduled = false;
      if (!ref.mounted ||
          !_ownsRoute ||
          ownerGeneration != _routeGeneration ||
          !_routeReloadRequired ||
          _routeReloadInFlight ||
          ref.read(teacherQuestionMutationActivityProvider(target)).isActive) {
        return;
      }
      _routeReloadInFlight = true;
      state = state.copyWith(authoritativeReloadPending: true);
      ref
          .read(teacherHomeworkDetailControllerProvider(target).notifier)
          .refresh();
    });
  }

  void _scheduleRouteReloadResolution(TeacherSessionKey sessionKey) {
    final ownerGeneration = _routeGeneration;
    final activity = ref.read(
      teacherQuestionMutationActivityProvider(target).notifier,
    );
    scheduleMicrotask(() {
      if (!ref.mounted ||
          !_ownsRoute ||
          _routeGeneration != ownerGeneration ||
          _activeSessionKey != sessionKey) {
        return;
      }
      activity.resolveAuthoritativeReload();
      _refreshHomeworkList(sessionKey);
    });
  }

  void clearNotice({required int ownerGeneration}) {
    if (!_matchesOwnerGeneration(ownerGeneration)) {
      return;
    }
    if (state.notice != null && !state.hasBlockingOutcome) {
      state = state.copyWith(notice: null);
    }
  }

  void refresh({required int ownerGeneration}) {
    if (!_matchesOwnerGeneration(ownerGeneration)) {
      return;
    }
    if (state.isBusy ||
        state.hasBlockingOutcome ||
        state.orderDirty ||
        _sharedActivity.isActive) {
      return;
    }
    final sessionKey = _activeSessionKey;
    if (sessionKey == null || !_canUseRoute(sessionKey)) {
      return;
    }
    final detail = ref.read(teacherHomeworkDetailControllerProvider(target));
    if (detail.status == TeacherHomeworkDetailStatus.loading ||
        detail.status == TeacherHomeworkDetailStatus.refreshing) {
      return;
    }
    if (_routeReloadRequired) {
      _routeReloadNeedsStart = false;
      _routeReloadScheduled = false;
      _routeReloadInFlight = true;
    }
    ref
        .read(teacherHomeworkDetailControllerProvider(target).notifier)
        .refresh();
  }

  void resetOrder({required int ownerGeneration}) {
    if (!_matchesOwnerGeneration(ownerGeneration)) {
      return;
    }
    if (state.isBusy ||
        state.hasBlockingOutcome ||
        !state.orderInitialized ||
        _sharedActivity.isActive) {
      return;
    }
    state = state.copyWith(draftOrderIds: state.authoritativeOrderIds);
  }

  void moveQuestionUp(String questionId, {required int ownerGeneration}) {
    _moveQuestion(questionId, -1, ownerGeneration: ownerGeneration);
  }

  void moveQuestionDown(String questionId, {required int ownerGeneration}) {
    _moveQuestion(questionId, 1, ownerGeneration: ownerGeneration);
  }

  void _moveQuestion(
    String questionId,
    int delta, {
    required int ownerGeneration,
  }) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null ||
        !_canUseRoute(sessionKey, ownerGeneration: ownerGeneration) ||
        state.isBusy ||
        state.hasBlockingOutcome ||
        state.serverLocked ||
        state.topicNotEditable ||
        state.authoritativeReloadPending ||
        _sharedActivity.isActive ||
        !_hasEditableHomework()) {
      return;
    }
    final current = state.draftOrderIds.toList();
    final index = current.indexWhere(
      (id) => id.toLowerCase() == questionId.toLowerCase(),
    );
    final next = index + delta;
    if (index < 0 || next < 0 || next >= current.length) {
      return;
    }
    final moved = current.removeAt(index);
    current.insert(next, moved);
    state = state.copyWith(draftOrderIds: current, notice: null);
  }

  Future<void> deleteQuestion(
    String questionId, {
    required int ownerGeneration,
  }) async {
    final detail = ref.read(teacherHomeworkDetailControllerProvider(target));
    final homework =
        detail.status == TeacherHomeworkDetailStatus.data && !detail.isStale
        ? detail.homework
        : null;
    final sessionKey = _activeSessionKey;
    if (homework == null ||
        sessionKey == null ||
        !_canMutate(homework, sessionKey, ownerGeneration: ownerGeneration) ||
        state.orderDirty ||
        !homework.questions.any(
          (question) => question.id.toLowerCase() == questionId.toLowerCase(),
        )) {
      return;
    }

    final activity = ref.read(
      teacherQuestionMutationActivityProvider(target).notifier,
    );
    final lease = activity.begin(TeacherQuestionMutationOperation.delete);
    if (lease == null) {
      return;
    }
    final pending = TeacherQuestionBuilderPendingOperation(
      lease: lease,
      authorityStateAtStart: detail,
      questionId: questionId,
    );
    final routeGeneration = _routeGeneration;
    state = state.copyWith(
      status: TeacherQuestionBuilderStatus.deleting,
      notice: null,
      pendingOperation: pending,
    );
    try {
      final returned = await ref
          .read(teacherHomeworkRepositoryProvider)
          .deleteQuestion(questionId);
      if (!_canPublish(pending, routeGeneration)) {
        return;
      }
      if (!_matchesTarget(returned)) {
        await _reconcile(pending, routeGeneration);
        return;
      }
      if (!_detailAuthorityUnchanged(pending)) {
        await _reconcile(pending.withConfirmedTransport(), routeGeneration);
        return;
      }
      _publishConfirmed(returned, pending, 'Question deleted successfully.');
    } on TeacherQuestionMutationOutcomeUnknownException {
      await _reconcile(pending, routeGeneration);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(pending, routeGeneration)) {
        return;
      }
      await _handleDefiniteFailure(exception.failure, pending, routeGeneration);
    } catch (_) {
      await _reconcile(pending, routeGeneration);
    } finally {
      _releaseIfAbandoned(pending, routeGeneration, activity);
    }
  }

  Future<void> saveOrder({required int ownerGeneration}) async {
    final detail = ref.read(teacherHomeworkDetailControllerProvider(target));
    final homework =
        detail.status == TeacherHomeworkDetailStatus.data && !detail.isStale
        ? detail.homework
        : null;
    final sessionKey = _activeSessionKey;
    if (homework == null ||
        sessionKey == null ||
        !_canMutate(homework, sessionKey, ownerGeneration: ownerGeneration) ||
        !state.orderDirty ||
        !_sameOrder(_questionOrder(homework), state.authoritativeOrderIds) ||
        !_sameIdSet(state.authoritativeOrderIds, state.draftOrderIds)) {
      if (homework != null) {
        _resetForAuthoritativeChange(homework);
      }
      return;
    }

    late final TeacherQuestionReorderRequest request;
    try {
      request = TeacherQuestionReorderRequest(questionIds: state.draftOrderIds);
    } on ArgumentError {
      _resetForAuthoritativeChange(homework);
      return;
    }
    final activity = ref.read(
      teacherQuestionMutationActivityProvider(target).notifier,
    );
    final lease = activity.begin(TeacherQuestionMutationOperation.reorder);
    if (lease == null) {
      return;
    }
    final pending = TeacherQuestionBuilderPendingOperation(
      lease: lease,
      authorityStateAtStart: detail,
      requestedOrderIds: request.questionIds,
    );
    final routeGeneration = _routeGeneration;
    state = state.copyWith(
      status: TeacherQuestionBuilderStatus.reordering,
      notice: null,
      pendingOperation: pending,
    );
    try {
      final returned = await ref
          .read(teacherHomeworkRepositoryProvider)
          .reorderQuestions(target.homeworkId, request);
      if (!_canPublish(pending, routeGeneration)) {
        return;
      }
      if (!_matchesTarget(returned)) {
        await _reconcile(pending, routeGeneration);
        return;
      }
      if (!_detailAuthorityUnchanged(pending)) {
        await _reconcile(pending.withConfirmedTransport(), routeGeneration);
        return;
      }
      _publishConfirmed(returned, pending, 'Questions reordered successfully.');
    } on TeacherQuestionMutationOutcomeUnknownException {
      await _reconcile(pending, routeGeneration);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(pending, routeGeneration)) {
        return;
      }
      await _handleDefiniteFailure(exception.failure, pending, routeGeneration);
    } catch (_) {
      await _reconcile(pending, routeGeneration);
    } finally {
      _releaseIfAbandoned(pending, routeGeneration, activity);
    }
  }

  Future<void> checkCurrentHomework({required int ownerGeneration}) async {
    if (!_matchesOwnerGeneration(ownerGeneration)) {
      return;
    }
    final pending = state.pendingOperation;
    if (state.status != TeacherQuestionBuilderStatus.outcomeReview ||
        pending == null) {
      return;
    }
    await _reconcile(pending, _routeGeneration);
  }

  void acceptEditorAuthoritativeHomework({
    required TeacherHomework homework,
    required TeacherSessionKey sessionKey,
    required int ownerGeneration,
    required String notice,
    bool serverLocked = false,
    bool topicNotEditable = false,
  }) {
    if (!_canUseRoute(sessionKey, ownerGeneration: ownerGeneration) ||
        !_matchesTarget(homework)) {
      return;
    }
    _acceptAuthoritativeHomework(homework, sessionKey);
    final order = _questionOrder(homework);
    state = state.copyWith(
      status: TeacherQuestionBuilderStatus.ready,
      authoritativeOrderIds: order,
      draftOrderIds: order,
      orderInitialized: true,
      serverLocked: state.serverLocked || serverLocked,
      topicNotEditable: state.topicNotEditable || topicNotEditable,
      notice: notice,
      pendingOperation: null,
    );
  }

  void showEditorNotice({
    required TeacherSessionKey sessionKey,
    required int ownerGeneration,
    required String notice,
    bool serverLocked = false,
  }) {
    if (!_canUseRoute(sessionKey, ownerGeneration: ownerGeneration)) {
      return;
    }
    state = state.copyWith(
      status: TeacherQuestionBuilderStatus.ready,
      serverLocked: state.serverLocked || serverLocked,
      notice: notice,
    );
  }

  void markEditorTargetUnavailable(
    TeacherSessionKey sessionKey, {
    required int ownerGeneration,
  }) {
    if (!_canUseRoute(sessionKey, ownerGeneration: ownerGeneration)) {
      return;
    }
    ref
        .read(teacherHomeworkDetailControllerProvider(target).notifier)
        .markNotFound(sessionKey);
    _refreshHomeworkList(sessionKey);
    state = state.copyWith(
      status: TeacherQuestionBuilderStatus.unavailable,
      notice: 'This Homework is no longer available.',
    );
  }

  Future<void> _handleDefiniteFailure(
    ApiFailure failure,
    TeacherQuestionBuilderPendingOperation pending,
    int routeGeneration,
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
        routeGeneration,
      );
      return;
    }
    if (failure.statusCode == 409 && _isQuestionConflict(failure.serverCode)) {
      await _reconcile(
        pending.withConflictCode(failure.serverCode!),
        routeGeneration,
      );
      return;
    }
    if (failure.statusCode == 422 &&
        failure.serverCode == ApiErrorCodes.validationFailed &&
        pending.operation == TeacherQuestionMutationOperation.reorder) {
      await _reconcile(
        pending.withConflictCode(ApiErrorCodes.validationFailed),
        routeGeneration,
      );
      return;
    }

    _release(pending);
    final message = switch (failure.serverCode) {
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying again.',
      ApiErrorCodes.forbidden =>
        'You do not have permission to change these Questions.',
      _ => 'The Question change could not be completed.',
    };
    state = state.copyWith(
      status: TeacherQuestionBuilderStatus.ready,
      notice: message,
      pendingOperation: null,
    );
  }

  Future<void> _reconcile(
    TeacherQuestionBuilderPendingOperation pending,
    int routeGeneration,
  ) async {
    if (!_canPublish(pending, routeGeneration)) {
      return;
    }
    state = state.copyWith(
      status: TeacherQuestionBuilderStatus.reconciling,
      pendingOperation: pending,
    );
    try {
      final current = await ref
          .read(teacherHomeworkRepositoryProvider)
          .fetchHomework(target.homeworkId);
      if (!_canPublish(pending, routeGeneration)) {
        return;
      }
      if (!_matchesTarget(current)) {
        _publishUnavailable(pending);
        return;
      }
      _acceptAuthoritativeHomework(current, pending.lease.sessionKey);

      final conflictCode = pending.conflictCode;
      if (conflictCode != null) {
        _release(pending);
        final serverLocked =
            conflictCode == ApiErrorCodes.businessConflict ||
            conflictCode == ApiErrorCodes.resultPairLocked;
        final topicNotEditable = conflictCode == ApiErrorCodes.topicNotEditable;
        final message = _conflictMessage(conflictCode, pending.operation);
        final order = _questionOrder(current);
        state = state.copyWith(
          status: TeacherQuestionBuilderStatus.ready,
          authoritativeOrderIds: order,
          draftOrderIds: order,
          orderInitialized: true,
          serverLocked: state.serverLocked || serverLocked,
          topicNotEditable: state.topicNotEditable || topicNotEditable,
          notice: message,
          pendingOperation: null,
        );
        return;
      }

      if (pending.transportConfirmed) {
        _publishConfirmed(
          current,
          pending,
          pending.operation == TeacherQuestionMutationOperation.delete
              ? 'Question deleted successfully.'
              : 'Questions reordered successfully.',
        );
        return;
      }

      final proven = switch (pending.operation) {
        TeacherQuestionMutationOperation.delete => !current.questions.any(
          (question) =>
              question.id.toLowerCase() == pending.questionId!.toLowerCase(),
        ),
        TeacherQuestionMutationOperation.reorder => _sameOrder(
          _questionOrder(current),
          pending.requestedOrderIds!,
        ),
        TeacherQuestionMutationOperation.add ||
        TeacherQuestionMutationOperation.update => false,
      };
      final message = proven
          ? pending.operation == TeacherQuestionMutationOperation.delete
                ? 'Question deleted successfully.'
                : 'Questions reordered successfully.'
          : pending.operation == TeacherQuestionMutationOperation.delete
          ? 'The delete result could not be confirmed. Review the current Question list before trying again.'
          : 'The reorder result could not be confirmed. Review the current Question order before trying again.';
      _release(pending);
      final order = _questionOrder(current);
      state = state.copyWith(
        status: TeacherQuestionBuilderStatus.ready,
        authoritativeOrderIds: order,
        draftOrderIds: order,
        orderInitialized: true,
        notice: message,
        pendingOperation: null,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(pending, routeGeneration)) {
        return;
      }
      if (_isSessionFailure(exception.failure)) {
        _release(pending);
        _clearForSessionFailure(exception.failure);
        return;
      }
      if (exception.failure.statusCode == 404 &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        _publishUnavailable(pending);
        return;
      }
      _publishBlockingReview(pending);
    } catch (_) {
      if (_canPublish(pending, routeGeneration)) {
        _publishBlockingReview(pending);
      }
    }
  }

  void _publishBlockingReview(TeacherQuestionBuilderPendingOperation pending) {
    ref
        .read(teacherQuestionMutationActivityProvider(target).notifier)
        .markOutcomeReviewBlocking(pending.lease);
    state = state.copyWith(
      status: TeacherQuestionBuilderStatus.outcomeReview,
      notice:
          'The current Homework could not be confirmed. Check the current Homework before taking another action.',
      pendingOperation: pending,
    );
  }

  void _publishConfirmed(
    TeacherHomework homework,
    TeacherQuestionBuilderPendingOperation pending,
    String message,
  ) {
    _acceptAuthoritativeHomework(homework, pending.lease.sessionKey);
    _release(pending);
    final order = _questionOrder(homework);
    state = state.copyWith(
      status: TeacherQuestionBuilderStatus.ready,
      authoritativeOrderIds: order,
      draftOrderIds: order,
      orderInitialized: true,
      notice: message,
      pendingOperation: null,
    );
  }

  void _publishUnavailable(TeacherQuestionBuilderPendingOperation pending) {
    ref
        .read(teacherHomeworkDetailControllerProvider(target).notifier)
        .markNotFound(pending.lease.sessionKey);
    _refreshHomeworkList(pending.lease.sessionKey);
    _release(pending);
    state = state.copyWith(
      status: TeacherQuestionBuilderStatus.unavailable,
      notice: 'This Homework is no longer available.',
      pendingOperation: null,
    );
  }

  void _resetForAuthoritativeChange(TeacherHomework homework) {
    final order = _questionOrder(homework);
    state = state.copyWith(
      status: TeacherQuestionBuilderStatus.ready,
      authoritativeOrderIds: order,
      draftOrderIds: order,
      orderInitialized: true,
      notice:
          'The Question list changed on the server. Review the current order before reordering again.',
    );
  }

  void _acceptAuthoritativeHomework(
    TeacherHomework homework,
    TeacherSessionKey sessionKey,
  ) {
    ref
        .read(teacherHomeworkDetailControllerProvider(target).notifier)
        .acceptAuthoritativeHomework(homework, sessionKey);
    _refreshHomeworkList(sessionKey);
  }

  void _refreshHomeworkList(TeacherSessionKey sessionKey) {
    final provider = teacherHomeworkListControllerProvider(target.topicId);
    if (ref.exists(provider)) {
      ref.read(provider.notifier).refreshAfterMutation(sessionKey);
    } else {
      ref.invalidate(provider);
    }
  }

  void _release(TeacherQuestionBuilderPendingOperation pending) {
    ref
        .read(teacherQuestionMutationActivityProvider(target).notifier)
        .release(pending.lease);
  }

  void _releaseIfAbandoned(
    TeacherQuestionBuilderPendingOperation pending,
    int routeGeneration,
    TeacherQuestionMutationActivityController activity,
  ) {
    final remainsBlocking =
        ref.mounted &&
        _canPublish(pending, routeGeneration) &&
        state.status == TeacherQuestionBuilderStatus.outcomeReview;
    if (!remainsBlocking) {
      activity.release(pending.lease);
    }
  }

  bool _canPublish(
    TeacherQuestionBuilderPendingOperation pending,
    int routeGeneration,
  ) {
    return ref.mounted &&
        _ownsRoute &&
        routeGeneration == _routeGeneration &&
        identical(state.pendingOperation?.lease, pending.lease) &&
        ref
            .read(teacherQuestionMutationActivityProvider(target).notifier)
            .owns(pending.lease) &&
        _canUseRoute(pending.lease.sessionKey);
  }

  bool _canMutate(
    TeacherHomework homework,
    TeacherSessionKey sessionKey, {
    required int ownerGeneration,
  }) {
    return _canUseRoute(sessionKey, ownerGeneration: ownerGeneration) &&
        _matchesTarget(homework) &&
        (homework.status == TeacherHomeworkStatus.draft ||
            homework.status == TeacherHomeworkStatus.active) &&
        !state.serverLocked &&
        !state.topicNotEditable &&
        !state.authoritativeReloadPending &&
        !state.isBusy &&
        !state.hasBlockingOutcome &&
        !ref.read(teacherQuestionMutationActivityProvider(target)).isActive;
  }

  bool _hasEditableHomework() {
    final detail = ref.read(teacherHomeworkDetailControllerProvider(target));
    final homework =
        detail.status == TeacherHomeworkDetailStatus.data && !detail.isStale
        ? detail.homework
        : null;
    return homework != null &&
        _matchesTarget(homework) &&
        (homework.status == TeacherHomeworkStatus.draft ||
            homework.status == TeacherHomeworkStatus.active);
  }

  bool _canUseRoute(TeacherSessionKey sessionKey, {int? ownerGeneration}) {
    return ref.mounted &&
        _ownsRoute &&
        _matchesOwnerGeneration(ownerGeneration) &&
        _activeSessionKey == sessionKey &&
        sessionKey.surface == AppDeviceSurface.desktop &&
        TeacherSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            sessionKey;
  }

  bool _matchesOwnerGeneration(int? ownerGeneration) {
    return ownerGeneration == null ||
        (_ownsRoute && ownerGeneration == _routeGeneration);
  }

  bool _matchesTarget(TeacherHomework homework) {
    return homework.id.toLowerCase() == target.homeworkId.toLowerCase() &&
        homework.topicId.toLowerCase() == target.topicId.toLowerCase();
  }

  bool _detailAuthorityUnchanged(
    TeacherQuestionBuilderPendingOperation pending,
  ) {
    return identical(
      ref.read(teacherHomeworkDetailControllerProvider(target)),
      pending.authorityStateAtStart,
    );
  }

  void _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    _clearSession();
    state = TeacherQuestionBuilderState();
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

  TeacherQuestionMutationActivityState get _sharedActivity =>
      ref.read(teacherQuestionMutationActivityProvider(target));

  void _clearSession() {
    _activeSessionKey = null;
    _initialized = false;
    _routeReloadRequired = false;
    _routeReloadNeedsStart = false;
    _routeReloadScheduled = false;
    _routeReloadInFlight = false;
    _routeReloadOnNextEnter = false;
  }
}

List<String> _questionOrder(TeacherHomework homework) {
  final questions = homework.questions.toList()
    ..sort((left, right) => left.position.compareTo(right.position));
  return List<String>.unmodifiable(
    questions.map((question) => question.id.toLowerCase()),
  );
}

bool _sameOrder(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index].toLowerCase() != right[index].toLowerCase()) {
      return false;
    }
  }
  return true;
}

bool _sameIdSet(List<String> left, List<String> right) {
  final leftSet = left.map((id) => id.toLowerCase()).toSet();
  final rightSet = right.map((id) => id.toLowerCase()).toSet();
  return leftSet.length == left.length &&
      rightSet.length == right.length &&
      leftSet.length == rightSet.length &&
      leftSet.containsAll(rightSet);
}

bool _isQuestionConflict(String? code) {
  return code == ApiErrorCodes.topicNotEditable ||
      code == ApiErrorCodes.taskClosed ||
      code == ApiErrorCodes.taskArchived ||
      code == ApiErrorCodes.businessConflict ||
      code == ApiErrorCodes.resultPairLocked ||
      code == ApiErrorCodes.assessmentHasNoScoreablePoints;
}

String _conflictMessage(
  String code,
  TeacherQuestionMutationOperation operation,
) {
  return switch (code) {
    ApiErrorCodes.businessConflict || ApiErrorCodes.resultPairLocked =>
      'Question editing is locked by the current server state. Review the current Homework before continuing.',
    ApiErrorCodes.taskClosed => 'This Homework is closed.',
    ApiErrorCodes.taskArchived => 'This Homework is archived.',
    ApiErrorCodes.topicNotEditable => 'The Topic is no longer editable.',
    ApiErrorCodes.assessmentHasNoScoreablePoints
        when operation == TeacherQuestionMutationOperation.delete =>
      'An active Homework must keep at least one scoreable Question. Add or adjust another Question before deleting this one.',
    ApiErrorCodes.assessmentHasNoScoreablePoints =>
      'An active Homework must keep at least one scoreable Question.',
    ApiErrorCodes.resourceNotFound
        when operation == TeacherQuestionMutationOperation.delete =>
      'This Question is no longer available. Review the current Question list before trying again.',
    ApiErrorCodes.resourceNotFound =>
      'The Question target is no longer available. Review the current Homework before trying again.',
    ApiErrorCodes.validationFailed =>
      'The Question list changed. Review the current order and try again.',
    _ => 'The Question change could not be completed.',
  };
}
