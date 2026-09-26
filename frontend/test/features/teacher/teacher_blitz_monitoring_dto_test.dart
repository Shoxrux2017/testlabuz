import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_blitz_monitoring_dto.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_attempt_exception.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_monitoring.dart';

import 'teacher_blitz_json_fixtures.dart';
import 'teacher_blitz_monitoring_fixtures.dart';

TeacherBlitzMonitoring _parse(Object? json) =>
    TeacherBlitzMonitoringDto.fromJson(json).toDomain();

void main() {
  test('parses a synchronized Active monitoring snapshot', () {
    final monitoring = _parse(
      monitoringJson(
        students: [
          notStartedRowJson(monitoringStudentA, fullName: 'Aziza'),
          inProgressRowJson(monitoringStudentB, fullName: 'Bobur'),
          terminalRowJson(monitoringStudentC, fullName: 'Dilnoza'),
        ],
      ),
    );
    final blitz = monitoring.blitz;
    expect(blitz.id, blitzJsonId);
    expect(blitz.status, TeacherBlitzStatus.active);
    expect(blitz.durationSeconds, 600);
    expect(blitz.activatedAt, DateTime.utc(2026, 9, 18, 4, 1));
    expect(blitz.timing.mode, TeacherBlitzTimerStartMode.synchronized);
    expect(blitz.timing.synchronizedEndsAt, DateTime.utc(2026, 9, 18, 4, 11));
    expect(blitz.timing.serverNow, DateTime.utc(2026, 9, 18, 4, 5));
    expect(monitoring.summary.assigned, 3);
    expect(monitoring.summary.notStarted, 1);
    expect(monitoring.summary.inProgress, 1);
    expect(monitoring.summary.finalized, 1);
    expect(monitoring.summary.waitingForTeacherReview, 0);
    expect(monitoring.summary.attemptExceptionsGranted, 0);
    expect(monitoring.students.map((row) => row.student.fullName), [
      'Aziza',
      'Bobur',
      'Dilnoza',
    ]);

    final notStarted = monitoring.students[0];
    expect(notStarted.status, TeacherBlitzMonitoringStudentStatus.notStarted);
    expect(notStarted.attemptNumber, isNull);
    expect(notStarted.remainingSeconds, 360);
    final inProgress = monitoring.students[1];
    expect(inProgress.status, TeacherBlitzMonitoringStudentStatus.inProgress);
    expect(inProgress.attemptNumber, 1);
    expect(inProgress.startedAt, DateTime.utc(2026, 9, 18, 4, 2));
    expect(inProgress.deadlineAt, DateTime.utc(2026, 9, 18, 4, 11));
    expect(inProgress.remainingSeconds, 360);
    final finalized = monitoring.students[2];
    expect(finalized.status, TeacherBlitzMonitoringStudentStatus.finalized);
    expect(finalized.remainingSeconds, 0);
    expect(
      finalized.finalizationReason,
      TeacherBlitzMonitoringFinalizationReason.studentSubmit,
    );
    expect(finalized.isGrantCandidate, isTrue);
  });

  test('parses an individual snapshot and an empty roster', () {
    final monitoring = _parse(
      monitoringJson(
        blitz: monitoringBlitzJson(
          mode: 'individual',
          synchronizedEndsAt: null,
        ),
        students: [
          notStartedRowJson(monitoringStudentA, remainingSeconds: null),
        ],
      ),
    );
    expect(monitoring.blitz.timing.mode, TeacherBlitzTimerStartMode.individual);
    expect(monitoring.blitz.timing.synchronizedEndsAt, isNull);
    expect(monitoring.students.single.remainingSeconds, isNull);

    final empty = _parse(monitoringJson(students: []));
    expect(empty.students, isEmpty);
    expect(empty.summary.assigned, 0);
  });

  test('a synchronized not-started row may show zero class time', () {
    final monitoring = _parse(
      monitoringJson(
        students: [notStartedRowJson(monitoringStudentA, remainingSeconds: 0)],
      ),
    );
    expect(monitoring.students.single.remainingSeconds, 0);
  });

  test('parses the reason-for-review and all finalization reasons', () {
    final monitoring = _parse(
      monitoringJson(
        students: [
          terminalRowJson(
            monitoringStudentA,
            status: 'waiting_for_teacher_review',
            finalizationReason: 'timeout_auto_submit',
          ),
          terminalRowJson(
            monitoringStudentB,
            finalizationReason: 'task_closed_auto_finalize',
          ),
        ],
      ),
    );
    expect(
      monitoring.students[0].status,
      TeacherBlitzMonitoringStudentStatus.waitingForTeacherReview,
    );
    expect(
      monitoring.students[0].finalizationReason,
      TeacherBlitzMonitoringFinalizationReason.timeout,
    );
    expect(monitoring.students[0].isGrantCandidate, isTrue);
    expect(
      monitoring.students[1].finalizationReason,
      TeacherBlitzMonitoringFinalizationReason.taskClosed,
    );
  });

  test('an unused exception makes the current replacement not started', () {
    final monitoring = _parse(
      monitoringJson(
        students: [
          notStartedRowJson(
            monitoringStudentA,
            remainingSeconds: null,
            attemptException: monitoringExceptionJson(
              reasonType: 'other_valid',
              reason: 'Excused absence.',
            ),
          ),
        ],
      ),
    );
    final row = monitoring.students.single;
    expect(row.status, TeacherBlitzMonitoringStudentStatus.notStarted);
    expect(row.attemptNumber, isNull);
    expect(row.isGrantCandidate, isFalse);
    final exception = row.attemptException!;
    expect(exception.id, monitoringExceptionId);
    expect(exception.invalidatedAttemptId, monitoringAttemptOne);
    expect(exception.replacementAttemptId, isNull);
    expect(
      exception.reasonType,
      TeacherBlitzAttemptExceptionReasonType.otherValid,
    );
    expect(exception.reason, 'Excused absence.');
    expect(exception.grantedAt, DateTime.utc(2026, 9, 18, 4, 6));
    expect(exception.replacementAttemptAvailable, isTrue);
    expect(monitoring.summary.attemptExceptionsGranted, 1);
  });

  test('Attempt #2 in progress or finalized carries its exception', () {
    final exception = monitoringExceptionJson(
      replacementAttemptId: monitoringAttemptTwo,
    );
    final monitoring = _parse(
      monitoringJson(
        students: [
          inProgressRowJson(
            monitoringStudentA,
            attemptNumber: 2,
            attemptException: exception,
          ),
          terminalRowJson(
            monitoringStudentB,
            attemptNumber: 2,
            attemptException: {
              ...exception,
              'id': 'a3000000-0000-0000-0000-000000000002',
            },
          ),
        ],
      ),
    );
    expect(monitoring.students[0].attemptNumber, 2);
    expect(monitoring.students[0].isGrantCandidate, isFalse);
    expect(
      monitoring.students[1].attemptException!.replacementAttemptId,
      monitoringAttemptTwo,
    );
    expect(monitoring.students[1].isGrantCandidate, isFalse);
  });

  group('rejects', () {
    final invalid = <String, Object?>{
      'a non-null score': monitoringJson(
        students: [
          {...terminalRowJson(monitoringStudentA), 'score': 5},
        ],
      ),
      'a summary that does not partition assigned': monitoringJson(
        students: [notStartedRowJson(monitoringStudentA)],
        summary: {
          'assigned': 1,
          'not_started': 0,
          'in_progress': 1,
          'finalized': 0,
          'waiting_for_teacher_review': 0,
          'attempt_exceptions_granted': 0,
        },
      ),
      'row counts that disagree with the summary': monitoringJson(
        students: [notStartedRowJson(monitoringStudentA)],
        summary: {
          'assigned': 2,
          'not_started': 2,
          'in_progress': 0,
          'finalized': 0,
          'waiting_for_teacher_review': 0,
          'attempt_exceptions_granted': 0,
        },
      ),
      'a wrong exception count': monitoringJson(
        students: [notStartedRowJson(monitoringStudentA)],
        summary: {
          'assigned': 1,
          'not_started': 1,
          'in_progress': 0,
          'finalized': 0,
          'waiting_for_teacher_review': 0,
          'attempt_exceptions_granted': 1,
        },
      ),
      'a duplicate Student': monitoringJson(
        students: [
          notStartedRowJson(monitoringStudentA),
          notStartedRowJson(monitoringStudentA),
        ],
      ),
      'Attempt #2 without an exception': monitoringJson(
        students: [inProgressRowJson(monitoringStudentA, attemptNumber: 2)],
      ),
      'Attempt #2 with an unused exception': monitoringJson(
        students: [
          terminalRowJson(
            monitoringStudentA,
            attemptNumber: 2,
            attemptException: monitoringExceptionJson(),
          ),
        ],
      ),
      'Attempt #1 with a started replacement': monitoringJson(
        students: [
          terminalRowJson(
            monitoringStudentA,
            attemptException: monitoringExceptionJson(
              replacementAttemptId: monitoringAttemptTwo,
            ),
          ),
        ],
      ),
      'an unused exception that is not available': monitoringJson(
        students: [
          notStartedRowJson(
            monitoringStudentA,
            remainingSeconds: null,
            attemptException: monitoringExceptionJson(
              replacementAttemptAvailable: false,
            ),
          ),
        ],
      ),
      'a started replacement that is still available': monitoringJson(
        students: [
          inProgressRowJson(
            monitoringStudentA,
            attemptNumber: 2,
            attemptException: monitoringExceptionJson(
              replacementAttemptId: monitoringAttemptTwo,
              replacementAttemptAvailable: true,
            ),
          ),
        ],
      ),
      'an unused replacement with class time': monitoringJson(
        students: [
          notStartedRowJson(
            monitoringStudentA,
            attemptException: monitoringExceptionJson(),
          ),
        ],
      ),
      'a Homework finalization reason': monitoringJson(
        students: [
          terminalRowJson(
            monitoringStudentA,
            finalizationReason: 'homework_deadline_auto_submit',
          ),
        ],
      ),
      'a not-started row with Attempt data': monitoringJson(
        students: [
          {...notStartedRowJson(monitoringStudentA), 'attempt_number': 1},
        ],
      ),
      'an in-progress row without a deadline': monitoringJson(
        students: [
          {...inProgressRowJson(monitoringStudentA), 'deadline_at': null},
        ],
      ),
      'an in-progress row with a finalization reason': monitoringJson(
        students: [
          {
            ...inProgressRowJson(monitoringStudentA),
            'finalization_reason': 'student_submit',
          },
        ],
      ),
      'a finalized row with remaining time': monitoringJson(
        students: [
          {...terminalRowJson(monitoringStudentA), 'remaining_seconds': 5},
        ],
      ),
      'a finalized row without a reason': monitoringJson(
        students: [
          {...terminalRowJson(monitoringStudentA), 'finalization_reason': null},
        ],
      ),
      'an Attempt number other than 1 or 2': monitoringJson(
        students: [inProgressRowJson(monitoringStudentA, attemptNumber: 3)],
      ),
      'an unknown row status': monitoringJson(
        students: [monitoringRowJson(monitoringStudentA, status: 'checked')],
      ),
      'a blank Student name': monitoringJson(
        students: [notStartedRowJson(monitoringStudentA, fullName: '  ')],
      ),
      'extra Student identity data': monitoringJson(
        students: [
          {
            ...notStartedRowJson(monitoringStudentA),
            'student': {
              'id': monitoringStudentA,
              'full_name': 'A',
              'email': 'a@example.test',
            },
          },
        ],
      ),
      'a Blitz that is not active': monitoringJson(
        blitz: monitoringBlitzJson(status: 'closed'),
      ),
      'a synchronized Blitz without a common end': monitoringJson(
        blitz: monitoringBlitzJson(synchronizedEndsAt: null),
      ),
      'an individual Blitz with a common end': monitoringJson(
        blitz: monitoringBlitzJson(mode: 'individual'),
        students: [
          notStartedRowJson(monitoringStudentA, remainingSeconds: null),
        ],
      ),
      'an individual not-started row with class time': monitoringJson(
        blitz: monitoringBlitzJson(
          mode: 'individual',
          synchronizedEndsAt: null,
        ),
        students: [
          notStartedRowJson(monitoringStudentA, remainingSeconds: 300),
        ],
      ),
      'a zero duration': monitoringJson(
        blitz: monitoringBlitzJson(durationSeconds: 0),
      ),
      'a fractional activation time': monitoringJson(
        blitz: monitoringBlitzJson(activatedAt: '2026-09-18T04:01:00.5Z'),
      ),
      'an unknown top-level key': {
        ...monitoringJson(),
        'message': 'Monitoring loaded.',
      },
      'an unknown data key': {
        'data': {
          ...(monitoringJson()['data']! as Map<String, Object?>),
          'meta': null,
        },
      },
      'a missing summary': {
        'data': {'blitz': monitoringBlitzJson(), 'students': <Object?>[]},
      },
      'an over-long exception reason': monitoringJson(
        students: [
          notStartedRowJson(
            monitoringStudentA,
            remainingSeconds: null,
            attemptException: monitoringExceptionJson(reason: 'x' * 4001),
          ),
        ],
      ),
    };
    invalid.forEach((name, json) {
      test(name, () {
        expect(() => _parse(json), throwsFormatException);
      });
    });
  });
}
