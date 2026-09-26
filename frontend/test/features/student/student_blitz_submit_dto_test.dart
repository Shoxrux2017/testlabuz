import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/data/dto/student_blitz_submit_dto.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_submit.dart';

import 'student_blitz_test_support.dart';

void main() {
  const fresh = StudentBlitzSubmitResponseExpectation.fresh;
  const replay = StudentBlitzSubmitResponseExpectation.completedReplay;

  test('fresh accepts the exact submitted + student_submit envelope', () {
    final result = _parse(_envelope(), fresh).toDomain();
    expect(result.attempt.id, studentBlitzAttemptId);
    expect(result.attempt.status, StudentBlitzAttemptStatus.submitted);
    expect(
      result.attempt.finalizationReason,
      StudentBlitzAttemptFinalizationReason.studentSubmit,
    );
    expect(result.attempt.submittedAt, result.attempt.finalizedAt);
  });

  test('an unanswered submitted Attempt is still a valid Submit', () {
    final result = _parse(_envelope(answers: const []), fresh).toDomain();
    expect(result.attempt.answers, isEmpty);
  });

  for (final status in ['waiting_for_teacher_review', 'checked']) {
    test('fresh rejects $status even with student_submit lineage', () {
      expect(
        () => _parse(_envelope(status: status), fresh),
        throwsFormatException,
      );
    });
  }

  for (final status in ['submitted', 'waiting_for_teacher_review', 'checked']) {
    test('completedReplay accepts $status + student_submit', () {
      final result = _parse(_envelope(status: status), replay).toDomain();
      expect(result.attempt.status.apiValue, status);
      expect(
        result.attempt.finalizationReason,
        StudentBlitzAttemptFinalizationReason.studentSubmit,
      );
    });
  }

  for (final expectation in StudentBlitzSubmitResponseExpectation.values) {
    group('${expectation.name} never accepts', () {
      test('an in-progress Attempt', () {
        expect(
          () => _parse({
            'data': blitzAttemptJson(),
            'message': 'Blitz attempt submitted successfully.',
          }, expectation),
          throwsFormatException,
        );
      });

      test('a timeout finalization', () {
        expect(
          () => _parse(
            _envelope(
              status: 'timed_out_finalized',
              reason: 'timeout_auto_submit',
              submittedAt: null,
              finalizedAt: '2026-09-17T12:05:00Z',
            ),
            expectation,
          ),
          throwsFormatException,
        );
      });

      test('a Teacher-close finalization', () {
        expect(
          () => _parse(
            _envelope(reason: 'task_closed_auto_finalize', submittedAt: null),
            expectation,
          ),
          throwsFormatException,
        );
      });

      for (final status in ['waiting_for_teacher_review', 'checked']) {
        for (final (reason, finalizedAt) in [
          ('timeout_auto_submit', '2026-09-17T12:05:00Z'),
          ('task_closed_auto_finalize', '2026-09-17T12:02:00Z'),
        ]) {
          test('$status with $reason lineage', () {
            expect(
              () => _parse(
                _envelope(
                  status: status,
                  reason: reason,
                  submittedAt: null,
                  finalizedAt: finalizedAt,
                ),
                expectation,
              ),
              throwsFormatException,
            );
          });
        }
      }

      test('a submission timestamp that differs from finalization', () {
        expect(
          () => _parse(
            _envelope(submittedAt: '2026-09-17T12:01:00Z'),
            expectation,
          ),
          throwsFormatException,
        );
      });

      test('a Submit at the deadline', () {
        expect(
          () => _parse(
            _envelope(
              submittedAt: '2026-09-17T12:05:00Z',
              finalizedAt: '2026-09-17T12:05:00Z',
            ),
            expectation,
          ),
          throwsFormatException,
        );
      });

      test('positive remaining time', () {
        expect(
          () => _parse(_envelope(remainingSeconds: 5), expectation),
          throwsFormatException,
        );
      });
    });
  }

  test('the envelope and message are exact', () {
    for (final json in <Object?>[
      {'data': _attempt()},
      {'data': _attempt(), 'message': 'Blitz submitted successfully.'},
      {
        'data': _attempt(),
        'message': 'Blitz attempt submitted successfully.',
        'extra': true,
      },
      [_attempt()],
      null,
    ]) {
      expect(() => _parse(json, fresh), throwsFormatException);
    }
  });

  test('the Attempt must be the expected Attempt of the expected Blitz', () {
    expect(
      () => StudentBlitzSubmitDto.fromJson(
        _envelope(),
        expectedAttemptId: studentBlitzReplacementAttemptId,
        expectedBlitzId: studentBlitzId,
        expectation: fresh,
      ),
      throwsFormatException,
    );
    expect(
      () => StudentBlitzSubmitDto.fromJson(
        _envelope(),
        expectedAttemptId: studentBlitzAttemptId,
        expectedBlitzId: otherStudentBlitzId,
        expectation: fresh,
      ),
      throwsFormatException,
    );
    expect(
      () => StudentBlitzSubmitDto.fromJson(
        _envelope(),
        expectedAttemptId: 'not-a-uuid',
        expectedBlitzId: studentBlitzId,
        expectation: fresh,
      ),
      throwsFormatException,
    );
  });

  test('score and checking fields are rejected', () {
    for (final key in ['awarded_points', 'checking_status', 'feedback']) {
      expect(
        () => _parse({
          'data': {..._attempt(), key: null},
          'message': 'Blitz attempt submitted successfully.',
        }, replay),
        throwsFormatException,
      );
    }
  });
}

StudentBlitzSubmitDto _parse(
  Object? json,
  StudentBlitzSubmitResponseExpectation expectation,
) => StudentBlitzSubmitDto.fromJson(
  json,
  expectedAttemptId: studentBlitzAttemptId,
  expectedBlitzId: studentBlitzId,
  expectation: expectation,
);

Map<String, Object?> _attempt({
  String status = 'submitted',
  String reason = 'student_submit',
  String? submittedAt = '2026-09-17T12:02:00Z',
  String finalizedAt = '2026-09-17T12:02:00Z',
  int remainingSeconds = 0,
  List<Object?>? answers,
}) => blitzAttemptJson(
  status: status,
  finalizationReason: reason,
  submittedAt: submittedAt,
  finalizedAt: finalizedAt,
  serverNow: '2026-09-17T12:02:00Z',
  remainingSeconds: remainingSeconds,
  answers: answers,
);

Map<String, Object?> _envelope({
  String status = 'submitted',
  String reason = 'student_submit',
  String? submittedAt = '2026-09-17T12:02:00Z',
  String finalizedAt = '2026-09-17T12:02:00Z',
  int remainingSeconds = 0,
  List<Object?>? answers,
}) => {
  'data': _attempt(
    status: status,
    reason: reason,
    submittedAt: submittedAt,
    finalizedAt: finalizedAt,
    remainingSeconds: remainingSeconds,
    answers: answers,
  ),
  'message': 'Blitz attempt submitted successfully.',
};
