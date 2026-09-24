import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_blitz_dto.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';

import 'teacher_blitz_json_fixtures.dart';

void main() {
  group('Teacher Blitz enums', () {
    test('map exact machine values and reject unsupported values', () {
      expect(TeacherBlitzStatus.values.map((status) => status.value), [
        'draft',
        'scheduled',
        'active',
        'closed',
        'archived',
      ]);
      for (final status in TeacherBlitzStatus.values) {
        expect(TeacherBlitzStatus.parse(status.value), status);
      }
      expect(TeacherBlitzAssignmentMode.values.map((mode) => mode.value), [
        'group',
        'selected_students',
      ]);
      for (final mode in TeacherBlitzAssignmentMode.values) {
        expect(TeacherBlitzAssignmentMode.parse(mode.value), mode);
      }
      expect(TeacherBlitzTimerStartMode.values.map((mode) => mode.value), [
        'synchronized',
        'individual',
      ]);
      for (final mode in TeacherBlitzTimerStartMode.values) {
        expect(TeacherBlitzTimerStartMode.parse(mode.value), mode);
      }

      for (final parse in <Object Function(String)>[
        TeacherBlitzStatus.parse,
        TeacherBlitzAssignmentMode.parse,
        TeacherBlitzTimerStartMode.parse,
      ]) {
        for (final invalid in ['', 'Draft', 'GROUP', 'Synchronized', 'other']) {
          expect(() => parse(invalid), throwsFormatException);
        }
      }
    });
  });

  group('Teacher Blitz summary DTO', () {
    test('parses exact Draft and Scheduled rows into domain', () {
      final draft = TeacherBlitzSummaryDto.fromJson(
        teacherBlitzSummaryJson(),
      ).toDomain();

      expect(draft.id, blitzJsonId);
      expect(draft.topicId, blitzJsonTopicId);
      expect(draft.groupId, blitzJsonGroupId);
      expect(draft.title, 'Equation Blitz');
      expect(draft.assignmentMode, TeacherBlitzAssignmentMode.group);
      expect(draft.totalPossiblePoints, 18.5);
      expect(draft.questionCount, 9);
      expect(draft.durationSeconds, blitzJsonDurationSeconds);
      expect(draft.scheduledAt, isNull);
      expect(draft.institutionTimezone, 'Asia/Tashkent');
      expect(draft.status, TeacherBlitzStatus.draft);
      expect(draft.createdAt, DateTime.utc(2026, 9, 17, 10));
      expect(draft.updatedAt, DateTime.utc(2026, 9, 17, 11));

      final scheduled = TeacherBlitzSummaryDto.fromJson(
        teacherBlitzSummaryJson(
          status: 'scheduled',
          scheduledAt: '2026-09-18T04:00:00.123456Z',
        )..['assignment_mode'] = 'selected_students',
      ).toDomain();

      expect(scheduled.status, TeacherBlitzStatus.scheduled);
      expect(
        scheduled.assignmentMode,
        TeacherBlitzAssignmentMode.selectedStudents,
      );
      expect(
        scheduled.scheduledAt,
        DateTime.utc(2026, 9, 18, 4, 0, 0, 123, 456),
      );
    });

    test('parses every status machine value', () {
      for (final status in TeacherBlitzStatus.values) {
        final summary = TeacherBlitzSummaryDto.fromJson(
          teacherBlitzSummaryJson(status: status.value),
        ).toDomain();
        expect(summary.status, status);
      }
    });

    test('rejects unknown, missing, and malformed identity fields', () {
      final unknown = teacherBlitzSummaryJson()..['deadline_at'] = null;
      final missing = teacherBlitzSummaryJson()..remove('group_id');
      final cases = <Map<String, Object?>>[
        unknown,
        missing,
        for (final key in ['id', 'topic_id', 'group_id']) ...[
          teacherBlitzSummaryJson()..[key] = 'not-a-uuid',
          teacherBlitzSummaryJson()..[key] = ' $blitzJsonId',
          teacherBlitzSummaryJson()..[key] = null,
        ],
        teacherBlitzSummaryJson()..['title'] = '   ',
        teacherBlitzSummaryJson()..['institution_timezone'] = '',
        teacherBlitzSummaryJson()..['status'] = 'running',
        teacherBlitzSummaryJson()..['assignment_mode'] = 'everyone',
        teacherBlitzSummaryJson()..['created_at'] = '2026-09-17 10:00:00',
        teacherBlitzSummaryJson()..['updated_at'] = null,
        teacherBlitzSummaryJson()..['scheduled_at'] = '2026-09-18T04:00:00',
      ];

      for (final json in cases) {
        expect(
          () => TeacherBlitzSummaryDto.fromJson(json),
          throwsFormatException,
        );
      }
    });

    test('requires non-negative points and counts plus positive duration', () {
      final cases = <Map<String, Object?>>[
        teacherBlitzSummaryJson()..['total_possible_points'] = -0.5,
        teacherBlitzSummaryJson()..['total_possible_points'] = '18.5',
        teacherBlitzSummaryJson()..['total_possible_points'] = null,
        teacherBlitzSummaryJson()..['question_count'] = -1,
        teacherBlitzSummaryJson()..['question_count'] = 1.5,
        teacherBlitzSummaryJson()..['duration_seconds'] = 0,
        teacherBlitzSummaryJson()..['duration_seconds'] = -60,
        teacherBlitzSummaryJson()..['duration_seconds'] = 60.5,
        teacherBlitzSummaryJson()..['duration_seconds'] = '600',
        teacherBlitzSummaryJson()..['duration_seconds'] = 1e20,
      ];

      for (final json in cases) {
        expect(
          () => TeacherBlitzSummaryDto.fromJson(json),
          throwsFormatException,
        );
      }

      final zeroCounts = TeacherBlitzSummaryDto.fromJson(
        teacherBlitzSummaryJson()
          ..['total_possible_points'] = 0
          ..['question_count'] = 0
          ..['duration_seconds'] = 1,
      ).toDomain();
      expect(zeroCounts.totalPossiblePoints, 0);
      expect(zeroCounts.questionCount, 0);
      expect(zeroCounts.durationSeconds, 1);
    });

    test('requires the requested Topic case-insensitively', () {
      final matching = TeacherBlitzSummaryDto.fromJson(
        teacherBlitzSummaryJson(),
        expectedTopicId: blitzJsonTopicId.toUpperCase(),
      );
      expect(matching.topicId, blitzJsonTopicId);

      expect(
        () => TeacherBlitzSummaryDto.fromJson(
          teacherBlitzSummaryJson(
            topicId: '10000000-0000-0000-0000-000000000002',
          ),
          expectedTopicId: blitzJsonTopicId,
        ),
        throwsFormatException,
      );
    });
  });

  group('Teacher Blitz resource DTO', () {
    test('parses a Draft with null, whole-second, or fractional schedule', () {
      final unscheduled = _parse(teacherBlitzJson());
      expect(unscheduled.status, TeacherBlitzStatus.draft);
      expect(unscheduled.scheduledAt, isNull);
      expect(unscheduled.timerStartModeSnapshot, isNull);
      expect(unscheduled.activatedAt, isNull);
      expect(unscheduled.synchronizedEndsAt, isNull);
      expect(unscheduled.closedAt, isNull);
      expect(unscheduled.archivedAt, isNull);

      final scheduled = _parse(
        teacherBlitzJson()..['scheduled_at'] = blitzJsonScheduledAt,
      );
      expect(scheduled.scheduledAt, DateTime.utc(2026, 9, 18, 4));

      final fractional = _parse(
        teacherBlitzJson()..['scheduled_at'] = '2026-09-18T04:00:00.123456Z',
      );
      expect(
        fractional.scheduledAt,
        DateTime.utc(2026, 9, 18, 4, 0, 0, 123, 456),
      );
    });

    test('maps every field of the exact resource into domain', () {
      final blitz = _parse(
        teacherBlitzJson(status: TeacherBlitzStatus.active)
          ..['description'] = 'Short timed review.',
      );

      expect(blitz.id, blitzJsonId);
      expect(blitz.topicId, blitzJsonTopicId);
      expect(blitz.groupId, blitzJsonGroupId);
      expect(blitz.title, 'Equation Blitz');
      expect(blitz.description, 'Short timed review.');
      expect(blitz.studentInstructions, 'Answer quickly and carefully.');
      expect(blitz.assignmentMode, TeacherBlitzAssignmentMode.group);
      expect(blitz.studentIds, isEmpty);
      expect(blitz.totalPossiblePoints, 18.5);
      expect(blitz.durationSeconds, blitzJsonDurationSeconds);
      expect(blitz.scheduledAt, DateTime.utc(2026, 9, 18, 4));
      expect(blitz.institutionTimezone, 'Asia/Tashkent');
      expect(blitz.status, TeacherBlitzStatus.active);
      expect(
        blitz.timerStartModeSnapshot,
        TeacherBlitzTimerStartMode.synchronized,
      );
      expect(blitz.attemptPolicy.normalAttempts, 1);
      expect(blitz.attemptPolicy.maxAdditionalExceptionAttempts, 1);
      expect(blitz.activatedAt, DateTime.utc(2026, 9, 18, 4, 1));
      expect(blitz.synchronizedEndsAt, DateTime.utc(2026, 9, 18, 4, 11));
      expect(blitz.closedAt, isNull);
      expect(blitz.archivedAt, isNull);
      expect(blitz.createdAt, DateTime.utc(2026, 9, 17, 10));
      expect(blitz.updatedAt, DateTime.utc(2026, 9, 17, 11));
      expect(blitz.questions, hasLength(9));
      expect(() => blitz.studentIds.add('x'), throwsUnsupportedError);
      expect(() => blitz.questions.clear(), throwsUnsupportedError);
    });

    test('parses every canonical lifecycle and timer shape', () {
      final scheduled = _parse(
        teacherBlitzJson(status: TeacherBlitzStatus.scheduled),
      );
      expect(scheduled.status, TeacherBlitzStatus.scheduled);
      expect(scheduled.timerStartModeSnapshot, isNull);

      for (final mode in TeacherBlitzTimerStartMode.values) {
        for (final status in [
          TeacherBlitzStatus.active,
          TeacherBlitzStatus.closed,
          TeacherBlitzStatus.archived,
        ]) {
          final blitz = _parse(
            teacherBlitzJson(status: status, timerMode: mode),
          );
          expect(blitz.status, status);
          expect(blitz.timerStartModeSnapshot, mode);
          expect(blitz.activatedAt, DateTime.utc(2026, 9, 18, 4, 1));
          expect(
            blitz.synchronizedEndsAt,
            mode == TeacherBlitzTimerStartMode.synchronized
                ? DateTime.utc(2026, 9, 18, 4, 11)
                : isNull,
          );
          expect(
            blitz.closedAt,
            status == TeacherBlitzStatus.active
                ? isNull
                : DateTime.utc(2026, 9, 18, 4, 12),
          );
        }
      }

      final preactivationArchive = _parse(
        teacherBlitzJson(
          status: TeacherBlitzStatus.archived,
          archivedBeforeActivation: true,
        ),
      );
      expect(preactivationArchive.activatedAt, isNull);
      expect(preactivationArchive.timerStartModeSnapshot, isNull);
      expect(preactivationArchive.closedAt, isNull);
      expect(preactivationArchive.archivedAt, DateTime.utc(2026, 9, 18, 5));

      final unscheduledArchive = _parse(
        teacherBlitzJson(
          status: TeacherBlitzStatus.archived,
          archivedBeforeActivation: true,
        )..['scheduled_at'] = null,
      );
      expect(unscheduledArchive.scheduledAt, isNull);
    });

    test('accepts close before or after the synchronized common end', () {
      final closedEarly = _parse(
        teacherBlitzJson(status: TeacherBlitzStatus.closed)
          ..['closed_at'] = '2026-09-18T04:05:00Z',
      );
      expect(closedEarly.closedAt, DateTime.utc(2026, 9, 18, 4, 5));

      final closedAtActivation = _parse(
        teacherBlitzJson(status: TeacherBlitzStatus.closed)
          ..['closed_at'] = blitzJsonActivatedAt,
      );
      expect(closedAtActivation.closedAt, closedAtActivation.activatedAt);
    });

    test('requires the synchronized end to equal activation plus duration', () {
      final longDuration = _parse(
        teacherBlitzJson(status: TeacherBlitzStatus.active)
          ..['duration_seconds'] = 3661
          ..['synchronized_ends_at'] = '2026-09-18T05:02:01Z',
      );
      expect(longDuration.durationSeconds, 3661);

      for (final end in [
        '2026-09-18T04:11:01Z',
        '2026-09-18T04:10:59Z',
        '2026-09-18T04:11:00.000001Z',
        blitzJsonActivatedAt,
      ]) {
        expect(
          () => TeacherBlitzDto.fromJson(
            teacherBlitzJson(status: TeacherBlitzStatus.active)
              ..['synchronized_ends_at'] = end,
          ),
          throwsFormatException,
        );
      }
    });

    test('rejects lifecycle timestamps that contradict the status', () {
      Map<String, Object?> json(TeacherBlitzStatus status) =>
          teacherBlitzJson(status: status);
      final cases = <Map<String, Object?>>[
        json(TeacherBlitzStatus.draft)..['activated_at'] = blitzJsonActivatedAt,
        json(TeacherBlitzStatus.draft)..['closed_at'] = blitzJsonClosedAt,
        json(TeacherBlitzStatus.draft)..['archived_at'] = blitzJsonArchivedAt,
        json(TeacherBlitzStatus.scheduled)..['scheduled_at'] = null,
        json(TeacherBlitzStatus.scheduled)
          ..['activated_at'] = blitzJsonActivatedAt,
        json(TeacherBlitzStatus.scheduled)..['closed_at'] = blitzJsonClosedAt,
        json(TeacherBlitzStatus.active)..['activated_at'] = null,
        json(TeacherBlitzStatus.active)..['closed_at'] = blitzJsonClosedAt,
        json(TeacherBlitzStatus.active)..['archived_at'] = blitzJsonArchivedAt,
        json(TeacherBlitzStatus.closed)..['closed_at'] = null,
        json(TeacherBlitzStatus.closed)..['activated_at'] = null,
        json(TeacherBlitzStatus.closed)..['archived_at'] = blitzJsonArchivedAt,
        json(TeacherBlitzStatus.closed)..['closed_at'] = '2026-09-18T04:00:59Z',
        json(TeacherBlitzStatus.archived)..['archived_at'] = null,
        json(TeacherBlitzStatus.archived)..['closed_at'] = null,
        json(TeacherBlitzStatus.archived)
          ..['archived_at'] = '2026-09-18T04:11:59Z',
        json(TeacherBlitzStatus.archived)
          ..['closed_at'] = '2026-09-18T04:00:59Z'
          ..['archived_at'] = '2026-09-18T04:00:59Z',
        teacherBlitzJson(
          status: TeacherBlitzStatus.archived,
          archivedBeforeActivation: true,
        )..['closed_at'] = blitzJsonClosedAt,
      ];

      for (final invalid in cases) {
        expect(() => TeacherBlitzDto.fromJson(invalid), throwsFormatException);
      }
    });

    test('rejects timer snapshots that contradict the lifecycle', () {
      Map<String, Object?> json(
        TeacherBlitzStatus status, {
        TeacherBlitzTimerStartMode mode =
            TeacherBlitzTimerStartMode.synchronized,
      }) => teacherBlitzJson(status: status, timerMode: mode);
      final cases = <Map<String, Object?>>[
        json(TeacherBlitzStatus.draft)
          ..['timer_start_mode_snapshot'] = 'synchronized',
        json(TeacherBlitzStatus.draft)
          ..['synchronized_ends_at'] = blitzJsonSynchronizedEndsAt,
        json(TeacherBlitzStatus.scheduled)
          ..['timer_start_mode_snapshot'] = 'individual',
        json(TeacherBlitzStatus.scheduled)
          ..['synchronized_ends_at'] = blitzJsonSynchronizedEndsAt,
        json(TeacherBlitzStatus.active)..['timer_start_mode_snapshot'] = null,
        json(TeacherBlitzStatus.active)..['synchronized_ends_at'] = null,
        json(
          TeacherBlitzStatus.active,
          mode: TeacherBlitzTimerStartMode.individual,
        )..['synchronized_ends_at'] = blitzJsonSynchronizedEndsAt,
        json(TeacherBlitzStatus.closed)..['synchronized_ends_at'] = null,
        json(
          TeacherBlitzStatus.closed,
          mode: TeacherBlitzTimerStartMode.individual,
        )..['synchronized_ends_at'] = blitzJsonSynchronizedEndsAt,
        json(TeacherBlitzStatus.archived)..['timer_start_mode_snapshot'] = null,
        json(TeacherBlitzStatus.archived)..['synchronized_ends_at'] = null,
        teacherBlitzJson(
          status: TeacherBlitzStatus.archived,
          archivedBeforeActivation: true,
        )..['timer_start_mode_snapshot'] = 'individual',
        teacherBlitzJson(
          status: TeacherBlitzStatus.archived,
          archivedBeforeActivation: true,
        )..['synchronized_ends_at'] = blitzJsonSynchronizedEndsAt,
        json(TeacherBlitzStatus.active)..['timer_start_mode_snapshot'] = 'solo',
        json(TeacherBlitzStatus.active)..['timer_start_mode_snapshot'] = 1,
      ];

      for (final invalid in cases) {
        expect(() => TeacherBlitzDto.fromJson(invalid), throwsFormatException);
      }
    });

    test('enforces the recipient assignment invariant', () {
      final selected = _parse(
        teacherBlitzJson()
          ..['assignment_mode'] = 'selected_students'
          ..['student_ids'] = [
            '30000000-0000-0000-0000-000000000001',
            '30000000-0000-0000-0000-00000000000a',
          ],
      );
      expect(
        selected.assignmentMode,
        TeacherBlitzAssignmentMode.selectedStudents,
      );
      expect(selected.studentIds, hasLength(2));

      final cases = <Map<String, Object?>>[
        teacherBlitzJson()
          ..['student_ids'] = ['30000000-0000-0000-0000-000000000001'],
        teacherBlitzJson()..['assignment_mode'] = 'selected_students',
        teacherBlitzJson()
          ..['assignment_mode'] = 'selected_students'
          ..['student_ids'] = ['not-a-uuid'],
        teacherBlitzJson()
          ..['assignment_mode'] = 'selected_students'
          ..['student_ids'] = [
            '30000000-0000-0000-0000-00000000000a',
            '30000000-0000-0000-0000-00000000000A',
          ],
        teacherBlitzJson()
          ..['assignment_mode'] = 'selected_students'
          ..['student_ids'] = [1],
        teacherBlitzJson()..['student_ids'] = null,
      ];

      for (final invalid in cases) {
        expect(() => TeacherBlitzDto.fromJson(invalid), throwsFormatException);
      }
    });

    test('requires the exact canonical attempt policy', () {
      for (final policy in <Object?>[
        {'normal_attempts': 2, 'max_additional_exception_attempts': 1},
        {'normal_attempts': 1, 'max_additional_exception_attempts': 0},
        {'normal_attempts': 1, 'max_additional_exception_attempts': 2},
        {'normal_attempts': '1', 'max_additional_exception_attempts': 1},
        {'normal_attempts': 1},
        {
          'normal_attempts': 1,
          'max_additional_exception_attempts': 1,
          'official_score_policy': 'highest_valid_completed',
        },
        null,
      ]) {
        expect(
          () => TeacherBlitzDto.fromJson(
            teacherBlitzJson()..['attempt_policy'] = policy,
          ),
          throwsFormatException,
        );
      }
    });

    test('requires positive whole-second duration', () {
      for (final duration in <Object?>[0, -1, 1.5, '600', null, 1e20]) {
        expect(
          () => TeacherBlitzDto.fromJson(
            teacherBlitzJson()..['duration_seconds'] = duration,
          ),
          throwsFormatException,
        );
      }
      expect(
        _parse(teacherBlitzJson()..['duration_seconds'] = 1).durationSeconds,
        1,
      );
      expect(
        _parse(teacherBlitzJson()..['duration_seconds'] = 7200).durationSeconds,
        7200,
      );
    });

    test('rejects unknown, missing, and malformed resource fields', () {
      final cases = <Map<String, Object?>>[
        teacherBlitzJson()..['deadline_at'] = null,
        teacherBlitzJson()..remove('group_id'),
        teacherBlitzJson()..remove('questions'),
        teacherBlitzJson()..['group_id'] = 'not-a-uuid',
        teacherBlitzJson()..['title'] = ' ',
        teacherBlitzJson()..['student_instructions'] = '',
        teacherBlitzJson()..['description'] = 3,
        teacherBlitzJson()..['total_possible_points'] = -1,
        teacherBlitzJson()..['institution_timezone'] = null,
        teacherBlitzJson()..['created_at'] = '2026-09-17T10:00:00+05:00',
      ];

      for (final invalid in cases) {
        expect(() => TeacherBlitzDto.fromJson(invalid), throwsFormatException);
      }
    });

    test('reuses every Question type through the Teacher Question DTO', () {
      final blitz = _parse(teacherBlitzJson());

      expect(
        blitz.questions.map((question) => question.type),
        TeacherQuestionType.values,
      );
      expect(
        blitz.questions.map((question) => question.position),
        List<int>.generate(9, (index) => index + 1),
      );
      expect(
        blitz.questions[6].configuration,
        isA<TeacherMatchingQuestionConfiguration>(),
      );
      expect(
        blitz.questions[8].configuration,
        isA<TeacherFillInBlankQuestionConfiguration>(),
      );

      final empty = _parse(teacherBlitzJson(questions: const []));
      expect(empty.questions, isEmpty);
    });

    test('rejects duplicate, gapped, out-of-order, or malformed Questions', () {
      final duplicate = teacherBlitzAllQuestionsJson();
      (duplicate[1]! as Map<String, Object?>)['id'] =
          (duplicate[0]! as Map<String, Object?>)['id']
              .toString()
              .toUpperCase();
      final gapped = teacherBlitzAllQuestionsJson();
      (gapped[1]! as Map<String, Object?>)['position'] = 3;
      final outOfOrder = teacherBlitzAllQuestionsJson();
      outOfOrder.insert(1, outOfOrder.removeAt(0));
      final malformed = teacherBlitzAllQuestionsJson();
      (malformed[0]! as Map<String, Object?>)['checking_mode'] = 'manual';

      for (final questions in [duplicate, gapped, outOfOrder, malformed]) {
        expect(
          () =>
              TeacherBlitzDto.fromJson(teacherBlitzJson(questions: questions)),
          throwsFormatException,
        );
      }
      expect(
        () => TeacherBlitzDto.fromJson(teacherBlitzJson()..['questions'] = {}),
        throwsFormatException,
      );
    });

    test('detail accepts exactly the top-level data envelope', () {
      final detail = TeacherBlitzDetailDto.fromJson({
        'data': teacherBlitzJson(),
      });
      expect(detail.blitz.id, blitzJsonId);

      for (final invalid in <Object?>[
        teacherBlitzJson(),
        {'data': teacherBlitzJson(), 'message': 'ok'},
        {'data': null},
        <Object?>[],
      ]) {
        expect(
          () => TeacherBlitzDetailDto.fromJson(invalid),
          throwsFormatException,
        );
      }
    });
  });
}

TeacherBlitz _parse(Map<String, Object?> json) {
  return TeacherBlitzDto.fromJson(json).toDomain();
}
