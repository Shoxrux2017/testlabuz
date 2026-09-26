import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_answer_editor_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_execution_operation_gate.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_execution_state.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_file_answer_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_submit_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_submit_readiness.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_submit_state.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_draft.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_submit.dart';

import 'student_blitz_execution_test_support.dart';
import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

void main() {
  test('a confirmed Submit sends one fresh request with one new key', () async {
    final h = await _Harness.create();
    final keys = h.h.keys.calls;
    final details = h.h.blitz.detailIds.length;
    final submit = h.controller.submitConfirmed(h.token);
    expect(h.state.status, StudentBlitzSubmitStatus.submitting);
    expect(h.gate, StudentBlitzExecutionOperation.submitting);
    final call = h.h.attempts.submits.single;
    expect(call.attemptId, studentBlitzAttemptId);
    expect(call.blitzId, studentBlitzId);
    expect(call.idempotencyKey, blitzKey(keys + 1));
    expect(call.expectation, StudentBlitzSubmitResponseExpectation.fresh);
    h.completeSubmit(_submitted());
    await submit;

    expect(h.state.status, StudentBlitzSubmitStatus.completed);
    expect(h.state.notice, 'Blitz submitted successfully.');
    expect(h.gate, StudentBlitzExecutionOperation.idle);
    expect(h.h.execution.status, StudentBlitzExecutionStatus.terminal);
    expect(h.h.execution.confirmedBySubmit, isTrue);
    expect(h.h.blitz.detailIds.length, details + 1);
    expect(h.h.keys.calls, keys + 1);
    await h.controller.retrySubmission();
    expect(h.h.attempts.submits, hasLength(1));
  });

  test('an unanswered Attempt can be submitted', () async {
    final h = await _Harness.create();
    expect(h.token.snapshot.confirmedAnsweredCount, 0);
    final submit = h.controller.submitConfirmed(h.token);
    h.completeSubmit(_submitted());
    await submit;
    expect(h.state.status, StudentBlitzSubmitStatus.completed);
  });

  test('a confirmation opened on an older state never submits', () async {
    final h = await _Harness.create();
    final captured = h.token;
    h.editor.updateDraft(_trueFalse, const StudentTrueFalseDraft(value: true));
    h.editor.discardChanges(_trueFalse);
    await h.controller.submitConfirmed(captured);
    expect(h.h.attempts.submits, isEmpty);
    expect(h.h.keys.calls, 1);
    expect(h.state.status, StudentBlitzSubmitStatus.idle);
    expect(h.state.notice, contains('Review the current attempt'));
  });

  test('no answer or file write can begin while Submit is in flight', () async {
    final h = await _Harness.create();
    final token = h.token;
    final submit = h.controller.submitConfirmed(token);
    h.editor.updateDraft(_trueFalse, const StudentTrueFalseDraft(value: true));
    await h.editor.saveAnswer(_trueFalse);
    await h.files.chooseFile(blitzQuestionId(3));
    expect(h.h.answers.saves, isEmpty);
    expect(h.h.picker.requests, isEmpty);
    await h.controller.submitConfirmed(token);
    expect(h.h.attempts.submits, hasLength(1));
    h.completeSubmit(_submitted());
    await submit;
  });

  group('uncertain Submit', () {
    for (final failure in [
      studentLocalFailure(ApiFailureKind.timeout),
      studentLocalFailure(ApiFailureKind.connection),
      studentLocalFailure(ApiFailureKind.invalidResponse),
      studentServerFailure(ApiErrorCodes.serverError, statusCode: 500),
    ]) {
      test('${failure.failure.kind} keeps the key for Retry', () async {
        final h = await _Harness.create();
        await h.uncertain(failure);
        expect(h.state.status, StudentBlitzSubmitStatus.uncertain);
        expect(h.gate, StudentBlitzExecutionOperation.submitUncertain);
        expect(h.h.execution.isExecuting, isTrue);
        final retry = h.controller.retrySubmission();
        final again = h.h.attempts.submits.last;
        expect(h.h.attempts.submits, hasLength(2));
        expect(again.idempotencyKey, h.h.attempts.submits.first.idempotencyKey);
        expect(
          again.expectation,
          StudentBlitzSubmitResponseExpectation.completedReplay,
        );
        expect(h.h.keys.calls, 2);
        h.completeSubmit(_submitted());
        await retry;
        expect(h.state.status, StudentBlitzSubmitStatus.completed);
        expect(h.state.notice, 'Blitz submitted successfully.');
      });
    }

    test('an unexpected Submit error is uncertain, never stuck', () async {
      final h = await _Harness.create();
      await h.uncertain(StateError('unexpected'));
      expect(h.state.status, StudentBlitzSubmitStatus.uncertain);
    });

    for (final status in [
      StudentBlitzAttemptStatus.waitingForReview,
      StudentBlitzAttemptStatus.checked,
    ]) {
      test(
        'Retry confirms a later ${status.apiValue} Student Submit',
        () async {
          final h = await _Harness.create();
          await h.uncertain(studentLocalFailure(ApiFailureKind.timeout));
          final retry = h.controller.retrySubmission();
          h.completeSubmit(_submitted(status: status));
          await retry;
          expect(h.state.status, StudentBlitzSubmitStatus.completed);
          expect(h.state.notice, 'Blitz submission confirmed.');
          expect(h.h.execution.attempt!.status, status);
        },
      );
    }

    for (final reason in [
      StudentBlitzAttemptFinalizationReason.timeout,
      StudentBlitzAttemptFinalizationReason.taskClosed,
    ]) {
      test('Retry never turns ${reason.apiValue} into a Submit', () async {
        final h = await _Harness.create();
        await h.uncertain(studentLocalFailure(ApiFailureKind.timeout));
        final retry = h.controller.retrySubmission();
        h.completeSubmit(
          blitzExecutionAttempt(
            status: reason == StudentBlitzAttemptFinalizationReason.timeout
                ? StudentBlitzAttemptStatus.timedOutFinalized
                : StudentBlitzAttemptStatus.submitted,
            finalizationReason: reason,
          ),
        );
        await retry;
        expect(h.state.status, StudentBlitzSubmitStatus.uncertain);
        expect(h.h.execution.isExecuting, isTrue);
      });
    }

    test(
      'Retry never trusts Submit-like timestamps of a Teacher close',
      () async {
        final h = await _Harness.create();
        await h.uncertain(studentLocalFailure(ApiFailureKind.timeout));
        final retry = h.controller.retrySubmission();
        final closedAt = DateTime.utc(2026, 9, 17, 12, 2);
        final base = _submitted();
        h.completeSubmit(
          StudentBlitzAttempt(
            id: base.id,
            assessmentId: base.assessmentId,
            attemptNumber: base.attemptNumber,
            status: StudentBlitzAttemptStatus.submitted,
            startedAt: base.startedAt,
            deadlineAt: base.deadlineAt,
            submittedAt: closedAt,
            finalizedAt: closedAt,
            finalizationReason:
                StudentBlitzAttemptFinalizationReason.taskClosed,
            timing: base.timing,
            questions: base.questions,
            answers: base.answers,
          ),
        );
        await retry;
        expect(h.state.status, StudentBlitzSubmitStatus.uncertain);
        expect(h.h.execution.isExecuting, isTrue);
      },
    );

    test('Check that finds it in progress stays uncertain', () async {
      final h = await _Harness.create();
      await h.uncertain(studentLocalFailure(ApiFailureKind.timeout));
      final check = h.controller.checkCurrentAttempt();
      expect(h.state.status, StudentBlitzSubmitStatus.checking);
      expect(h.h.replays.single, same(h.h.completedRequest));
      await h.h.completeReplay(blitzExecutionAttempt());
      await check;
      expect(h.state.status, StudentBlitzSubmitStatus.uncertain);
      expect(h.gate, StudentBlitzExecutionOperation.submitUncertain);
      h.editor.updateDraft(
        _trueFalse,
        const StudentTrueFalseDraft(value: true),
      );
      await h.editor.saveAnswer(_trueFalse);
      expect(h.h.answers.saves, isEmpty);
      final retry = h.controller.retrySubmission();
      expect(
        h.h.attempts.submits.last.idempotencyKey,
        h.h.attempts.submits.first.idempotencyKey,
      );
      h.completeSubmit(_submitted());
      await retry;
    });

    for (final (name, attempt, notice) in [
      (
        'a Student Submit',
        _submitted(),
        'This Blitz attempt is already submitted.',
      ),
      (
        'a timeout',
        blitzExecutionAttempt(
          status: StudentBlitzAttemptStatus.timedOutFinalized,
          finalizationReason: StudentBlitzAttemptFinalizationReason.timeout,
        ),
        null,
      ),
      (
        'a Teacher close',
        blitzExecutionAttempt(
          status: StudentBlitzAttemptStatus.submitted,
          finalizationReason: StudentBlitzAttemptFinalizationReason.taskClosed,
        ),
        null,
      ),
      (
        'a checked Attempt',
        _submitted(status: StudentBlitzAttemptStatus.checked),
        'This Blitz attempt is already submitted.',
      ),
    ]) {
      test('Check that finds $name resolves without a success claim', () async {
        final h = await _Harness.create();
        await h.uncertain(studentLocalFailure(ApiFailureKind.timeout));
        final check = h.controller.checkCurrentAttempt();
        await h.h.completeReplay(attempt);
        await check;
        expect(h.state.status, StudentBlitzSubmitStatus.reconciledTerminal);
        expect(h.state.notice, notice);
        expect(h.gate, StudentBlitzExecutionOperation.idle);
        expect(h.h.execution.status, StudentBlitzExecutionStatus.terminal);
        expect(h.h.execution.confirmedBySubmit, isFalse);
        await h.controller.retrySubmission();
        expect(h.h.attempts.submits, hasLength(1));
      });
    }

    test('an expiry replay that finds it final resolves the Submit', () async {
      final h = await _Harness.create();
      await h.uncertain(studentLocalFailure(ApiFailureKind.timeout));
      h.h.executionController.markLocalTimeExpired(
        h.h.execution.countdownAnchor!,
      );
      await h.h.completeReplay(_submitted());
      expect(h.state.status, StudentBlitzSubmitStatus.reconciledTerminal);
      expect(h.state.notice, 'This Blitz attempt is already submitted.');
      expect(h.gate, StudentBlitzExecutionOperation.idle);
      await h.controller.retrySubmission();
      await h.controller.checkCurrentAttempt();
      expect(h.h.attempts.submits, hasLength(1));
      expect(h.h.replays, hasLength(1));
    });

    test('a failed Check keeps the Submit unconfirmed', () async {
      final h = await _Harness.create();
      await h.uncertain(studentLocalFailure(ApiFailureKind.timeout));
      final check = h.controller.checkCurrentAttempt();
      await h.h.failReplay(studentLocalFailure(ApiFailureKind.connection));
      await check;
      expect(h.state.status, StudentBlitzSubmitStatus.uncertain);
    });
  });

  group('deterministic Submit rejections', () {
    test(
      'blitz_time_expired re-reads the Attempt and never claims Submit',
      () async {
        final h = await _Harness.create();
        final submit = h.controller.submitConfirmed(h.token);
        h.failSubmit(
          studentServerFailure(ApiErrorCodes.blitzTimeExpired, statusCode: 409),
        );
        await submit;
        await flushStudentControllers();
        expect(h.state.status, StudentBlitzSubmitStatus.failure);
        expect(h.gate, StudentBlitzExecutionOperation.terminalReconciliation);
        expect(h.h.execution.localTimeExpired, isTrue);
        expect(h.h.replays.single, same(h.h.completedRequest));
        await h.h.completeReplay(
          blitzExecutionAttempt(
            status: StudentBlitzAttemptStatus.timedOutFinalized,
            finalizationReason: StudentBlitzAttemptFinalizationReason.timeout,
          ),
        );
        expect(h.state.status, StudentBlitzSubmitStatus.reconciledTerminal);
        expect(h.state.notice, isNull);
        expect(h.gate, StudentBlitzExecutionOperation.idle);
        expect(h.h.attempts.submits, hasLength(1));
      },
    );

    test('blitz_time_expired without a network keeps writes closed', () async {
      final h = await _Harness.create();
      final submit = h.controller.submitConfirmed(h.token);
      h.failSubmit(
        studentServerFailure(ApiErrorCodes.blitzTimeExpired, statusCode: 409),
      );
      await submit;
      await h.h.failReplay(studentLocalFailure(ApiFailureKind.connection));
      expect(
        h.state.notice,
        'Time has expired.\n'
        'Reconnect and refresh to confirm the final attempt state.',
      );
      expect(h.h.execution.acceptsWrites, isFalse);
      expect(h.readiness.isReady, isFalse);
    });

    test(
      'attempt_not_editable that re-reads as in progress stays read-only',
      () async {
        final h = await _Harness.create();
        final submit = h.controller.submitConfirmed(h.token);
        h.failSubmit(
          studentServerFailure(
            ApiErrorCodes.attemptNotEditable,
            statusCode: 409,
          ),
        );
        await submit;
        await h.h.completeReplay(blitzExecutionAttempt());
        expect(
          h.h.execution.status,
          StudentBlitzExecutionStatus.reconciliationFailed,
        );
        expect(h.h.execution.acceptsWrites, isFalse);
        expect(h.readiness.isReady, isFalse);
        expect(h.h.attempts.submits, hasLength(1));
      },
    );

    test('blitz_not_active re-reads the Attempt, detail and list', () async {
      final h = await _Harness.create();
      final details = h.h.blitz.detailIds.length;
      final lists = h.h.blitz.activeCalls;
      final submit = h.controller.submitConfirmed(h.token);
      h.failSubmit(
        studentServerFailure(ApiErrorCodes.blitzNotActive, statusCode: 409),
      );
      await submit;
      await h.h.completeReplay(
        blitzExecutionAttempt(
          status: StudentBlitzAttemptStatus.submitted,
          finalizationReason: StudentBlitzAttemptFinalizationReason.taskClosed,
        ),
      );
      expect(h.state.status, StudentBlitzSubmitStatus.reconciledTerminal);
      expect(h.h.blitz.detailIds.length, greaterThan(details));
      expect(h.h.blitz.activeCalls, greaterThan(lists));
    });

    test('idempotency_key_reused allows only a later new Submit', () async {
      final h = await _Harness.create();
      final submit = h.controller.submitConfirmed(h.token);
      h.failSubmit(
        studentServerFailure(
          ApiErrorCodes.idempotencyKeyReused,
          statusCode: 409,
        ),
      );
      await submit;
      expect(
        h.state.notice,
        'The Blitz could not be submitted safely.\n'
        'Check the current attempt before trying again.',
      );
      expect(h.h.replays.single, same(h.h.completedRequest));
      await h.h.completeReplay(blitzExecutionAttempt());
      expect(h.state.status, StudentBlitzSubmitStatus.failure);
      expect(h.gate, StudentBlitzExecutionOperation.idle);
      final again = h.controller.submitConfirmed(h.token);
      expect(h.h.attempts.submits, hasLength(2));
      expect(
        h.h.attempts.submits.last.idempotencyKey,
        isNot(h.h.attempts.submits.first.idempotencyKey),
      );
      expect(
        h.h.attempts.submits.last.expectation,
        StudentBlitzSubmitResponseExpectation.fresh,
      );
      h.completeSubmit(_submitted());
      await again;
    });

    test('validation_failed re-reads before any new Submit', () async {
      final h = await _Harness.create();
      final submit = h.controller.submitConfirmed(h.token);
      h.failSubmit(
        studentServerFailure(ApiErrorCodes.validationFailed, statusCode: 422),
      );
      await submit;
      expect(
        h.state.notice,
        'The submission request could not be validated.\n'
        'Refresh the current Blitz and try again if it remains editable.',
      );
      expect(h.h.replays, hasLength(1));
    });

    test('resource_not_found clears the unavailable execution', () async {
      final h = await _Harness.create();
      final details = h.h.blitz.detailIds.length;
      final lists = h.h.blitz.activeCalls;
      final submit = h.controller.submitConfirmed(h.token);
      h.failSubmit(
        studentServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
      );
      await submit;
      await h.h.failReplay(
        studentServerFailure(ApiErrorCodes.resourceNotFound, statusCode: 404),
      );
      expect(h.h.execution.status, StudentBlitzExecutionStatus.none);
      expect(h.state.status, StudentBlitzSubmitStatus.idle);
      // Detail must not keep offering a Resume of a vanished Attempt.
      expect(h.h.blitz.detailIds.length, greaterThan(details));
      expect(h.h.blitz.activeCalls, greaterThan(lists));
    });

    test('a session failure clears the key and reconciles auth', () async {
      final h = await _Harness.create();
      final submit = h.controller.submitConfirmed(h.token);
      h.failSubmit(studentServerFailure(ApiErrorCodes.userInactive));
      await submit;
      expect(h.state.status, StudentBlitzSubmitStatus.idle);
      expect(h.h.auth.bootstrapCalls, 1);
      await h.controller.retrySubmission();
      expect(h.h.attempts.submits, hasLength(1));
    });
  });

  group('countdown races', () {
    test('a Submit started before zero still succeeds after it', () async {
      final h = await _Harness.create();
      final submit = h.controller.submitConfirmed(h.token);
      h.h.executionController.markLocalTimeExpired(
        h.h.execution.countdownAnchor!,
      );
      h.completeSubmit(_submitted());
      await submit;
      await flushStudentControllers();
      expect(h.state.status, StudentBlitzSubmitStatus.completed);
      expect(h.h.replays, isEmpty);
    });

    test('a Submit rejected as late reconciles with one replay', () async {
      final h = await _Harness.create();
      final submit = h.controller.submitConfirmed(h.token);
      h.h.executionController.markLocalTimeExpired(
        h.h.execution.countdownAnchor!,
      );
      h.failSubmit(
        studentServerFailure(ApiErrorCodes.blitzTimeExpired, statusCode: 409),
      );
      await submit;
      await flushStudentControllers();
      expect(h.h.replays, hasLength(1));
      await h.h.completeReplay(
        blitzExecutionAttempt(
          status: StudentBlitzAttemptStatus.timedOutFinalized,
          finalizationReason: StudentBlitzAttemptFinalizationReason.timeout,
        ),
      );
      expect(h.h.replays, hasLength(1));
      expect(h.state.status, StudentBlitzSubmitStatus.reconciledTerminal);
    });

    test('no new Submit begins after local zero', () async {
      final h = await _Harness.create();
      final captured = h.token;
      h.h.executionController.markLocalTimeExpired(
        h.h.execution.countdownAnchor!,
      );
      await h.controller.submitConfirmed(captured);
      expect(h.h.attempts.submits, isEmpty);
    });
  });

  test('a Submit completing after disposal still ends its write', () async {
    final h = await BlitzExecutionHarness.executing();
    addTearDown(h.dispose);
    final pending = Completer<StudentBlitzSubmitResult>();
    h.attempts.onSubmit = (_) => pending.future;
    final readiness = h.container.listen(
      studentBlitzSubmitReadinessProvider(blitzExecutionTarget),
      (_, _) {},
    );
    final subscription = h.container.listen(
      studentBlitzSubmitControllerProvider(blitzExecutionTarget),
      (_, _) {},
    );
    final submit = h.container
        .read(
          studentBlitzSubmitControllerProvider(blitzExecutionTarget).notifier,
        )
        .submitConfirmed(readiness.read().readyToken!);
    expect(h.attempts.submits, hasLength(1));
    // The route goes away while the POST is still in flight.
    subscription.close();
    readiness.close();
    await flushStudentControllers();
    pending.completeError(studentLocalFailure(ApiFailureKind.timeout));
    await submit;
    final replay = h.executionController.refreshCurrentAttempt();
    expect(h.replays, hasLength(1));
    await h.completeReplay(blitzExecutionAttempt());
    expect(await replay, StudentBlitzAttemptReplayOutcome.active);
  });

  test('a completion after a session switch is ignored', () async {
    final h = await _Harness.create();
    final submit = h.controller.submitConfirmed(h.token);
    h.h.auth.replaceUser(studentUser('student-b'));
    await flushStudentControllers();
    h.completeSubmit(_submitted());
    await submit;
    expect(h.state.status, StudentBlitzSubmitStatus.idle);
    expect(h.h.execution.status, StudentBlitzExecutionStatus.none);
  });

  test('leaving an uncertain Submit discards its key', () async {
    final h = await _Harness.create();
    await h.uncertain(studentLocalFailure(ApiFailureKind.timeout));
    h.controller.clearLocalState();
    expect(h.state.status, StudentBlitzSubmitStatus.idle);
    expect(h.gate, StudentBlitzExecutionOperation.idle);
    await h.controller.retrySubmission();
    await h.controller.checkCurrentAttempt();
    expect(h.h.attempts.submits, hasLength(1));
    expect(h.h.replays, isEmpty);
  });
}

final _trueFalse = blitzQuestionId(1);

StudentBlitzAttempt _submitted({
  StudentBlitzAttemptStatus status = StudentBlitzAttemptStatus.submitted,
}) => blitzExecutionAttempt(
  status: status,
  finalizationReason: StudentBlitzAttemptFinalizationReason.studentSubmit,
);

class _Harness {
  _Harness(this.h) {
    h.listen(studentBlitzSubmitControllerProvider(blitzExecutionTarget));
    h.listen(studentBlitzSubmitReadinessProvider(blitzExecutionTarget));
    h.attempts.onSubmit = (_) {
      final completer = Completer<StudentBlitzSubmitResult>();
      pendingSubmits.add(completer);
      return completer.future;
    };
  }

  static Future<_Harness> create() async {
    final harness = _Harness(await BlitzExecutionHarness.executing());
    addTearDown(harness.h.dispose);
    await flushStudentControllers();
    return harness;
  }

  final BlitzExecutionHarness h;
  final pendingSubmits = <Completer<StudentBlitzSubmitResult>>[];

  StudentBlitzSubmitState get state => h.container.read(
    studentBlitzSubmitControllerProvider(blitzExecutionTarget),
  );
  StudentBlitzSubmitController get controller => h.container.read(
    studentBlitzSubmitControllerProvider(blitzExecutionTarget).notifier,
  );
  StudentBlitzSubmitReadiness get readiness => h.container.read(
    studentBlitzSubmitReadinessProvider(blitzExecutionTarget),
  );
  StudentBlitzSubmitReadyToken get token => readiness.readyToken!;
  StudentBlitzExecutionOperation get gate => h.container.read(
    studentBlitzExecutionOperationGateProvider(blitzExecutionTarget),
  );
  StudentBlitzAnswerEditorController get editor => h.container.read(
    studentBlitzAnswerEditorControllerProvider(blitzExecutionTarget).notifier,
  );
  StudentBlitzFileAnswerController get files => h.container.read(
    studentBlitzFileAnswerControllerProvider(blitzExecutionTarget).notifier,
  );

  void completeSubmit(StudentBlitzAttempt attempt) =>
      pendingSubmits.last.complete(StudentBlitzSubmitResult(attempt: attempt));
  void failSubmit(Object error) => pendingSubmits.last.completeError(error);

  Future<void> uncertain(Object error) async {
    final submit = controller.submitConfirmed(token);
    failSubmit(error);
    await submit;
    await flushStudentControllers();
  }
}
