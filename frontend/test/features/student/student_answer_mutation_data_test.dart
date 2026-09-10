import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/student/data/dto/student_attempt_answer_mutation_dto.dart';
import 'package:testlabuz_client/features/student/data/dto/student_homework_attempt_dto.dart';
import 'package:testlabuz_client/features/student/data/dto/student_question_dto.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_remote_data_source.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_draft.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/domain/student_submission_upload.dart';

void main() {
  test(
    'save sends exact JSON PUT, encoded IDs and no idempotency or retry',
    () async {
      final question = _question(StudentQuestionType.multipleChoice);
      final mutation = StudentMultipleChoiceDraft(
        selectedOptionIds: {_id(2), _id(1)},
      ).toMutation(question);
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(
          200,
          _envelope(question.type, _answer(question.type)),
        ),
      );
      final attemptId = _attemptId.toUpperCase();
      final result = await _repository(
        adapter,
      ).saveAnswer(attemptId, question, mutation);
      expect(result.questionId, question.id);
      expect(result.type, StudentQuestionType.multipleChoice);
      expect((result.answer as StudentChoiceAnswerValue).selectedOptionIds, [
        _id(1),
        _id(2),
      ]);
      expect(result.updatedAt, DateTime.utc(2026, 9, 8, 12, 10));
      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(
        request.path,
        '/student/attempts/${Uri.encodeComponent(attemptId)}/answers/${Uri.encodeComponent(question.id)}',
      );
      expect(
        request.uri.path,
        '/api/v1/student/attempts/$attemptId/answers/${question.id}',
      );
      expect(request.data, {
        'type': 'multiple_choice',
        'selected_option_ids': [_id(1), _id(2)],
      });
      expect(request.contentType, Headers.jsonContentType);
      expect(request.queryParameters, isEmpty);
      expect(request.followRedirects, isFalse);
      expect(
        request.headers.keys.any(
          (key) => key.toLowerCase() == 'idempotency-key',
        ),
        isFalse,
      );
    },
  );

  test(
    'invalid route IDs and mutation type mismatch never reach transport',
    () {
      final question = _question(StudentQuestionType.trueFalse);
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(
          200,
          _envelope(question.type, _answer(question.type)),
        ),
      );
      final source = _source(adapter);
      const mutation = StudentTrueFalseMutation(value: true);
      for (final invalid in [
        '',
        '../attempt',
        '$_attemptId/extra',
        '$_attemptId\n',
      ]) {
        expect(
          () => source.saveAnswer(invalid, question, mutation),
          throwsArgumentError,
        );
        final invalidQuestion = StudentQuestion(
          id: invalid,
          type: question.type,
          prompt: question.prompt,
          instructions: null,
          points: 1,
          position: 1,
          answerUi: question.answerUi,
        );
        expect(
          () => source.saveAnswer(_attemptId, invalidQuestion, mutation),
          throwsArgumentError,
        );
      }
      expect(
        () => source.saveAnswer(
          _attemptId,
          question,
          const StudentShortWrittenMutation(text: 'wrong type'),
        ),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'all non-file saved answer shapes parse through GET and mutation parser',
    () async {
      for (final type in StudentQuestionType.values.where(
        (type) => type != StudentQuestionType.fileBased,
      )) {
        final question = _question(type);
        final shared = parseStudentAttemptAnswerValue(_answer(type), question);
        final get = StudentHomeworkAttemptDto.fromJson(
          _attempt(type, _answer(type)),
        ).answers.single.value;
        final mutation = StudentAnswerDraft.fromAnswer(
          question,
          shared,
        ).toMutation(question);
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(200, _envelope(type, _answer(type))),
        );
        final saved = await _repository(
          adapter,
        ).saveAnswer(_attemptId, question, mutation);
        expect(
          StudentAnswerDraft.fromAnswer(
            question,
            get,
          ).isDirty(question, saved.answer),
          isFalse,
        );
        expect(saved.answer.runtimeType, shared.runtimeType);
        expect(adapter.requests.single.data, mutation.toJson());
      }
    },
  );

  test(
    'every clearable type accepts only a null answer and null timestamp pair',
    () async {
      for (final type in [
        StudentQuestionType.multipleChoice,
        StudentQuestionType.shortWritten,
        StudentQuestionType.openWritten,
        StudentQuestionType.matching,
        StudentQuestionType.ordering,
        StudentQuestionType.fillInBlank,
      ]) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(200, _envelope(type, null, updatedAt: null)),
        );
        final question = _question(type);
        final result = await _repository(adapter).saveAnswer(
          _attemptId,
          question,
          StudentAnswerDraft.fromAnswer(question, null).toMutation(question),
        );
        expect(result.answer, isNull);
        expect(result.updatedAt, isNull);
      }
    },
  );

  test(
    'all unexpected 2xx statuses are invalidResponse without replay',
    () async {
      final question = _question(StudentQuestionType.trueFalse);
      for (var status = 201; status < 300; status++) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(
            status,
            _envelope(question.type, _answer(question.type)),
          ),
        );
        await expectLater(
          _repository(adapter).saveAnswer(
            _attemptId,
            question,
            const StudentTrueFalseMutation(value: true),
          ),
          throwsA(_failureKind(ApiFailureKind.invalidResponse)),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test(
    'success keys, target, type and timestamp nullability are exact',
    () async {
      final type = StudentQuestionType.shortWritten;
      final payloads = <Object?>[
        null,
        [],
        {},
        {'data': null},
        {..._envelope(type, _answer(type)), 'message': 'unexpected'},
        {'data': _result(type, _answer(type))..remove('type')},
        {'data': _result(type, _answer(type))..['question_id'] = _id(99)},
        {'data': _result(type, _answer(type))..['question_id'] = 'bad-id'},
        {'data': _result(type, _answer(type))..['type'] = 'open_written'},
        {'data': _result(type, _answer(type))..['type'] = 'unsupported'},
        {'data': _result(type, _answer(type))..['score'] = 1},
        {'data': _result(type, _answer(type))..['checking_status'] = 'checked'},
        {'data': _result(type, _answer(type))..['feedback'] = 'private'},
        _envelope(type, null),
        _envelope(type, _answer(type), updatedAt: null),
        _envelope(type, {'text': 'answer', 'score': 1}),
        for (final invalid in [
          '2026-09-08T12:10Z',
          '2026-09-08T12:10:00.000Z',
          '2026-09-08T12:10:00,1Z',
          '2026-09-08T12:10:00+00:00',
          '2026-09-08 12:10:00Z',
          '2026-02-30T12:10:00Z',
          '2026-09-08T24:10:00Z',
          'not-a-date',
          42,
        ])
          _envelope(type, _answer(type), updatedAt: invalid),
      ];
      for (final payload in payloads) {
        final adapter = _RecordingAdapter((_) => _jsonResponse(200, payload));
        await expectLater(
          _repository(adapter).saveAnswer(
            _attemptId,
            _question(type),
            const StudentShortWrittenMutation(text: 'answer'),
          ),
          throwsA(_failureKind(ApiFailureKind.invalidResponse)),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test(
    'null single/boolean answers and requested type mismatch are rejected',
    () {
      for (final type in [
        StudentQuestionType.singleChoice,
        StudentQuestionType.trueFalse,
      ]) {
        expect(
          () => StudentAttemptAnswerMutationDto.fromJson(
            _envelope(type, null, updatedAt: null),
            question: _question(type),
            requestedType: type,
          ),
          throwsFormatException,
        );
      }
      expect(
        () => StudentAttemptAnswerMutationDto.fromJson(
          _envelope(StudentQuestionType.shortWritten, {'text': 'text'}),
          question: _question(StudentQuestionType.shortWritten),
          requestedType: StudentQuestionType.openWritten,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'GET and mutation share child, selection, position and persisted text rules',
    () {
      for (final invalid in <(StudentQuestionType, Object?)>[
        (
          StudentQuestionType.singleChoice,
          {
            'selected_option_ids': [_id(99)],
          },
        ),
        (
          StudentQuestionType.singleChoice,
          {
            'selected_option_ids': [_id(1), _id(2)],
          },
        ),
        (
          StudentQuestionType.multipleChoice,
          {
            'selected_option_ids': [_id(1), _id(2), _id(3)],
          },
        ),
        (
          StudentQuestionType.multipleChoice,
          {
            'selected_option_ids': [_id(1), _id(1).toUpperCase()],
          },
        ),
        (StudentQuestionType.multipleChoice, {'selected_option_ids': []}),
        (
          StudentQuestionType.multipleChoice,
          {
            'selected_option_ids': ['malformed'],
          },
        ),
        (StudentQuestionType.trueFalse, {'value': 'true'}),
        (StudentQuestionType.trueFalse, {'value': 1}),
        (StudentQuestionType.shortWritten, {'text': ' \n'}),
        (StudentQuestionType.openWritten, {'text': ''}),
        (
          StudentQuestionType.matching,
          {
            'pairs': [
              {'left_item_id': _id(99), 'right_item_id': _id(4)},
            ],
          },
        ),
        (
          StudentQuestionType.matching,
          {
            'pairs': [
              {'left_item_id': _id(1), 'right_item_id': _id(1)},
            ],
          },
        ),
        (
          StudentQuestionType.matching,
          {
            'pairs': [
              {'left_item_id': _id(1), 'right_item_id': _id(4)},
              {'left_item_id': _id(2), 'right_item_id': _id(4)},
            ],
          },
        ),
        (StudentQuestionType.matching, {'pairs': []}),
        (
          StudentQuestionType.ordering,
          {
            'items': [
              {'item_id': _id(99), 'position': 1},
            ],
          },
        ),
        (
          StudentQuestionType.ordering,
          {
            'items': [
              {'item_id': _id(1), 'position': 4},
            ],
          },
        ),
        (
          StudentQuestionType.ordering,
          {
            'items': [
              {'item_id': _id(1), 'position': 0},
            ],
          },
        ),
        (
          StudentQuestionType.ordering,
          {
            'items': [
              {'item_id': _id(1), 'position': 1},
              {'item_id': _id(2), 'position': 1},
            ],
          },
        ),
        (StudentQuestionType.ordering, {'items': []}),
        (
          StudentQuestionType.fillInBlank,
          {
            'values': [
              {'blank_id': _id(99), 'text': 'answer'},
            ],
          },
        ),
        (
          StudentQuestionType.fillInBlank,
          {
            'values': [
              {'blank_id': _id(1), 'text': ' \t'},
            ],
          },
        ),
        (StudentQuestionType.fillInBlank, {'values': []}),
      ]) {
        final question = _question(invalid.$1);
        expect(
          () => parseStudentAttemptAnswerValue(invalid.$2, question),
          throwsFormatException,
        );
        expect(
          () => StudentHomeworkAttemptDto.fromJson(
            _attempt(invalid.$1, invalid.$2),
          ),
          throwsFormatException,
        );
        expect(
          () => StudentAttemptAnswerMutationDto.fromJson(
            _envelope(invalid.$1, invalid.$2),
            question: question,
            requestedType: invalid.$1,
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'shared parser and existing mutation DTO preserve strict file metadata',
    () {
      final question = _question(StudentQuestionType.fileBased);
      final answer = _answer(question.type);
      final selected = StudentSubmissionUploadFile(
        name: 'work.pdf',
        length: 128,
        openRead: () => Stream.value(List.filled(128, 1)),
      );
      expect(
        parseStudentAttemptAnswerValue(answer, question),
        isA<StudentFileAnswerValue>(),
      );
      expect(
        StudentHomeworkAttemptDto.fromJson(
          _attempt(question.type, answer),
        ).answers.single.value,
        isA<StudentFileAnswerValue>(),
      );
      final saved = StudentAttemptAnswerMutationDto.fromJson(
        _envelope(question.type, answer),
        question: question,
        requestedType: question.type,
        selectedFile: selected,
      );
      expect(saved.answer, isA<StudentFileAnswerValue>());
      expect(saved.updatedAt, DateTime.utc(2026, 9, 8, 12, 10));
      for (final invalidFile in [
        {
          'id': _id(9),
          'original_name': 'work.pdf',
          'extension': 'exe',
          'size_bytes': 1,
        },
        {
          'id': _id(9),
          'original_name': 'work.pdf',
          'extension': 'pdf',
          'size_bytes': 0,
        },
        {
          'id': _id(9),
          'original_name': 'work.pdf',
          'extension': 'pdf',
          'size_bytes': 15728641,
        },
        {
          'id': 'bad',
          'original_name': 'work.pdf',
          'extension': 'pdf',
          'size_bytes': 1,
        },
        {
          'id': _id(9),
          'original_name': 'work.pdf',
          'extension': 'pdf',
          'size_bytes': 128,
          'checksum': 'private',
        },
        {
          'id': _id(9),
          'original_name': 'work.pdf',
          'extension': 'pdf',
          'size_bytes': 128,
          'storage_path': 'private',
        },
      ]) {
        expect(
          () => parseStudentAttemptAnswerValue({'file': invalidFile}, question),
          throwsFormatException,
        );
        expect(
          () => StudentAttemptAnswerMutationDto.fromJson(
            _envelope(question.type, {'file': invalidFile}),
            question: question,
            requestedType: question.type,
            selectedFile: selected,
          ),
          throwsFormatException,
        );
      }
      for (final invalid in [
        _envelope(question.type, null, updatedAt: null),
        _envelope(question.type, null),
        _envelope(question.type, answer, updatedAt: null),
        {'data': _result(question.type, answer)..['question_id'] = _id(99)},
        {'data': _result(question.type, answer)..['type'] = 'short_written'},
      ]) {
        expect(
          () => StudentAttemptAnswerMutationDto.fromJson(
            invalid,
            question: question,
            requestedType: question.type,
            selectedFile: selected,
          ),
          throwsFormatException,
        );
      }
      for (final invalidQuestion in [
        _question(StudentQuestionType.shortWritten),
        StudentQuestion(
          id: question.id,
          type: question.type,
          prompt: question.prompt,
          instructions: null,
          points: 1,
          position: 1,
          answerUi: const StudentEmptyAnswerUi(),
        ),
      ]) {
        expect(
          () => StudentAttemptAnswerMutationDto.fromJson(
            _envelope(question.type, answer),
            question: invalidQuestion,
            requestedType: question.type,
            selectedFile: selected,
          ),
          throwsFormatException,
        );
      }
      expect(
        () => StudentAttemptAnswerMutationDto.fromJson(
          _envelope(question.type, answer),
          question: question,
          requestedType: StudentQuestionType.shortWritten,
          selectedFile: selected,
        ),
        throwsFormatException,
      );
    },
  );

  test('historical GET file policy survives a lower current upload limit', () {
    final type = StudentQuestionType.fileBased;
    final questionJson = _questionJson(type);
    questionJson['answer_ui'] = {
      'allowed_extensions': ['pdf', 'docx', 'ppt', 'pptx'],
      'max_size_bytes': 64,
    };
    final question = StudentQuestionDto.fromJson(questionJson).toDomain();
    final attemptJson = _attempt(type, _answer(type));
    attemptJson['questions'] = [questionJson];
    final historical = StudentHomeworkAttemptDto.fromJson(attemptJson);
    expect(
      (historical.answers.single.value as StudentFileAnswerValue)
          .file
          .sizeBytes,
      128,
    );
    expect(
      () => StudentAttemptAnswerMutationDto.fromJson(
        _envelope(type, _answer(type)),
        question: question,
        requestedType: type,
        selectedFile: StudentSubmissionUploadFile(
          name: 'work.pdf',
          length: 128,
          openRead: () => Stream.value(List.filled(128, 1)),
        ),
      ),
      throwsFormatException,
    );
  });

  test('FE-003 non-file JSON mutation cannot upload a file Question', () async {
    final question = _question(StudentQuestionType.fileBased);
    final adapter = _RecordingAdapter(
      (_) => throw StateError('JSON Save must not send file answers.'),
    );
    expect(
      () => StudentAnswerDraft.fromAnswer(question, null),
      throwsArgumentError,
    );
    await expectLater(
      _repository(adapter).saveAnswer(
        _attemptId,
        question,
        const StudentShortWrittenMutation(text: 'not a file upload'),
      ),
      throwsArgumentError,
    );
    expect(adapter.requests, isEmpty);
  });

  test(
    'malformed JSON and uncertain transport failures never retry PUT',
    () async {
      final question = _question(StudentQuestionType.trueFalse);
      for (final failure in [
        (DioExceptionType.connectionError, ApiFailureKind.connection),
        (DioExceptionType.sendTimeout, ApiFailureKind.timeout),
        (DioExceptionType.receiveTimeout, ApiFailureKind.timeout),
        (DioExceptionType.connectionTimeout, ApiFailureKind.timeout),
        (DioExceptionType.cancel, ApiFailureKind.cancelled),
        (DioExceptionType.unknown, ApiFailureKind.unknown),
      ]) {
        final adapter = _RecordingAdapter(
          (request) =>
              throw DioException(requestOptions: request, type: failure.$1),
        );
        await expectLater(
          _repository(adapter).saveAnswer(
            _attemptId,
            question,
            const StudentTrueFalseMutation(value: true),
          ),
          throwsA(_failureKind(failure.$2)),
        );
        expect(adapter.requests, hasLength(1));
      }
      final adapter = _RecordingAdapter(
        (_) => ResponseBody.fromString(
          '{"data":',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      await expectLater(
        _repository(adapter).saveAnswer(
          _attemptId,
          question,
          const StudentTrueFalseMutation(value: true),
        ),
        throwsA(_failureKind(ApiFailureKind.invalidResponse)),
      );
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    'structured errors retain machine code, status and field validation',
    () async {
      for (final failure in [
        (401, 'authentication_required'),
        (403, 'forbidden'),
        (404, 'resource_not_found'),
        (409, 'task_not_active'),
        (409, 'task_closed'),
        (409, 'task_archived'),
        (409, 'deadline_passed'),
        (409, 'attempt_not_editable'),
        (409, 'business_conflict'),
        (422, 'validation_failed'),
        (422, 'selection_limit_exceeded'),
        (500, 'server_error'),
      ]) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(failure.$1, {
            'message': 'Safe error.',
            'code': failure.$2,
            'errors': {
              'answer': ['Invalid answer.'],
            },
            'request_id': 'answer-request-1',
          }),
        );
        await expectLater(
          _repository(adapter).saveAnswer(
            _attemptId,
            _question(StudentQuestionType.trueFalse),
            const StudentTrueFalseMutation(value: true),
          ),
          throwsA(
            isA<ApiRequestException>()
                .having((error) => error.failure.serverCode, 'code', failure.$2)
                .having(
                  (error) => error.failure.statusCode,
                  'status',
                  failure.$1,
                )
                .having((error) => error.failure.fieldErrors, 'fields', {
                  'answer': ['Invalid answer.'],
                }),
          ),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );
}

StudentHomeworkAttemptRepositoryImpl _repository(_RecordingAdapter adapter) =>
    StudentHomeworkAttemptRepositoryImpl(remoteDataSource: _source(adapter));

StudentHomeworkAttemptRemoteDataSource _source(_RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://example.test/api/v1',
      contentType: Headers.jsonContentType,
    ),
  );
  dio.httpClientAdapter = adapter;
  return StudentHomeworkAttemptRemoteDataSource(
    dio: dio,
    failureMapper: const DioFailureMapper(),
  );
}

TypeMatcher<ApiRequestException> _failureKind(ApiFailureKind kind) =>
    isA<ApiRequestException>().having(
      (error) => error.failure.kind,
      'kind',
      kind,
    );

ResponseBody _jsonResponse(int status, Object? payload) =>
    ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return await respond(options);
  }

  @override
  void close({bool force = false}) {}
}

StudentQuestion _question(StudentQuestionType type) =>
    StudentQuestionDto.fromJson(_questionJson(type)).toDomain();

Map<String, Object?> _questionJson(StudentQuestionType type) => {
  'id': _questionId,
  'type': type.apiValue,
  'prompt': 'Question',
  'instructions': null,
  'points': 1,
  'position': 1,
  'answer_ui': switch (type) {
    StudentQuestionType.singleChoice || StudentQuestionType.multipleChoice => {
      'options': [
        for (var id = 1; id <= 3; id++) {'id': _id(id), 'text': 'Option $id'},
      ],
      if (type == StudentQuestionType.multipleChoice) 'max_selections': 2,
    },
    StudentQuestionType.matching => {
      'left_items': [
        for (var id = 1; id <= 3; id++) {'id': _id(id), 'text': 'Left $id'},
      ],
      'right_items': [
        for (var id = 4; id <= 6; id++) {'id': _id(id), 'text': 'Right $id'},
      ],
    },
    StudentQuestionType.ordering => {
      'items': [
        for (var id = 1; id <= 3; id++) {'id': _id(id), 'text': 'Item $id'},
      ],
    },
    StudentQuestionType.fillInBlank => {
      'blanks': [
        for (var id = 1; id <= 3; id++)
          {'id': _id(id), 'key': 'blank$id', 'position': id},
      ],
    },
    StudentQuestionType.fileBased => {
      'allowed_extensions': ['pdf', 'docx', 'ppt', 'pptx'],
      'max_size_bytes': 15728640,
    },
    _ => <String, Object?>{},
  },
};

Object _answer(StudentQuestionType type) => switch (type) {
  StudentQuestionType.singleChoice => {
    'selected_option_ids': [_id(1)],
  },
  StudentQuestionType.multipleChoice => {
    'selected_option_ids': [_id(1), _id(2)],
  },
  StudentQuestionType.trueFalse => {'value': true},
  StudentQuestionType.shortWritten ||
  StudentQuestionType.openWritten => {'text': ' Exact answer 🙂 '},
  StudentQuestionType.matching => {
    'pairs': [
      {'left_item_id': _id(1), 'right_item_id': _id(5)},
    ],
  },
  StudentQuestionType.ordering => {
    'items': [
      {'item_id': _id(3), 'position': 1},
    ],
  },
  StudentQuestionType.fillInBlank => {
    'values': [
      {'blank_id': _id(1), 'text': ' Exact blank 🙂 '},
    ],
  },
  StudentQuestionType.fileBased => {
    'file': {
      'id': _id(9),
      'original_name': 'work.pdf',
      'extension': 'pdf',
      'size_bytes': 128,
    },
  },
};

Map<String, Object?> _envelope(
  StudentQuestionType type,
  Object? answer, {
  Object? updatedAt = _updatedAt,
}) => {'data': _result(type, answer, updatedAt: updatedAt)};

Map<String, Object?> _result(
  StudentQuestionType type,
  Object? answer, {
  Object? updatedAt = _updatedAt,
}) => {
  'question_id': _questionId,
  'type': type.apiValue,
  'answer': answer,
  'updated_at': updatedAt,
};

Map<String, Object?> _attempt(StudentQuestionType type, Object? answer) => {
  'id': _attemptId,
  'assessment_id': _id(70),
  'attempt_number': 1,
  'status': 'in_progress',
  'started_at': '2026-09-08T12:00:00Z',
  'submitted_at': null,
  'finalized_at': null,
  'finalization_reason': null,
  'deadline_at': null,
  'questions': [_questionJson(type)],
  'answers': [_result(type, answer)],
};

String _id(int number) =>
    'a0000000-0000-0000-0000-${number.toString().padLeft(12, '0')}';
const _attemptId = 'a1000000-0000-0000-0000-000000000001';
const _questionId = 'a2000000-0000-0000-0000-000000000001';
const _updatedAt = '2026-09-08T12:10:00Z';
