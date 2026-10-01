import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_submission_detail_dto.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_detail.dart';

import 'teacher_submission_test_support.dart';

void main() {
  group('Teacher submission detail DTO', () {
    test('parses every question type, answer status and a missing answer', () {
      final detail = TeacherSubmissionDetailDto.fromJson(
        submissionDetailJson(),
      ).toDomain();

      expect(detail.submission.id, submissionId);
      expect(
        detail.submission.status,
        TeacherSubmissionStatus.waitingForTeacherReview,
      );
      expect(detail.submittedAt, DateTime.utc(2026, 9, 30, 10));
      expect(detail.questions.map((q) => q.position), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
      ]);
      expect(detail.questions.map((q) => q.type), [
        TeacherQuestionType.singleChoice,
        TeacherQuestionType.multipleChoice,
        TeacherQuestionType.trueFalse,
        TeacherQuestionType.shortWritten,
        TeacherQuestionType.openWritten,
        TeacherQuestionType.fileBased,
        TeacherQuestionType.matching,
        TeacherQuestionType.ordering,
        TeacherQuestionType.fillInBlank,
        TeacherQuestionType.openWritten,
      ]);

      final single = detail.questions[0];
      final options =
          (single.configuration as TeacherReviewChoiceConfiguration).options;
      expect(
        options.map((option) => (option.id, option.text, option.isCorrect)),
        [(detailId(1), 'Paris', true), (detailId(2), 'Rome', false)],
      );
      expect(
        (single.answer!.value as TeacherReviewChoiceValue).selectedOptionIds,
        [detailId(1)],
      );
      expect(
        single.answer!.checkingStatus,
        TeacherReviewAnswerStatus.autoChecked,
      );
      expect(single.answer!.awardedPoints, 1);

      final essay = detail.questions[4].answer!;
      expect(essay.checkingStatus, TeacherReviewAnswerStatus.teacherChecked);
      expect([essay.awardedPoints, essay.feedback], [2.5, 'Good start.']);
      expect(
        [essay.checkedBy?.id, essay.checkedBy?.fullName],
        [detailTeacherId, 'Dilnoza Teacher'],
      );
      expect(
        (essay.value as TeacherReviewTextValue).text,
        'An essay about DNS.',
      );

      final file =
          (detail.questions[5].answer!.value as TeacherReviewFileValue).file;
      expect(
        [file.id, file.originalName, file.extension, file.sizeBytes],
        [detailFileId, 'report.pdf', 'pdf', 2048],
      );
      expect(
        detail.questions[5].answer!.checkingStatus,
        TeacherReviewAnswerStatus.waitingForTeacherReview,
      );

      final matching = detail.questions[6];
      expect(
        (matching.configuration as TeacherReviewMatchingConfiguration).pairs
            .map((pair) => (pair.left, pair.right)),
        [('HTTP', 'Web'), ('SMTP', 'Mail')],
      );
      expect(
        (matching.answer!.value as TeacherReviewMatchingValue).pairs.map(
          (pair) => (pair.leftItemId, pair.rightItemId),
        ),
        [(detailId(11), detailId(15))],
      );
      expect(
        (detail.questions[7].answer!.value as TeacherReviewOrderingValue).items
            .map((item) => (item.itemId, item.position)),
        [(detailId(21), 1), (detailId(20), 2)],
      );
      expect(
        (detail.questions[8].configuration
                as TeacherReviewFillInBlankConfiguration)
            .blanks
            .single
            .acceptedAnswers,
        ['HTTP'],
      );
      expect(
        (detail.questions[8].answer!.value as TeacherReviewFillInBlankValue)
            .values
            .single
            .text,
        'http',
      );
      expect(detail.questions[9].answer, isNull);
    });

    test('accepts a submission still waiting for automatic checking', () {
      final questions = submissionDetailQuestions();
      for (final question in questions) {
        final answer = question['answer'] as Map<String, Object?>?;
        if (answer != null) {
          answer
            ..['checking_status'] = 'pending'
            ..['awarded_points'] = null
            ..['feedback'] = null
            ..['checked_by'] = null
            ..['checked_at'] = null;
        }
      }
      final detail = TeacherSubmissionDetailDto.fromJson(
        submissionDetailJson(
          questions: questions,
          status: 'submitted',
          waiting: 0,
          reviewed: 0,
        ),
      ).toDomain();

      expect(
        detail.questions.first.answer!.checkingStatus,
        TeacherReviewAnswerStatus.pending,
      );
    });

    test(
      'accepts a manual short written question without accepted answers',
      () {
        final json = submissionDetailJson();
        _question(json, 4)
          ..['checking_mode'] = 'manual'
          ..['configuration'] = <String, Object?>{};
        _answer(json, 4)
          ..['checking_status'] = 'teacher_checked'
          ..['checked_by'] = <String, Object?>{
            'id': detailTeacherId,
            'full_name': 'Dilnoza Teacher',
          };
        json['review'] = <String, Object?>{
          'waiting_answers': 1,
          'reviewed_answers': 2,
        };

        final question = TeacherSubmissionDetailDto.fromJson(
          json,
        ).toDomain().questions[3];

        expect(
          (question.configuration as TeacherReviewShortWrittenConfiguration)
              .acceptedAnswers,
          isEmpty,
        );
      },
    );

    test('accepts blank keys that differ only by case', () {
      final json = submissionDetailJson();
      final question = _question(json, 9);
      question['prompt'] = 'The {{proto}} and {{Proto}} protocols';
      ((question['configuration']! as Map<String, Object?>)['blanks']!
              as List<Object?>)
          .add(<String, Object?>{
            'id': detailId(31),
            'key': 'Proto',
            'position': 2,
            'accepted_answers': ['FTP'],
          });

      final blanks =
          (TeacherSubmissionDetailDto.fromJson(
                    json,
                  ).toDomain().questions[8].configuration
                  as TeacherReviewFillInBlankConfiguration)
              .blanks;

      expect(blanks.map((blank) => blank.key), ['proto', 'Proto']);
    });

    test('rejects a missing or an extra key at every level', () {
      final maps =
          <String, Map<String, Object?> Function(Map<String, Object?>)>{
            'entry': (json) => _entry(json, 1),
            'question': (json) => _question(json, 1),
            'configuration': (json) =>
                _question(json, 3)['configuration']! as Map<String, Object?>,
            'option': (json) => _row(json, 1, 'options'),
            'pair': (json) => _row(json, 7, 'pairs'),
            'ordering item': (json) => _row(json, 8, 'items'),
            'blank': (json) => _row(json, 9, 'blanks'),
            'answer': (json) => _answer(json, 1),
            'value': (json) => _value(json, 3),
            'file': (json) => _value(json, 6)['file']! as Map<String, Object?>,
            'reviewer': (json) =>
                _answer(json, 5)['checked_by']! as Map<String, Object?>,
          };

      for (final MapEntry(key: level, value: locate) in maps.entries) {
        final extra = submissionDetailJson();
        locate(extra)['unexpected'] = true;
        expect(
          () => TeacherSubmissionDetailDto.fromJson(extra),
          throwsFormatException,
          reason: 'extra $level',
        );

        final missing = submissionDetailJson();
        final map = locate(missing);
        map.remove(map.keys.first);
        expect(
          () => TeacherSubmissionDetailDto.fromJson(missing),
          throwsFormatException,
          reason: 'missing $level',
        );
      }
    });

    test('rejects every contradiction', () {
      final mutations = <String, void Function(Map<String, Object?>)>{
        'extra top-level key': (json) => json['extra'] = true,
        'missing questions': (json) => json.remove('questions'),
        'question instructions': (json) =>
            _question(json, 1)['instructions'] = 'x',
        'unknown type': (json) => _question(json, 1)['type'] = 'essay',
        'mode not allowed': (json) =>
            _question(json, 1)['checking_mode'] = 'manual',
        'repeated blank key': (json) =>
            ((_question(json, 9)['configuration']!
                        as Map<String, Object?>)['blanks']!
                    as List<Object?>)
                .add(<String, Object?>{
                  'id': detailId(31),
                  'key': 'proto',
                  'position': 2,
                  'accepted_answers': ['FTP'],
                }),
        'unknown mode': (json) => _question(json, 1)['checking_mode'] = 'peer',
        'unknown matching item': (json) => _value(json, 7)['pairs'] = [
          <String, Object?>{
            'left_item_id': detailId(98),
            'right_item_id': detailId(15),
          },
        ],
        'unknown ordering item': (json) => _value(json, 8)['items'] = [
          <String, Object?>{'item_id': detailId(98), 'position': 1},
        ],
        'ordering position out of range': (json) => _value(json, 8)['items'] = [
          <String, Object?>{'item_id': detailId(20), 'position': 3},
        ],
        'unknown blank': (json) => _value(json, 9)['values'] = [
          <String, Object?>{'blank_id': detailId(98), 'text': 'x'},
        ],
        'review status on an automatic Question': (json) {
          _answer(json, 1)
            ..['checking_status'] = 'waiting_for_teacher_review'
            ..['awarded_points'] = null
            ..['checked_at'] = null;
          json['review'] = <String, Object?>{
            'waiting_answers': 2,
            'reviewed_answers': 1,
          };
        },
        'teacher checked on an automatic Question': (json) {
          _answer(json, 1)
            ..['checking_status'] = 'teacher_checked'
            ..['checked_by'] = Map<String, Object?>.of(
              _answer(json, 5)['checked_by']! as Map<String, Object?>,
            );
          json['review'] = <String, Object?>{
            'waiting_answers': 1,
            'reviewed_answers': 2,
          };
        },
        'pending answer in a waiting submission': (json) => _answer(json, 1)
          ..['checking_status'] = 'pending'
          ..['awarded_points'] = null
          ..['checked_at'] = null,
        'unknown status': (json) =>
            _answer(json, 1)['checking_status'] = 'graded',
        'pending with points': (json) =>
            _answer(json, 1)['checking_status'] = 'pending',
        'awarded above points': (json) =>
            _answer(json, 1)['awarded_points'] = 2,
        'negative awarded': (json) => _answer(json, 1)['awarded_points'] = -1,
        'unknown option id': (json) =>
            _value(json, 1)['selected_option_ids'] = [detailId(99)],
        'two single selections': (json) =>
            _value(json, 1)['selected_option_ids'] = [detailId(1), detailId(2)],
        'more selections than correct options': (json) =>
            _value(json, 2)['selected_option_ids'] = [
              detailId(3),
              detailId(4),
              detailId(5),
            ],
        'value shape of another type': (json) =>
            _answer(json, 3)['value'] = <String, Object?>{'text': 'yes'},
        'teacher checked without reviewer': (json) =>
            _answer(json, 5)['checked_by'] = null,
        'reviewer extra key': (json) =>
            (_answer(json, 5)['checked_by']! as Map<String, Object?>)['role'] =
                'x',
        'auto checked with feedback': (json) =>
            _answer(json, 1)['feedback'] = 'x',
        'file extension': (json) =>
            (_value(json, 6)['file']! as Map<String, Object?>)['extension'] =
                'exe',
        'empty file': (json) =>
            (_value(json, 6)['file']! as Map<String, Object?>)['size_bytes'] =
                0,
        'repeated matching left item': (json) => _value(json, 7)['pairs'] = [
          <String, Object?>{
            'left_item_id': detailId(11),
            'right_item_id': detailId(12),
          },
          <String, Object?>{
            'left_item_id': detailId(11),
            'right_item_id': detailId(15),
          },
        ],
        'repeated ordering position': (json) => _value(json, 8)['items'] = [
          <String, Object?>{'item_id': detailId(20), 'position': 1},
          <String, Object?>{'item_id': detailId(21), 'position': 1},
        ],
        'blank text': (json) => _value(json, 9)['values'] = [
          <String, Object?>{'blank_id': detailId(30), 'text': '  '},
        ],
        'options out of order': (json) {
          final options =
              (_question(json, 1)['configuration']!
                      as Map<String, Object?>)['options']!
                  as List<Object?>;
          (options[0]! as Map<String, Object?>)['position'] = 2;
          (options[1]! as Map<String, Object?>)['position'] = 1;
        },
        'questions out of order': (json) {
          final questions = json['questions']! as List<Object?>;
          final first = questions.removeAt(0);
          questions.insert(1, first);
        },
        'waiting count': (json) => json['review'] = <String, Object?>{
          'waiting_answers': 2,
          'reviewed_answers': 1,
        },
        'reviewed count': (json) => json['review'] = <String, Object?>{
          'waiting_answers': 1,
          'reviewed_answers': 0,
        },
        'checked submission with a waiting answer': (json) {
          json['status'] = 'checked';
          json['score'] = <String, Object?>{
            'earned_points': 7,
            'possible_points': 14,
            'normalized_score': 50,
          };
        },
        'submitted submission with checked answers': (json) {
          json['status'] = 'submitted';
          json['review'] = <String, Object?>{
            'waiting_answers': 1,
            'reviewed_answers': 1,
          };
        },
      };

      for (final MapEntry(key: name, value: mutate) in mutations.entries) {
        final json = submissionDetailJson();
        mutate(json);
        expect(
          () => TeacherSubmissionDetailDto.fromJson(json),
          throwsFormatException,
          reason: name,
        );
      }
    });
  });
}

Map<String, Object?> _entry(Map<String, Object?> json, int position) {
  return (json['questions']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .firstWhere(
        (entry) =>
            (entry['question']! as Map<String, Object?>)['position'] ==
            position,
      );
}

Map<String, Object?> _question(Map<String, Object?> json, int position) =>
    _entry(json, position)['question']! as Map<String, Object?>;

Map<String, Object?> _answer(Map<String, Object?> json, int position) =>
    _entry(json, position)['answer']! as Map<String, Object?>;

Map<String, Object?> _row(
  Map<String, Object?> json,
  int position,
  String key,
) =>
    ((_question(json, position)['configuration']! as Map<String, Object?>)[key]!
                as List<Object?>)
            .first!
        as Map<String, Object?>;

Map<String, Object?> _value(Map<String, Object?> json, int position) =>
    _answer(json, position)['value']! as Map<String, Object?>;
