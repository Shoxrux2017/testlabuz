import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/student/data/dto/student_homework_submit_dto.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_remote_data_source.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_repository.dart';

void main() {
  test('repository forwards all three Submit arguments unchanged', () async {
    final source = _RecordingSubmitSource();
    final StudentHomeworkAttemptRepository repository =
        StudentHomeworkAttemptRepositoryImpl(remoteDataSource: source);
    final attemptId = _attemptId.toUpperCase();
    final homeworkId = _homeworkId.toUpperCase();
    final key = _key.toUpperCase();
    final result = await repository.submitAttempt(attemptId, homeworkId, key);
    expect(source.arguments, (attemptId, homeworkId, key));
    expect(result.attempt.id, _attemptId);
    expect(result.attempt.assessmentId, _homeworkId);
  });

  for (final status in [
    StudentHomeworkAttemptStatus.submitted,
    StudentHomeworkAttemptStatus.waitingForReview,
    StudentHomeworkAttemptStatus.checked,
  ]) {
    test(
      'Submit accepts explicit ${status.apiValue} and preserves exact request',
      () async {
        final adapter = _RecordingAdapter(
          (_) =>
              _jsonResponse(200, _envelope(_attempt(status: status.apiValue))),
        );
        final StudentHomeworkAttemptRepository repository = _repository(
          adapter,
        );
        final attemptId = _attemptId.toUpperCase();
        final homeworkId = _homeworkId.toUpperCase();
        final key = _key.toUpperCase();
        final result = await repository.submitAttempt(
          attemptId,
          homeworkId,
          key,
        );

        expect(result.attempt.id, _attemptId);
        expect(result.attempt.assessmentId, _homeworkId);
        expect(result.attempt.status, status);
        expect(
          result.attempt.finalizationReason,
          StudentHomeworkAttemptFinalizationReason.studentSubmit,
        );
        expect(result.attempt.submittedAt, DateTime.utc(2026, 9, 8, 12, 10));
        expect(result.attempt.finalizedAt, result.attempt.submittedAt);
        expect(result.attempt.answers, isEmpty);
        expect(adapter.request.method, 'POST');
        expect(
          adapter.request.path,
          '/student/attempts/${Uri.encodeComponent(attemptId)}/submit',
        );
        expect(
          adapter.request.uri.path,
          '/api/v1/student/attempts/$attemptId/submit',
        );
        expect(adapter.request.data, const <String, Object?>{});
        expect(adapter.request.queryParameters, isEmpty);
        expect(adapter.request.followRedirects, isFalse);
        expect(adapter.request.headers['Idempotency-Key'], key);
        expect(
          adapter.request.headers.keys.where(
            (header) => header.toLowerCase() == 'idempotency-key',
          ),
          hasLength(1),
        );
        expect(adapter.requests, hasLength(1));
      },
    );
  }

  test('DTO compares canonical response IDs case-insensitively', () {
    final dto = StudentHomeworkSubmitDto.fromJson(
      _envelope(
        _attempt()
          ..['id'] = _attemptId.toUpperCase()
          ..['assessment_id'] = _homeworkId.toUpperCase(),
      ),
      expectedAttemptId: _attemptId,
      expectedHomeworkId: _homeworkId,
    );
    expect(dto.toDomain().attempt.id, _attemptId.toUpperCase());
    expect(dto.toDomain().attempt.assessmentId, _homeworkId.toUpperCase());
  });

  test('all three UUID inputs are validated before any transport', () async {
    final adapter = _RecordingAdapter(
      (_) => _jsonResponse(200, _envelope(_attempt())),
    );
    final source = _source(adapter);
    final StudentHomeworkAttemptRepository repository = _repository(adapter);
    for (final invalid in [
      '',
      '../attempts',
      '$_attemptId/extra',
      ' $_attemptId',
      _attemptId.replaceAll('-', ''),
      '$_attemptId\n',
    ]) {
      final argumentSets = [
        (invalid, _homeworkId, _key),
        (_attemptId, invalid, _key),
        (_attemptId, _homeworkId, invalid),
      ];
      for (final arguments in argumentSets) {
        expect(
          () => source.submitAttempt(arguments.$1, arguments.$2, arguments.$3),
          throwsArgumentError,
        );
        await expectLater(
          repository.submitAttempt(arguments.$1, arguments.$2, arguments.$3),
          throwsArgumentError,
        );
      }
    }
    expect(adapter.requests, isEmpty);
  });

  test('DTO rejects invalid expected UUIDs before comparing ownership', () {
    for (final invalid in [
      '',
      '../attempts',
      _attemptId.replaceAll('-', ''),
      '$_attemptId\n',
    ]) {
      expect(
        () => StudentHomeworkSubmitDto.fromJson(
          _envelope(_attempt()),
          expectedAttemptId: invalid,
          expectedHomeworkId: _homeworkId,
        ),
        throwsFormatException,
      );
      expect(
        () => StudentHomeworkSubmitDto.fromJson(
          _envelope(_attempt()),
          expectedAttemptId: _attemptId,
          expectedHomeworkId: invalid,
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'every successful HTTP status other than 200 is invalid without retry',
    () async {
      for (var status = 201; status < 300; status += 1) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(status, _envelope(_attempt())),
        );
        await expectLater(
          _repository(adapter).submitAttempt(_attemptId, _homeworkId, _key),
          throwsA(_failureKind(ApiFailureKind.invalidResponse)),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  final invalidPayloads = <String, Object?>{
    'null envelope': null,
    'array envelope': [],
    'empty envelope': {},
    'missing message': {'data': _attempt()},
    'extra top-level key': _envelope(_attempt())..['extra'] = true,
    'score at envelope': _envelope(_attempt())..['score'] = 10,
    'wrong message': _envelope(_attempt())..['message'] = 'Submitted.',
    'non-string message': _envelope(_attempt())..['message'] = 1,
    'missing data': {'message': 'Homework submitted successfully.'},
    'null Attempt': _envelope(null),
    'wrong Attempt ID': _envelope(_attempt()..['id'] = _key),
    'wrong Homework ID': _envelope(_attempt()..['assessment_id'] = _key),
    'invalid Attempt UUID': _envelope(_attempt()..['id'] = '../attempts'),
    'invalid Homework UUID': _envelope(
      _attempt()..['assessment_id'] = 'invalid',
    ),
    'in-progress Attempt': _envelope(
      _attempt(status: 'in_progress')
        ..['submitted_at'] = null
        ..['finalized_at'] = null
        ..['finalization_reason'] = null,
    ),
    'deadline finalization': _envelope(
      _attempt()
        ..['submitted_at'] = null
        ..['finalized_at'] = '2026-09-10T13:00:00Z'
        ..['finalization_reason'] = 'homework_deadline_auto_submit',
    ),
    'closed finalization': _envelope(
      _attempt()
        ..['submitted_at'] = null
        ..['finalization_reason'] = 'task_closed_auto_finalize',
    ),
    'terminal without reason': _envelope(
      _attempt()..['finalization_reason'] = null,
    ),
    'null submitted timestamp': _envelope(_attempt()..['submitted_at'] = null),
    'missing submitted timestamp': _envelope(
      _attempt()..remove('submitted_at'),
    ),
    'different finalization timestamp': _envelope(
      _attempt()..['finalized_at'] = '2026-09-08T12:11:00Z',
    ),
    'missing answers': _envelope(_attempt()..remove('answers')),
    'score field': _envelope(_attempt()..['score'] = 10),
    'checking field': _envelope(_attempt()..['checking_status'] = 'checked'),
    'malformed timestamp': _envelope(
      _attempt()..['started_at'] = '2026-09-08T12:00Z',
    ),
    'submission at deadline': _envelope(
      _attempt()
        ..['submitted_at'] = '2026-09-10T13:00:00Z'
        ..['finalized_at'] = '2026-09-10T13:00:00Z',
    ),
    'unknown saved Question': _envelope(
      _attempt()
        ..['answers'] = [
          {
            'question_id': _key,
            'type': 'true_false',
            'answer': {'value': true},
            'updated_at': '2026-09-08T12:00:00Z',
          },
        ],
    ),
  };
  for (final payload in invalidPayloads.entries) {
    test('200 ${payload.key} becomes invalidResponse without replay', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, payload.value),
      );
      await expectLater(
        _repository(adapter).submitAttempt(_attemptId, _homeworkId, _key),
        throwsA(_failureKind(ApiFailureKind.invalidResponse)),
      );
      expect(adapter.requests, hasLength(1));
    });
  }

  test('malformed raw JSON becomes invalidResponse without replay', () async {
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
      _repository(adapter).submitAttempt(_attemptId, _homeworkId, _key),
      throwsA(_failureKind(ApiFailureKind.invalidResponse)),
    );
    expect(adapter.requests, hasLength(1));
  });

  test(
    'Submit preserves shared machine failures and metadata without retry',
    () async {
      for (final failure in [
        (401, 'authentication_required'),
        (403, 'institution_inactive'),
        (404, 'resource_not_found'),
        (409, 'task_not_active'),
        (409, 'task_closed'),
        (409, 'task_archived'),
        (409, 'deadline_passed'),
        (409, 'attempt_not_editable'),
        (409, 'idempotency_key_reused'),
        (409, 'business_conflict'),
        (422, 'validation_failed'),
        (429, 'too_many_requests'),
        (500, 'internal_server_error'),
      ]) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(failure.$1, {
            'message': 'Safe API failure.',
            'code': failure.$2,
            'errors': {
              'request': ['Invalid request.'],
            },
            'request_id': 'submit-request-1',
          }),
        );
        await expectLater(
          _repository(adapter).submitAttempt(_attemptId, _homeworkId, _key),
          throwsA(
            _failureKind(
                  failure.$1 == 422
                      ? ApiFailureKind.validation
                      : ApiFailureKind.server,
                )
                .having(
                  (error) => error.failure.statusCode,
                  'status',
                  failure.$1,
                )
                .having((error) => error.failure.serverCode, 'code', failure.$2)
                .having(
                  (error) => error.failure.requestId,
                  'request ID',
                  'submit-request-1',
                )
                .having((error) => error.failure.fieldErrors, 'field errors', {
                  'request': ['Invalid request.'],
                }),
          ),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test(
    'transport failures use existing mapping with no automatic Submit retry',
    () async {
      for (final failure in [
        (DioExceptionType.connectionError, ApiFailureKind.connection),
        (DioExceptionType.connectionTimeout, ApiFailureKind.timeout),
        (DioExceptionType.sendTimeout, ApiFailureKind.timeout),
        (DioExceptionType.receiveTimeout, ApiFailureKind.timeout),
        (DioExceptionType.cancel, ApiFailureKind.cancelled),
        (DioExceptionType.unknown, ApiFailureKind.unknown),
      ]) {
        final adapter = _RecordingAdapter(
          (options) =>
              throw DioException(requestOptions: options, type: failure.$1),
        );
        await expectLater(
          _repository(adapter).submitAttempt(_attemptId, _homeworkId, _key),
          throwsA(_failureKind(failure.$2)),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );
}

StudentHomeworkAttemptRepositoryImpl _repository(_RecordingAdapter adapter) =>
    StudentHomeworkAttemptRepositoryImpl(remoteDataSource: _source(adapter));

StudentHomeworkAttemptRemoteDataSource _source(_RecordingAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
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
  RequestOptions get request => requests.single;

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

class _RecordingSubmitSource extends StudentHomeworkAttemptRemoteDataSource {
  _RecordingSubmitSource()
    : super(dio: Dio(), failureMapper: const DioFailureMapper());

  (String, String, String)? arguments;

  @override
  Future<StudentHomeworkSubmitDto> submitAttempt(
    String attemptId,
    String expectedHomeworkId,
    String idempotencyKey,
  ) async {
    arguments = (attemptId, expectedHomeworkId, idempotencyKey);
    return StudentHomeworkSubmitDto.fromJson(
      _envelope(_attempt()),
      expectedAttemptId: attemptId,
      expectedHomeworkId: expectedHomeworkId,
    );
  }
}

Map<String, Object?> _envelope(Object? attempt) => {
  'data': attempt,
  'message': 'Homework submitted successfully.',
};

Map<String, Object?> _attempt({String status = 'submitted'}) => {
  'id': _attemptId,
  'assessment_id': _homeworkId,
  'attempt_number': 1,
  'status': status,
  'started_at': '2026-09-08T12:00:00Z',
  'submitted_at': '2026-09-08T12:10:00Z',
  'finalized_at': '2026-09-08T12:10:00Z',
  'finalization_reason': 'student_submit',
  'deadline_at': '2026-09-10T13:00:00Z',
  'questions': [],
  'answers': [],
};

const _homeworkId = 'a1000000-0000-0000-0000-000000000001';
const _attemptId = 'a2000000-0000-0000-0000-000000000001';
const _key = 'a3000000-0000-4000-8000-000000000001';
