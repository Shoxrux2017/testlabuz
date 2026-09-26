import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';

import 'student_blitz_test_support.dart';

const _key = 'c1000000-0000-4000-8000-000000000001';

void main() {
  group('execution request', () {
    test('each intent serializes its exact body', () {
      expect(
        StudentBlitzAttemptRequest.startNormal(idempotencyKey: _key).toJson(),
        {'intent': 'start_normal'},
      );
      expect(
        StudentBlitzAttemptRequest.startReplacement(
          idempotencyKey: _key,
        ).toJson(),
        {'intent': 'start_replacement'},
      );
      final resume = StudentBlitzAttemptRequest.resume(
        attemptId: studentBlitzAttemptId.toUpperCase(),
        idempotencyKey: _key,
      );
      expect(resume.toJson(), {
        'intent': 'resume',
        'attempt_id': studentBlitzAttemptId,
      });
      expect(resume.idempotencyKey, _key);
    });

    test('invalid Attempt IDs and keys are rejected before transport', () {
      for (final invalid in ['', 'attempt-1', ' $_key', '$_key/x']) {
        expect(
          () => StudentBlitzAttemptRequest.resume(
            attemptId: invalid,
            idempotencyKey: _key,
          ),
          throwsArgumentError,
        );
        expect(
          () => StudentBlitzAttemptRequest.startNormal(idempotencyKey: invalid),
          throwsArgumentError,
        );
      }
    });
  });

  group('server-projected action', () {
    test('maps the attempt summary to exactly one path or none', () {
      expect(
        studentBlitzExecutionAction(studentBlitzAttemptSummary()),
        StudentBlitzExecutionAction.startNormal,
      );
      expect(
        studentBlitzExecutionAction(
          studentBlitzAttemptSummary(
            normalUsed: 1,
            inProgressAttemptId: studentBlitzAttemptId,
          ),
        ),
        StudentBlitzExecutionAction.resume,
      );
      expect(
        studentBlitzExecutionAction(
          studentBlitzAttemptSummary(
            normalUsed: 1,
            exceptionGranted: true,
            replacementAvailable: true,
          ),
        ),
        StudentBlitzExecutionAction.startReplacement,
      );
      expect(
        studentBlitzExecutionAction(studentBlitzAttemptSummary(normalUsed: 1)),
        isNull,
      );
      expect(
        studentBlitzExecutionAction(
          studentBlitzAttemptSummary(normalUsed: 1, exceptionGranted: true),
        ),
        isNull,
      );
    });
  });

  group('intent-specific Start success', () {
    final normal = StudentBlitzAttemptRequest.startNormal(idempotencyKey: _key);
    final replacement = StudentBlitzAttemptRequest.startReplacement(
      idempotencyKey: _key,
    );
    final resumeFirst = StudentBlitzAttemptRequest.resume(
      attemptId: studentBlitzAttemptId,
      idempotencyKey: _key,
    );
    final first = studentBlitzAttempt();
    final second = studentBlitzAttempt(
      id: studentBlitzReplacementAttemptId,
      attemptNumber: 2,
    );

    bool accepted(
      StudentBlitzAttemptRequest request,
      StudentBlitzAttempt attempt, {
      StudentBlitzAttemptStartResultKind kind =
          StudentBlitzAttemptStartResultKind.created,
      StudentBlitzTimerMode? expectedMode,
    }) => isAcceptedStudentBlitzStartResult(
      request: request,
      blitzId: studentBlitzId,
      result: studentBlitzStartResult(attempt: attempt, kind: kind),
      expectedMode: expectedMode,
    );

    test('normal Start accepts only Attempt #1, created or resumed', () {
      expect(accepted(normal, first), isTrue);
      expect(
        accepted(
          normal,
          first,
          kind: StudentBlitzAttemptStartResultKind.resumed,
        ),
        isTrue,
      );
      expect(accepted(normal, second), isFalse);
    });

    test('replacement Start accepts only Attempt #2', () {
      expect(accepted(replacement, second), isTrue);
      expect(
        accepted(
          replacement,
          second,
          kind: StudentBlitzAttemptStartResultKind.resumed,
        ),
        isTrue,
      );
      expect(accepted(replacement, first), isFalse);
    });

    test('Resume accepts only a 200 with the exact requested Attempt', () {
      expect(
        accepted(
          resumeFirst,
          first,
          kind: StudentBlitzAttemptStartResultKind.resumed,
        ),
        isTrue,
      );
      expect(accepted(resumeFirst, first), isFalse);
      expect(
        accepted(
          resumeFirst,
          second,
          kind: StudentBlitzAttemptStartResultKind.resumed,
        ),
        isFalse,
      );
    });

    test('a terminal replay of the same requested Attempt is accepted', () {
      final terminal = studentBlitzAttempt(
        status: StudentBlitzAttemptStatus.timedOutFinalized,
        finalizationReason: StudentBlitzAttemptFinalizationReason.timeout,
      );
      expect(accepted(normal, terminal), isTrue);
      expect(
        accepted(
          resumeFirst,
          terminal,
          kind: StudentBlitzAttemptStartResultKind.resumed,
        ),
        isTrue,
      );
    });

    test('another Blitz or another timer mode is never accepted', () {
      expect(
        accepted(
          normal,
          studentBlitzAttempt(assessmentId: otherStudentBlitzId),
        ),
        isFalse,
      );
      expect(
        accepted(
          normal,
          studentBlitzAttempt(assessmentId: studentBlitzId.toUpperCase()),
        ),
        isTrue,
      );
      expect(
        accepted(normal, first, expectedMode: StudentBlitzTimerMode.individual),
        isFalse,
      );
      expect(
        accepted(
          normal,
          first,
          expectedMode: StudentBlitzTimerMode.synchronized,
        ),
        isTrue,
      );
    });
  });
}
