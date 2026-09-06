import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_topic_result_pair_operation_dto.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_pair_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_pair.dart';

const _pairId = '40000000-0000-0000-0000-000000000001';
const _topicId = '10000000-0000-0000-0000-000000000001';
const _otherTopicId = '10000000-0000-0000-0000-000000000002';
const _homeworkId = '20000000-0000-0000-0000-000000000001';
const _otherHomeworkId = '20000000-0000-0000-0000-000000000002';

void main() {
  group('TeacherTopicResultPairRemoteDataSource', () {
    test('uses exact GET and PUT requests and parses strict success', () async {
      final adapter = _RecordingAdapter((options) {
        return switch (options.method) {
          'GET' => _jsonResponse(200, {'data': _pairJson()}),
          'PUT' => _jsonResponse(200, {
            'data': _pairJson(),
            'message': TeacherTopicResultPairMutationDto.successMessage,
          }),
          _ => throw StateError('Unexpected method.'),
        };
      });
      final repository = _repository(adapter);

      final fetched = await repository.fetchResultPair(_topicId);
      final updated = await repository.setOfficialHomework(
        _topicId,
        _homeworkId,
      );

      expect(fetched?.homeworkAssessmentId, _homeworkId);
      expect(updated.homeworkAssessmentId, _homeworkId);
      expect(adapter.requests, hasLength(2));
      final get = adapter.requests[0];
      expect(get.method, 'GET');
      expect(get.path, '/teacher/topics/$_topicId/result-pair');
      expect(get.data, isNull);
      expect(get.queryParameters, isEmpty);
      expect(get.followRedirects, isFalse);
      final put = adapter.requests[1];
      expect(put.method, 'PUT');
      expect(put.path, '/teacher/topics/$_topicId/result-pair');
      expect(put.queryParameters, isEmpty);
      expect(put.data, {'homework_assessment_id': _homeworkId});
      expect((put.data as Map).keys, hasLength(1));
      expect(put.followRedirects, isFalse);
    });

    test(
      'GET returns confirmed null without confusing it with failure',
      () async {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(200, {'data': null}),
        );

        expect(await _repository(adapter).fetchResultPair(_topicId), isNull);
        expect(adapter.requests, hasLength(1));
      },
    );

    test('GET malformed success is an ordinary invalid response', () async {
      for (final body in <Object?>[
        {'data': _pairJson(), 'message': 'Unexpected.'},
        {'data': _pairJson()..remove('locked_at')},
      ]) {
        final adapter = _RecordingAdapter((_) => _jsonResponse(200, body));

        await expectLater(
          _repository(adapter).fetchResultPair(_topicId),
          throwsA(
            isA<ApiRequestException>().having(
              (error) => error.failure.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      }
    });

    test('GET rejects a non-null pair for another Topic', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {
          'data': _pairJson()..['topic_id'] = _otherTopicId,
        }),
      );

      await expectLater(
        _repository(adapter).fetchResultPair(_topicId),
        throwsA(
          isA<ApiRequestException>().having(
            (error) => error.failure.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('PUT requires exact 200 message and strict pair response', () async {
      for (final response in <(int, Object?)>[
        (
          200,
          {'data': _pairJson(), 'message': 'Unexpected designation message.'},
        ),
        (
          200,
          {
            'data': _pairJson()..['unknown'] = true,
            'message': TeacherTopicResultPairMutationDto.successMessage,
          },
        ),
        (
          201,
          {
            'data': _pairJson(),
            'message': TeacherTopicResultPairMutationDto.successMessage,
          },
        ),
      ]) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(response.$1, response.$2),
        );

        await expectLater(
          _repository(adapter).setOfficialHomework(_topicId, _homeworkId),
          throwsA(isA<TeacherTopicResultPairMutationOutcomeUnknownException>()),
        );
        expect(adapter.requests, hasLength(1));
      }
    });

    test('PUT identity mismatches remain outcome unknown', () async {
      for (final pair in <Map<String, Object?>>[
        _pairJson()..['topic_id'] = _otherTopicId,
        _pairJson()..['homework_assessment_id'] = _otherHomeworkId,
      ]) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(200, {
            'data': pair,
            'message': TeacherTopicResultPairMutationDto.successMessage,
          }),
        );

        await expectLater(
          _repository(adapter).setOfficialHomework(_topicId, _homeworkId),
          throwsA(isA<TeacherTopicResultPairMutationOutcomeUnknownException>()),
        );
        expect(adapter.requests, hasLength(1));
      }
    });

    test('maps every exact documented definite PUT failure', () async {
      final failures = <(int, String)>[
        (401, 'authentication_required'),
        (403, 'forbidden'),
        (403, 'password_change_required'),
        (403, 'user_inactive'),
        (403, 'institution_inactive'),
        (404, 'resource_not_found'),
        (409, 'topic_not_editable'),
        (409, 'official_task_requires_group_assignment'),
        (409, 'business_conflict'),
        (409, 'result_pair_locked'),
        (422, 'validation_failed'),
        (429, 'rate_limited'),
      ];

      for (final failure in failures) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(failure.$1, _errorJson(failure.$1, failure.$2)),
        );

        await expectLater(
          _repository(adapter).setOfficialHomework(_topicId, _homeworkId),
          throwsA(
            isA<ApiRequestException>()
                .having(
                  (error) => error.failure.statusCode,
                  'statusCode',
                  failure.$1,
                )
                .having(
                  (error) => error.failure.serverCode,
                  'serverCode',
                  failure.$2,
                ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      }
    });

    test(
      'arbitrary or malformed 409 remains unknown and is not retried',
      () async {
        for (final body in <Object?>[
          _errorJson(409, 'unexpected_conflict'),
          {
            'message': 'Conflict.',
            'code': 'result_pair_locked',
            'errors': {
              'field': ['Unexpected details.'],
            },
          },
        ]) {
          final adapter = _RecordingAdapter((_) => _jsonResponse(409, body));

          await expectLater(
            _repository(adapter).setOfficialHomework(_topicId, _homeworkId),
            throwsA(
              isA<TeacherTopicResultPairMutationOutcomeUnknownException>(),
            ),
          );
          expect(adapter.requests, hasLength(1));
        }
      },
    );

    test('ambiguous Dio failure remains unknown and is not retried', () async {
      final adapter = _RecordingAdapter(
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        _repository(adapter).setOfficialHomework(_topicId, _homeworkId),
        throwsA(isA<TeacherTopicResultPairMutationOutcomeUnknownException>()),
      );
      expect(adapter.requests, hasLength(1));
    });

    test('GET maps Dio failures through ordinary read mapping', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(404, _errorJson(404, 'resource_not_found')),
      );

      await expectLater(
        _repository(adapter).fetchResultPair(_topicId),
        throwsA(
          isA<ApiRequestException>()
              .having((error) => error.failure.statusCode, 'statusCode', 404)
              .having(
                (error) => error.failure.serverCode,
                'serverCode',
                'resource_not_found',
              ),
        ),
      );
    });

    test('rejects malformed targets before transport', () {
      final adapter = _RecordingAdapter(
        (_) => throw StateError('Transport must not be called.'),
      );
      final source = _source(adapter);

      expect(() => source.fetchResultPair('bad-topic'), throwsArgumentError);
      expect(
        () => source.setOfficialHomework(_topicId, 'bad-homework'),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });
  });
}

TeacherTopicResultPairRepositoryImpl _repository(_RecordingAdapter adapter) {
  return TeacherTopicResultPairRepositoryImpl(
    remoteDataSource: _source(adapter),
  );
}

TeacherTopicResultPairRemoteDataSource _source(_RecordingAdapter adapter) {
  return TeacherTopicResultPairRemoteDataSource(
    dio: _dio(adapter),
    failureMapper: const DioFailureMapper(),
  );
}

Dio _dio(_RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

Map<String, Object?> _pairJson() {
  return {
    'id': _pairId,
    'topic_id': _topicId,
    'homework_assessment_id': _homeworkId,
    'blitz_assessment_id': null,
    'cohort_snapshotted_at': null,
    'locked_at': null,
    'designated_at': '2026-09-03T10:00:00Z',
    'created_at': '2026-09-03T10:00:00Z',
    'updated_at': '2026-09-03T10:00:00Z',
  };
}

Map<String, Object?> _errorJson(int status, String code) {
  return {
    'message': 'Safe server error.',
    'code': code,
    'errors': status == 422
        ? {
            'homework_assessment_id': ['The selected Homework is invalid.'],
          }
        : <String, Object?>{},
    'request_id': 'req-result-pair-1',
  };
}

ResponseBody _jsonResponse(int statusCode, Object? body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
