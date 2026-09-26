import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/data/dto/student_blitz_attempt_dto.dart';
import 'package:testlabuz_client/features/student/domain/student_attempt_answer.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';

import 'student_blitz_test_support.dart';

void main() {
  group('in-progress Attempt', () {
    test('synchronized #1 anchors on the server remaining seconds', () {
      final attempt = _parse(blitzAttemptJson());
      expect(attempt.id, studentBlitzAttemptId);
      expect(attempt.assessmentId, studentBlitzId);
      expect(attempt.attemptNumber, 1);
      expect(attempt.status, StudentBlitzAttemptStatus.inProgress);
      expect(attempt.startedAt, DateTime.utc(2026, 9, 17, 12));
      expect(attempt.deadlineAt, DateTime.utc(2026, 9, 17, 12, 5));
      expect(attempt.submittedAt, isNull);
      expect(attempt.finalizedAt, isNull);
      expect(attempt.finalizationReason, isNull);
      expect(attempt.timing.mode, StudentBlitzTimerMode.synchronized);
      expect(attempt.timing.serverNow, DateTime.utc(2026, 9, 17, 12));
      expect(attempt.timing.remainingSeconds, 300);
      expect(attempt.questions.single.type, StudentQuestionType.trueFalse);
      expect(attempt.answers, isEmpty);
    });

    test('individual #1 and both replacement #2 modes are accepted', () {
      final individual = _parse(
        blitzAttemptJson(
          mode: 'individual',
          deadlineAt: '2026-09-17T12:10:00Z',
          serverNow: '2026-09-17T12:00:30Z',
          remainingSeconds: 570,
        ),
      );
      expect(individual.timing.mode, StudentBlitzTimerMode.individual);
      expect(individual.timing.remainingSeconds, 570);
      for (final mode in ['synchronized', 'individual']) {
        final replacement = _parse(
          blitzAttemptJson(
            id: studentBlitzReplacementAttemptId,
            attemptNumber: 2,
            mode: mode,
            startedAt: '2026-09-17T12:10:00Z',
            deadlineAt: '2026-09-17T12:20:00Z',
            serverNow: '2026-09-17T12:10:00Z',
            remainingSeconds: 600,
          ),
        );
        expect(replacement.attemptNumber, 2);
        expect(replacement.deadlineAt, DateTime.utc(2026, 9, 17, 12, 20));
      }
    });

    test('remaining seconds must equal the exact whole-second difference', () {
      for (final remaining in [299, 301, 0, -1, null]) {
        _reject(blitzAttemptJson(remainingSeconds: remaining));
      }
      expect(
        _parse(
          blitzAttemptJson(
            serverNow: '2026-09-17T12:04:59Z',
            remainingSeconds: 1,
          ),
        ).timing.remainingSeconds,
        1,
      );
    });

    test('an in-progress Attempt cannot carry finalization metadata', () {
      _reject(blitzAttemptJson(finalizedAt: '2026-09-17T12:01:00Z'));
      _reject(blitzAttemptJson(submittedAt: '2026-09-17T12:01:00Z'));
      _reject(blitzAttemptJson(finalizationReason: 'student_submit'));
    });
  });

  group('terminal Attempt', () {
    test('explicit submit finalizes before the deadline at submit time', () {
      final attempt = _parse(
        _terminal(
          'submitted',
          'student_submit',
          submittedAt: '2026-09-17T12:02:00Z',
          finalizedAt: '2026-09-17T12:02:00Z',
        ),
      );
      expect(attempt.status, StudentBlitzAttemptStatus.submitted);
      expect(
        attempt.finalizationReason,
        StudentBlitzAttemptFinalizationReason.studentSubmit,
      );
      expect(attempt.submittedAt, attempt.finalizedAt);
      _reject(
        _terminal(
          'submitted',
          'student_submit',
          submittedAt: '2026-09-17T12:02:00Z',
          finalizedAt: '2026-09-17T12:03:00Z',
        ),
      );
      _reject(
        _terminal(
          'submitted',
          'student_submit',
          submittedAt: '2026-09-17T12:05:00Z',
          finalizedAt: '2026-09-17T12:05:00Z',
        ),
      );
    });

    test('timeout finalizes exactly at the deadline without submit time', () {
      final attempt = _parse(
        _terminal(
          'timed_out_finalized',
          'timeout_auto_submit',
          finalizedAt: '2026-09-17T12:05:00Z',
        ),
      );
      expect(attempt.status, StudentBlitzAttemptStatus.timedOutFinalized);
      _reject(
        _terminal(
          'timed_out_finalized',
          'timeout_auto_submit',
          finalizedAt: '2026-09-17T12:04:59Z',
        ),
      );
      _reject(
        _terminal(
          'timed_out_finalized',
          'timeout_auto_submit',
          submittedAt: '2026-09-17T12:05:00Z',
          finalizedAt: '2026-09-17T12:05:00Z',
        ),
      );
    });

    test('Teacher close finalizes before the deadline without submit time', () {
      final attempt = _parse(
        _terminal(
          'submitted',
          'task_closed_auto_finalize',
          finalizedAt: '2026-09-17T12:03:00Z',
        ),
      );
      expect(
        attempt.finalizationReason,
        StudentBlitzAttemptFinalizationReason.taskClosed,
      );
      _reject(
        _terminal(
          'submitted',
          'task_closed_auto_finalize',
          finalizedAt: '2026-09-17T12:05:00Z',
        ),
      );
    });

    for (final status in ['waiting_for_teacher_review', 'checked']) {
      test('$status replay keeps coherent finalization metadata', () {
        for (final (reason, submitted, finalized) in [
          ('student_submit', '2026-09-17T12:02:00Z', '2026-09-17T12:02:00Z'),
          ('timeout_auto_submit', null, '2026-09-17T12:05:00Z'),
          ('task_closed_auto_finalize', null, '2026-09-17T12:03:00Z'),
        ]) {
          final attempt = _parse(
            _terminal(
              status,
              reason,
              submittedAt: submitted,
              finalizedAt: finalized,
            ),
          );
          expect(attempt.status.apiValue, status);
          expect(attempt.finalizationReason!.apiValue, reason);
        }
      });
    }

    test('status and reason pairs must match their lifecycle', () {
      _reject(
        _terminal(
          'timed_out_finalized',
          'student_submit',
          submittedAt: '2026-09-17T12:02:00Z',
          finalizedAt: '2026-09-17T12:02:00Z',
        ),
      );
      _reject(
        _terminal(
          'submitted',
          'timeout_auto_submit',
          finalizedAt: '2026-09-17T12:05:00Z',
        ),
      );
      _reject(
        _terminal(
          'submitted',
          'homework_deadline_auto_submit',
          finalizedAt: '2026-09-17T12:05:00Z',
        ),
      );
      _reject(
        _terminal('submitted', null, finalizedAt: '2026-09-17T12:03:00Z'),
      );
      _reject(_terminal('submitted', 'task_closed_auto_finalize'));
    });

    test('every terminal Attempt reports zero remaining seconds', () {
      _reject(
        _terminal(
          'submitted',
          'task_closed_auto_finalize',
          finalizedAt: '2026-09-17T12:03:00Z',
          remainingSeconds: 120,
        ),
      );
    });
  });

  group('resource shape', () {
    test('attempt numbers are only #1 normal and #2 replacement', () {
      for (final number in [0, 3, -1]) {
        _reject(blitzAttemptJson(attemptNumber: number));
      }
    });

    test('deadline is required and must follow the start', () {
      _reject(blitzAttemptJson(deadlineAt: null));
      _reject(
        blitzAttemptJson(
          deadlineAt: '2026-09-17T12:00:00Z',
          remainingSeconds: 0,
        ),
      );
    });

    test('fractional or offset Attempt timestamps are rejected', () {
      for (final invalid in [
        blitzAttemptJson(startedAt: '2026-09-17T12:00:00.500Z'),
        blitzAttemptJson(deadlineAt: '2026-09-17T12:05:00.000Z'),
        blitzAttemptJson(serverNow: '2026-09-17T12:00:00.250Z'),
        blitzAttemptJson(startedAt: '2026-09-17T17:00:00+05:00'),
      ]) {
        _reject(invalid);
      }
    });

    test('exact keys reject score, checking and unknown timing fields', () {
      for (final key in blitzAttemptJson().keys) {
        _reject(blitzAttemptJson()..remove(key));
      }
      for (final leak in ['earned_points', 'score', 'blitz_id', 'checked_at']) {
        _reject(blitzAttemptJson()..[leak] = null);
      }
      final timing = blitzAttemptJson()['timing']! as Map<String, Object?>;
      _reject(
        blitzAttemptJson()..['timing'] = {...timing, 'deadline_at': null},
      );
      _reject(
        blitzAttemptJson()..['timing'] = ({...timing}..remove('server_now')),
      );
      _reject(blitzAttemptJson()..['timing'] = {...timing, 'mode': 'manual'});
      final question = blitzQuestionJson(StudentQuestionType.trueFalse, 1)
        ..['is_correct'] = true;
      _reject(blitzAttemptJson(questions: [question]));
    });
  });

  group('Questions and saved answers', () {
    test('all nine safe Question types parse with their saved answers', () {
      final attempt = _parse(
        blitzAttemptJson(
          questions: [
            for (final type in StudentQuestionType.values)
              blitzQuestionJson(type, type.index + 1),
          ],
          answers: [
            for (final type in StudentQuestionType.values)
              blitzAnswerJson(type, type.index + 1),
          ],
        ),
      );
      expect(
        attempt.questions.map((question) => question.type),
        StudentQuestionType.values,
      );
      expect(attempt.answers, hasLength(StudentQuestionType.values.length));
      final text = attempt.answers
          .firstWhere((a) => a.type == StudentQuestionType.shortWritten)
          .value;
      expect((text as StudentTextAnswerValue).text, '  Exact saved text\n');
      final file = attempt.answers
          .firstWhere((a) => a.type == StudentQuestionType.fileBased)
          .value;
      expect((file as StudentFileAnswerValue).file.originalName, 'blitz.pdf');
    });

    test('unanswered Questions simply have no answer entry', () {
      final attempt = _parse(
        blitzAttemptJson(
          questions: [
            blitzQuestionJson(StudentQuestionType.trueFalse, 1),
            blitzQuestionJson(StudentQuestionType.shortWritten, 2),
          ],
          answers: [blitzAnswerJson(StudentQuestionType.shortWritten, 2)],
        ),
      );
      expect(attempt.questions, hasLength(2));
      expect(attempt.answers.single.questionId, blitzUuid(102));
    });

    test('duplicate answers, foreign child IDs and bad positions fail', () {
      final question = blitzQuestionJson(StudentQuestionType.singleChoice, 1);
      _reject(
        blitzAttemptJson(
          questions: [question],
          answers: [
            blitzAnswerJson(StudentQuestionType.singleChoice, 1),
            blitzAnswerJson(StudentQuestionType.singleChoice, 1),
          ],
        ),
      );
      _reject(
        blitzAttemptJson(
          questions: [question],
          answers: [
            blitzAnswerJson(StudentQuestionType.singleChoice, 1)
              ..['answer'] = {
                'selected_option_ids': [blitzUuid(77)],
              },
          ],
        ),
      );
      _reject(
        blitzAttemptJson(
          questions: [question],
          answers: [blitzAnswerJson(StudentQuestionType.trueFalse, 1)],
        ),
      );
      _reject(
        blitzAttemptJson(
          questions: [blitzQuestionJson(StudentQuestionType.trueFalse, 2)],
        ),
      );
    });
  });

  group('Start envelope', () {
    test('201 started and 200 resumed map from HTTP status only', () {
      final created = StudentBlitzAttemptStartOperationDto.fromResponse(
        statusCode: 201,
        body: _envelope('Blitz attempt started successfully.'),
      ).toDomain();
      expect(created.resultKind, StudentBlitzAttemptStartResultKind.created);
      expect(created.attempt.id, studentBlitzAttemptId);
      final resumed = StudentBlitzAttemptStartOperationDto.fromResponse(
        statusCode: 200,
        body: _envelope(
          'Blitz attempt resumed successfully.',
          attempt: blitzAttemptJson(
            id: studentBlitzReplacementAttemptId,
            attemptNumber: 2,
          ),
        ),
      ).toDomain();
      expect(resumed.resultKind, StudentBlitzAttemptStartResultKind.resumed);
      expect(resumed.attempt.attemptNumber, 2);
    });

    test('mismatched status, message or envelope is not success', () {
      for (final (status, body) in [
        (201, _envelope('Blitz attempt resumed successfully.')),
        (200, _envelope('Blitz attempt started successfully.')),
        (202, _envelope('Blitz attempt started successfully.')),
        (null, _envelope('Blitz attempt started successfully.')),
        (201, {'data': blitzAttemptJson()}),
        (
          201,
          {
            ..._envelope('Blitz attempt started successfully.'),
            'meta': <String, Object?>{},
          },
        ),
        (201, _envelope(null)),
      ]) {
        expect(
          () => StudentBlitzAttemptStartOperationDto.fromResponse(
            statusCode: status,
            body: body,
          ),
          throwsFormatException,
        );
      }
    });
  });
}

StudentBlitzAttempt _parse(Object? json) =>
    StudentBlitzAttemptDto.fromJson(json).toDomain();

void _reject(Object? json) => expect(() => _parse(json), throwsFormatException);

Map<String, Object?> _terminal(
  String status,
  String? reason, {
  String? submittedAt,
  String? finalizedAt,
  int remainingSeconds = 0,
}) => blitzAttemptJson(
  status: status,
  finalizationReason: reason,
  submittedAt: submittedAt,
  finalizedAt: finalizedAt,
  serverNow: '2026-09-17T12:30:00Z',
  remainingSeconds: remainingSeconds,
);

Map<String, Object?> _envelope(
  String? message, {
  Map<String, Object?>? attempt,
}) => {'data': attempt ?? blitzAttemptJson(), 'message': message};
