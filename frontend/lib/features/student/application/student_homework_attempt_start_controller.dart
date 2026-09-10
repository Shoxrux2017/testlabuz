import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/idempotency_key_generator.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_homework_attempt_repository_impl.dart';
import '../domain/student_homework.dart';
import '../domain/student_homework_route_target.dart';
import 'student_homework_attempt_start_state.dart';
import 'student_homework_detail_controller.dart';
import 'student_homework_detail_state.dart';
import 'student_homework_list_controller.dart';
import 'student_session_key.dart';

final studentHomeworkAttemptStartControllerProvider = NotifierProvider
    .autoDispose
    .family<
      StudentHomeworkAttemptStartController,
      StudentHomeworkAttemptStartState,
      StudentHomeworkRouteTarget
    >(StudentHomeworkAttemptStartController.new);

class StudentHomeworkAttemptStartController
    extends Notifier<StudentHomeworkAttemptStartState> {
  StudentHomeworkAttemptStartController(this.target);

  final StudentHomeworkRouteTarget target;
  StudentSessionKey? _activeSessionKey;
  String? _pendingIdempotencyKey;
  var _generation = 0;

  @override
  StudentHomeworkAttemptStartState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (key == null) {
      _clearOwnership();
      return const StudentHomeworkAttemptStartState();
    }
    if (_activeSessionKey == key) {
      return state;
    }
    _clearOwnership();
    _activeSessionKey = key;
    return const StudentHomeworkAttemptStartState();
  }

  Future<void> start() async {
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        (state.status != StudentHomeworkAttemptStartStatus.idle &&
            state.status != StudentHomeworkAttemptStartStatus.failure)) {
      return;
    }
    final detail = ref.read(studentHomeworkDetailControllerProvider(target));
    final homework = detail.homework;
    if (detail.status != StudentHomeworkDetailStatus.data ||
        homework == null ||
        homework.id.toLowerCase() != target.homeworkId ||
        homework.topic.id.toLowerCase() != target.topicId ||
        homework.status != StudentHomeworkStatus.active ||
        homework.attempts.remaining <= 0 ||
        homework.attempts.inProgressAttempt != null) {
      return;
    }
    _pendingIdempotencyKey = ref
        .read(idempotencyKeyGeneratorProvider)
        .generate();
    await _submit(key);
  }

  Future<void> retry() async {
    final key = _activeSessionKey;
    if (key != null &&
        _matchesSession(key) &&
        state.status == StudentHomeworkAttemptStartStatus.uncertain &&
        _pendingIdempotencyKey != null) {
      await _submit(key);
    }
  }

  bool consumeCompletion() {
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        state.status != StudentHomeworkAttemptStartStatus.completed) {
      return false;
    }
    state = const StudentHomeworkAttemptStartState();
    return true;
  }

  Future<void> _submit(StudentSessionKey key) async {
    final idempotencyKey = _pendingIdempotencyKey!;
    final generation = ++_generation;
    final requestTarget = target;
    state = const StudentHomeworkAttemptStartState(
      status: StudentHomeworkAttemptStartStatus.submitting,
    );
    try {
      final result = await ref
          .read(studentHomeworkAttemptRepositoryProvider)
          .startAttempt(requestTarget.homeworkId, idempotencyKey);
      if (!_canPublish(generation, key, requestTarget)) {
        return;
      }
      if (result.attempt.assessmentId.toLowerCase() !=
              requestTarget.homeworkId ||
          !isCanonicalStudentAttemptId(result.attempt.id)) {
        throw ApiRequestException(
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            message: 'The attempt response could not be confirmed.',
          ),
        );
      }
      _reconcileHomework(key, includeList: true);
      _pendingIdempotencyKey = null;
      state = StudentHomeworkAttemptStartState(
        status: StudentHomeworkAttemptStartStatus.completed,
        completedAttemptId: result.attempt.id.toLowerCase(),
        completedResultKind: result.resultKind,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key, requestTarget) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      final failure = exception.failure;
      if (_isUncertain(failure)) {
        state = StudentHomeworkAttemptStartState(
          status: StudentHomeworkAttemptStartStatus.uncertain,
          failure: failure,
        );
        return;
      }
      _pendingIdempotencyKey = null;
      state = StudentHomeworkAttemptStartState(
        status: StudentHomeworkAttemptStartStatus.failure,
        failure: failure,
      );
      switch (failure.serverCode) {
        case ApiErrorCodes.deadlinePassed:
        case ApiErrorCodes.businessConflict:
          _reconcileHomework(key);
        case ApiErrorCodes.attemptsExhausted:
        case ApiErrorCodes.taskNotActive:
        case ApiErrorCodes.taskClosed:
        case ApiErrorCodes.taskArchived:
        case ApiErrorCodes.assessmentNotAssigned:
        case ApiErrorCodes.resourceNotFound:
          _reconcileHomework(key, includeList: true);
      }
    }
  }

  bool _isUncertain(ApiFailure failure) => switch (failure.kind) {
    ApiFailureKind.connection ||
    ApiFailureKind.timeout ||
    ApiFailureKind.cancelled ||
    ApiFailureKind.invalidResponse ||
    ApiFailureKind.unknown => true,
    ApiFailureKind.server || ApiFailureKind.validation =>
      failure.statusCode == null ||
          failure.statusCode! < 400 ||
          failure.statusCode! >= 500,
  };

  void _reconcileHomework(StudentSessionKey key, {bool includeList = false}) {
    // Invalidation also rejects any detail read begun before the Start outcome.
    ref.invalidate(studentHomeworkDetailControllerProvider(target));
    final listProvider = studentHomeworkListControllerProvider(target.topicId);
    if (includeList && ref.exists(listProvider)) {
      ref.read(listProvider.notifier).markAuthoritativeRowsStale(key);
    }
  }

  bool _canPublish(
    int generation,
    StudentSessionKey key,
    StudentHomeworkRouteTarget requestTarget,
  ) =>
      ref.mounted &&
      generation == _generation &&
      target == requestTarget &&
      _matchesSession(key);

  bool _matchesSession(StudentSessionKey key) =>
      ref.mounted &&
      _activeSessionKey == key &&
      StudentSessionSnapshot.fromSession(
            ref.read(authSessionControllerProvider),
            ref.read(appDeviceSurfaceProvider),
          ).eligibleKey ==
          key;

  bool _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code != ApiErrorCodes.authenticationRequired &&
        code != ApiErrorCodes.passwordChangeRequired &&
        code != ApiErrorCodes.userInactive &&
        code != ApiErrorCodes.institutionInactive) {
      return false;
    }
    _clearOwnership();
    state = const StudentHomeworkAttemptStartState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _pendingIdempotencyKey = null;
    _generation += 1;
  }
}
