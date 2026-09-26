import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/data/dto/student_blitz_dto.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz.dart';

import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

void main() {
  group('active list', () {
    test('an exact empty envelope is an empty server list', () {
      expect(_list({'data': <Object?>[]}), isEmpty);
    });

    for (final scenario in [
      BlitzScenario.synchronizedNotStarted,
      BlitzScenario.synchronizedInProgress,
      BlitzScenario.individualNotStarted,
      BlitzScenario.individualInProgress,
      BlitzScenario.synchronizedReplacementAvailable,
      BlitzScenario.synchronizedReplacementInProgress,
      BlitzScenario.individualReplacementAvailable,
    ]) {
      test('accepts the delivered ${scenario.name} shape', () {
        final item = _list({
          'data': [activeBlitzJson(scenario: scenario)],
        }).single;
        final (timing, attempts) = blitzScenarioJson(scenario);
        expect(item.id, studentBlitzId);
        expect(item.topic.id, studentTopicId);
        expect(item.topic.title, 'Internet Basics');
        expect(item.title, 'Classroom Blitz');
        expect(item.status, StudentBlitzStatus.active);
        expect(item.durationSeconds, 600);
        expect(item.timing.mode.apiValue, timing['mode']);
        expect(item.timing.remainingSeconds, timing['remaining_seconds']);
        expect(
          item.timing.deadlineAt,
          _instant(timing['deadline_at'] as String?),
        );
        expect(
          item.timing.synchronizedEndsAt,
          _instant(timing['synchronized_ends_at'] as String?),
        );
        expect(item.timing.serverNow, _instant(timing['server_now'] as String));
        expect(item.attempts.normalAttempts, 1);
        expect(item.attempts.normalUsed, attempts['normal_used']);
        expect(
          item.attempts.inProgressAttemptId,
          attempts['in_progress_attempt_id'],
        );
        expect(
          item.attempts.additionalExceptionGranted,
          attempts['additional_exception_granted'],
        );
        expect(
          item.attempts.replacementAttemptAvailable,
          attempts['replacement_attempt_available'],
        );
      });
    }

    test('server order is preserved and duplicate Blitz IDs are rejected', () {
      final items = _list({
        'data': [activeBlitzJson(id: otherStudentBlitzId), activeBlitzJson()],
      });
      expect(items.map((item) => item.id), [
        otherStudentBlitzId,
        studentBlitzId,
      ]);
      _rejectList({
        'data': [
          activeBlitzJson(),
          activeBlitzJson(id: studentBlitzId.toUpperCase()),
        ],
      });
    });

    test('unknown or missing envelope and item keys are rejected', () {
      _rejectList(<String, Object?>{});
      _rejectList({'data': <Object?>[], 'meta': <String, Object?>{}});
      _rejectList({'data': <Object?>[], 'links': <String, Object?>{}});
      _rejectList({'data': <String, Object?>{}});
      for (final key in activeBlitzJson().keys) {
        _rejectList({
          'data': [activeBlitzJson()..remove(key)],
        });
      }
      for (final leak in ['questions', 'answers', 'description']) {
        _rejectList({
          'data': [activeBlitzJson()..[leak] = <Object?>[]],
        });
      }
    });

    test('only an active status and a positive duration are accepted', () {
      for (final status in ['closed', 'draft', 'scheduled', 'archived', null]) {
        _rejectList({
          'data': [activeBlitzJson()..['status'] = status],
        });
      }
      for (final duration in [0, -1, 1.5, '600', null]) {
        _rejectList({
          'data': [activeBlitzJson()..['duration_seconds'] = duration],
        });
      }
    });
  });

  group('attempt summary', () {
    for (final (name, attempts) in [
      ('two normal attempts', blitzAttemptsJson()..['normal_attempts'] = 2),
      ('normal used above one', blitzAttemptsJson(normalUsed: 2)),
      (
        'unused normal with an in-progress Attempt',
        blitzAttemptsJson(inProgressAttemptId: studentBlitzAttemptId),
      ),
      (
        'unused normal with an exception',
        blitzAttemptsJson(exceptionGranted: true),
      ),
      (
        'replacement without an exception',
        blitzAttemptsJson(normalUsed: 1, replacementAvailable: true),
      ),
      (
        'replacement with an in-progress Attempt',
        blitzAttemptsJson(
          normalUsed: 1,
          inProgressAttemptId: studentBlitzAttemptId,
          exceptionGranted: true,
          replacementAvailable: true,
        ),
      ),
      (
        'non-canonical in-progress Attempt ID',
        blitzAttemptsJson(normalUsed: 1, inProgressAttemptId: 'attempt-1'),
      ),
      (
        'non-boolean exception flag',
        blitzAttemptsJson()..['additional_exception_granted'] = 0,
      ),
      ('unknown summary key', blitzAttemptsJson()..['normal_limit'] = 1),
    ]) {
      test('rejects $name', () {
        _rejectDetail(blitzDetailJson()..['attempts'] = attempts);
      });
    }
  });

  group('timing integrity', () {
    test('canonical whole seconds must match the exact integer remaining', () {
      final detail = _detail(
        blitzDetailJson()
          ..['timing'] = blitzTimingJson(
            serverNow: '2026-09-17T12:04:59Z',
            remainingSeconds: 1,
          ),
      );
      expect(detail.timing.remainingSeconds, 1);
      for (final remaining in [0, 2, 299, -1]) {
        _rejectDetail(
          blitzDetailJson()
            ..['timing'] = blitzTimingJson(
              serverNow: '2026-09-17T12:04:59Z',
              remainingSeconds: remaining,
            ),
        );
      }
    });

    test('12:00:00Z to 12:10:00Z requires exactly 600 remaining seconds', () {
      final json = blitzDetailJson(
        scenario: BlitzScenario.individualInProgress,
      );
      expect(_detail(json).timing.remainingSeconds, 600);
      _rejectDetail(
        json
          ..['timing'] = {
            ...(json['timing']! as Map<String, Object?>),
            'remaining_seconds': 599,
          },
      );
    });

    for (final key in ['server_now', 'deadline_at', 'synchronized_ends_at']) {
      test('rejects fractional and non-Z $key strings', () {
        final base = blitzTimingJson();
        final value = base[key]! as String;
        for (final invalid in [
          value.replaceFirst('Z', '.500Z'),
          value.replaceFirst('Z', '+00:00'),
          value.replaceFirst('12:', '17:').replaceFirst('Z', '+05:00'),
          value.replaceFirst(':00Z', 'Z'),
          value.replaceFirst('T', ' '),
        ]) {
          _rejectDetail(
            blitzDetailJson()..['timing'] = {...base, key: invalid},
          );
        }
      });
    }

    for (final (name, timing) in [
      (
        'synchronized normal deadline other than the common end',
        blitzTimingJson(
          deadlineAt: '2026-09-17T12:06:00Z',
          remainingSeconds: 360,
        ),
      ),
      (
        'synchronized without a common end',
        blitzTimingJson(synchronizedEndsAt: null),
      ),
      (
        'synchronized not started without a deadline',
        blitzTimingJson(deadlineAt: null, remainingSeconds: null),
      ),
      (
        'deadline before the server clock',
        blitzTimingJson(serverNow: '2026-09-17T12:06:00Z', remainingSeconds: 0),
      ),
      (
        'deadline without remaining seconds',
        blitzTimingJson(remainingSeconds: null),
      ),
      ('unknown timer mode', blitzTimingJson(mode: 'manual')),
      ('unknown timing key', blitzTimingJson()..['ends_at'] = null),
    ]) {
      test('rejects $name', () {
        _rejectDetail(blitzDetailJson()..['timing'] = timing);
      });
    }

    test('individual pre-Start timing has no deadline or common end', () {
      final json = blitzDetailJson(
        scenario: BlitzScenario.individualNotStarted,
      );
      final timing = json['timing']! as Map<String, Object?>;
      _rejectDetail(
        blitzDetailJson(scenario: BlitzScenario.individualNotStarted)
          ..['timing'] = {
            ...timing,
            'deadline_at': '2026-09-17T12:10:00Z',
            'remaining_seconds': 600,
          },
      );
      _rejectDetail(
        blitzDetailJson(scenario: BlitzScenario.individualNotStarted)
          ..['timing'] = {
            ...timing,
            'synchronized_ends_at': '2026-09-17T12:10:00Z',
          },
      );
    });

    test('an in-progress Attempt requires its deadline', () {
      final json = blitzDetailJson(
        scenario: BlitzScenario.individualInProgress,
      );
      _rejectDetail(
        json
          ..['timing'] = {
            ...(json['timing']! as Map<String, Object?>),
            'deadline_at': null,
            'remaining_seconds': null,
          },
      );
    });

    test('an available replacement never carries an effective deadline', () {
      for (final scenario in [
        BlitzScenario.synchronizedReplacementAvailable,
        BlitzScenario.individualReplacementAvailable,
      ]) {
        final json = blitzDetailJson(scenario: scenario);
        _rejectDetail(
          json
            ..['timing'] = {
              ...(json['timing']! as Map<String, Object?>),
              'deadline_at': '2026-09-17T12:20:00Z',
              'remaining_seconds': 600,
            },
        );
      }
    });

    test('a replacement #2 deadline may pass the synchronized common end', () {
      final detail = _detail(
        blitzDetailJson(
          scenario: BlitzScenario.synchronizedReplacementInProgress,
        ),
      );
      expect(detail.timing.deadlineAt, DateTime.utc(2026, 9, 17, 12, 20));
      expect(
        detail.timing.synchronizedEndsAt,
        DateTime.utc(2026, 9, 17, 12, 5),
      );
    });

    // Revalidation 2026-09-26: a finished latest Attempt keeps a 200 detail.
    test('finished synchronized #1 has the common-end deadline and 0 left', () {
      final detail = _detail(
        blitzDetailJson()
          ..['timing'] = blitzTimingJson(remainingSeconds: 0)
          ..['attempts'] = blitzAttemptsJson(normalUsed: 1),
      );
      expect(detail.timing.deadlineAt, DateTime.utc(2026, 9, 17, 12, 5));
      expect(detail.timing.remainingSeconds, 0);
      expect(detail.attempts.isFinished, isTrue);
      _rejectDetail(
        blitzDetailJson()
          ..['timing'] = blitzTimingJson(
            deadlineAt: '2026-09-17T12:04:00Z',
            remainingSeconds: 0,
          )
          ..['attempts'] = blitzAttemptsJson(normalUsed: 1),
      );
    });

    test('finished individual deadline may be before the server clock', () {
      final detail = _detail(
        blitzDetailJson()
          ..['timing'] = blitzTimingJson(
            mode: 'individual',
            serverNow: '2026-09-17T13:00:00Z',
            synchronizedEndsAt: null,
            deadlineAt: '2026-09-17T12:10:00Z',
            remainingSeconds: 0,
          )
          ..['attempts'] = blitzAttemptsJson(normalUsed: 1),
      );
      expect(detail.timing.deadlineAt, DateTime.utc(2026, 9, 17, 12, 10));
      expect(detail.attempts.isFinished, isTrue);
    });

    test('finished #2 may end after the synchronized common end', () {
      final detail = _detail(
        blitzDetailJson()
          ..['timing'] = blitzTimingJson(
            serverNow: '2026-09-17T12:12:00Z',
            deadlineAt: '2026-09-17T12:20:00Z',
            remainingSeconds: 0,
          )
          ..['attempts'] = blitzAttemptsJson(
            normalUsed: 1,
            exceptionGranted: true,
          ),
      );
      expect(detail.timing.deadlineAt, DateTime.utc(2026, 9, 17, 12, 20));
    });

    test('finished summary requires a deadline and zero remaining', () {
      for (final timing in [
        blitzTimingJson(remainingSeconds: 300),
        blitzTimingJson(deadlineAt: null, remainingSeconds: null),
        blitzTimingJson(remainingSeconds: null),
        blitzTimingJson(
          mode: 'individual',
          synchronizedEndsAt: null,
          deadlineAt: null,
          remainingSeconds: 0,
        ),
      ]) {
        _rejectDetail(
          blitzDetailJson()
            ..['timing'] = timing
            ..['attempts'] = blitzAttemptsJson(normalUsed: 1),
        );
      }
    });
  });

  group('detail', () {
    for (final scenario in BlitzScenario.values) {
      test('accepts the delivered ${scenario.name} detail', () {
        final detail = _detail(blitzDetailJson(scenario: scenario));
        expect(detail.id, studentBlitzId);
        expect(detail.description, 'Timed practice.');
        expect(detail.studentInstructions, 'Answer independently.');
        expect(detail.totalPossiblePoints, 5);
        expect(detail.durationSeconds, 600);
      });
    }

    test(
      'description is nullable and points may be a whole or decimal number',
      () {
        final detail = _detail(
          blitzDetailJson()
            ..['description'] = null
            ..['total_possible_points'] = 2.5,
        );
        expect(detail.description, isNull);
        expect(detail.totalPossiblePoints, 2.5);
        expect(
          _detail(
            blitzDetailJson()..['total_possible_points'] = 0,
          ).totalPossiblePoints,
          0,
        );
        for (final points in [-1, '5', null]) {
          _rejectDetail(blitzDetailJson()..['total_possible_points'] = points);
        }
      },
    );

    test('exact keys reject missing fields and any Question leakage', () {
      for (final key in blitzDetailJson().keys) {
        _rejectDetail(blitzDetailJson()..remove(key));
      }
      for (final leak in ['questions', 'answer_ui', 'answers', 'is_correct']) {
        _rejectDetail(blitzDetailJson()..[leak] = <Object?>[]);
      }
    });

    test('Topic and text fields must be canonical and non-blank', () {
      for (final topic in [
        blitzTopicJson(id: 'topic-1'),
        blitzTopicJson(title: '  '),
        {...blitzTopicJson(), 'status': 'active'},
      ]) {
        _rejectDetail(blitzDetailJson()..['topic'] = topic);
      }
      for (final key in ['title', 'student_instructions']) {
        _rejectDetail(blitzDetailJson()..[key] = ' ');
      }
      _rejectDetail(blitzDetailJson()..['id'] = 'blitz-1');
      _rejectDetail(blitzDetailJson()..['status'] = 'closed');
    });
  });
}

List<StudentActiveBlitzSummary> _list(Object? json) =>
    StudentActiveBlitzListDto.fromJson(json).toDomain();

void _rejectList(Object? json) =>
    expect(() => _list(json), throwsFormatException);

StudentBlitzDetail _detail(Object? json) =>
    StudentBlitzDetailDto.fromJson(json).toDomain();

void _rejectDetail(Object? json) =>
    expect(() => _detail(json), throwsFormatException);

DateTime? _instant(String? value) =>
    value == null ? null : DateTime.parse(value);
