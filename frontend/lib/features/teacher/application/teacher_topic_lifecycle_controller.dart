import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_topic_repository_impl.dart';
import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_mutation.dart';
import 'teacher_session_key.dart';
import 'teacher_material_mutation_activity.dart';
import 'teacher_topic_detail_controller.dart';
import 'teacher_topic_lifecycle_state.dart';
import 'teacher_topic_list_controller.dart';

final teacherTopicLifecycleControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherTopicLifecycleController,
      TeacherTopicLifecycleState,
      String
    >(TeacherTopicLifecycleController.new);

class TeacherTopicLifecycleController
    extends Notifier<TeacherTopicLifecycleState> {
  TeacherTopicLifecycleController(this.topicId);

  final String topicId;
  TeacherSessionKey? _activeSessionKey;
  TeacherTopicLifecycleAction? _activeAction;
  int _operationGeneration = 0;
  var _pendingTopicNotEditable = false;

  @override
  TeacherTopicLifecycleState build() {
    final key = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (!isCanonicalTeacherTopicId(topicId) ||
        key == null ||
        key.surface != AppDeviceSurface.desktop) {
      _clearSession();
      return const TeacherTopicLifecycleState();
    }
    if (_activeSessionKey == key) {
      return state;
    }
    _clearSession();
    _activeSessionKey = key;
    return const TeacherTopicLifecycleState();
  }

  Future<void> perform(TeacherTopicLifecycleAction action) async {
    final key = _activeSessionKey;
    final current = ref
        .read(teacherTopicDetailControllerProvider(topicId))
        .topic;
    if (state.isBusy ||
        key == null ||
        ref
            .read(teacherMaterialMutationActivityProvider(topicId))
            .isActiveFor(key) ||
        current == null ||
        !teacherTopicLifecycleActions(current).contains(action) ||
        !_matchesSession(key)) {
      return;
    }
    final generation = ++_operationGeneration;
    _activeAction = action;
    _pendingTopicNotEditable = false;
    state = TeacherTopicLifecycleState(
      status: TeacherTopicLifecycleStatus.submitting,
      action: action,
    );
    try {
      final topic = await ref
          .read(teacherTopicRepositoryProvider)
          .performLifecycleAction(topicId, action);
      if (!_canPublish(generation, key, action)) {
        return;
      }
      _publishSuccess(topic, key, action);
    } on TeacherTopicMutationOutcomeUnknownException {
      await _reconcile(generation, key, action);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key, action)) {
        return;
      }
      if (exception.failure.statusCode == 409 &&
          exception.failure.serverCode == ApiErrorCodes.topicNotEditable) {
        _pendingTopicNotEditable = true;
        await _reconcile(
          generation,
          key,
          action,
          topicNotEditable: _pendingTopicNotEditable,
        );
      } else {
        _activeAction = null;
        _publishDefiniteFailure(exception.failure, action);
      }
    } catch (_) {
      await _reconcile(generation, key, action);
    }
  }

  Future<void> checkCurrentTopic() async {
    final key = _activeSessionKey;
    final action = state.action;
    if (!state.canCheckCurrent ||
        key == null ||
        action == null ||
        !_matchesSession(key)) {
      return;
    }
    final generation = ++_operationGeneration;
    _activeAction = action;
    await _reconcile(
      generation,
      key,
      action,
      topicNotEditable: _pendingTopicNotEditable,
    );
  }

  void consumeFeedback() {
    if (!state.isBusy && !state.canCheckCurrent) {
      state = const TeacherTopicLifecycleState();
    }
  }

  Future<void> _reconcile(
    int generation,
    TeacherSessionKey key,
    TeacherTopicLifecycleAction action, {
    bool topicNotEditable = false,
  }) async {
    if (!_canPublish(generation, key, action)) {
      return;
    }
    state = TeacherTopicLifecycleState(
      status: TeacherTopicLifecycleStatus.reconciling,
      action: action,
    );
    try {
      final current = await ref
          .read(teacherTopicRepositoryProvider)
          .fetchTopic(topicId);
      if (!_canPublish(generation, key, action)) {
        return;
      }
      ref
          .read(teacherTopicDetailControllerProvider(topicId).notifier)
          .acceptAuthoritativeTopic(current);
      _activeAction = null;
      if (topicNotEditable) {
        _pendingTopicNotEditable = false;
        state = TeacherTopicLifecycleState(
          status: TeacherTopicLifecycleStatus.notAvailable,
          action: action,
          feedback: _notAvailableMessage(action),
        );
      } else if (current.status == action.expectedStatus) {
        _publishSuccess(current, key, action);
      } else {
        _pendingTopicNotEditable = false;
        state = TeacherTopicLifecycleState(
          status: TeacherTopicLifecycleStatus.unconfirmedCurrentState,
          action: action,
          feedback:
              'The requested Topic action could not be confirmed. Current server state is shown.',
        );
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key, action)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      if (exception.failure.statusCode == 404 &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        _activeAction = null;
        _pendingTopicNotEditable = false;
        ref
            .read(teacherTopicDetailControllerProvider(topicId).notifier)
            .markNotFound();
        state = TeacherTopicLifecycleState(
          status: TeacherTopicLifecycleStatus.notAvailable,
          action: action,
          feedback: 'This Topic is unavailable.',
        );
        return;
      }
      state = TeacherTopicLifecycleState(
        status: TeacherTopicLifecycleStatus.outcomeUnknown,
        action: action,
        feedback:
            'The action outcome is unknown. Check the current Topic before taking another action.',
      );
    } catch (_) {
      if (_canPublish(generation, key, action)) {
        state = TeacherTopicLifecycleState(
          status: TeacherTopicLifecycleStatus.outcomeUnknown,
          action: action,
          feedback:
              'The action outcome is unknown. Check the current Topic before taking another action.',
        );
      }
    }
  }

  void _publishSuccess(
    TeacherTopic topic,
    TeacherSessionKey key,
    TeacherTopicLifecycleAction action,
  ) {
    _activeAction = null;
    _pendingTopicNotEditable = false;
    ref
        .read(teacherTopicDetailControllerProvider(topicId).notifier)
        .acceptAuthoritativeTopic(topic);
    ref
        .read(teacherTopicListRetainedQueryProvider)
        .markAuthoritativeRowsStale(key);
    if (ref.exists(teacherTopicListControllerProvider)) {
      ref.invalidate(teacherTopicListControllerProvider);
    }
    state = TeacherTopicLifecycleState(
      status: TeacherTopicLifecycleStatus.confirmedSuccess,
      action: action,
      feedback: action.successMessage,
    );
  }

  void _publishDefiniteFailure(
    ApiFailure failure,
    TeacherTopicLifecycleAction action,
  ) {
    _pendingTopicNotEditable = false;
    if (_clearForSessionFailure(failure)) {
      return;
    }
    if (failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound) {
      ref
          .read(teacherTopicDetailControllerProvider(topicId).notifier)
          .markNotFound();
    }
    final message = switch (failure.serverCode) {
      ApiErrorCodes.forbidden =>
        'You do not have permission to change this Topic.',
      ApiErrorCodes.resourceNotFound => 'This Topic is unavailable.',
      ApiErrorCodes.rateLimited =>
        'Too many requests. Wait before trying again.',
      _ => 'The Topic action could not be completed.',
    };
    state = TeacherTopicLifecycleState(
      status: TeacherTopicLifecycleStatus.definiteFailure,
      action: action,
      feedback: message,
    );
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
    state = const TeacherTopicLifecycleState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  bool _canPublish(
    int generation,
    TeacherSessionKey key,
    TeacherTopicLifecycleAction action,
  ) {
    return ref.mounted &&
        generation == _operationGeneration &&
        _activeAction == action &&
        _matchesSession(key);
  }

  bool _matchesSession(TeacherSessionKey key) {
    return ref.mounted &&
        _activeSessionKey == key &&
        key.surface == AppDeviceSurface.desktop &&
        TeacherSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            key;
  }

  void _clearSession() {
    _activeSessionKey = null;
    _operationGeneration += 1;
    _activeAction = null;
    _pendingTopicNotEditable = false;
  }
}

String _notAvailableMessage(TeacherTopicLifecycleAction action) {
  if (action == TeacherTopicLifecycleAction.activate) {
    return 'Activation was not available. Check the current Topic state, active Group context, required Topic information, and that at least one current Learning Material exists.';
  }

  return 'This action is not available in the current server state.';
}
