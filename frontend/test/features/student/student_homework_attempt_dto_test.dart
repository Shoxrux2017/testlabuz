import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/data/dto/student_homework_attempt_dto.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';

void main() {
  group('Homework Attempt lifecycle', () {
    test(
      'accepts in-progress Attempts with either deadline and zero answers',
      () {
        for (final deadline in [null, _deadline]) {
          final dto = _parse(_attempt()..['deadline_at'] = deadline);
          expect(dto.status, StudentHomeworkAttemptStatus.inProgress);
          expect(dto.startedAt, DateTime.utc(2026, 9, 8, 12));
          expect(
            dto.deadlineAt,
            deadline == null ? null : DateTime.parse(deadline),
          );
          expect(dto.answers, isEmpty);
          expect(dto.questions, isEmpty);
          expect(dto.id, _attemptId);
          expect(dto.assessmentId, _homeworkId);
          expect(dto.attemptNumber, 1);
        }
      },
    );

    for (final status in [
      'submitted',
      'waiting_for_teacher_review',
      'checked',
    ]) {
      for (final reason in StudentHomeworkAttemptFinalizationReason.values) {
        test('accepts coherent $status with ${reason.apiValue}', () {
          for (final deadline in [null, _deadline]) {
            if (deadline == null &&
                reason ==
                    StudentHomeworkAttemptFinalizationReason.homeworkDeadline) {
              continue;
            }
            final dto = _parse(
              _completed(status, reason)..['deadline_at'] = deadline,
            );
            expect(dto.status.apiValue, status);
            expect(dto.finalizationReason, reason);
            expect(dto.finalizedAt, isNotNull);
            expect(
              dto.submittedAt,
              reason == StudentHomeworkAttemptFinalizationReason.studentSubmit
                  ? dto.finalizedAt
                  : null,
            );
          }
        });
      }
    }

    test('rejects unknown Homework status and finalization reason', () {
      for (final value in ['timed_out_finalized', 'unknown', null, 1]) {
        _reject(_attempt()..['status'] = value);
      }
      for (final value in ['timeout_auto_submit', 'unknown', '', 1]) {
        _reject(
          _completed('submitted', _studentSubmit)
            ..['finalization_reason'] = value,
        );
      }
    });

    test(
      'rejects incomplete and contradictory finalization in every status',
      () {
        for (final field in [
          'submitted_at',
          'finalized_at',
          'finalization_reason',
        ]) {
          _reject(
            _attempt()
              ..[field] = field == 'finalization_reason'
                  ? 'student_submit'
                  : _finished,
          );
        }
        for (final status in [
          'submitted',
          'waiting_for_teacher_review',
          'checked',
        ]) {
          for (final field in [
            'finalized_at',
            'finalization_reason',
            'submitted_at',
          ]) {
            _reject(_completed(status, _studentSubmit)..[field] = null);
          }
          _reject(
            _completed(status, _studentSubmit)..['submitted_at'] = _started,
          );
          for (final reason in [_deadlineReason, _closedReason]) {
            _reject(_completed(status, reason)..['submitted_at'] = _finished);
          }
          _reject(_completed(status, _deadlineReason)..['deadline_at'] = null);
          _reject(
            _completed(status, _deadlineReason)..['finalized_at'] = _finished,
          );
          for (final reason in [_studentSubmit, _closedReason]) {
            for (final finalized in [_deadline, '2026-09-10T13:00:01Z']) {
              final payload = _completed(status, reason)
                ..['finalized_at'] = finalized;
              if (reason == _studentSubmit) payload['submitted_at'] = finalized;
              _reject(payload);
            }
          }
          _reject(
            _completed(status, _studentSubmit)..['started_at'] = _deadline,
          );
          _reject(
            _completed(status, _closedReason)..['started_at'] = _deadline,
          );
          _reject(
            _completed(status, _deadlineReason)
              ..['started_at'] = '2026-09-11T00:00:00Z',
          );
        }
      },
    );

    test('requires exact whole-second UTC calendar timestamps', () {
      for (final field in [
        'started_at',
        'submitted_at',
        'finalized_at',
        'deadline_at',
      ]) {
        for (final value in [
          '',
          '2026-09-08',
          '2026-09-08T12:00Z',
          '2026-09-08T12:00:00.000Z',
          '2026-09-08T12:00:00,1Z',
          '2026-09-08T12:00:00+00:00',
          '2026-09-08T12:00:00',
          '2026-02-30T12:00:00Z',
          '2026-09-08T24:00:00Z',
          1,
          false,
        ]) {
          _reject(_completed('submitted', _studentSubmit)..[field] = value);
        }
      }
      _reject(_attempt()..['started_at'] = null);
      for (final value in [null, 0, -1, 4, 1.0, '1']) {
        _reject(_attempt()..['attempt_number'] = value);
      }
      for (final value in [1, 2, 3]) {
        expect(
          _parse(_attempt()..['attempt_number'] = value).attemptNumber,
          value,
        );
      }
      for (final field in ['id', 'assessment_id']) {
        for (final value in [
          null,
          '',
          'bad-id',
          ' $_attemptId',
          '$_attemptId\n',
          1,
        ]) {
          _reject(_attempt()..[field] = value);
        }
      }
    });
  });

  group('Homework Attempt saved answers', () {
    test(
      'reuses all nine safe Question types and preserves every typed answer',
      () {
        final payload = _attemptWithAllAnswers();
        final dto = _parse(payload);
        final attempt = dto.toDomain();
        expect(
          attempt.questions.map((question) => question.type),
          StudentQuestionType.values,
        );
        expect(
          attempt.answers.map((answer) => answer.type),
          StudentQuestionType.values,
        );
        for (final answer in attempt.answers) {
          expect(answer.updatedAt, DateTime.parse(_finished));
          switch (answer.value) {
            case StudentChoiceAnswerValue(:final selectedOptionIds):
              expect(selectedOptionIds, [_uuid(1)]);
              expect(() => selectedOptionIds.clear(), throwsUnsupportedError);
            case StudentBooleanAnswerValue(:final value):
              expect(value, isFalse);
            case StudentTextAnswerValue(:final text):
              expect(text, '  Exact saved text\n');
            case StudentMatchingAnswerValue(:final pairs):
              expect(pairs.single.leftItemId, _uuid(1));
              expect(pairs.single.rightItemId, _uuid(3));
              expect(() => pairs.clear(), throwsUnsupportedError);
            case StudentOrderingAnswerValue(:final items):
              expect(items.single.itemId, _uuid(1));
              expect(items.single.position, 2);
              expect(() => items.clear(), throwsUnsupportedError);
            case StudentFillBlankAnswerValue(:final values):
              expect(values.single.blankId, _uuid(1));
              expect(values.single.text, '  Exact blank\n');
              expect(() => values.clear(), throwsUnsupportedError);
            case StudentFileAnswerValue(:final file):
              expect(file.id, _uuid(99));
              expect(file.originalName, 'homework.pptx');
              expect(file.extension, 'pptx');
              expect(file.sizeBytes, 1_048_576);
          }
        }
        for (final collection in [
          dto.questions,
          dto.answers,
          attempt.questions,
          attempt.answers,
        ]) {
          expect(() => collection.clear(), throwsUnsupportedError);
        }
      },
    );

    test(
      'accepts partial answers and partial non-contiguous ordering positions',
      () {
        final payload = _attemptWithAllAnswers();
        payload['answers'] = [_answers(payload).last];
        expect(_parse(payload).answers, hasLength(1));
        final ordering = _single(StudentQuestionType.ordering);
        _answerValue(ordering)['items'] = [
          {'item_id': _uuid(3), 'position': 1},
          {'item_id': _uuid(1), 'position': 3},
        ];
        final value =
            _parse(ordering).answers.single.value as StudentOrderingAnswerValue;
        expect(value.items.map((item) => item.position), [1, 3]);
      },
    );

    test(
      'rejects missing and extra keys at every nested transport boundary',
      () {
        final payload = _attemptWithAllAnswers();
        for (final map in _maps(payload)) {
          map['unknown'] = true;
          _reject(payload);
          map.remove('unknown');
          for (final key in map.keys.toList()) {
            final value = map.remove(key);
            _reject(payload);
            map[key] = value;
          }
          for (final key in [
            'score',
            'checking_status',
            'awarded_points',
            'feedback',
            'checked_at',
            'is_correct',
            'accepted_answers',
            'correct_position',
            'match_key',
            'storage_disk',
            'storage_key',
            'mime_type',
            'checksum_sha256',
            'uploaded_by_user_id',
            'institution_id',
            'removed_at',
          ]) {
            map[key] = 'protected';
            _reject(payload);
            map.remove(key);
          }
        }
      },
    );

    test('requires unique Question IDs and exact ascending positions 1..N', () {
      final first = _question(StudentQuestionType.trueFalse, 1);
      final second = _question(StudentQuestionType.shortWritten, 2);
      for (final questions in [
        [
          first,
          {...second, 'id': first['id']},
        ],
        [
          first,
          {...second, 'id': (first['id']! as String).toUpperCase()},
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
        _reject(_attempt()..['questions'] = questions);
      }
    });

    test('requires unique answers, existing Question and matching type', () {
      final payload = _single(StudentQuestionType.trueFalse);
      final answer = _answers(payload).single;
      for (final answers in [
        [answer, answer],
        [
          answer,
          {
            ...answer,
            'question_id': (answer['question_id']! as String).toUpperCase(),
          },
        ],
        [
          {...answer, 'question_id': _uuid(999)},
        ],
        [
          {...answer, 'question_id': 'not-a-uuid'},
        ],
        [
          {...answer, 'type': 'short_written'},
        ],
        [
          {...answer, 'type': 'unknown'},
        ],
        [
          {...answer, 'answer': null},
        ],
      ]) {
        _reject({...payload, 'answers': answers});
      }
      for (final timestamp in [
        null,
        '2026-09-08T12:00Z',
        '2026-09-08T12:00:00.1Z',
        '2026-09-08T12:00:00+00:00',
      ]) {
        _reject({
          ...payload,
          'answers': [
            {...answer, 'updated_at': timestamp},
          ],
        });
      }
    });

    for (final type in [
      StudentQuestionType.singleChoice,
      StudentQuestionType.multipleChoice,
    ]) {
      test(
        'validates ${type.apiValue} saved count and owned unique option IDs',
        () {
          for (final ids in [
            [],
            [_uuid(1), _uuid(1)],
            [_uuid(1), _uuid(2)],
            [_uuid(99)],
            ['bad'],
            [null],
          ]) {
            final payload = _single(type);
            _answerValue(payload)['selected_option_ids'] = ids;
            _reject(payload);
          }
        },
      );
    }

    test(
      'requires boolean and non-empty written state while preserving text',
      () {
        for (final value in [null, 1, 'true', 'false']) {
          final payload = _single(StudentQuestionType.trueFalse);
          _answerValue(payload)['value'] = value;
          _reject(payload);
        }
        for (final type in [
          StudentQuestionType.shortWritten,
          StudentQuestionType.openWritten,
        ]) {
          for (final text in ['', ' \n\t ', null, 1, false]) {
            final payload = _single(type);
            _answerValue(payload)['text'] = text;
            _reject(payload);
          }
        }
      },
    );

    test(
      'validates matching side ownership and uniqueness without correctness',
      () {
        for (final pairs in [
          [],
          [
            {'left_item_id': _uuid(3), 'right_item_id': _uuid(1)},
          ],
          [
            {'left_item_id': _uuid(99), 'right_item_id': _uuid(3)},
          ],
          [
            {'left_item_id': _uuid(1), 'right_item_id': _uuid(99)},
          ],
          [
            {'left_item_id': 'bad', 'right_item_id': _uuid(3)},
          ],
          [
            {'left_item_id': _uuid(1), 'right_item_id': _uuid(3)},
            {'left_item_id': _uuid(1), 'right_item_id': _uuid(4)},
          ],
          [
            {'left_item_id': _uuid(1), 'right_item_id': _uuid(3)},
            {'left_item_id': _uuid(2), 'right_item_id': _uuid(3)},
          ],
        ]) {
          final payload = _single(StudentQuestionType.matching);
          _answerValue(payload)['pairs'] = pairs;
          _reject(payload);
        }
      },
    );

    test(
      'validates ordering ownership, position bounds and separate uniqueness',
      () {
        for (final items in [
          [],
          [
            {'item_id': _uuid(99), 'position': 1},
          ],
          [
            {'item_id': 'bad', 'position': 1},
          ],
          for (final position in [0, -1, 4, 1.0, '1', null])
            [
              {'item_id': _uuid(1), 'position': position},
            ],
          [
            {'item_id': _uuid(1), 'position': 1},
            {'item_id': _uuid(1), 'position': 2},
          ],
          [
            {'item_id': _uuid(1), 'position': 1},
            {'item_id': _uuid(2), 'position': 1},
          ],
        ]) {
          final payload = _single(StudentQuestionType.ordering);
          _answerValue(payload)['items'] = items;
          _reject(payload);
        }
      },
    );

    test(
      'validates fill blank ownership, uniqueness and semantic non-empty text',
      () {
        for (final values in [
          [],
          [
            {'blank_id': _uuid(99), 'text': 'saved'},
          ],
          [
            {'blank_id': 'bad', 'text': 'saved'},
          ],
          for (final text in ['', ' \n\t ', null, 1])
            [
              {'blank_id': _uuid(1), 'text': text},
            ],
          [
            {'blank_id': _uuid(1), 'text': 'one'},
            {'blank_id': _uuid(1), 'text': 'two'},
          ],
        ]) {
          final payload = _single(StudentQuestionType.fillInBlank);
          _answerValue(payload)['values'] = values;
          _reject(payload);
        }
      },
    );

    test(
      'validates safe submission metadata and exact supported size bounds',
      () {
        for (final extension in ['pdf', 'docx', 'ppt', 'pptx']) {
          for (final bytes in [1, 15_728_640]) {
            final payload = _single(StudentQuestionType.fileBased);
            final file = _answerValue(payload)['file']! as Map<String, Object?>;
            file['extension'] = extension;
            file['size_bytes'] = bytes;
            expect(
              (_parse(payload).answers.single.value as StudentFileAnswerValue)
                  .file
                  .sizeBytes,
              bytes,
            );
          }
        }
        for (final entry in <String, List<Object?>>{
          'id': ['bad', null],
          'original_name': ['', '  ', null, 1],
          'extension': ['exe', 'PDF', '', null],
          'size_bytes': [0, -1, 15_728_641, 1.0, '1', null],
        }.entries) {
          for (final value in entry.value) {
            final payload = _single(StudentQuestionType.fileBased);
            (_answerValue(payload)['file']!
                    as Map<String, Object?>)[entry.key] =
                value;
            _reject(payload);
          }
        }
      },
    );
  });
}

StudentHomeworkAttemptDto _parse(Object? json) =>
    StudentHomeworkAttemptDto.fromJson(json);
void _reject(Object? json) => expect(() => _parse(json), throwsFormatException);

Map<String, Object?> _attempt() => {
  'id': _attemptId,
  'assessment_id': _homeworkId,
  'attempt_number': 1,
  'status': 'in_progress',
  'started_at': _started,
  'submitted_at': null,
  'finalized_at': null,
  'finalization_reason': null,
  'deadline_at': _deadline,
  'questions': <Object?>[],
  'answers': <Object?>[],
};

Map<String, Object?> _completed(
  String status,
  StudentHomeworkAttemptFinalizationReason reason,
) => _attempt()
  ..['status'] = status
  ..['finalization_reason'] = reason.apiValue
  ..['finalized_at'] = reason == _deadlineReason ? _deadline : _finished
  ..['submitted_at'] = reason == _studentSubmit ? _finished : null;

Map<String, Object?> _attemptWithAllAnswers() => _attempt()
  ..['questions'] = [
    for (final type in StudentQuestionType.values)
      _question(type, type.index + 1),
  ]
  ..['answers'] = [
    for (final type in StudentQuestionType.values)
      _answer(type, type.index + 1),
  ];

Map<String, Object?> _single(StudentQuestionType type) => _attempt()
  ..['questions'] = [_question(type, 1)]
  ..['answers'] = [_answer(type, 1)];

Map<String, Object?> _question(StudentQuestionType type, int position) => {
  'id': _uuid(100 + position),
  'type': type.apiValue,
  'prompt': 'Safe prompt',
  'instructions': null,
  'points': 1,
  'position': position,
  'answer_ui': switch (type) {
    StudentQuestionType.singleChoice => <String, Object?>{
      'options': [_item(1), _item(2)],
    },
    StudentQuestionType.multipleChoice => <String, Object?>{
      'options': [_item(1), _item(2)],
      'max_selections': 1,
    },
    StudentQuestionType.trueFalse ||
    StudentQuestionType.shortWritten ||
    StudentQuestionType.openWritten => <String, Object?>{},
    StudentQuestionType.fileBased => <String, Object?>{
      'allowed_extensions': ['pdf', 'docx', 'ppt', 'pptx'],
      'max_size_bytes': 15_728_640,
    },
    StudentQuestionType.matching => <String, Object?>{
      'left_items': [_item(1), _item(2)],
      'right_items': [_item(3), _item(4)],
    },
    StudentQuestionType.ordering => <String, Object?>{
      'items': [_item(1), _item(2), _item(3)],
    },
    StudentQuestionType.fillInBlank => <String, Object?>{
      'blanks': [
        <String, Object?>{'id': _uuid(1), 'key': 'blank_1', 'position': 1},
      ],
    },
  },
};

Map<String, Object?> _answer(StudentQuestionType type, int position) => {
  'question_id': _uuid(100 + position),
  'type': type.apiValue,
  'updated_at': _finished,
  'answer': switch (type) {
    StudentQuestionType.singleChoice ||
    StudentQuestionType.multipleChoice => <String, Object?>{
      'selected_option_ids': [_uuid(1)],
    },
    StudentQuestionType.trueFalse => <String, Object?>{'value': false},
    StudentQuestionType.shortWritten || StudentQuestionType.openWritten =>
      <String, Object?>{'text': '  Exact saved text\n'},
    StudentQuestionType.matching => <String, Object?>{
      'pairs': [
        <String, Object?>{'left_item_id': _uuid(1), 'right_item_id': _uuid(3)},
      ],
    },
    StudentQuestionType.ordering => <String, Object?>{
      'items': [
        <String, Object?>{'item_id': _uuid(1), 'position': 2},
      ],
    },
    StudentQuestionType.fillInBlank => <String, Object?>{
      'values': [
        <String, Object?>{'blank_id': _uuid(1), 'text': '  Exact blank\n'},
      ],
    },
    StudentQuestionType.fileBased => <String, Object?>{
      'file': <String, Object?>{
        'id': _uuid(99),
        'original_name': 'homework.pptx',
        'extension': 'pptx',
        'size_bytes': 1_048_576,
      },
    },
  },
};

List<Map<String, Object?>> _answers(Map<String, Object?> payload) =>
    (payload['answers']! as List).cast<Map<String, Object?>>();
Map<String, Object?> _answerValue(Map<String, Object?> payload) =>
    _answers(payload).single['answer']! as Map<String, Object?>;
List<Map<String, Object?>> _maps(Object? value) {
  if (value is Map<String, Object?>) {
    return [value, ...value.values.expand(_maps)];
  }
  if (value is List) return value.expand(_maps).toList();
  return [];
}

Map<String, Object?> _item(int id) => {'id': _uuid(id), 'text': 'Item $id'};
String _uuid(int id) =>
    'a0000000-0000-0000-0000-${id.toString().padLeft(12, '0')}';
const _attemptId = 'a1000000-0000-0000-0000-000000000001';
const _homeworkId = 'a2000000-0000-0000-0000-000000000001';
const _started = '2026-09-08T12:00:00Z';
const _finished = '2026-09-09T12:00:00Z';
const _deadline = '2026-09-10T13:00:00Z';
const _studentSubmit = StudentHomeworkAttemptFinalizationReason.studentSubmit;
const _deadlineReason =
    StudentHomeworkAttemptFinalizationReason.homeworkDeadline;
const _closedReason = StudentHomeworkAttemptFinalizationReason.taskClosed;
