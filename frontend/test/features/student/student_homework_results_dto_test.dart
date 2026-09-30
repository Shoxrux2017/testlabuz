import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/data/dto/student_blitz_attempt_dto.dart';
import 'package:testlabuz_client/features/student/data/dto/student_homework_attempt_dto.dart';
import 'package:testlabuz_client/features/student/data/dto/student_homework_dto.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';

import 'student_blitz_test_support.dart';

/// S09-BE-007B: the Student Homework parsers accept released results, feedback
/// and the official Homework score, and reject every inconsistent shape.
void main() {
  group('Homework official score', () {
    test('accepts a visible official score on the summary and detail', () {
      final summary = StudentHomeworkSummaryDto.fromJson(
        _summary(official: _official()),
      ).toDomain();
      final detail = StudentHomeworkDetailDto.fromJson(
        _detail(official: _official()),
      ).toDomain();

      for (final (visible, score) in [
        (summary.scoreVisible, summary.officialScore),
        (detail.scoreVisible, detail.officialScore),
      ]) {
        expect(visible, isTrue);
        expect(score?.normalizedScore, 87.5);
        expect(score?.attemptNumber, 2);
      }
    });

    test('keeps the hidden defaults when nothing is visible', () {
      final summary = StudentHomeworkSummaryDto.fromJson(_summary()).toDomain();
      final detail = StudentHomeworkDetailDto.fromJson(_detail()).toDomain();

      expect([summary.scoreVisible, summary.officialScore], [false, null]);
      expect([detail.scoreVisible, detail.officialScore], [false, null]);
    });

    test('rejects a score_visible flag that disagrees with official_score', () {
      for (final payload in [
        _summary()..['score_visible'] = true,
        _summary(official: _official())..['score_visible'] = false,
        _detail()..['score_visible'] = true,
        _detail(official: _official())..['score_visible'] = false,
      ]) {
        expect(() => _parseEither(payload), throwsFormatException);
      }
    });

    test('rejects a malformed official score', () {
      for (final official in <Object?>[
        <String, Object?>{'normalized_score': 87.5},
        <String, Object?>{
          'normalized_score': 87.5,
          'attempt_number': 2,
          'selected_at': '2026-09-30T10:00:00Z',
        },
        _official(score: 100.01),
        _official(score: -1),
        _official(score: '87.5'),
        _official(number: 0),
        _official(number: 4),
        _official(number: 2.0),
        'ready',
      ]) {
        expect(
          () => StudentHomeworkSummaryDto.fromJson(
            _summary()
              ..['score_visible'] = true
              ..['official_score'] = official,
          ),
          throwsFormatException,
        );
      }
    });
  });

  group('Homework attempt results', () {
    test('lists every terminal Attempt with its own result', () {
      final detail = StudentHomeworkDetailDto.fromJson(
        _detail(official: _official()),
      ).toDomain();

      expect(detail.attemptResults.map((item) => item.attemptId), [
        _uuid(31),
        _uuid(32),
        _uuid(33),
      ]);
      expect(detail.attemptResults.map((item) => item.status), [
        StudentHomeworkAttemptStatus.checked,
        StudentHomeworkAttemptStatus.checked,
        StudentHomeworkAttemptStatus.waitingForReview,
      ]);
      expect(detail.attemptResults.map((item) => item.result.visible), [
        true,
        true,
        false,
      ]);
      expect(detail.attemptResults.map((item) => item.result.normalizedScore), [
        72.5,
        87.5,
        null,
      ]);
    });

    test('accepts no terminal Attempt while the first is in progress', () {
      final detail = StudentHomeworkDetailDto.fromJson(
        _detail(
          results: [],
          used: 1,
          inProgress: true,
          myStatus: 'in_progress',
        ),
      ).toDomain();

      expect(detail.attemptResults, isEmpty);
      // The terminal Attempts below a later in-progress one are listed.
      final later = StudentHomeworkDetailDto.fromJson(
        _detail(
          results: _results().sublist(0, 2),
          inProgress: true,
          myStatus: 'in_progress',
        ),
      ).toDomain();
      expect(later.attemptResults.map((item) => item.attemptNumber), [1, 2]);
    });

    test('rejects results that do not match the Attempt history', () {
      final items = _results();
      for (final payload in [
        // Wrong count for the used Attempts.
        _detail(results: items.sublist(0, 2)),
        // Numbers must be exactly 1..N and ids unique.
        _detail(results: [items[1], items[0], items[2]]),
        _detail(
          results: [
            items[0],
            {...items[1], 'attempt_id': _uuid(31)},
            items[2],
          ],
        ),
        // The latest terminal Attempt carries my_status.
        _detail(myStatus: 'checked'),
        // In-progress Attempts are never listed, by status or by id.
        _detail(
          results: [
            {...items[0], 'status': 'in_progress', 'result': _hidden()},
            items[1],
            items[2],
          ],
        ),
        _detail(
          results: [
            ...items.sublist(0, 2),
            {...items[2], 'status': 'in_progress'},
          ],
          inProgress: true,
          myStatus: 'in_progress',
        ),
        _detail(
          results: [
            items[0],
            {...items[1], 'attempt_id': _uuid(40)},
          ],
          inProgress: true,
          myStatus: 'in_progress',
        ),
      ]) {
        expect(
          () => StudentHomeworkDetailDto.fromJson(payload),
          throwsFormatException,
        );
      }
    });

    test('rejects a malformed attempt result item', () {
      for (final change in <void Function(Map<String, Object?>)>[
        (item) => item['score'] = 72.5,
        (item) => item.remove('status'),
        (item) => item['attempt_id'] = 'attempt-1',
        (item) => item['attempt_number'] = 1.0,
        (item) => item['attempt_number'] = '1',
        (item) => item['status'] = 'timed_out_finalized',
      ]) {
        final items = _results();
        change(items[0]);
        expect(
          () => StudentHomeworkDetailDto.fromJson(_detail(results: items)),
          throwsFormatException,
        );
      }
    });

    test('rejects an official score its visible Attempt does not confirm', () {
      for (final official in [
        _official(score: 72.5),
        _official(number: 3),
        _official(number: 1, score: 72.5)..['attempt_number'] = 3,
      ]) {
        expect(
          () => StudentHomeworkDetailDto.fromJson(_detail(official: official)),
          throwsFormatException,
        );
      }
    });

    test('rejects a malformed result', () {
      for (final result in <Object?>[
        _hidden()..['normalized_score'] = 50,
        _visible(72.5)..['visible'] = 'true',
        <String, Object?>{'visible': false},
        _hidden()..['score'] = null,
        <String, Object?>{'visible': true, 'normalized_score': null},
        _visible(100.5),
        _visible(-0.5),
        null,
      ]) {
        final items = _results()..[0] = {..._results()[0], 'result': result};
        expect(
          () => StudentHomeworkDetailDto.fromJson(_detail(results: items)),
          throwsFormatException,
        );
      }
      final waitingVisible = _results()
        ..[2] = {..._results()[2], 'result': _visible(40)};
      expect(
        () =>
            StudentHomeworkDetailDto.fromJson(_detail(results: waitingVisible)),
        throwsFormatException,
      );
    });
  });

  group('Homework Attempt result and feedback', () {
    test('accepts a visible result with feedback on the answers', () {
      final attempt = StudentHomeworkAttemptDto.fromJson(
        _attempt(result: _visible(75), feedback: [null, 'Well argued.']),
      ).toDomain();

      expect(attempt.result.visible, isTrue);
      expect(attempt.result.normalizedScore, 75);
      expect(attempt.answers.map((answer) => answer.feedback), [
        null,
        'Well argued.',
      ]);
    });

    test('accepts any non-empty feedback text as the server stores it', () {
      final attempt = StudentHomeworkAttemptDto.fromJson(
        _attempt(result: _visible(75), feedback: ['\u00A0', ' Kept ']),
      ).toDomain();

      expect(attempt.answers.map((answer) => answer.feedback), [
        '\u00A0',
        ' Kept ',
      ]);
    });

    test('accepts a hidden result with null feedback in every state', () {
      for (final status in [
        'submitted',
        'waiting_for_teacher_review',
        'checked',
      ]) {
        final attempt = StudentHomeworkAttemptDto.fromJson(
          _attempt(status: status),
        ).toDomain();

        expect(attempt.result.visible, isFalse);
        expect(attempt.result.normalizedScore, isNull);
        expect(attempt.answers.map((answer) => answer.feedback), [null, null]);
      }
    });

    test('rejects a result or feedback that its state does not allow', () {
      for (final payload in [
        _attempt(status: 'waiting_for_teacher_review', result: _visible(75)),
        _attempt(feedback: [null, 'Hidden feedback.']),
        _attempt(result: _visible(75), feedback: [null, '']),
        _attempt(result: _visible(75), feedback: [null, 5]),
        _attempt()..remove('result'),
        _withoutFeedbackKey(_attempt()),
      ]) {
        expect(
          () => StudentHomeworkAttemptDto.fromJson(payload),
          throwsFormatException,
        );
      }
    });

    test('keeps rejecting feedback on Blitz Attempt answers', () {
      final blitz = blitzAttemptJson(
        answers: [blitzAnswerJson(StudentQuestionType.trueFalse, 1)],
      );
      expect(() => StudentBlitzAttemptDto.fromJson(blitz), returnsNormally);

      ((blitz['answers']! as List).single as Map<String, Object?>)['feedback'] =
          null;

      expect(
        () => StudentBlitzAttemptDto.fromJson(blitz),
        throwsFormatException,
      );
    });
  });
}

Object _parseEither(Map<String, Object?> payload) =>
    payload.containsKey('questions')
    ? StudentHomeworkDetailDto.fromJson(payload)
    : StudentHomeworkSummaryDto.fromJson(payload);

Map<String, Object?> _summary({
  Map<String, Object?>? official,
  int used = 3,
  String myStatus = 'waiting_for_teacher_review',
}) => {
  'id': _uuid(1),
  'topic': <String, Object?>{'id': _uuid(2), 'title': 'Internet Basics'},
  'title': 'Homework 1',
  'status': 'closed',
  'deadline_at': null,
  'attempts': <String, Object?>{
    'allowed': 3,
    'used': used,
    'remaining': 0,
    'official_score_policy': 'highest_valid_completed',
  },
  'my_status': myStatus,
  'score_visible': official != null,
  'official_score': official,
};

Map<String, Object?> _detail({
  Map<String, Object?>? official,
  List<Map<String, Object?>>? results,
  int used = 3,
  bool inProgress = false,
  String myStatus = 'waiting_for_teacher_review',
}) {
  final summary = _summary(official: official, used: used, myStatus: myStatus);
  (summary['attempts']!
      as Map<String, Object?>)['in_progress_attempt'] = inProgress
      ? <String, Object?>{
          'id': _uuid(40),
          'attempt_number': used,
          'started_at': '2026-09-08T12:00:00Z',
        }
      : null;
  return {
    ...summary,
    'description': null,
    'student_instructions': 'Complete the task.',
    'total_possible_points': 8,
    'attempt_results': results ?? _results(),
    'questions': <Object?>[],
  };
}

/// Three terminal Attempts: #1 checked 72.5, #2 checked 87.5, #3 waiting.
List<Map<String, Object?>> _results() => [
  _result(1, 'checked', _visible(72.5)),
  _result(2, 'checked', _visible(87.5)),
  _result(3, 'waiting_for_teacher_review', _hidden()),
];

Map<String, Object?> _result(
  int number,
  String status,
  Map<String, Object?> result,
) => {
  'attempt_id': _uuid(30 + number),
  'attempt_number': number,
  'status': status,
  'result': result,
};

Map<String, Object?> _official({Object? score = 87.5, Object? number = 2}) => {
  'normalized_score': score,
  'attempt_number': number,
};

Map<String, Object?> _visible(num score) => {
  'visible': true,
  'normalized_score': score,
};

Map<String, Object?> _hidden() => {'visible': false, 'normalized_score': null};

/// A frozen Attempt with a true/false and an open written answer.
Map<String, Object?> _attempt({
  String status = 'checked',
  Map<String, Object?>? result,
  List<Object?> feedback = const [null, null],
}) => {
  'id': _uuid(31),
  'assessment_id': _uuid(1),
  'attempt_number': 1,
  'status': status,
  'started_at': '2026-09-08T12:00:00Z',
  'submitted_at': '2026-09-09T12:00:00Z',
  'finalized_at': '2026-09-09T12:00:00Z',
  'finalization_reason': 'student_submit',
  'deadline_at': null,
  'result': result ?? _hidden(),
  'questions': [
    _question(_uuid(51), 'true_false', 1),
    _question(_uuid(52), 'open_written', 2),
  ],
  'answers': [
    <String, Object?>{
      'question_id': _uuid(51),
      'type': 'true_false',
      'answer': <String, Object?>{'value': true},
      'updated_at': '2026-09-08T12:30:00Z',
      'feedback': feedback[0],
    },
    <String, Object?>{
      'question_id': _uuid(52),
      'type': 'open_written',
      'answer': <String, Object?>{'text': 'DNS resolves names.'},
      'updated_at': '2026-09-08T12:40:00Z',
      'feedback': feedback[1],
    },
  ],
};

Map<String, Object?> _question(String id, String type, int position) => {
  'id': id,
  'type': type,
  'prompt': 'Visible prompt',
  'instructions': null,
  'points': 4,
  'position': position,
  'answer_ui': <String, Object?>{},
};

Map<String, Object?> _withoutFeedbackKey(Map<String, Object?> attempt) {
  for (final answer in attempt['answers']! as List) {
    (answer as Map<String, Object?>).remove('feedback');
  }
  return attempt;
}

String _uuid(int value) =>
    'b${value.toString().padLeft(7, '0')}-0000-0000-0000-000000000000';
