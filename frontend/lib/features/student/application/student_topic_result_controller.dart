import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_topic_repository_impl.dart';
import '../domain/student_topic.dart';
import '../domain/student_topic_result.dart';
import 'student_session_key.dart';
import 'student_topic_result_state.dart';

/// The Student's own Topic result for one Topic; callers key it by the
/// lowercase Topic id.
final studentTopicResultControllerProvider = NotifierProvider.autoDispose
    .family<StudentTopicResultController, StudentTopicResultState, String>(
      (topicId) => StudentTopicResultController(topicId.toLowerCase()),
    );

class StudentTopicResultController extends Notifier<StudentTopicResultState> {
  StudentTopicResultController(this.topicId);

  final String topicId;
  StudentSessionKey? _activeSessionKey;
  var _generation = 0;

  @override
  StudentTopicResultState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (!isCanonicalStudentTopicId(topicId) || key == null) {
      _clearOwnership();
      return const StudentTopicResultState();
    }
    if (_activeSessionKey == key && !ref.isRefresh) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = key;
    final generation = _generation;
    scheduleMicrotask(() {
      if (_matchesSession(key) && generation == _generation) {
        unawaited(_load(key));
      }
    });
    return const StudentTopicResultState(
      status: StudentTopicResultLoadStatus.loading,
    );
  }

  /// Reloads; a confirmed response stays shown while the request runs.
  void refresh() {
    final key = _activeSessionKey;
    if (key == null || state.isLoading || !_matchesSession(key)) {
      return;
    }
    unawaited(_load(key));
  }

  Future<void> _load(StudentSessionKey key) async {
    final generation = ++_generation;
    final loaded = state.loaded;
    final retained = state.result;
    state = loaded
        ? StudentTopicResultState(
            status: StudentTopicResultLoadStatus.refreshing,
            loaded: true,
            result: retained,
          )
        : const StudentTopicResultState(
            status: StudentTopicResultLoadStatus.loading,
          );
    try {
      final result = await ref
          .read(studentTopicRepositoryProvider)
          .fetchTopicResult(topicId);
      if (_canPublish(generation, key)) {
        state = StudentTopicResultState(
          status: StudentTopicResultLoadStatus.data,
          loaded: true,
          result: result,
        );
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      _publishFailure(exception.failure, loaded: loaded, retained: retained);
    } catch (_) {
      if (_canPublish(generation, key)) {
        _publishFailure(
          ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Student Topic result failure.',
          ),
          loaded: loaded,
          retained: retained,
        );
      }
    }
  }

  void _publishFailure(
    ApiFailure failure, {
    required bool loaded,
    required StudentTopicResult? retained,
  }) {
    state = StudentTopicResultState(
      status: StudentTopicResultLoadStatus.error,
      loaded: loaded,
      result: loaded ? retained : null,
      failure: failure,
    );
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
    state = const StudentTopicResultState();
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
