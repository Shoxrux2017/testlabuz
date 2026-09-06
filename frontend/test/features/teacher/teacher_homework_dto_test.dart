import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_homework_dto.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_homework_list_dto.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '20000000-0000-0000-0000-000000000001';

void main() {
  group('Teacher Homework DTO', () {
    test('parses all statuses, recipient modes, and nullable deadlines', () {
      for (final status in TeacherHomeworkStatus.values) {
        final json = _homeworkJson(status: status);
        final homework = TeacherHomeworkDto.fromJson(json).toDomain();

        expect(homework.status, status);
        expect(homework.deadlineAt, DateTime.utc(2026, 9, 10, 12));
        expect(homework.attemptPolicy.normalAttempts, 3);
        expect(
          homework.attemptPolicy.officialScorePolicy,
          'highest_valid_completed',
        );
      }

      final selected = _homeworkJson()
        ..['assignment_mode'] = 'selected_students'
        ..['student_ids'] = [
          '30000000-0000-0000-0000-000000000001',
          '30000000-0000-0000-0000-000000000002',
        ]
        ..['deadline_at'] = null;
      final homework = TeacherHomeworkDto.fromJson(selected).toDomain();

      expect(
        homework.assignmentMode,
        TeacherHomeworkAssignmentMode.selectedStudents,
      );
      expect(homework.studentIds, hasLength(2));
      expect(homework.deadlineAt, isNull);
    });

    test('parses every Question type into typed configuration', () {
      final homework = TeacherHomeworkDto.fromJson(_homeworkJson()).toDomain();

      expect(homework.questions, hasLength(9));
      expect(
        homework.questions.map((question) => question.type),
        TeacherQuestionType.values,
      );
      expect(
        homework.questions[0].configuration,
        isA<TeacherChoiceQuestionConfiguration>(),
      );
      expect(
        homework.questions[1].configuration,
        isA<TeacherChoiceQuestionConfiguration>(),
      );
      expect(
        homework.questions[2].configuration,
        isA<TeacherTrueFalseQuestionConfiguration>(),
      );
      expect(
        homework.questions[3].configuration,
        isA<TeacherShortWrittenAutomaticConfiguration>(),
      );
      expect(
        homework.questions[4].configuration,
        isA<TeacherEmptyQuestionConfiguration>(),
      );
      expect(
        homework.questions[5].configuration,
        isA<TeacherFileBasedQuestionConfiguration>(),
      );
      expect(
        homework.questions[6].configuration,
        isA<TeacherMatchingQuestionConfiguration>(),
      );
      expect(
        homework.questions[7].configuration,
        isA<TeacherOrderingQuestionConfiguration>(),
      );
      expect(
        homework.questions[8].configuration,
        isA<TeacherFillInBlankQuestionConfiguration>(),
      );

      final manualShort = _questionJson(TeacherQuestionType.shortWritten, 1)
        ..['checking_mode'] = 'manual'
        ..['configuration'] = <String, Object?>{};
      expect(
        TeacherHomeworkDto.fromJson(
          _homeworkJson()..['questions'] = [manualShort],
        ).toDomain().questions.single.configuration,
        isA<TeacherEmptyQuestionConfiguration>(),
      );
    });

    test('rejects unknown, missing, malformed UUID, and timestamp fields', () {
      final unknown = _homeworkJson()..['unknown'] = true;
      final missing = _homeworkJson()..remove('title');
      final malformedId = _homeworkJson()..['id'] = 'not-a-uuid';
      final nonUtc = _homeworkJson()
        ..['created_at'] = '2026-09-01T15:00:00+05:00';
      final impossible = _homeworkJson()
        ..['updated_at'] = '2026-02-31T10:00:00Z';

      for (final json in [unknown, missing, malformedId, nonUtc, impossible]) {
        expect(() => TeacherHomeworkDto.fromJson(json), throwsFormatException);
      }
    });

    test('requires finite non-negative JSON numeric points and totals', () {
      for (final invalid in <Object?>[
        '1.5',
        -0.1,
        double.nan,
        double.infinity,
      ]) {
        final total = _homeworkJson()..['total_possible_points'] = invalid;
        expect(() => TeacherHomeworkDto.fromJson(total), throwsFormatException);

        final points = _homeworkJson();
        ((points['questions']! as List<Object?>).first
                as Map<String, Object?>)['points'] =
            invalid;
        expect(
          () => TeacherHomeworkDto.fromJson(points),
          throwsFormatException,
        );
      }
    });

    test('requires the fixed attempt policy and valid lifecycle shapes', () {
      for (final policy in [
        {
          'normal_attempts': 2,
          'official_score_policy': 'highest_valid_completed',
        },
        {'normal_attempts': 3, 'official_score_policy': 'latest_completed'},
        {
          'normal_attempts': 3,
          'official_score_policy': 'highest_valid_completed',
          'extra': true,
        },
      ]) {
        expect(
          () => TeacherHomeworkDto.fromJson(
            _homeworkJson()..['attempt_policy'] = policy,
          ),
          throwsFormatException,
        );
      }

      final activeWithoutActivation = _homeworkJson(
        status: TeacherHomeworkStatus.active,
      )..['activated_at'] = null;
      final closedWithoutClose = _homeworkJson(
        status: TeacherHomeworkStatus.closed,
      )..['closed_at'] = null;
      final draftWithActivation = _homeworkJson()
        ..['activated_at'] = '2026-09-02T10:00:00Z';
      final archivedHalfHistory = _homeworkJson(
        status: TeacherHomeworkStatus.archived,
      )..['closed_at'] = null;

      for (final json in [
        activeWithoutActivation,
        closedWithoutClose,
        draftWithActivation,
        archivedHalfHistory,
      ]) {
        expect(() => TeacherHomeworkDto.fromJson(json), throwsFormatException);
      }

      final directArchive =
          _homeworkJson(status: TeacherHomeworkStatus.archived)
            ..['activated_at'] = null
            ..['closed_at'] = null;
      expect(
        TeacherHomeworkDto.fromJson(directArchive).status,
        TeacherHomeworkStatus.archived,
      );
    });

    test('strictly validates assignment mode and canonical Student IDs', () {
      final groupWithStudents = _homeworkJson()
        ..['student_ids'] = ['30000000-0000-0000-0000-000000000001'];
      final selectedWithoutStudents = _homeworkJson()
        ..['assignment_mode'] = 'selected_students';
      final malformedStudent = _homeworkJson()
        ..['assignment_mode'] = 'selected_students'
        ..['student_ids'] = ['invalid'];
      final duplicateStudent = _homeworkJson()
        ..['assignment_mode'] = 'selected_students'
        ..['student_ids'] = [
          '30000000-0000-0000-0000-00000000000A',
          '30000000-0000-0000-0000-00000000000a',
        ];

      for (final json in [
        groupWithStudents,
        selectedWithoutStudents,
        malformedStudent,
        duplicateStudent,
      ]) {
        expect(() => TeacherHomeworkDto.fromJson(json), throwsFormatException);
      }
    });

    test('requires unique IDs and exact ordered Question positions', () {
      final duplicateId = _homeworkJson();
      final duplicateQuestions = duplicateId['questions']! as List<Object?>;
      (duplicateQuestions[1]! as Map<String, Object?>)['id'] =
          (duplicateQuestions.first! as Map<String, Object?>)['id'];
      final gapped = _homeworkJson();
      ((gapped['questions']! as List<Object?>)[1]!
              as Map<String, Object?>)['position'] =
          3;
      final outOfOrder = _homeworkJson();
      final questions = outOfOrder['questions']! as List<Object?>;
      final first = questions.removeAt(0);
      questions.insert(1, first);

      for (final json in [duplicateId, gapped, outOfOrder]) {
        expect(() => TeacherHomeworkDto.fromJson(json), throwsFormatException);
      }
    });

    test('rejects wrong checking modes and malformed typed configs', () {
      final wrongChecking = _homeworkJson();
      ((wrongChecking['questions']! as List<Object?>).first
              as Map<String, Object?>)['checking_mode'] =
          'manual';
      final tooFewOptions = _homeworkJson();
      final choice =
          (tooFewOptions['questions']! as List<Object?>).first
              as Map<String, Object?>;
      (choice['configuration']! as Map<String, Object?>)['options'] = [
        {'text': 'Only', 'is_correct': true, 'position': 1},
      ];
      final unknownNestedKey = _homeworkJson();
      final trueFalse =
          (unknownNestedKey['questions']! as List<Object?>)[2]
              as Map<String, Object?>;
      (trueFalse['configuration']! as Map<String, Object?>)['extra'] = true;
      final wrongExtensions = _homeworkJson();
      final file =
          (wrongExtensions['questions']! as List<Object?>)[5]
              as Map<String, Object?>;
      (file['configuration']! as Map<String, Object?>)['allowed_extensions'] = [
        'pdf',
        'docx',
        'pptx',
        'ppt',
      ];

      for (final json in [
        wrongChecking,
        tooFewOptions,
        unknownNestedKey,
        wrongExtensions,
      ]) {
        expect(() => TeacherHomeworkDto.fromJson(json), throwsFormatException);
      }
    });

    test('requires exact Fill Blank placeholder correspondence', () {
      for (final prompt in [
        'No placeholder',
        '{{capital}} and {{capital}}',
        '{{another_key}}',
      ]) {
        final json = _homeworkJson();
        ((json['questions']! as List<Object?>).last
                as Map<String, Object?>)['prompt'] =
            prompt;
        expect(() => TeacherHomeworkDto.fromJson(json), throwsFormatException);
      }

      final invalidKey = _homeworkJson();
      final fill =
          (invalidKey['questions']! as List<Object?>).last
              as Map<String, Object?>;
      final blank =
          ((fill['configuration']! as Map<String, Object?>)['blanks']!
                  as List<Object?>)
              .single;
      (blank! as Map<String, Object?>)['key'] = '1invalid';
      expect(
        () => TeacherHomeworkDto.fromJson(invalidKey),
        throwsFormatException,
      );
    });
  });

  group('Teacher Homework envelopes', () {
    test('strictly parses collection envelope and requested pagination', () {
      final query = const TeacherHomeworkListQuery.initial().withPage(2);
      final page = TeacherHomeworkListDto.fromJson(
        _listJson([_summaryJson()], page: 2, total: 21, lastPage: 2),
        expectedTopicId: _topicId,
        requestedQuery: query,
      ).toDomain();

      expect(page.items.single.status, TeacherHomeworkStatus.draft);
      expect(page.pagination.page, 2);
      expect(page.pagination.total, 21);
    });

    test('rejects malformed collection envelope and cross-Topic rows', () {
      final unknown = _listJson([_summaryJson()])..['unknown'] = true;
      final missingMeta = _listJson([_summaryJson()])..remove('meta');
      final wrongPage = _listJson([_summaryJson()], page: 2);
      final wrongTopic = _listJson([
        _summaryJson()..['topic_id'] = '10000000-0000-0000-0000-000000000002',
      ]);
      final duplicate = _listJson([_summaryJson(), _summaryJson()], total: 2);

      for (final json in [
        unknown,
        missingMeta,
        wrongPage,
        wrongTopic,
        duplicate,
      ]) {
        expect(
          () => TeacherHomeworkListDto.fromJson(
            json,
            expectedTopicId: _topicId,
            requestedQuery: const TeacherHomeworkListQuery.initial(),
          ),
          throwsFormatException,
        );
      }
    });

    test('detail accepts exactly the top-level data envelope', () {
      final parsed = TeacherHomeworkDetailDto.fromJson({
        'data': _homeworkJson(),
      });
      expect(parsed.homework.id, _homeworkId);

      for (final json in [
        <String, Object?>{},
        {'data': _homeworkJson(), 'message': 'unexpected'},
        {'data': null},
      ]) {
        expect(
          () => TeacherHomeworkDetailDto.fromJson(json),
          throwsFormatException,
        );
      }
    });
  });
}

Map<String, Object?> _homeworkJson({
  TeacherHomeworkStatus status = TeacherHomeworkStatus.draft,
}) {
  final activatedAt = switch (status) {
    TeacherHomeworkStatus.draft => null,
    _ => '2026-09-02T10:00:00Z',
  };
  final closedAt = switch (status) {
    TeacherHomeworkStatus.closed ||
    TeacherHomeworkStatus.archived => '2026-09-03T10:00:00Z',
    _ => null,
  };
  return {
    'id': _homeworkId,
    'topic_id': _topicId,
    'title': 'Stage 6 Homework',
    'description': null,
    'student_instructions': 'Complete every Question.',
    'assignment_mode': 'group',
    'student_ids': <Object?>[],
    'total_possible_points': 18.5,
    'deadline_at': '2026-09-10T12:00:00Z',
    'institution_timezone': 'Asia/Tashkent',
    'status': status.value,
    'attempt_policy': {
      'normal_attempts': 3,
      'official_score_policy': 'highest_valid_completed',
    },
    'activated_at': activatedAt,
    'closed_at': closedAt,
    'archived_at': status == TeacherHomeworkStatus.archived
        ? '2026-09-04T10:00:00Z'
        : null,
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-04T10:00:00Z',
    'questions': [
      for (var index = 0; index < TeacherQuestionType.values.length; index += 1)
        _questionJson(TeacherQuestionType.values[index], index + 1),
    ],
  };
}

Map<String, Object?> _questionJson(TeacherQuestionType type, int position) {
  final checkingMode = switch (type) {
    TeacherQuestionType.openWritten ||
    TeacherQuestionType.fileBased => 'manual',
    _ => 'automatic',
  };
  final prompt = type == TeacherQuestionType.fillInBlank
      ? 'The capital is {{capital}}.'
      : 'Question prompt $position';
  final configuration = switch (type) {
    TeacherQuestionType.singleChoice => {
      'options': [
        {'text': 'A', 'is_correct': true, 'position': 1},
        {'text': 'B', 'is_correct': false, 'position': 2},
      ],
    },
    TeacherQuestionType.multipleChoice => {
      'options': [
        {'text': 'A', 'is_correct': true, 'position': 1},
        {'text': 'B', 'is_correct': true, 'position': 2},
      ],
    },
    TeacherQuestionType.trueFalse => {'correct_value': true},
    TeacherQuestionType.shortWritten => {
      'accepted_answers': ['Answer', 'Alternate'],
    },
    TeacherQuestionType.openWritten => <String, Object?>{},
    TeacherQuestionType.fileBased => {
      'allowed_extensions': ['pdf', 'docx', 'ppt', 'pptx'],
    },
    TeacherQuestionType.matching => {
      'pairs': [
        {
          'client_key': '40000000-0000-0000-0000-000000000001',
          'left': 'Left',
          'right': 'Right',
        },
      ],
    },
    TeacherQuestionType.ordering => {
      'items': [
        {'text': 'First', 'correct_position': 1},
        {'text': 'Second', 'correct_position': 2},
      ],
    },
    TeacherQuestionType.fillInBlank => {
      'blanks': [
        {
          'key': 'capital',
          'position': 1,
          'accepted_answers': ['Tashkent'],
        },
      ],
    },
  };
  return {
    'id': '50000000-0000-0000-0000-${position.toString().padLeft(12, '0')}',
    'type': type.value,
    'prompt': prompt,
    'instructions': position.isEven ? null : 'Read carefully.',
    'points': position == 1 ? 0 : 1.5,
    'position': position,
    'checking_mode': checkingMode,
    'configuration': configuration,
  };
}

Map<String, Object?> _summaryJson() {
  return {
    'id': _homeworkId,
    'topic_id': _topicId,
    'title': 'Stage 6 Homework',
    'assignment_mode': 'group',
    'total_possible_points': 18.5,
    'question_count': 9,
    'deadline_at': null,
    'institution_timezone': 'Asia/Tashkent',
    'status': 'draft',
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-04T10:00:00Z',
  };
}

Map<String, Object?> _listJson(
  List<Object?> rows, {
  int page = 1,
  int total = 1,
  int lastPage = 1,
}) {
  return {
    'data': rows,
    'meta': {
      'pagination': {
        'page': page,
        'per_page': 20,
        'total': total,
        'last_page': lastPage,
      },
    },
  };
}
