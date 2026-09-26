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
import 'package:testlabuz_client/features/student/application/student_blitz_execution_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_execution_state.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_attempt_answer.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';

import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

void main() {
  group('Start success handoff', () {
    test('hands the Attempt and the exact sent request over at once', () async {
      final h = await _Harness.executing();
      final sent = h.attempts.requests.single;

      expect(h.execution.status, StudentBlitzExecutionStatus.active);
      expect(h.execution.attempt!.id, studentBlitzAttemptId);
      expect(h.execution.publicationToken, isNotNull);
      expect(h.execution.blitzTitle, 'Classroom Blitz');
      expect(h.execution.countdownAnchor!.subjectId, studentBlitzAttemptId);
      expect(h.execution.countdownAnchor!.remainingSeconds, 300);
      expect(h.execution.acceptsWrites, isTrue);
      expect(h.start.status, StudentBlitzAttemptStartStatus.active);
      expect(h.start.feedback, StudentBlitzStartFeedback.started);

      final replay = h.executionController.refreshCurrentAttempt();
      expect(h.attempts.requests.last, same(sent));
      h.pendingStarts.last.complete(studentBlitzStartResult());
      expect(await replay, StudentBlitzAttemptReplayOutcome.active);
    });

    test('a terminal Start result is a terminal execution', () async {
      final h = await _Harness.ready(studentBlitzDetail());
      final start = h.startController.start(
        StudentBlitzExecutionAction.startNormal,
      );
      h.pendingStarts.single.complete(
        studentBlitzStartResult(attempt: _timedOut()),
      );
      await start;
      expect(h.execution.status, StudentBlitzExecutionStatus.terminal);
      expect(h.execution.attempt!.status, _timedOut().status);
      expect(h.execution.countdownAnchor, isNull);
      expect(h.execution.confirmedBySubmit, isFalse);
      expect(h.start.status, StudentBlitzAttemptStartStatus.terminal);
    });

    test('an uncertain or failed Start creates no execution context', () async {
      final h = await _Harness.ready(inProgressBlitzDetail());
      final first = h.startController.start(StudentBlitzExecutionAction.resume);
      h.pendingStarts.single.completeError(
        studentLocalFailure(ApiFailureKind.timeout),
      );
      await first;
      expect(h.start.status, StudentBlitzAttemptStartStatus.uncertain);
      expect(h.execution.status, StudentBlitzExecutionStatus.none);
      expect(
        await h.executionController.refreshCurrentAttempt(),
        StudentBlitzAttemptReplayOutcome.unavailable,
      );

      final retry = h.startController.retry();
      h.pendingStarts.last.completeError(
        studentServerFailure(ApiErrorCodes.attemptNotEditable, statusCode: 409),
      );
      await retry;
      expect(h.start.status, StudentBlitzAttemptStartStatus.failure);
      expect(h.execution.status, StudentBlitzExecutionStatus.none);
      expect(h.attempts.requests, hasLength(2));
    });

    test(
      'a request and Attempt that do not belong together are refused',
      () async {
        final h = await _Harness.ready(studentBlitzDetail());
        final controller = h.executionController;
        for (final (attempt, request) in [
          (
            _second(),
            StudentBlitzAttemptRequest.startNormal(idempotencyKey: blitzKey(9)),
          ),
          (
            studentBlitzAttempt(),
            StudentBlitzAttemptRequest.startReplacement(
              idempotencyKey: blitzKey(9),
            ),
          ),
          (
            _second(),
            StudentBlitzAttemptRequest.resume(
              attemptId: studentBlitzAttemptId,
              idempotencyKey: blitzKey(9),
            ),
          ),
          (
            studentBlitzAttempt(assessmentId: otherStudentBlitzId),
            StudentBlitzAttemptRequest.startNormal(idempotencyKey: blitzKey(9)),
          ),
        ]) {
          expect(controller.acceptStartedAttempt(attempt, request), isFalse);
        }
        expect(h.execution.status, StudentBlitzExecutionStatus.none);
      },
    );
  });

  group('completed Start request replay', () {
    for (final shape in _Shape.values) {
      test(
        '${shape.name} resends the exact intent, Attempt ID and key',
        () async {
          final h = await _Harness.executing(shape: shape);
          final sent = h.attempts.requests.single;
          final keys = h.keys.calls;
          final detailBefore = h.blitz.detailIds.length;

          // A newer detail must never re-derive the replay intent.
          h.detailController.refresh();
          h.pendingDetails.last.complete(replacementBlitzDetail());
          await flushStudentControllers();

          final replay = h.executionController.refreshCurrentAttempt();
          final resent = h.attempts.requests.last;
          expect(h.attempts.requests, hasLength(2));
          expect(resent, same(sent));
          expect(resent.intent, shape.intent);
          expect(resent.attemptId, shape.requestedAttemptId);
          expect(resent.idempotencyKey, blitzKey(1));
          expect(resent.toJson(), shape.body);
          expect(h.attempts.blitzIds.last, studentBlitzId);
          expect(h.keys.calls, keys);

          h.pendingStarts.last.complete(
            studentBlitzStartResult(
              attempt: shape.attempt(
                status: StudentBlitzAttemptStatus.submitted,
              ),
              // The replay keeps the original status; 201 is not a new Attempt.
              kind: shape.kind,
            ),
          );
          expect(await replay, StudentBlitzAttemptReplayOutcome.terminal);
          expect(h.execution.attempt!.id, shape.attemptId);
          expect(h.blitz.detailIds.length, greaterThan(detailBefore));
        },
      );
    }

    test('an active replay adopts the full current Attempt', () async {
      final h = await _Harness.executing();
      final token = h.execution.publicationToken;
      final replay = h.executionController.refreshCurrentAttempt();
      expect(h.execution.status, StudentBlitzExecutionStatus.refreshing);
      expect(h.execution.acceptsWrites, isFalse);
      h.pendingStarts.last.complete(
        studentBlitzStartResult(
          attempt: studentBlitzAttempt(
            remainingSeconds: 200,
            serverNow: DateTime.utc(2026, 9, 17, 12, 1, 40),
            answers: [_trueAnswer()],
          ),
        ),
      );
      expect(await replay, StudentBlitzAttemptReplayOutcome.active);
      expect(h.execution.status, StudentBlitzExecutionStatus.active);
      expect(h.execution.publicationToken, isNot(same(token)));
      expect(h.execution.attempt!.answers.single.questionId, blitzUuid(101));
      expect(h.execution.countdownAnchor!.remainingSeconds, 200);
    });

    test('concurrent recovery requests share one replay', () async {
      final h = await _Harness.executing();
      final first = h.executionController.refreshCurrentAttempt();
      final second = h.executionController.refreshCurrentAttempt();
      expect(h.attempts.requests, hasLength(2));
      h.pendingStarts.last.complete(studentBlitzStartResult());
      expect(await first, StudentBlitzAttemptReplayOutcome.active);
      expect(await second, StudentBlitzAttemptReplayOutcome.active);
    });

    for (final (name, result) in [
      ('another Attempt', studentBlitzStartResult(attempt: _second())),
      (
        'another normal Attempt',
        studentBlitzStartResult(
          attempt: studentBlitzAttempt(id: blitzUuid(77)),
        ),
      ),
      (
        'another Blitz',
        studentBlitzStartResult(
          attempt: studentBlitzAttempt(assessmentId: otherStudentBlitzId),
        ),
      ),
      (
        'another timer mode',
        studentBlitzStartResult(
          attempt: studentBlitzAttempt(mode: StudentBlitzTimerMode.individual),
        ),
      ),
    ]) {
      test('a replay resolving $name is never adopted', () async {
        final h = await _Harness.executing();
        final replay = h.executionController.refreshCurrentAttempt();
        h.pendingStarts.last.complete(result);
        expect(await replay, StudentBlitzAttemptReplayOutcome.unavailable);
        expect(h.execution.status, StudentBlitzExecutionStatus.none);
        expect(h.execution.attempt, isNull);
        expect(h.start.status, StudentBlitzAttemptStartStatus.idle);
      });
    }

    test(
      'a Resume replay answered as a new Attempt is never adopted',
      () async {
        final h = await _Harness.executing(shape: _Shape.resumeFirst);
        final replay = h.executionController.refreshCurrentAttempt();
        h.pendingStarts.last.complete(studentBlitzStartResult());
        expect(await replay, StudentBlitzAttemptReplayOutcome.unavailable);
        expect(h.execution.status, StudentBlitzExecutionStatus.none);
      },
    );

    test('a replay 404 drops the execution without detail', () async {
      final h = await _Harness.executing();
      final replay = h.executionController.refreshCurrentAttempt();
      h.pendingStarts.last.completeError(
        studentServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
      );
      expect(await replay, StudentBlitzAttemptReplayOutcome.unavailable);
      expect(h.execution.status, StudentBlitzExecutionStatus.none);
      expect(
        await h.executionController.refreshCurrentAttempt(),
        StudentBlitzAttemptReplayOutcome.unavailable,
      );
      expect(h.attempts.requests, hasLength(2));
    });

    for (final failure in [
      studentLocalFailure(ApiFailureKind.connection),
      studentServerFailure(ApiErrorCodes.serverError, statusCode: 500),
      studentServerFailure(ApiErrorCodes.idempotencyKeyReused, statusCode: 409),
    ]) {
      test('${failure.failure.kind} ${failure.failure.serverCode} keeps the '
          'Attempt read-only for a later check', () async {
        final h = await _Harness.executing();
        final token = h.execution.publicationToken;
        final replay = h.executionController.refreshCurrentAttempt();
        h.pendingStarts.last.completeError(failure);
        expect(await replay, StudentBlitzAttemptReplayOutcome.failed);
        expect(
          h.execution.status,
          StudentBlitzExecutionStatus.reconciliationFailed,
        );
        expect(h.execution.attempt!.id, studentBlitzAttemptId);
        expect(h.execution.publicationToken, same(token));
        expect(h.execution.failure, same(failure.failure));
        expect(h.execution.acceptsWrites, isFalse);

        final again = h.executionController.refreshCurrentAttempt();
        expect(h.attempts.requests.last, same(h.attempts.requests.first));
        h.pendingStarts.last.complete(studentBlitzStartResult());
        expect(await again, StudentBlitzAttemptReplayOutcome.active);
      });
    }

    test('an unexpected replay error is a failed check', () async {
      final h = await _Harness.executing();
      final replay = h.executionController.refreshCurrentAttempt();
      h.pendingStarts.last.completeError(StateError('unexpected'));
      expect(await replay, StudentBlitzAttemptReplayOutcome.failed);
      expect(h.execution.failure!.kind, ApiFailureKind.unknown);
    });

    test('a completion after a session switch is ignored', () async {
      final h = await _Harness.executing();
      final replay = h.executionController.refreshCurrentAttempt();
      h.auth.replaceUser(studentUser('student-b'));
      await flushStudentControllers();
      h.pendingStarts.last.complete(studentBlitzStartResult());
      expect(await replay, StudentBlitzAttemptReplayOutcome.unavailable);
      expect(h.execution.status, StudentBlitzExecutionStatus.none);
      expect(
        await h.executionController.refreshCurrentAttempt(),
        StudentBlitzAttemptReplayOutcome.unavailable,
      );
      expect(h.attempts.requests, hasLength(2));
    });

    test('leaving clears the completed request', () async {
      final h = await _Harness.executing();
      h.executionController.clearLocalState();
      expect(h.execution.status, StudentBlitzExecutionStatus.none);
      expect(
        await h.executionController.refreshCurrentAttempt(),
        StudentBlitzAttemptReplayOutcome.unavailable,
      );
      expect(h.attempts.requests, hasLength(1));
      expect(h.start.status, StudentBlitzAttemptStartStatus.idle);
    });
  });

  group('answer mutation adoption', () {
    test('replaces exactly one answer and publishes a new token', () async {
      final h = await _Harness.executing(
        attempt: studentBlitzAttempt(answers: [_trueAnswer(position: 2)]),
      );
      final before = h.execution;
      final accepted = h.executionController.acceptAnswerMutation(
        attemptId: studentBlitzAttemptId,
        questionId: blitzUuid(101),
        result: _mutation(),
        expectedPublication: before.publicationToken,
      );
      expect(accepted, isTrue);
      final after = h.execution;
      expect(after.publicationToken, isNot(same(before.publicationToken)));
      expect(after.attempt!.questions, before.attempt!.questions);
      expect(after.attempt!.deadlineAt, before.attempt!.deadlineAt);
      expect(after.countdownAnchor, before.countdownAnchor);
      expect(after.attempt!.answers, hasLength(2));
      final saved = after.attempt!.answers.firstWhere(
        (answer) => answer.questionId == blitzUuid(101),
      );
      expect((saved.value as StudentBooleanAnswerValue).value, isFalse);
      expect(
        after.attempt!.answers.any((a) => a.questionId == blitzUuid(102)),
        isTrue,
      );
    });

    test('a cleared answer removes the persisted entry', () async {
      final question = studentBlitzQuestion(1);
      final h = await _Harness.executing(
        attempt: studentBlitzAttempt(
          questions: [_textQuestion(), question],
          answers: [
            StudentAttemptAnswerState(
              questionId: blitzUuid(103),
              type: StudentQuestionType.openWritten,
              value: const StudentTextAnswerValue(text: 'draft'),
              updatedAt: DateTime.utc(2026, 9, 17, 12, 1),
            ),
          ],
        ),
      );
      final accepted = h.executionController.acceptAnswerMutation(
        attemptId: studentBlitzAttemptId,
        questionId: blitzUuid(103),
        result: StudentAttemptAnswerMutationResult(
          questionId: blitzUuid(103),
          type: StudentQuestionType.openWritten,
          answer: null,
          updatedAt: null,
        ),
        expectedPublication: h.execution.publicationToken,
      );
      expect(accepted, isTrue);
      expect(h.execution.attempt!.answers, isEmpty);
    });

    test('a stale or foreign mutation is never applied', () async {
      final h = await _Harness.executing();
      final stale = h.execution.publicationToken;
      expect(
        h.executionController.acceptAnswerMutation(
          attemptId: studentBlitzAttemptId,
          questionId: blitzUuid(101),
          result: _mutation(),
          expectedPublication: stale,
        ),
        isTrue,
      );
      final current = h.execution;
      for (final (attemptId, questionId, result, token) in [
        (studentBlitzAttemptId, blitzUuid(101), _mutation(), stale),
        (
          studentBlitzReplacementAttemptId,
          blitzUuid(101),
          _mutation(),
          current.publicationToken,
        ),
        (
          studentBlitzAttemptId,
          blitzUuid(109),
          _mutation(questionId: blitzUuid(109)),
          current.publicationToken,
        ),
        (
          studentBlitzAttemptId,
          blitzUuid(101),
          StudentAttemptAnswerMutationResult(
            questionId: blitzUuid(101),
            type: StudentQuestionType.shortWritten,
            answer: const StudentTextAnswerValue(text: 'x'),
            updatedAt: DateTime.utc(2026, 9, 17, 12, 1),
          ),
          current.publicationToken,
        ),
        (
          studentBlitzAttemptId,
          blitzUuid(101),
          _mutation(questionId: blitzUuid(102)),
          current.publicationToken,
        ),
      ]) {
        expect(
          h.executionController.acceptAnswerMutation(
            attemptId: attemptId,
            questionId: questionId,
            result: result,
            expectedPublication: token,
          ),
          isFalse,
        );
      }
      expect(h.execution, same(current));
    });

    test('a terminal Attempt never accepts an answer mutation', () async {
      final h = await _Harness.executing();
      final replay = h.executionController.refreshCurrentAttempt();
      h.pendingStarts.last.complete(
        studentBlitzStartResult(attempt: _timedOut()),
      );
      await replay;
      expect(
        h.executionController.acceptAnswerMutation(
          attemptId: studentBlitzAttemptId,
          questionId: blitzUuid(101),
          result: _mutation(),
          expectedPublication: h.execution.publicationToken,
        ),
        isFalse,
      );
    });
  });

  group('local countdown expiry', () {
    test(
      'closes writes at once and replays the completed request once',
      () async {
        final h = await _Harness.executing();
        final anchor = h.execution.countdownAnchor!;
        final listCalls = h.blitz.activeCalls;
        final details = h.blitz.detailIds.length;
        h.executionController.markLocalTimeExpired(anchor);
        h.executionController.markLocalTimeExpired(anchor);

        expect(h.execution.localTimeExpired, isTrue);
        expect(h.execution.acceptsWrites, isFalse);
        expect(
          h.execution.attempt!.status,
          StudentBlitzAttemptStatus.inProgress,
        );
        expect(h.attempts.requests, hasLength(2));
        expect(h.attempts.requests.last, same(h.attempts.requests.first));

        h.pendingStarts.last.complete(
          studentBlitzStartResult(attempt: _timedOut()),
        );
        await flushStudentControllers();
        expect(h.execution.status, StudentBlitzExecutionStatus.terminal);
        expect(h.execution.attempt!.finalizationReason, isNotNull);
        expect(h.blitz.detailIds.length, details + 1);
        expect(h.blitz.activeCalls, listCalls + 1);
      },
    );

    test('an obsolete anchor cannot expire the execution', () async {
      final h = await _Harness.executing();
      h.executionController.markLocalTimeExpired(
        StudentBlitzCountdownAnchor(
          subjectId: studentBlitzAttemptId,
          deadlineAt: DateTime.utc(2026, 9, 17, 12, 5),
          serverNow: DateTime.utc(2026, 9, 17, 11),
          remainingSeconds: 1,
        ),
      );
      expect(h.execution.localTimeExpired, isFalse);
      expect(h.attempts.requests, hasLength(1));
    });

    test('only positive server time re-opens writes', () async {
      final h = await _Harness.executing();
      h.executionController.markLocalTimeExpired(h.execution.countdownAnchor!);
      h.pendingStarts.last.complete(
        studentBlitzStartResult(
          attempt: studentBlitzAttempt(
            remainingSeconds: 30,
            serverNow: DateTime.utc(2026, 9, 17, 12, 4, 30),
          ),
        ),
      );
      await flushStudentControllers();
      expect(h.execution.status, StudentBlitzExecutionStatus.active);
      expect(h.execution.localTimeExpired, isFalse);
      expect(h.execution.countdownAnchor!.remainingSeconds, 30);
      expect(h.execution.acceptsWrites, isTrue);
    });

    test(
      'zero server time keeps writes closed without a replay loop',
      () async {
        final h = await _Harness.executing();
        h.executionController.markLocalTimeExpired(
          h.execution.countdownAnchor!,
        );
        h.pendingStarts.last.complete(
          studentBlitzStartResult(
            attempt: studentBlitzAttempt(
              remainingSeconds: 0,
              serverNow: DateTime.utc(2026, 9, 17, 12, 5),
            ),
          ),
        );
        await flushStudentControllers();
        expect(h.execution.localTimeExpired, isTrue);
        expect(h.execution.acceptsWrites, isFalse);
        h.executionController.markLocalTimeExpired(
          h.execution.countdownAnchor!,
        );
        expect(h.attempts.requests, hasLength(2));
      },
    );

    test('a failed expiry replay keeps writes closed', () async {
      final h = await _Harness.executing();
      h.executionController.markLocalTimeExpired(h.execution.countdownAnchor!);
      h.pendingStarts.last.completeError(
        studentLocalFailure(ApiFailureKind.connection),
      );
      await flushStudentControllers();
      expect(h.execution.localTimeExpired, isTrue);
      expect(
        h.execution.status,
        StudentBlitzExecutionStatus.reconciliationFailed,
      );
      expect(h.execution.acceptsWrites, isFalse);
    });

    test('waits for an in-flight write and never competes with it', () async {
      final h = await _Harness.executing();
      final write = h.executionController.beginWrite()!;
      h.executionController.markLocalTimeExpired(h.execution.countdownAnchor!);
      expect(h.attempts.requests, hasLength(1));
      expect(h.executionController.beginWrite(), isNull);

      // A success that committed before the deadline is still adopted.
      expect(
        h.executionController.acceptAnswerMutation(
          attemptId: studentBlitzAttemptId,
          questionId: blitzUuid(101),
          result: _mutation(),
          expectedPublication: h.execution.publicationToken,
        ),
        isTrue,
      );
      final joined = h.executionController.refreshCurrentAttempt();
      h.executionController.endWrite(write);
      expect(h.attempts.requests, hasLength(2));
      h.pendingStarts.last.complete(
        studentBlitzStartResult(attempt: _timedOut()),
      );
      expect(await joined, StudentBlitzAttemptReplayOutcome.terminal);
      expect(h.attempts.requests, hasLength(2));
    });

    test('a Submit success during the wait needs no replay', () async {
      final h = await _Harness.executing();
      final write = h.executionController.beginWrite()!;
      h.executionController.markLocalTimeExpired(h.execution.countdownAnchor!);
      expect(
        h.executionController.acceptSubmittedAttempt(_submitted()),
        isTrue,
      );
      h.executionController.endWrite(write);
      await flushStudentControllers();
      expect(h.attempts.requests, hasLength(1));
      expect(h.execution.status, StudentBlitzExecutionStatus.terminal);
      expect(h.execution.confirmedBySubmit, isTrue);
    });
  });

  group('detail reconciliation during execution', () {
    for (final (name, failure) in [
      (
        'timeExpired',
        studentServerFailure(ApiErrorCodes.blitzTimeExpired, statusCode: 409),
      ),
      (
        'notActive',
        studentServerFailure(ApiErrorCodes.blitzNotActive, statusCode: 409),
      ),
      (
        'notFound',
        studentServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
      ),
    ]) {
      test('detail $name replays instead of dropping the shell', () async {
        final h = await _Harness.executing();
        h.detailController.refresh();
        h.pendingDetails.last.completeError(failure);
        await flushStudentControllers();
        expect(h.attempts.requests, hasLength(2));
        expect(h.attempts.requests.last, same(h.attempts.requests.first));
        expect(h.execution.isExecuting, isTrue);
        h.pendingStarts.last.complete(
          studentBlitzStartResult(attempt: _closed()),
        );
        await flushStudentControllers();
        expect(h.execution.status, StudentBlitzExecutionStatus.terminal);
        expect(
          h.execution.attempt!.finalizationReason,
          StudentBlitzAttemptFinalizationReason.taskClosed,
        );
      });
    }

    test('detail that no longer confirms this Attempt replays', () async {
      final h = await _Harness.executing();
      h.detailController.refresh();
      h.pendingDetails.last.complete(finishedBlitzDetail());
      await flushStudentControllers();
      expect(h.attempts.requests, hasLength(2));
    });

    test('an older detail snapshot never grants more time', () async {
      final h = await _Harness.executing(
        attempt: studentBlitzAttempt(
          remainingSeconds: 2,
          serverNow: DateTime.utc(2026, 9, 17, 12, 4, 58),
        ),
      );
      h.detailController.refresh();
      h.pendingDetails.last.complete(inProgressBlitzDetail());
      await flushStudentControllers();
      expect(h.execution.countdownAnchor!.remainingSeconds, 2);
    });

    test('a newer detail snapshot of this Attempt re-anchors', () async {
      final h = await _Harness.executing();
      final first = h.execution.countdownAnchor!;
      h.detailController.refresh();
      h.pendingDetails.last.complete(
        inProgressBlitzDetail(
          remainingSeconds: 240,
          serverNow: DateTime.utc(2026, 9, 17, 12, 1),
        ),
      );
      await flushStudentControllers();
      expect(h.execution.countdownAnchor, isNot(first));
      expect(h.execution.countdownAnchor!.remainingSeconds, 240);
      expect(h.attempts.requests, hasLength(1));
    });
  });

  group('Submit adoption', () {
    test('adopts a Student Submit terminal Attempt', () async {
      final h = await _Harness.executing();
      final details = h.blitz.detailIds.length;
      expect(
        h.executionController.acceptSubmittedAttempt(_submitted()),
        isTrue,
      );
      expect(h.execution.status, StudentBlitzExecutionStatus.terminal);
      expect(h.execution.confirmedBySubmit, isTrue);
      expect(h.blitz.detailIds.length, details + 1);
      expect(h.start.status, StudentBlitzAttemptStartStatus.terminal);
    });

    test('refuses an in-progress or foreign Attempt', () async {
      final h = await _Harness.executing();
      for (final attempt in [
        studentBlitzAttempt(),
        studentBlitzAttempt(
          id: studentBlitzReplacementAttemptId,
          attemptNumber: 2,
          status: StudentBlitzAttemptStatus.submitted,
        ),
      ]) {
        expect(h.executionController.acceptSubmittedAttempt(attempt), isFalse);
      }
      expect(h.execution.status, StudentBlitzExecutionStatus.active);
    });
  });
}

enum _Shape {
  startNormal,
  resumeFirst,
  resumeSecond,
  startReplacement;

  StudentBlitzAttemptIntent get intent => switch (this) {
    startNormal => StudentBlitzAttemptIntent.startNormal,
    resumeFirst || resumeSecond => StudentBlitzAttemptIntent.resume,
    startReplacement => StudentBlitzAttemptIntent.startReplacement,
  };

  bool get second => this == resumeSecond || this == startReplacement;

  String get attemptId =>
      second ? studentBlitzReplacementAttemptId : studentBlitzAttemptId;

  String? get requestedAttemptId =>
      intent == StudentBlitzAttemptIntent.resume ? attemptId : null;

  Map<String, Object?> get body => {
    'intent': intent.apiValue,
    if (intent == StudentBlitzAttemptIntent.resume) 'attempt_id': attemptId,
  };

  StudentBlitzAttemptStartResultKind get kind =>
      intent == StudentBlitzAttemptIntent.resume
      ? StudentBlitzAttemptStartResultKind.resumed
      : StudentBlitzAttemptStartResultKind.created;

  StudentBlitzExecutionAction get action => switch (this) {
    startNormal => StudentBlitzExecutionAction.startNormal,
    resumeFirst || resumeSecond => StudentBlitzExecutionAction.resume,
    startReplacement => StudentBlitzExecutionAction.startReplacement,
  };

  StudentBlitzDetail get detail => switch (this) {
    startNormal => studentBlitzDetail(),
    resumeFirst => inProgressBlitzDetail(),
    resumeSecond => inProgressBlitzDetail(
      attemptId: studentBlitzReplacementAttemptId,
      exceptionGranted: true,
    ),
    startReplacement => replacementBlitzDetail(),
  };

  StudentBlitzDetail get executingDetail => second
      ? inProgressBlitzDetail(
          attemptId: studentBlitzReplacementAttemptId,
          exceptionGranted: true,
        )
      : inProgressBlitzDetail();

  StudentBlitzAttempt attempt({
    StudentBlitzAttemptStatus status = StudentBlitzAttemptStatus.inProgress,
  }) => studentBlitzAttempt(
    id: attemptId,
    attemptNumber: second ? 2 : 1,
    status: status,
  );
}

StudentBlitzAttempt _second() =>
    studentBlitzAttempt(id: studentBlitzReplacementAttemptId, attemptNumber: 2);

StudentBlitzAttempt _timedOut() => studentBlitzAttempt(
  status: StudentBlitzAttemptStatus.timedOutFinalized,
  finalizationReason: StudentBlitzAttemptFinalizationReason.timeout,
);

StudentBlitzAttempt _closed() => studentBlitzAttempt(
  status: StudentBlitzAttemptStatus.submitted,
  finalizationReason: StudentBlitzAttemptFinalizationReason.taskClosed,
);

StudentBlitzAttempt _submitted() =>
    studentBlitzAttempt(status: StudentBlitzAttemptStatus.submitted);

StudentQuestion _textQuestion() => StudentQuestion(
  id: blitzUuid(103),
  type: StudentQuestionType.openWritten,
  prompt: 'Explain',
  instructions: null,
  points: 1,
  position: 2,
  answerUi: const StudentEmptyAnswerUi(),
);

StudentAttemptAnswerState _trueAnswer({int position = 1}) =>
    StudentAttemptAnswerState(
      questionId: blitzUuid(100 + position),
      type: StudentQuestionType.trueFalse,
      value: const StudentBooleanAnswerValue(value: true),
      updatedAt: DateTime.utc(2026, 9, 17, 12, 1),
    );

StudentAttemptAnswerMutationResult _mutation({String? questionId}) =>
    StudentAttemptAnswerMutationResult(
      questionId: questionId ?? blitzUuid(101),
      type: StudentQuestionType.trueFalse,
      answer: const StudentBooleanAnswerValue(value: false),
      updatedAt: DateTime.utc(2026, 9, 17, 12, 2),
    );

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

  /// A handed-off execution whose post-Start detail read confirmed it.
  static Future<_Harness> executing({
    _Shape shape = _Shape.startNormal,
    StudentBlitzAttempt? attempt,
  }) async {
    final harness = await ready(shape.detail);
    final start = harness.startController.start(shape.action);
    harness.pendingStarts.single.complete(
      studentBlitzStartResult(
        attempt: attempt ?? shape.attempt(),
        kind: shape.kind,
      ),
    );
    await start;
    await flushStudentControllers();
    harness.pendingDetails.last.complete(shape.executingDetail);
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

  StudentBlitzExecutionState get execution =>
      container.read(studentBlitzExecutionControllerProvider(target));
  StudentBlitzExecutionController get executionController =>
      container.read(studentBlitzExecutionControllerProvider(target).notifier);
  StudentBlitzAttemptStartState get start =>
      container.read(studentBlitzAttemptStartControllerProvider(target));
  StudentBlitzAttemptStartController get startController => container.read(
    studentBlitzAttemptStartControllerProvider(target).notifier,
  );
  StudentBlitzDetailController get detailController =>
      container.read(studentBlitzDetailControllerProvider(target).notifier);
}
