import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/idempotency_key_generator.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_active_blitz_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_attempt_start_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_attempt_start_state.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_detail_state.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_execution_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_execution_state.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_route_target.dart';

import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

void main() {
  group('confirmed action to exact request', () {
    test('Start Blitz sends start_normal once and adopts created #1', () async {
      final harness = await _Harness.ready(studentBlitzDetail());
      final operation = harness.controller.start(
        StudentBlitzExecutionAction.startNormal,
      );
      expect(harness.state.status, StudentBlitzAttemptStartStatus.submitting);
      expect(
        harness.state.originatingIntent,
        StudentBlitzAttemptIntent.startNormal,
      );
      final request = harness.attempts.requests.single;
      expect(request.intent, StudentBlitzAttemptIntent.startNormal);
      expect(request.attemptId, isNull);
      expect(request.idempotencyKey, blitzKey(1));
      expect(harness.attempts.blitzIds.single, studentBlitzId);
      final listCalls = harness.blitz.activeCalls;
      harness.pendingStarts.single.complete(studentBlitzStartResult());
      await operation;
      await flushStudentControllers();

      expect(harness.state.status, StudentBlitzAttemptStartStatus.active);
      expect(harness.execution.attempt!.id, studentBlitzAttemptId);
      expect(
        harness.state.resultKind,
        StudentBlitzAttemptStartResultKind.created,
      );
      expect(harness.state.feedback, StudentBlitzStartFeedback.started);
      expect(harness.execution.blitzTitle, 'Classroom Blitz');
      expect(
        harness.execution.countdownAnchor!.subjectId,
        studentBlitzAttemptId,
      );
      expect(harness.execution.countdownAnchor!.remainingSeconds, 300);
      expect(harness.keys.calls, 1);
      expect(harness.blitz.detailIds, hasLength(2));
      expect(harness.detail.status, StudentBlitzDetailStatus.refreshing);
      expect(harness.blitz.activeCalls, listCalls + 1);
    });

    test(
      'a safe concurrent normal Start may return 200 with the same #1',
      () async {
        final harness = await _Harness.ready(studentBlitzDetail());
        final operation = harness.controller.start(
          StudentBlitzExecutionAction.startNormal,
        );
        harness.pendingStarts.single.complete(
          studentBlitzStartResult(
            kind: StudentBlitzAttemptStartResultKind.resumed,
          ),
        );
        await operation;
        expect(harness.state.status, StudentBlitzAttemptStartStatus.active);
        expect(harness.state.feedback, StudentBlitzStartFeedback.resumed);
      },
    );

    test('Resume sends the exact confirmed in-progress Attempt ID', () async {
      final harness = await _Harness.ready(inProgressBlitzDetail());
      final operation = harness.controller.start(
        StudentBlitzExecutionAction.resume,
      );
      final request = harness.attempts.requests.single;
      expect(request.intent, StudentBlitzAttemptIntent.resume);
      expect(request.attemptId, studentBlitzAttemptId);
      expect(harness.state.requestedAttemptId, studentBlitzAttemptId);
      harness.pendingStarts.single.complete(
        studentBlitzStartResult(
          kind: StudentBlitzAttemptStartResultKind.resumed,
        ),
      );
      await operation;
      expect(harness.state.status, StudentBlitzAttemptStartStatus.active);
      expect(harness.state.feedback, StudentBlitzStartFeedback.resumed);
    });

    test('replacement Start sends start_replacement and adopts #2', () async {
      final harness = await _Harness.ready(replacementBlitzDetail());
      final operation = harness.controller.start(
        StudentBlitzExecutionAction.startReplacement,
      );
      final request = harness.attempts.requests.single;
      expect(request.intent, StudentBlitzAttemptIntent.startReplacement);
      expect(request.attemptId, isNull);
      harness.pendingStarts.single.complete(
        studentBlitzStartResult(attempt: _second()),
      );
      await operation;
      expect(harness.state.status, StudentBlitzAttemptStartStatus.active);
      expect(harness.execution.attempt!.attemptNumber, 2);
      expect(
        harness.state.feedback,
        StudentBlitzStartFeedback.additionalStarted,
      );
    });

    test(
      'a concurrent replacement Start may return 200 with the same #2',
      () async {
        final harness = await _Harness.ready(replacementBlitzDetail());
        final operation = harness.controller.start(
          StudentBlitzExecutionAction.startReplacement,
        );
        harness.pendingStarts.single.complete(
          studentBlitzStartResult(
            attempt: _second(),
            kind: StudentBlitzAttemptStartResultKind.resumed,
          ),
        );
        await operation;
        expect(harness.state.status, StudentBlitzAttemptStartStatus.active);
        expect(
          harness.state.feedback,
          StudentBlitzStartFeedback.additionalAlreadyInProgress,
        );
      },
    );

    test('replacement Resume sends the exact #2 ID', () async {
      final harness = await _Harness.ready(
        inProgressBlitzDetail(
          attemptId: studentBlitzReplacementAttemptId,
          exceptionGranted: true,
        ),
      );
      final operation = harness.controller.start(
        StudentBlitzExecutionAction.resume,
      );
      expect(
        harness.attempts.requests.single.attemptId,
        studentBlitzReplacementAttemptId,
      );
      harness.pendingStarts.single.complete(
        studentBlitzStartResult(
          attempt: _second(),
          kind: StudentBlitzAttemptStartResultKind.resumed,
        ),
      );
      await operation;
      expect(harness.state.status, StudentBlitzAttemptStartStatus.active);
      expect(harness.execution.attempt!.id, studentBlitzReplacementAttemptId);
    });

    test(
      'an action the confirmed detail no longer offers sends nothing',
      () async {
        final harness = await _Harness.ready(inProgressBlitzDetail());
        await harness.controller.start(StudentBlitzExecutionAction.startNormal);
        await harness.controller.start(
          StudentBlitzExecutionAction.startReplacement,
        );
        expect(harness.attempts.requests, isEmpty);

        final finished = await _Harness.ready(finishedBlitzDetail());
        for (final action in StudentBlitzExecutionAction.values) {
          await finished.controller.start(action);
        }
        expect(finished.attempts.requests, isEmpty);

        final refreshing = await _Harness.ready(studentBlitzDetail());
        refreshing.detailController.refresh();
        await refreshing.controller.start(
          StudentBlitzExecutionAction.startNormal,
        );
        expect(refreshing.attempts.requests, isEmpty);
        expect(refreshing.keys.calls, 0);
      },
    );

    test('duplicate Start and Retry cannot add a second request', () async {
      final harness = await _Harness.ready(studentBlitzDetail());
      final pending = harness.controller.start(
        StudentBlitzExecutionAction.startNormal,
      );
      await harness.controller.start(StudentBlitzExecutionAction.startNormal);
      await harness.controller.retry();
      expect(harness.attempts.requests, hasLength(1));
      expect(harness.keys.calls, 1);
      harness.pendingStarts.single.complete(studentBlitzStartResult());
      await pending;
    });
  });

  group('uncertain outcome', () {
    for (final failure in [
      studentLocalFailure(ApiFailureKind.timeout),
      studentLocalFailure(ApiFailureKind.connection),
      studentLocalFailure(ApiFailureKind.cancelled),
      studentLocalFailure(ApiFailureKind.invalidResponse),
      studentLocalFailure(ApiFailureKind.unknown),
      studentServerFailure(ApiErrorCodes.serverError, statusCode: 500),
    ]) {
      test(
        '${failure.failure.kind} keeps the frozen request for Retry',
        () async {
          final harness = await _Harness.ready(inProgressBlitzDetail());
          final first = harness.controller.start(
            StudentBlitzExecutionAction.resume,
          );
          harness.pendingStarts.single.completeError(failure);
          await first;
          expect(
            harness.state.status,
            StudentBlitzAttemptStartStatus.uncertain,
          );
          expect(harness.execution.attempt, isNull);
          await harness.controller.start(StudentBlitzExecutionAction.resume);
          expect(harness.attempts.requests, hasLength(1));

          final retry = harness.controller.retry();
          final resent = harness.attempts.requests.last;
          expect(harness.attempts.requests, hasLength(2));
          expect(resent.intent, StudentBlitzAttemptIntent.resume);
          expect(resent.attemptId, studentBlitzAttemptId);
          expect(resent.idempotencyKey, blitzKey(1));
          expect(harness.keys.calls, 1);
          harness.pendingStarts.last.complete(
            studentBlitzStartResult(
              kind: StudentBlitzAttemptStartResultKind.resumed,
            ),
          );
          await retry;
          expect(harness.state.status, StudentBlitzAttemptStartStatus.active);
        },
      );
    }

    test('Retry never reinterprets the request from a newer detail', () async {
      final harness = await _Harness.ready(inProgressBlitzDetail());
      final first = harness.controller.start(
        StudentBlitzExecutionAction.resume,
      );
      harness.pendingStarts.single.completeError(
        studentLocalFailure(ApiFailureKind.timeout),
      );
      await first;
      harness.detailController.refresh();
      harness.pendingDetails.last.complete(replacementBlitzDetail());
      await flushStudentControllers();
      expect(
        harness.detail.confirmedBlitz!.attempts.replacementAttemptAvailable,
        isTrue,
      );

      final retry = harness.controller.retry();
      final resent = harness.attempts.requests.last;
      expect(resent.intent, StudentBlitzAttemptIntent.resume);
      expect(resent.attemptId, studentBlitzAttemptId);
      expect(resent.idempotencyKey, blitzKey(1));
      harness.pendingStarts.last.completeError(
        studentServerFailure(ApiErrorCodes.attemptNotEditable, statusCode: 409),
      );
      await retry;
      expect(harness.state.status, StudentBlitzAttemptStartStatus.failure);
    });

    test(
      'a success for another Blitz is uncertain with the same key',
      () async {
        final harness = await _Harness.ready(studentBlitzDetail());
        final first = harness.controller.start(
          StudentBlitzExecutionAction.startNormal,
        );
        harness.pendingStarts.single.complete(
          studentBlitzStartResult(
            attempt: studentBlitzAttempt(assessmentId: otherStudentBlitzId),
          ),
        );
        await first;
        expect(harness.state.status, StudentBlitzAttemptStartStatus.uncertain);
        expect(harness.state.failure!.kind, ApiFailureKind.invalidResponse);
        expect(harness.execution.attempt, isNull);
        expect(harness.blitz.detailIds, hasLength(1));
        final retry = harness.controller.retry();
        expect(harness.attempts.requests.last.idempotencyKey, blitzKey(1));
        harness.pendingStarts.last.complete(studentBlitzStartResult());
        await retry;
        expect(harness.state.status, StudentBlitzAttemptStartStatus.active);
      },
    );

    test('a stale Resume of #1 answered with #2 is never accepted', () async {
      final harness = await _Harness.ready(inProgressBlitzDetail());
      final first = harness.controller.start(
        StudentBlitzExecutionAction.resume,
      );
      harness.pendingStarts.single.complete(
        studentBlitzStartResult(
          attempt: _second(),
          kind: StudentBlitzAttemptStartResultKind.resumed,
        ),
      );
      await first;
      expect(harness.state.status, StudentBlitzAttemptStartStatus.uncertain);
      expect(harness.execution.attempt, isNull);
    });

    test('a normal Start answered with #2 is never accepted', () async {
      final harness = await _Harness.ready(studentBlitzDetail());
      final first = harness.controller.start(
        StudentBlitzExecutionAction.startNormal,
      );
      harness.pendingStarts.single.complete(
        studentBlitzStartResult(attempt: _second()),
      );
      await first;
      expect(harness.state.status, StudentBlitzAttemptStartStatus.uncertain);
    });

    test('an Attempt in another timer mode is not accepted', () async {
      final harness = await _Harness.ready(studentBlitzDetail());
      final first = harness.controller.start(
        StudentBlitzExecutionAction.startNormal,
      );
      harness.pendingStarts.single.complete(
        studentBlitzStartResult(
          attempt: studentBlitzAttempt(mode: StudentBlitzTimerMode.individual),
        ),
      );
      await first;
      expect(harness.state.status, StudentBlitzAttemptStartStatus.uncertain);
    });
  });

  group('deterministic outcome', () {
    for (final code in [
      ApiErrorCodes.blitzNotActive,
      ApiErrorCodes.blitzTimeExpired,
      ApiErrorCodes.attemptsExhausted,
      ApiErrorCodes.assessmentNotAssigned,
      ApiErrorCodes.businessConflict,
    ]) {
      test('$code clears the key and reconciles detail and list', () async {
        final harness = await _Harness.ready(studentBlitzDetail());
        final listCalls = harness.blitz.activeCalls;
        final first = harness.controller.start(
          StudentBlitzExecutionAction.startNormal,
        );
        harness.pendingStarts.single.completeError(
          studentServerFailure(code, statusCode: 409),
        );
        await first;
        expect(harness.state.status, StudentBlitzAttemptStartStatus.failure);
        expect(harness.state.failure!.serverCode, code);
        expect(harness.blitz.detailIds, hasLength(2));
        expect(harness.blitz.activeCalls, listCalls + 1);
        await harness.controller.retry();
        expect(harness.attempts.requests, hasLength(1));

        harness.pendingDetails.last.complete(studentBlitzDetail());
        await flushStudentControllers();
        final again = harness.controller.start(
          StudentBlitzExecutionAction.startNormal,
        );
        expect(harness.attempts.requests.last.idempotencyKey, blitzKey(2));
        harness.pendingStarts.last.complete(studentBlitzStartResult());
        await again;
      });
    }

    test('404 marks the Blitz unavailable through reconciliation', () async {
      final harness = await _Harness.ready(studentBlitzDetail());
      final first = harness.controller.start(
        StudentBlitzExecutionAction.startNormal,
      );
      harness.pendingStarts.single.completeError(
        studentServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
      );
      await first;
      harness.pendingDetails.last.completeError(
        studentServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
      );
      await flushStudentControllers();
      expect(harness.detail.status, StudentBlitzDetailStatus.notFound);
    });

    test('stale Resume attempt_not_editable never auto-starts #2', () async {
      final harness = await _Harness.ready(inProgressBlitzDetail());
      final first = harness.controller.start(
        StudentBlitzExecutionAction.resume,
      );
      harness.pendingStarts.single.completeError(
        studentServerFailure(ApiErrorCodes.attemptNotEditable, statusCode: 409),
      );
      await first;
      expect(harness.state.status, StudentBlitzAttemptStartStatus.failure);
      harness.pendingDetails.last.complete(replacementBlitzDetail());
      await flushStudentControllers();
      expect(
        studentBlitzExecutionAction(harness.detail.confirmedBlitz!.attempts),
        StudentBlitzExecutionAction.startReplacement,
      );
      expect(harness.attempts.requests, hasLength(1));
      expect(harness.keys.calls, 1);
    });

    for (final code in [
      ApiErrorCodes.idempotencyKeyReused,
      ApiErrorCodes.validationFailed,
    ]) {
      test('$code is a deterministic failure without replay', () async {
        final harness = await _Harness.ready(studentBlitzDetail());
        final first = harness.controller.start(
          StudentBlitzExecutionAction.startNormal,
        );
        harness.pendingStarts.single.completeError(
          studentServerFailure(
            code,
            statusCode: code == ApiErrorCodes.validationFailed ? 422 : 409,
          ),
        );
        await first;
        expect(harness.state.status, StudentBlitzAttemptStartStatus.failure);
        await harness.controller.retry();
        expect(harness.attempts.requests, hasLength(1));
      });
    }

    test('a session failure clears the request and reconciles auth', () async {
      final harness = await _Harness.ready(studentBlitzDetail());
      final first = harness.controller.start(
        StudentBlitzExecutionAction.startNormal,
      );
      harness.pendingStarts.single.completeError(
        studentServerFailure(ApiErrorCodes.userInactive),
      );
      await first;
      expect(harness.state.status, StudentBlitzAttemptStartStatus.idle);
      expect(harness.auth.bootstrapCalls, 1);
      await harness.controller.retry();
      expect(harness.attempts.requests, hasLength(1));
    });
  });

  group('terminal replay', () {
    test('a terminal same-key replay is terminal, not an execution', () async {
      final harness = await _Harness.ready(studentBlitzDetail());
      final first = harness.controller.start(
        StudentBlitzExecutionAction.startNormal,
      );
      harness.pendingStarts.single.complete(
        studentBlitzStartResult(
          attempt: studentBlitzAttempt(
            status: StudentBlitzAttemptStatus.timedOutFinalized,
            finalizationReason: StudentBlitzAttemptFinalizationReason.timeout,
          ),
        ),
      );
      await first;
      expect(harness.state.status, StudentBlitzAttemptStartStatus.terminal);
      expect(harness.execution.status, StudentBlitzExecutionStatus.terminal);
      expect(
        harness.execution.attempt!.status,
        StudentBlitzAttemptStatus.timedOutFinalized,
      );
      expect(harness.execution.countdownAnchor, isNull);
      expect(harness.blitz.detailIds, hasLength(2));
    });
  });

  group('execution handoff', () {
    test('a completion after a session switch is ignored', () async {
      final harness = await _Harness.ready(studentBlitzDetail());
      final first = harness.controller.start(
        StudentBlitzExecutionAction.startNormal,
      );
      harness.auth.replaceUser(studentUser('student-b'));
      await flushStudentControllers();
      harness.pendingStarts.single.complete(studentBlitzStartResult());
      await first;
      expect(harness.state.status, StudentBlitzAttemptStartStatus.idle);
      expect(harness.execution.attempt, isNull);
      await harness.controller.retry();
      expect(harness.attempts.requests, hasLength(1));
    });

    test('a dropped execution allows only a new explicit request', () async {
      final harness = await _Harness.active();
      harness.executionController.clearLocalState();
      expect(harness.state.status, StudentBlitzAttemptStartStatus.idle);
      expect(harness.state.acceptsNewRequest, isTrue);
      expect(harness.attempts.requests, hasLength(1));
    });

    test('a finalized execution allows a new explicit request', () async {
      final harness = await _Harness.active();
      expect(harness.state.acceptsNewRequest, isFalse);
      expect(
        harness.executionController.acceptSubmittedAttempt(
          studentBlitzAttempt(status: StudentBlitzAttemptStatus.submitted),
        ),
        isTrue,
      );
      expect(harness.state.status, StudentBlitzAttemptStartStatus.terminal);
      expect(harness.state.acceptsNewRequest, isTrue);
    });

    test('feedback is consumed once', () async {
      final harness = await _Harness.active();
      expect(
        harness.controller.consumeFeedback(),
        StudentBlitzStartFeedback.started,
      );
      expect(harness.state.feedback, isNull);
      expect(harness.controller.consumeFeedback(), isNull);
    });
  });

  test(
    'an unexpected Start error is uncertain and keeps the request',
    () async {
      final harness = await _Harness.ready(studentBlitzDetail());
      final first = harness.controller.start(
        StudentBlitzExecutionAction.startNormal,
      );
      harness.pendingStarts.single.completeError(StateError('unexpected'));
      await first;
      expect(harness.state.status, StudentBlitzAttemptStartStatus.uncertain);
      expect(harness.state.failure!.kind, ApiFailureKind.unknown);
      final retry = harness.controller.retry();
      expect(harness.attempts.requests.last.idempotencyKey, blitzKey(1));
      harness.pendingStarts.last.complete(studentBlitzStartResult());
      await retry;
      expect(harness.state.status, StudentBlitzAttemptStartStatus.active);
    },
  );
}

StudentBlitzAttempt _second() =>
    studentBlitzAttempt(id: studentBlitzReplacementAttemptId, attemptNumber: 2);

class _Harness {
  _Harness() {
    blitz.onFetchBlitz = (_) {
      final completer = Completer<StudentBlitzDetail>();
      pendingDetails.add(completer);
      return completer.future;
    };
    attempts.onStart = (_, _) {
      final completer = Completer<StudentBlitzAttemptStartResult>();
      pendingStarts.add(completer);
      return completer.future;
    };
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        studentBlitzRepositoryProvider.overrideWithValue(blitz),
        studentBlitzAttemptRepositoryProvider.overrideWithValue(attempts),
        idempotencyKeyGeneratorProvider.overrideWithValue(keys),
      ],
    );
    addTearDown(container.dispose);
    for (final subscription in [
      container.listen(studentActiveBlitzControllerProvider, (_, _) {}),
      container.listen(studentBlitzDetailControllerProvider(target), (_, _) {}),
      container.listen(
        studentBlitzExecutionControllerProvider(target),
        (_, _) {},
      ),
      container.listen(
        studentBlitzAttemptStartControllerProvider(target),
        (_, _) {},
      ),
    ]) {
      addTearDown(subscription.close);
    }
  }

  static Future<_Harness> ready(StudentBlitzDetail detail) async {
    final harness = _Harness();
    await flushStudentControllers();
    harness.pendingDetails.single.complete(detail);
    await flushStudentControllers();
    return harness;
  }

  /// Started normal #1 with the post-Start detail read still pending.
  static Future<_Harness> active() async {
    final harness = await ready(studentBlitzDetail());
    final operation = harness.controller.start(
      StudentBlitzExecutionAction.startNormal,
    );
    harness.pendingStarts.single.complete(studentBlitzStartResult());
    await operation;
    await flushStudentControllers();
    return harness;
  }

  final target = StudentBlitzRouteTarget(
    topicId: studentTopicId,
    blitzId: studentBlitzId,
  );
  final auth = FakeStudentAuthSessionController.authenticated(
    studentUser('student-a'),
  );
  final blitz = FakeStudentBlitzRepository();
  final attempts = FakeStudentBlitzAttemptRepository();
  final keys = SequentialBlitzKeys();
  final pendingDetails = <Completer<StudentBlitzDetail>>[];
  final pendingStarts = <Completer<StudentBlitzAttemptStartResult>>[];
  late final ProviderContainer container;

  StudentBlitzAttemptStartState get state =>
      container.read(studentBlitzAttemptStartControllerProvider(target));
  StudentBlitzAttemptStartController get controller => container.read(
    studentBlitzAttemptStartControllerProvider(target).notifier,
  );
  StudentBlitzExecutionState get execution =>
      container.read(studentBlitzExecutionControllerProvider(target));
  StudentBlitzExecutionController get executionController =>
      container.read(studentBlitzExecutionControllerProvider(target).notifier);
  StudentBlitzDetailState get detail =>
      container.read(studentBlitzDetailControllerProvider(target));
  StudentBlitzDetailController get detailController =>
      container.read(studentBlitzDetailControllerProvider(target).notifier);
}
