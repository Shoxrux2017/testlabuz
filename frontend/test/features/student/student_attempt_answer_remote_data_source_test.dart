import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/student/data/dto/student_question_dto.dart';
import 'package:testlabuz_client/features/student/data/student_attempt_answer_remote_data_source.dart';
import 'package:testlabuz_client/features/student/data/student_attempt_answer_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_attempt_answer.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/domain/student_submission_upload.dart';

import 'student_blitz_test_support.dart';

void main() {
  group('typed answer PUT', () {
    test('sends the exact shared route and body once, without a key', () async {
      final adapter = _Adapter(
        (_) => blitzJsonResponse(200, {
          'data': blitzAnswerJson(StudentQuestionType.shortWritten, 1),
        }),
      );
      final question = _question(StudentQuestionType.shortWritten);
      final result = await _repository(adapter).saveAnswer(
        studentBlitzAttemptId,
        question,
        const StudentShortWrittenMutation(text: '  Exact saved text\n'),
      );

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(
        request.uri.toString(),
        'https://example.test/api/v1/student/attempts/'
        '$studentBlitzAttemptId/answers/${question.id}',
      );
      expect(request.uri.query, isEmpty);
      expect(request.followRedirects, isFalse);
      expect(request.headers.containsKey('Idempotency-Key'), isFalse);
      expect(request.data, {
        'type': 'short_written',
        'text': '  Exact saved text\n',
      });
      expect(result.questionId, question.id);
      expect(result.type, StudentQuestionType.shortWritten);
      expect(
        (result.answer! as StudentTextAnswerValue).text,
        '  Exact saved text\n',
      );
      expect(result.updatedAt, DateTime.utc(2026, 9, 17, 12, 1));
    });

    test('a cleared answer returns null answer and timestamp', () async {
      final adapter = _Adapter(
        (_) => blitzJsonResponse(200, {
          'data': {
            'question_id': blitzUuid(101),
            'type': 'open_written',
            'answer': null,
            'updated_at': null,
          },
        }),
      );
      final result = await _repository(adapter).saveAnswer(
        studentBlitzAttemptId,
        _question(StudentQuestionType.openWritten),
        const StudentOpenWrittenMutation(text: ''),
      );
      expect(adapter.requests.single.data, {
        'type': 'open_written',
        'text': '',
      });
      expect(result.answer, isNull);
      expect(result.updatedAt, isNull);
    });

    test('a mutation of another type is rejected before any request', () {
      final adapter = _Adapter((_) => blitzJsonResponse(200, {}));
      expect(
        () => _source(adapter).saveAnswer(
          studentBlitzAttemptId,
          _question(StudentQuestionType.trueFalse),
          const StudentShortWrittenMutation(text: 'x'),
        ),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });

    for (final (name, status, payload) in [
      (
        'another Question',
        200,
        {
          'data': {
            ...blitzAnswerJson(StudentQuestionType.shortWritten, 2),
            'type': 'short_written',
          },
        },
      ),
      (
        'another type',
        200,
        {'data': blitzAnswerJson(StudentQuestionType.openWritten, 1)},
      ),
      (
        'an unexpected message key',
        200,
        {
          'data': blitzAnswerJson(StudentQuestionType.shortWritten, 1),
          'message': 'Saved.',
        },
      ),
      (
        'a non-200 success status',
        201,
        {'data': blitzAnswerJson(StudentQuestionType.shortWritten, 1)},
      ),
    ]) {
      test('$name is an invalid response', () async {
        final adapter = _Adapter((_) => blitzJsonResponse(status, payload));
        await expectLater(
          _repository(adapter).saveAnswer(
            studentBlitzAttemptId,
            _question(StudentQuestionType.shortWritten),
            const StudentShortWrittenMutation(text: 'x'),
          ),
          throwsA(_failureKind(ApiFailureKind.invalidResponse)),
        );
        expect(adapter.requests, hasLength(1));
      });
    }

    test('a server failure is mapped once and never retried', () async {
      final adapter = _Adapter(
        (_) => blitzErrorResponse(409, ApiErrorCodes.blitzTimeExpired),
      );
      await expectLater(
        _repository(adapter).saveAnswer(
          studentBlitzAttemptId,
          _question(StudentQuestionType.trueFalse),
          const StudentTrueFalseMutation(value: true),
        ),
        throwsA(
          isA<ApiRequestException>().having(
            (error) => error.failure.serverCode,
            'code',
            ApiErrorCodes.blitzTimeExpired,
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });

    test('a 500 is mapped once and never retried', () async {
      final adapter = _Adapter(
        (_) => blitzErrorResponse(500, ApiErrorCodes.serverError),
      );
      await expectLater(
        _repository(adapter).saveAnswer(
          studentBlitzAttemptId,
          _question(StudentQuestionType.trueFalse),
          const StudentTrueFalseMutation(value: true),
        ),
        throwsA(_failureKind(ApiFailureKind.server)),
      );
      expect(adapter.requests, hasLength(1));
    });
  });

  group('file answer multipart PUT', () {
    test('uploads the exact multipart body and reports progress', () async {
      final adapter = _Adapter(
        (_) => blitzJsonResponse(200, {
          'data': blitzAnswerJson(StudentQuestionType.fileBased, 1),
        }),
      );
      final progress = <(int, int)>[];
      final result = await _repository(adapter).uploadFileAnswer(
        studentBlitzAttemptId,
        _question(StudentQuestionType.fileBased),
        _file(),
        onProgress: (sent, total) => progress.add((sent, total)),
      );

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(
        request.uri.path,
        '/api/v1/student/attempts/$studentBlitzAttemptId/answers/'
        '${blitzUuid(101)}',
      );
      expect(request.headers.containsKey('Idempotency-Key'), isFalse);
      final form = request.data as FormData;
      expect(form.fields.single.key, 'type');
      expect(form.fields.single.value, 'file_based');
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'blitz.pdf');
      expect(utf8.decode(adapter.bodies.single), contains('file_based'));
      expect(progress, isNotEmpty);
      expect(progress.last.$1, progress.last.$2);
      final file = (result.answer! as StudentFileAnswerValue).file;
      expect(file.id, blitzUuid(99));
      expect(file.sizeBytes, 2048);
    });

    test(
      'a response that does not match the selected file is invalid',
      () async {
        final adapter = _Adapter(
          (_) => blitzJsonResponse(200, {
            'data': blitzAnswerJson(StudentQuestionType.fileBased, 1),
          }),
        );
        await expectLater(
          _repository(adapter).uploadFileAnswer(
            studentBlitzAttemptId,
            _question(StudentQuestionType.fileBased),
            _file(name: 'other.pdf'),
          ),
          throwsA(_failureKind(ApiFailureKind.invalidResponse)),
        );
      },
    );

    test('an unreadable local source is not a server outcome', () async {
      final adapter = _Adapter((_) => blitzJsonResponse(200, {}));
      await expectLater(
        _repository(adapter).uploadFileAnswer(
          studentBlitzAttemptId,
          _question(StudentQuestionType.fileBased),
          StudentSubmissionUploadFile(
            name: 'blitz.pdf',
            length: 2048,
            openRead: () => Stream.error(const _SourceReadFailure()),
          ),
        ),
        throwsA(isA<StudentSubmissionSourceUnavailable>()),
      );
    });

    test('a non-file Question cannot upload a file', () {
      final adapter = _Adapter((_) => blitzJsonResponse(200, {}));
      expect(
        () => _source(adapter).uploadFileAnswer(
          studentBlitzAttemptId,
          _question(StudentQuestionType.openWritten),
          _file(),
        ),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });
  });
}

class _SourceReadFailure implements Exception {
  const _SourceReadFailure();
}

StudentQuestion _question(StudentQuestionType type) =>
    StudentQuestionDto.fromJson(blitzQuestionJson(type, 1)).toDomain();

StudentSubmissionUploadFile _file({String name = 'blitz.pdf'}) =>
    StudentSubmissionUploadFile(
      name: name,
      length: 2048,
      openRead: () => Stream.value(List<int>.filled(2048, 7)),
    );

StudentAttemptAnswerRemoteDataSource _source(_Adapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://example.test/api/v1',
      contentType: Headers.jsonContentType,
    ),
  )..httpClientAdapter = adapter;
  return StudentAttemptAnswerRemoteDataSource(
    dio: dio,
    failureMapper: const DioFailureMapper(),
  );
}

StudentAttemptAnswerRepositoryImpl _repository(_Adapter adapter) =>
    StudentAttemptAnswerRepositoryImpl(remoteDataSource: _source(adapter));

TypeMatcher<ApiRequestException> _failureKind(ApiFailureKind kind) =>
    isA<ApiRequestException>().having(
      (error) => error.failure.kind,
      'kind',
      kind,
    );

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  final bodies = <List<int>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      bodies.add(
        await requestStream.fold<List<int>>(
          [],
          (bytes, chunk) => bytes..addAll(chunk),
        ),
      );
    }
    return await respond(options);
  }

  @override
  void close({bool force = false}) {}
}
