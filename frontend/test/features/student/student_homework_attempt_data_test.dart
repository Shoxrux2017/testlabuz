import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_remote_data_source.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';

void main() {
  for (final status in [200, 201]) {
    test(
      'Start sends exact POST, empty body and key; $status maps from HTTP only',
      () async {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(status, {'data': _attempt()}),
        );
        final repository = _repository(adapter);
        final homeworkId = _homeworkId.toUpperCase();
        final result = await repository.startAttempt(homeworkId, _key);

        expect(
          result.resultKind,
          status == 201
              ? StudentHomeworkAttemptStartResultKind.created
              : StudentHomeworkAttemptStartResultKind.resumed,
        );
        expect(result.attempt.id, _attemptId);
        expect(result.attempt.status, StudentHomeworkAttemptStatus.inProgress);
        expect(adapter.request.method, 'POST');
        expect(
          adapter.request.path,
          '/student/homework/${Uri.encodeComponent(homeworkId)}/attempts',
        );
        expect(
          adapter.request.uri.path,
          '/api/v1/student/homework/$homeworkId/attempts',
        );
        expect(adapter.request.data, const <String, Object?>{});
        expect(adapter.request.queryParameters, isEmpty);
        expect(adapter.request.followRedirects, isFalse);
        expect(adapter.request.headers['Idempotency-Key'], _key);
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

  test(
    'Attempt GET sends exact bodyless and queryless request without redirects',
    () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {'data': _attempt()}),
      );
      final attemptId = _attemptId.toUpperCase();
      final result = await _repository(adapter).fetchAttempt(attemptId);

      expect(result.id, _attemptId);
      expect(result.assessmentId, _homeworkId);
      expect(adapter.request.method, 'GET');
      expect(
        adapter.request.path,
        '/student/attempts/${Uri.encodeComponent(attemptId)}',
      );
      expect(adapter.request.uri.path, '/api/v1/student/attempts/$attemptId');
      expect(adapter.request.data, isNull);
      expect(adapter.request.queryParameters, isEmpty);
      expect(adapter.request.followRedirects, isFalse);
      expect(
        adapter.request.headers.keys.any(
          (header) => header.toLowerCase() == 'idempotency-key',
        ),
        isFalse,
      );
    },
  );

  test('invalid target IDs and idempotency keys fail before transport', () {
    final adapter = _RecordingAdapter(
      (_) => _jsonResponse(200, {'data': _attempt()}),
    );
    final source = _source(adapter);
    for (final invalid in [
      '',
      '../homework',
      '$_attemptId/extra',
      ' $_attemptId',
      _attemptId.replaceAll('-', ''),
      '$_attemptId\n',
    ]) {
      expect(() => source.startAttempt(invalid, _key), throwsArgumentError);
      expect(
        () => source.startAttempt(_homeworkId, invalid),
        throwsArgumentError,
      );
      expect(() => source.fetchAttempt(invalid), throwsArgumentError);
    }
    expect(adapter.requests, isEmpty);
  });

  test(
    'every unexpected successful status is invalid without replay',
    () async {
      for (final start in [true, false]) {
        for (var status = 200; status < 300; status += 1) {
          if (status == 200 || (start && status == 201)) continue;
          final adapter = _RecordingAdapter(
            (_) => _jsonResponse(status, {'data': _attempt()}),
          );
          await expectLater(
            _request(_repository(adapter), start: start),
            throwsA(_failureKind(ApiFailureKind.invalidResponse)),
          );
          expect(adapter.requests, hasLength(1));
        }
      }
    },
  );

  test(
    'malformed envelopes and invalid Attempt integrity never enter domain',
    () async {
      final payloads = <Object?>[
        null,
        [],
        {},
        {'data': null},
        {'data': []},
        {'data': _attempt(), 'message': 'Unexpected'},
        {'data': _attempt()..remove('answers')},
        {'data': _attempt()..['score'] = 9},
        {'data': _attempt()..['status'] = 'timed_out_finalized'},
        {'data': _attempt()..['started_at'] = '2026-09-08T12:00Z'},
        {
          'data': _attempt()
            ..['answers'] = [
              {
                'question_id': _key,
                'type': 'true_false',
                'answer': {'value': true},
                'updated_at': '2026-09-08T12:00:00Z',
              },
            ],
        },
      ];
      for (final start in [true, false]) {
        for (final payload in payloads) {
          final adapter = _RecordingAdapter((_) => _jsonResponse(200, payload));
          await expectLater(
            _request(_repository(adapter), start: start),
            throwsA(_failureKind(ApiFailureKind.invalidResponse)),
          );
          expect(adapter.requests, hasLength(1));
        }
      }
    },
  );

  test(
    'malformed raw JSON maps to invalidResponse for Start and read',
    () async {
      for (final start in [true, false]) {
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
          _request(_repository(adapter), start: start),
          throwsA(_failureKind(ApiFailureKind.invalidResponse)),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test(
    'structured failures preserve infrastructure machine codes and metadata',
    () async {
      for (final failure in [
        (401, 'authentication_required'),
        (403, 'institution_inactive'),
        (404, 'resource_not_found'),
        (409, 'task_not_active'),
        (409, 'task_closed'),
        (409, 'task_archived'),
        (409, 'assessment_not_assigned'),
        (409, 'deadline_passed'),
        (409, 'attempts_exhausted'),
        (409, 'idempotency_key_reused'),
        (409, 'business_conflict'),
        (422, 'validation_failed'),
        (429, 'too_many_requests'),
        (500, 'internal_server_error'),
      ]) {
        for (final start in [true, false]) {
          final adapter = _RecordingAdapter(
            (_) => _jsonResponse(failure.$1, {
              'message': 'Safe API failure.',
              'code': failure.$2,
              'errors': {
                'request': ['Invalid request.'],
              },
              'request_id': 'attempt-request-1',
            }),
          );
          await expectLater(
            _request(_repository(adapter), start: start),
            throwsA(
              isA<ApiRequestException>()
                  .having(
                    (error) => error.failure.kind,
                    'kind',
                    failure.$1 == 422
                        ? ApiFailureKind.validation
                        : ApiFailureKind.server,
                  )
                  .having(
                    (error) => error.failure.statusCode,
                    'status',
                    failure.$1,
                  )
                  .having(
                    (error) => error.failure.serverCode,
                    'code',
                    failure.$2,
                  )
                  .having(
                    (error) => error.failure.requestId,
                    'request ID',
                    'attempt-request-1',
                  )
                  .having(
                    (error) => error.failure.fieldErrors,
                    'field errors',
                    {
                      'request': ['Invalid request.'],
                    },
                  ),
            ),
          );
          expect(adapter.requests, hasLength(1));
        }
      }
    },
  );

  test(
    'transport failures map without automatic Start or read retries',
    () async {
      for (final failure in [
        (DioExceptionType.connectionError, ApiFailureKind.connection),
        (DioExceptionType.connectionTimeout, ApiFailureKind.timeout),
        (DioExceptionType.sendTimeout, ApiFailureKind.timeout),
        (DioExceptionType.receiveTimeout, ApiFailureKind.timeout),
        (DioExceptionType.cancel, ApiFailureKind.cancelled),
        (DioExceptionType.unknown, ApiFailureKind.unknown),
      ]) {
        for (final start in [true, false]) {
          final adapter = _RecordingAdapter(
            (options) =>
                throw DioException(requestOptions: options, type: failure.$1),
          );
          await expectLater(
            _request(_repository(adapter), start: start),
            throwsA(_failureKind(failure.$2)),
          );
          expect(adapter.requests, hasLength(1));
        }
      }
    },
  );

  test(
    'unstructured error responses map through existing invalid-response handling',
    () async {
      for (final start in [true, false]) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(503, {'unexpected': true}),
        );
        await expectLater(
          _request(_repository(adapter), start: start),
          throwsA(
            _failureKind(
              ApiFailureKind.invalidResponse,
            ).having((error) => error.failure.statusCode, 'status', 503),
          ),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );
}

Future<Object> _request(
  StudentHomeworkAttemptRepositoryImpl repository, {
  required bool start,
}) => start
    ? repository.startAttempt(_homeworkId, _key)
    : repository.fetchAttempt(_attemptId);

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

Map<String, Object?> _attempt() => {
  'id': _attemptId,
  'assessment_id': _homeworkId,
  'attempt_number': 1,
  'status': 'in_progress',
  'started_at': '2026-09-08T12:00:00Z',
  'submitted_at': null,
  'finalized_at': null,
  'finalization_reason': null,
  'deadline_at': '2026-09-10T13:00:00Z',
  'questions': [],
  'answers': [],
};

const _homeworkId = 'a1000000-0000-0000-0000-000000000001';
const _attemptId = 'a2000000-0000-0000-0000-000000000001';
const _key = 'a3000000-0000-4000-8000-000000000001';
