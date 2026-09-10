import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/data/dto/student_dto_parse.dart';
import 'package:testlabuz_client/features/student/data/dto/student_homework_dto.dart';
import 'package:testlabuz_client/features/student/data/dto/student_homework_list_dto.dart';
import 'package:testlabuz_client/features/student/data/dto/student_question_dto.dart';
import 'package:testlabuz_client/features/student/domain/student_homework.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list_query.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';

void main() {
  group('Homework list query', () {
    test('emits exact defaults and selected machine values without search', () {
      final query = StudentHomeworkListQuery(topicId: _topicId);
      expect(query.toQueryParameters(), {
        'topic_id': _topicId,
        'page': 1,
        'per_page': 20,
        'sort': 'created_at',
        'direction': 'desc',
      });
      for (final status in StudentHomeworkStatus.values) {
        final changed = query.withPage(3).withStatus(status);
        expect(changed.page, 1);
        expect(changed.toQueryParameters()['status'], status.apiValue);
        expect(changed.withStatus(null), query);
      }
      for (final sort in StudentHomeworkSort.values) {
        for (final direction in StudentHomeworkSortDirection.values) {
          final sorted = StudentHomeworkListQuery(
            topicId: _topicId,
            sort: sort,
            direction: direction,
            perPage: 100,
          );
          expect(sorted.toQueryParameters()['sort'], sort.apiValue);
          expect(sorted.toQueryParameters()['direction'], direction.apiValue);
          expect(sorted.toQueryParameters()['per_page'], 100);
        }
      }
      expect(query, StudentHomeworkListQuery(topicId: _topicId.toUpperCase()));
      expect(
        query.hashCode,
        StudentHomeworkListQuery(topicId: _topicId.toUpperCase()).hashCode,
      );
      expect(
        () => query.toQueryParameters()['search'] = 'x',
        throwsUnsupportedError,
      );
    });

    test('rejects invalid IDs and pagination before transport', () {
      for (final id in [
        '',
        'homework-id',
        '../topics',
        _topicId.replaceAll('-', ''),
        ' $_topicId',
      ]) {
        expect(
          () => StudentHomeworkListQuery(topicId: id),
          throwsArgumentError,
        );
        expect(isCanonicalStudentHomeworkId(id), isFalse);
        expect(isCanonicalStudentAttemptId(id), isFalse);
      }
      expect(isCanonicalStudentHomeworkId(_homeworkId), isTrue);
      expect(isCanonicalStudentAttemptId(_attemptId.toUpperCase()), isTrue);
      expect(
        () => StudentHomeworkListQuery(topicId: _topicId, page: 0),
        throwsArgumentError,
      );
      for (final perPage in [0, 101]) {
        expect(
          () => StudentHomeworkListQuery(topicId: _topicId, perPage: perPage),
          throwsArgumentError,
        );
      }
    });
  });

  group('Homework summary', () {
    for (final status in StudentHomeworkStatus.values) {
      for (final myStatus in StudentHomeworkMyStatus.values) {
        test(
          'accepts ${status.apiValue}/${myStatus.apiValue} and backend remaining',
          () {
            final payload = _summary(
              status: status.apiValue,
              myStatus: myStatus.apiValue,
            );
            final dto = StudentHomeworkSummaryDto.fromJson(payload);
            final summary = dto.toDomain();
            expect(summary.status, status);
            expect(summary.myStatus, myStatus);
            expect(summary.scoreVisible, isFalse);
            expect(summary.deadlineAt, DateTime.utc(2026, 9, 10, 13));
            expect(summary.attempts.allowed, 3);
            expect(
              summary.attempts.used,
              myStatus == StudentHomeworkMyStatus.notStarted ? 0 : 1,
            );
            expect(summary.attempts.remaining, 1);
            expect(summary.attempts.inProgressAttempt, isNull);
            expect(summary.topic.id, _topicId);
            payload['deadline_at'] = null;
            expect(
              StudentHomeworkSummaryDto.fromJson(payload).deadlineAt,
              isNull,
            );
          },
        );
      }
    }

    test(
      'rejects unsupported enums, score visibility and malformed primitive fields',
      () {
        for (final entry in <String, List<Object?>>{
          'status': ['draft', 'unknown', null, 1],
          'my_status': ['timed_out_finalized', 'unknown', null, 1],
          'score_visible': [true, null, 0, 'false'],
          'id': ['bad-id', null, 1],
          'title': ['', null, 1],
          'deadline_at': [1, false],
          'topic': [null, []],
          'attempts': [null, []],
        }.entries) {
          for (final invalid in entry.value) {
            expect(
              () => StudentHomeworkSummaryDto.fromJson(
                _summary()..[entry.key] = invalid,
              ),
              throwsFormatException,
              reason: '${entry.key}: $invalid',
            );
          }
        }
        final payload = _summary();
        (payload['topic']! as Map<String, Object?>)['id'] = 'bad-topic';
        expect(
          () => StudentHomeworkSummaryDto.fromJson(payload),
          throwsFormatException,
        );
      },
    );

    test('enforces every attempt count, policy and used/status invariant', () {
      for (final entry in <String, List<Object?>>{
        'allowed': [0, 2, 4, 3.0, '3'],
        'used': [-1, 4, 0, 1.0, '1'],
        'remaining': [-1, 4, 3, 1.0, '1'],
        'official_score_policy': ['latest', null, 1],
      }.entries) {
        for (final invalid in entry.value) {
          final payload = _summary();
          (payload['attempts']! as Map<String, Object?>)[entry.key] = invalid;
          expect(
            () => StudentHomeworkSummaryDto.fromJson(payload),
            throwsFormatException,
            reason: '${entry.key}: $invalid',
          );
        }
      }
      final notStartedWithUsed = _summary(myStatus: 'not_started');
      (notStartedWithUsed['attempts']! as Map<String, Object?>)['used'] = 1;
      expect(
        () => StudentHomeworkSummaryDto.fromJson(notStartedWithUsed),
        throwsFormatException,
      );
      final withDetailIdentity = _summary();
      (withDetailIdentity['attempts']!
              as Map<String, Object?>)['in_progress_attempt'] =
          null;
      expect(
        () => StudentHomeworkSummaryDto.fromJson(withDetailIdentity),
        throwsFormatException,
      );
    });

    test(
      'requires whole-second real UTC timestamps without tightening Topic parsing',
      () {
        for (final timestamp in [
          '2026-09-10T13:00Z',
          '2026-09-10T13:00:00.000Z',
          '2026-09-10T13:00:00,5Z',
          '2026-09-10T13:00:00+00:00',
          '2026-09-10T13:00:00',
          '2026-09-10 13:00:00Z',
          '2026-02-29T13:00:00Z',
          '2026-09-31T13:00:00Z',
          '2026-09-10T24:00:00Z',
          '2026-09-10T13:60:00Z',
          '2026-09-10T13:00:60Z',
        ]) {
          expect(
            () => StudentHomeworkSummaryDto.fromJson(
              _summary()..['deadline_at'] = timestamp,
            ),
            throwsFormatException,
            reason: timestamp,
          );
        }
        expect(
          StudentHomeworkSummaryDto.fromJson(
            _summary()..['deadline_at'] = '2024-02-29T13:00:00Z',
          ).deadlineAt,
          DateTime.utc(2024, 2, 29, 13),
        );
        expect(
          readStudentNullableUtcTimestamp({
            'lesson_at': '2026-09-10T13:00Z',
          }, 'lesson_at'),
          DateTime.utc(2026, 9, 10, 13),
        );
        expect(
          readStudentNullableUtcTimestamp({
            'lesson_at': '2026-09-10T13:00:00.125Z',
          }, 'lesson_at'),
          DateTime.utc(2026, 9, 10, 13, 0, 0, 125),
        );
      },
    );

    test('requires exact summary and nested keys', () {
      _expectExactKeys(_summary(), StudentHomeworkSummaryDto.fromJson);
    });

    test('accepts all bounded backend used and remaining combinations', () {
      for (var used = 0; used <= 3; used += 1) {
        for (var remaining = 0; remaining <= 3 - used; remaining += 1) {
          final payload = _summary(
            myStatus: used == 0 ? 'not_started' : 'submitted',
          );
          final attempts = payload['attempts']! as Map<String, Object?>;
          attempts['used'] = used;
          attempts['remaining'] = remaining;
          final parsed = StudentHomeworkSummaryDto.fromJson(payload).attempts;
          expect(parsed.used, used);
          expect(parsed.remaining, remaining);
        }
      }
    });
  });

  group('Homework list integrity', () {
    test(
      'accepts canonical case-insensitive Topic scope and immutable domain rows',
      () {
        final row = _summary();
        (row['topic']! as Map<String, Object?>)['id'] = _topicId.toUpperCase();
        final dto = _parseList(_list([row]));
        expect(dto.page, 1);
        expect(dto.perPage, 20);
        expect(dto.total, 1);
        expect(dto.lastPage, 1);
        final domain = dto.toDomain();
        expect(domain.items.single, isA<StudentHomeworkSummary>());
        expect(() => dto.items.clear(), throwsUnsupportedError);
        expect(() => domain.items.clear(), throwsUnsupportedError);
      },
    );

    test(
      'preserves server totals and established empty out-of-range convention',
      () {
        final empty = _parseList(
          _list([], page: 3, total: 21, lastPage: 2),
          page: 3,
        );
        expect(empty.page, 3);
        expect(empty.total, 21);
        expect(empty.lastPage, 2);
        expect(_parseList(_list([], total: 0)).lastPage, 1);
        expect(_parseList(_list([], page: 4, total: 0), page: 4).page, 4);
        expect(
          _parseList(_list([_summary()], perPage: 100), perPage: 100).perPage,
          100,
        );
      },
    );

    test(
      'rejects duplicate Homework IDs including case variants and wrong Topic',
      () {
        expect(
          () => _parseList(
            _list([
              _summary(),
              _summary()..['id'] = _homeworkId.toUpperCase(),
            ], total: 2),
          ),
          throwsFormatException,
        );
        final row = _summary();
        (row['topic']! as Map<String, Object?>)['id'] = _uuid(99);
        expect(() => _parseList(_list([row])), throwsFormatException);
      },
    );

    test(
      'rejects contradictory pagination, row counts and request identity',
      () {
        for (final entry in <String, List<Object?>>{
          'page': [0, 2, 1.0],
          'per_page': [0, 21, 101, 20.0],
          'total': [-1, 0, 1.0],
          'last_page': [0, 2, 1.0],
        }.entries) {
          for (final invalid in entry.value) {
            final payload = _list([_summary()]);
            ((payload['meta']! as Map)['pagination']! as Map)[entry.key] =
                invalid;
            expect(
              () => _parseList(payload),
              throwsFormatException,
              reason: '${entry.key}: $invalid',
            );
          }
        }
        expect(
          () => _parseList(_list([_summary()], page: 2), page: 2),
          throwsFormatException,
        );
        final rows = List.generate(
          21,
          (index) => _summary()..['id'] = _uuid(index + 100),
        );
        expect(
          () => _parseList(_list(rows, total: 21, lastPage: 2)),
          throwsFormatException,
        );
        expect(
          () => _parseList(_list([_summary(), _summary()..['id'] = _uuid(8)])),
          throwsFormatException,
        );
      },
    );

    test('requires exact envelope, pagination and nested row shapes', () {
      _expectExactKeys(_list([_summary()]), _parseList);
      for (final invalid in [
        null,
        [],
        1,
        {'data': [], 'meta': null},
      ]) {
        expect(() => _parseList(invalid), throwsFormatException);
      }
    });
  });

  group('Homework detail', () {
    test('accepts null or coherent in-progress Attempt and every status', () {
      for (final status in StudentHomeworkMyStatus.values) {
        final detail = StudentHomeworkDetailDto.fromJson(
          _detail(myStatus: status.apiValue),
        ).toDomain();
        expect(detail.myStatus, status);
        expect(detail.topic.id, _topicId);
        expect(detail.totalPossiblePoints, 10.0);
        expect(detail.questions, isEmpty);
        expect(
          detail.attempts.inProgressAttempt != null,
          status == StudentHomeworkMyStatus.inProgress,
        );
        if (detail.attempts.inProgressAttempt case final attempt?) {
          expect(attempt.id, _attemptId);
          expect(attempt.attemptNumber, 1);
          expect(attempt.startedAt, DateTime.utc(2026, 9, 8, 12));
          expect(attempt.startedAt.isUtc, isTrue);
        }
      }
    });

    test(
      'rejects inconsistent in-progress identity and impossible Attempt number',
      () {
        final inProgressWithoutAttempt = _detail(myStatus: 'in_progress');
        (inProgressWithoutAttempt['attempts']! as Map)['in_progress_attempt'] =
            null;
        expect(
          () => StudentHomeworkDetailDto.fromJson(inProgressWithoutAttempt),
          throwsFormatException,
        );
        for (final status in [
          'not_started',
          'submitted',
          'waiting_for_teacher_review',
          'checked',
        ]) {
          final payload = _detail(myStatus: status);
          (payload['attempts']! as Map)['in_progress_attempt'] = _attempt();
          expect(
            () => StudentHomeworkDetailDto.fromJson(payload),
            throwsFormatException,
            reason: status,
          );
        }
        for (final entry in <String, List<Object?>>{
          'attempt_number': [0, 2, 4, 1.0],
          'id': ['bad-attempt', null],
          'started_at': [
            null,
            '2026-09-08T12:00Z',
            '2026-09-08T12:00:00.0Z',
            '2026-09-08T12:00:00+00:00',
            '2026-02-30T12:00:00Z',
          ],
        }.entries) {
          for (final invalid in entry.value) {
            final payload = _detail(myStatus: 'in_progress');
            ((payload['attempts']! as Map)['in_progress_attempt']!
                    as Map)[entry.key] =
                invalid;
            expect(
              () => StudentHomeworkDetailDto.fromJson(payload),
              throwsFormatException,
              reason: '${entry.key}: $invalid',
            );
          }
        }
        final terminalWithoutUsed = _detail();
        (terminalWithoutUsed['attempts']! as Map)['used'] = 0;
        expect(
          () => StudentHomeworkDetailDto.fromJson(terminalWithoutUsed),
          throwsFormatException,
        );
      },
    );

    test('requires finite non-negative numeric points', () {
      for (final points in [0, 1, 1.25]) {
        final payload = _detail()..['total_possible_points'] = points;
        expect(
          StudentHomeworkDetailDto.fromJson(payload).totalPossiblePoints,
          points.toDouble(),
        );
        expect(
          StudentQuestionDto.fromJson(
            _question(StudentQuestionType.trueFalse)..['points'] = points,
          ).points,
          points.toDouble(),
        );
      }
      for (final points in [
        -1,
        double.nan,
        double.infinity,
        double.negativeInfinity,
        '1.0',
        null,
      ]) {
        expect(
          () => StudentHomeworkDetailDto.fromJson(
            _detail()..['total_possible_points'] = points,
          ),
          throwsFormatException,
        );
        expect(
          () => StudentQuestionDto.fromJson(
            _question(StudentQuestionType.trueFalse)..['points'] = points,
          ),
          throwsFormatException,
        );
      }
    });

    test(
      'requires unique Question IDs with ordered contiguous positions 1..N',
      () {
        final first = _question(StudentQuestionType.trueFalse);
        final second = _question(StudentQuestionType.openWritten, index: 2);
        final payload = _detail()..['questions'] = [first, second];
        final dto = StudentHomeworkDetailDto.fromJson(payload);
        expect(dto.questions.map((question) => question.position), [1, 2]);
        expect(() => dto.questions.clear(), throwsUnsupportedError);
        expect(() => dto.toDomain().questions.clear(), throwsUnsupportedError);
        for (final questions in [
          [
            first,
            {...second, 'id': first['id']},
          ],
          [
            first,
            {...second, 'position': 1},
          ],
          [
            first,
            {...second, 'position': 3},
          ],
          [second, first],
          [second],
        ]) {
          expect(
            () => StudentHomeworkDetailDto.fromJson(
              _detail()..['questions'] = questions,
            ),
            throwsFormatException,
          );
        }
      },
    );

    test(
      'requires exact detail and Attempt shapes without protected fields',
      () {
        _expectExactKeys(
          _detail(myStatus: 'in_progress'),
          StudentHomeworkDetailDto.fromJson,
        );
        expect(
          () => StudentHomeworkDetailDto.fromJson(
            _detail()..['score_visible'] = true,
          ),
          throwsFormatException,
        );
      },
    );
  });

  group('Student safe Question projection', () {
    for (final type in StudentQuestionType.values) {
      test('accepts exact ${type.apiValue} answer UI', () {
        final dto = StudentQuestionDto.fromJson(_question(type));
        final question = dto.toDomain();
        expect(question.type, type);
        expect(question.points, 1.5);
        expect(question.position, 1);
        expect(question.prompt, 'Visible prompt');
        expect(question.instructions, isNull);
        switch (question.answerUi) {
          case StudentChoiceAnswerUi(:final options, :final maxSelections):
            expect(options.map((option) => option.text), ['One', 'Two']);
            expect(
              maxSelections,
              type == StudentQuestionType.multipleChoice ? 2 : null,
            );
            expect(() => options.clear(), throwsUnsupportedError);
          case StudentEmptyAnswerUi():
            expect([
              StudentQuestionType.trueFalse,
              StudentQuestionType.shortWritten,
              StudentQuestionType.openWritten,
            ], contains(type));
          case StudentFileAnswerUi(
            :final allowedExtensions,
            :final maxSizeBytes,
          ):
            expect(allowedExtensions, ['pdf', 'docx', 'ppt', 'pptx']);
            expect(maxSizeBytes, 15_728_640);
            expect(() => allowedExtensions.clear(), throwsUnsupportedError);
          case StudentMatchingAnswerUi(:final leftItems, :final rightItems):
            expect(leftItems.single.text, 'One');
            expect(rightItems.single.text, 'Two');
            expect(() => leftItems.clear(), throwsUnsupportedError);
            expect(() => rightItems.clear(), throwsUnsupportedError);
          case StudentOrderingAnswerUi(:final items):
            expect(items.map((item) => item.text), ['One', 'Two']);
            expect(() => items.clear(), throwsUnsupportedError);
          case StudentFillBlankAnswerUi(:final blanks):
            expect(blanks.single.key, 'blank_1');
            expect(blanks.single.position, 1);
            expect(() => blanks.clear(), throwsUnsupportedError);
        }
      });

      test(
        'rejects missing/unknown ${type.apiValue} keys at every nested boundary',
        () {
          _expectExactKeys(_question(type), StudentQuestionDto.fromJson);
        },
      );

      test(
        'rejects every protected key throughout ${type.apiValue} projection',
        () {
          final payload = _question(type);
          for (final map in _maps(payload)) {
            for (final key in _protectedKeys) {
              map[key] = 'protected answer';
              expect(
                () => StudentQuestionDto.fromJson(payload),
                throwsFormatException,
                reason: '${type.apiValue}: $key',
              );
              map.remove(key);
            }
          }
        },
      );
    }

    test('rejects invalid Question identifiers, types and positions', () {
      for (final entry in <String, List<Object?>>{
        'id': ['bad-question', null],
        'type': ['unknown', null],
        'position': [0, -1, 1.0, '1'],
        'instructions': [1, false],
        'prompt': ['', null, 1],
        'answer_ui': [null, []],
      }.entries) {
        for (final invalid in entry.value) {
          expect(
            () => StudentQuestionDto.fromJson(
              _question(StudentQuestionType.trueFalse)..[entry.key] = invalid,
            ),
            throwsFormatException,
          );
        }
      }
    });

    test('requires choice counts, unique IDs and valid maximum selections', () {
      for (final type in [
        StudentQuestionType.singleChoice,
        StudentQuestionType.multipleChoice,
      ]) {
        for (final options in [
          [],
          [_item(1, 'One')],
          [_item(1, 'One'), _item(1, 'Duplicate')],
          [
            _item(1, 'One'),
            {'id': 'bad-option', 'text': 'Two'},
          ],
        ]) {
          final payload = _question(type);
          (payload['answer_ui']! as Map)['options'] = options;
          expect(
            () => StudentQuestionDto.fromJson(payload),
            throwsFormatException,
          );
        }
      }
      for (final maximum in [0, -1, 3, 2.0, null]) {
        final payload = _question(StudentQuestionType.multipleChoice);
        (payload['answer_ui']! as Map)['max_selections'] = maximum;
        expect(
          () => StudentQuestionDto.fromJson(payload),
          throwsFormatException,
        );
      }
    });

    test(
      'requires exact unique file extensions and bounded integer byte metadata',
      () {
        for (final extensions in [
          [],
          ['pdf'],
          ['pdf', 'docx', 'ppt', 'ppt'],
          ['pdf', 'docx', 'ppt', 'exe'],
          ['PDF', 'docx', 'ppt', 'pptx'],
          ['pdf', 'docx', 'ppt', 1],
        ]) {
          final payload = _question(StudentQuestionType.fileBased);
          (payload['answer_ui']! as Map)['allowed_extensions'] = extensions;
          expect(
            () => StudentQuestionDto.fromJson(payload),
            throwsFormatException,
          );
        }
        for (final bytes in [0, -1, 15_728_641, 1.0, '1']) {
          final payload = _question(StudentQuestionType.fileBased);
          (payload['answer_ui']! as Map)['max_size_bytes'] = bytes;
          expect(
            () => StudentQuestionDto.fromJson(payload),
            throwsFormatException,
          );
        }
      },
    );

    test(
      'requires non-empty unique matching sides with no overlapping IDs',
      () {
        for (final side in ['left_items', 'right_items']) {
          for (final items in [
            [],
            [_item(1, 'One'), _item(1, 'Duplicate')],
          ]) {
            final payload = _question(StudentQuestionType.matching);
            (payload['answer_ui']! as Map)[side] = items;
            expect(
              () => StudentQuestionDto.fromJson(payload),
              throwsFormatException,
            );
          }
        }
        final overlapping = _question(StudentQuestionType.matching);
        (overlapping['answer_ui']! as Map)['right_items'] = [_item(1, 'One')];
        expect(
          () => StudentQuestionDto.fromJson(overlapping),
          throwsFormatException,
        );
      },
    );

    test('requires non-empty unique ordering item IDs', () {
      for (final items in [
        [],
        [_item(1, 'One'), _item(1, 'Duplicate')],
      ]) {
        final payload = _question(StudentQuestionType.ordering);
        (payload['answer_ui']! as Map)['items'] = items;
        expect(
          () => StudentQuestionDto.fromJson(payload),
          throwsFormatException,
        );
      }
    });

    test('requires unique blank IDs, keys and positive unique positions', () {
      final first = {'id': _uuid(1), 'key': 'blank_1', 'position': 1};
      final second = {'id': _uuid(2), 'key': 'blank_2', 'position': 2};
      for (final invalid in [
        {...second, 'id': first['id']},
        {...second, 'key': first['key']},
        {...second, 'position': first['position']},
        {...second, 'position': 0},
        {...second, 'position': 1.0},
        {...second, 'id': 'bad-blank'},
      ]) {
        final payload = _question(StudentQuestionType.fillInBlank);
        (payload['answer_ui']! as Map)['blanks'] = [first, invalid];
        expect(
          () => StudentQuestionDto.fromJson(payload),
          throwsFormatException,
        );
      }
    });
  });
}

StudentHomeworkListDto _parseList(
  Object? json, {
  int page = 1,
  int perPage = 20,
}) => StudentHomeworkListDto.fromJson(
  json,
  requestedQuery: StudentHomeworkListQuery(
    topicId: _topicId,
    page: page,
    perPage: perPage,
  ),
);

void _expectExactKeys(Object? payload, Object? Function(Object?) parse) {
  for (final map in _maps(payload)) {
    map['unexpected'] = true;
    expect(() => parse(payload), throwsFormatException);
    map.remove('unexpected');
    for (final key in map.keys.toList()) {
      final value = map.remove(key);
      expect(
        () => parse(payload),
        throwsFormatException,
        reason: 'Missing $key',
      );
      map[key] = value;
    }
  }
}

List<Map<String, Object?>> _maps(Object? value) {
  if (value is Map<String, Object?>) {
    return [value, ...value.values.expand(_maps)];
  }
  if (value is List) return value.expand(_maps).toList();
  return [];
}

Map<String, Object?> _summary({
  String status = 'active',
  String myStatus = 'submitted',
}) => {
  'id': _homeworkId,
  'topic': <String, Object?>{'id': _topicId, 'title': 'Internet Basics'},
  'title': 'Homework 1',
  'status': status,
  'deadline_at': '2026-09-10T13:00:00Z',
  'attempts': <String, Object?>{
    'allowed': 3,
    'used': myStatus == 'not_started' ? 0 : 1,
    'remaining': 1,
    'official_score_policy': 'highest_valid_completed',
  },
  'my_status': myStatus,
  'score_visible': false,
};

Map<String, Object?> _detail({String myStatus = 'submitted'}) {
  final summary = _summary(myStatus: myStatus);
  (summary['attempts']! as Map<String, Object?>)['in_progress_attempt'] =
      myStatus == 'in_progress' ? _attempt() : null;
  return {
    ...summary,
    'description': null,
    'student_instructions': 'Complete the task.',
    'total_possible_points': 10,
    'questions': <Object?>[],
  };
}

Map<String, Object?> _attempt() => {
  'id': _attemptId,
  'attempt_number': 1,
  'started_at': '2026-09-08T12:00:00Z',
};

Map<String, Object?> _list(
  List<Object?> rows, {
  int page = 1,
  int perPage = 20,
  int total = 1,
  int lastPage = 1,
}) => {
  'data': rows,
  'meta': <String, Object?>{
    'pagination': <String, Object?>{
      'page': page,
      'per_page': perPage,
      'total': total,
      'last_page': lastPage,
    },
  },
};

Map<String, Object?> _question(StudentQuestionType type, {int index = 1}) => {
  'id': _uuid(index + 20),
  'type': type.apiValue,
  'prompt': 'Visible prompt',
  'instructions': null,
  'points': 1.5,
  'position': index,
  'answer_ui': switch (type) {
    StudentQuestionType.singleChoice => <String, Object?>{
      'options': [_item(1, 'One'), _item(2, 'Two')],
    },
    StudentQuestionType.multipleChoice => <String, Object?>{
      'options': [_item(1, 'One'), _item(2, 'Two')],
      'max_selections': 2,
    },
    StudentQuestionType.trueFalse ||
    StudentQuestionType.shortWritten ||
    StudentQuestionType.openWritten => <String, Object?>{},
    StudentQuestionType.fileBased => <String, Object?>{
      'allowed_extensions': ['pdf', 'docx', 'ppt', 'pptx'],
      'max_size_bytes': 15_728_640,
    },
    StudentQuestionType.matching => <String, Object?>{
      'left_items': [_item(1, 'One')],
      'right_items': [_item(2, 'Two')],
    },
    StudentQuestionType.ordering => <String, Object?>{
      'items': [_item(1, 'One'), _item(2, 'Two')],
    },
    StudentQuestionType.fillInBlank => <String, Object?>{
      'blanks': [
        <String, Object?>{'id': _uuid(1), 'key': 'blank_1', 'position': 1},
      ],
    },
  },
};

Map<String, Object?> _item(int id, String text) => {
  'id': _uuid(id),
  'text': text,
};
String _uuid(int number) =>
    'a0000000-0000-0000-0000-${number.toString().padLeft(12, '0')}';

const _topicId = 'a1000000-0000-0000-0000-000000000001';
const _homeworkId = 'a2000000-0000-0000-0000-000000000001';
const _attemptId = 'a3000000-0000-0000-0000-000000000001';
const _protectedKeys = [
  'is_correct',
  'correct_value',
  'accepted_answers',
  'correct_position',
  'match_key',
  'checking_mode',
  'configuration',
  'client_key',
];
