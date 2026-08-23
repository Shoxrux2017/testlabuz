import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_topic_repository_impl.dart';
import '../domain/teacher_topic.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_detail_state.dart';

final teacherTopicDetailControllerProvider = NotifierProvider.autoDispose
    .family<TeacherTopicDetailController, TeacherTopicDetailState, String>(
      TeacherTopicDetailController.new,
    );

class TeacherTopicDetailController extends Notifier<TeacherTopicDetailState> {
  TeacherTopicDetailController(this.topicId);

  final String topicId;
  TeacherSessionKey? _activeSessionKey;
  int _generation = 0;
  var _disposeRegistered = false;

  @override
  TeacherTopicDetailState build() {
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() => _generation += 1);
    }
    final key = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (!isCanonicalTeacherTopicId(topicId) || key == null) {
      _clearOwnership();
      return const TeacherTopicDetailState();
    }
    if (_activeSessionKey == key) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = key;
    scheduleMicrotask(() => _load(key, retainTopic: false));

    return const TeacherTopicDetailState(
      status: TeacherTopicDetailStatus.loading,
    );
  }

  void refresh() {
    final key = _activeSessionKey;
    if (key == null || state.isLoading || !_matchesSession(key)) {
      return;
    }
    unawaited(_load(key, retainTopic: state.topic != null));
  }

  Future<TeacherTopic?> refreshForMaterialReconciliation() async {
    final key = _activeSessionKey;
    if (key == null || state.isLoading || !_matchesSession(key)) {
      return null;
    }
    return _load(key, retainTopic: state.topic != null);
  }

  void acceptAuthoritativeTopic(TeacherTopic topic) {
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        topic.id.toLowerCase() != topicId.toLowerCase()) {
      return;
    }
    _generation += 1;
    state = TeacherTopicDetailState(
      status: TeacherTopicDetailStatus.data,
      topic: topic,
    );
  }

  void markNotFound() {
    final key = _activeSessionKey;
    if (key == null || !_matchesSession(key)) {
      return;
    }
    _generation += 1;
    state = const TeacherTopicDetailState(
      status: TeacherTopicDetailStatus.notFound,
    );
  }

  Future<TeacherTopic?> _load(
    TeacherSessionKey key, {
    required bool retainTopic,
  }) async {
    final generation = ++_generation;
    final retainedTopic = retainTopic ? state.topic : null;
    state = TeacherTopicDetailState(
      status: retainedTopic == null
          ? TeacherTopicDetailStatus.loading
          : TeacherTopicDetailStatus.refreshing,
      topic: retainedTopic,
    );
    try {
      final topic = await ref
          .read(teacherTopicRepositoryProvider)
          .fetchTopic(topicId);
      if (!_canPublish(generation, key)) {
        return null;
      }
      state = TeacherTopicDetailState(
        status: TeacherTopicDetailStatus.data,
        topic: topic,
      );
      return topic;
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key)) {
        return null;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return null;
      }
      if (exception.failure.statusCode == 404 &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        state = const TeacherTopicDetailState(
          status: TeacherTopicDetailStatus.notFound,
        );
        return null;
      }
      state = TeacherTopicDetailState(
        status: TeacherTopicDetailStatus.error,
        failure: exception.failure,
      );
      return null;
    } catch (_) {
      if (_canPublish(generation, key)) {
        state = TeacherTopicDetailState(
          status: TeacherTopicDetailStatus.error,
          failure: ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Teacher Topic detail failure.',
          ),
        );
      }
      return null;
    }
  }

  bool _canPublish(int generation, TeacherSessionKey key) {
    return ref.mounted &&
        generation == _generation &&
        _activeSessionKey == key &&
        _matchesSession(key);
  }

  bool _matchesSession(TeacherSessionKey key) {
    return ref.mounted &&
        _activeSessionKey == key &&
        TeacherSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            key;
  }

  bool _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code != ApiErrorCodes.authenticationRequired &&
        code != ApiErrorCodes.passwordChangeRequired &&
        code != ApiErrorCodes.userInactive &&
        code != ApiErrorCodes.institutionInactive) {
      return false;
    }
    _clearOwnership();
    state = const TeacherTopicDetailState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }

    return true;
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _generation += 1;
  }
}
