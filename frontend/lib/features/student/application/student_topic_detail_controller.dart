import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_topic_repository_impl.dart';
import '../domain/student_topic.dart';
import 'student_session_key.dart';
import 'student_topic_detail_state.dart';
import 'student_topic_list_controller.dart';

final studentTopicDetailControllerProvider = NotifierProvider.autoDispose
    .family<StudentTopicDetailController, StudentTopicDetailState, String>(
      StudentTopicDetailController.new,
    );

class StudentTopicDetailController extends Notifier<StudentTopicDetailState> {
  StudentTopicDetailController(this.topicId);

  final String topicId;
  StudentSessionKey? _activeSessionKey;
  int _generation = 0;
  var _disposeRegistered = false;

  @override
  StudentTopicDetailState build() {
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() => _generation += 1);
    }
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (!isCanonicalStudentTopicId(topicId) || key == null) {
      _clearOwnership();
      return const StudentTopicDetailState();
    }
    if (_activeSessionKey == key) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = key;
    scheduleMicrotask(() => _load(key, retainTopic: false));
    return const StudentTopicDetailState(
      status: StudentTopicDetailStatus.loading,
    );
  }

  void refresh() {
    final key = _activeSessionKey;
    if (key == null || state.isLoading || !_matchesSession(key)) {
      return;
    }
    unawaited(_load(key, retainTopic: state.topic != null));
  }

  Future<StudentTopicDetail?> refreshForMaterialReconciliation() {
    final key = _activeSessionKey;
    if (key == null || !_matchesSession(key)) {
      return Future.value();
    }
    return _load(key, retainTopic: state.topic != null);
  }

  Future<StudentTopicDetail?> _load(
    StudentSessionKey key, {
    required bool retainTopic,
  }) async {
    final generation = ++_generation;
    final retainedTopic = retainTopic ? state.topic : null;
    state = StudentTopicDetailState(
      status: retainedTopic == null
          ? StudentTopicDetailStatus.loading
          : StudentTopicDetailStatus.refreshing,
      topic: retainedTopic,
    );
    try {
      final topic = await ref
          .read(studentTopicRepositoryProvider)
          .fetchTopic(topicId);
      if (!_canPublish(generation, key)) {
        return null;
      }
      state = StudentTopicDetailState(
        status: StudentTopicDetailStatus.data,
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
        state = const StudentTopicDetailState(
          status: StudentTopicDetailStatus.notFound,
        );
        _invalidateTopicList(key);
        return null;
      }
      state = StudentTopicDetailState(
        status: StudentTopicDetailStatus.error,
        topic: retainedTopic,
        failure: exception.failure,
      );
      return null;
    } catch (_) {
      if (_canPublish(generation, key)) {
        state = StudentTopicDetailState(
          status: StudentTopicDetailStatus.error,
          topic: retainedTopic,
          failure: ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Student Topic detail failure.',
          ),
        );
      }
      return null;
    }
  }

  bool _canPublish(int generation, StudentSessionKey key) {
    return ref.mounted &&
        generation == _generation &&
        _activeSessionKey == key &&
        _matchesSession(key);
  }

  bool _matchesSession(StudentSessionKey key) {
    return ref.mounted &&
        _activeSessionKey == key &&
        StudentSessionSnapshot.fromSession(
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
    state = const StudentTopicDetailState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _invalidateTopicList(StudentSessionKey key) {
    ref
        .read(studentTopicListRetainedQueryProvider)
        .markAuthoritativeRowsStale(key);
    ref.invalidate(studentTopicListControllerProvider);
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _generation += 1;
  }
}
