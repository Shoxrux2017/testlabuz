import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_list.dart';

import 'teacher_topic_result_test_support.dart';

const _otherStudentId = '60000000-0000-0000-0000-000000000002';

void main() {
  group('Teacher Topic result data source', () {
    test('lists results with the exact query and parses counts', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, teacherTopicResultListJson()),
      );

      final list = await _repository(
        adapter,
      ).fetchResults(teacherResultTopicId, const TeacherTopicResultListQuery());

      expect(list.items.single.studentId, teacherResultStudentId);
      expect(list.counts.of(TeacherTopicResultStatus.calculated), 1);
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/teacher/topics/$teacherResultTopicId/results');
      expect(request.queryParameters, {'page': 1, 'per_page': 25});
      expect(request.data, isNull);
      expect(request.followRedirects, isFalse);
    });

    test('sends the status and category filters and the page', () async {
      const query = TeacherTopicResultListQuery(
        status: TeacherTopicResultStatus.closed,
        category: TeacherTopicResultCategoryCode.notCompleted,
        page: 2,
      );
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(
          200,
          teacherTopicResultListJson(
            items: const [],
            page: 2,
            total: 1,
            counts: teacherResultCountsJson(closed: 1),
          ),
        ),
      );

      final list = await _repository(
        adapter,
      ).fetchResults(teacherResultTopicId, query);

      expect(list.items, isEmpty);
      expect(adapter.requests.single.queryParameters, {
        'result_status': 'closed',
        'category': 'not_completed',
        'page': 2,
        'per_page': 25,
      });
    });

    test('reads one result with its detail', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {'data': teacherTopicResultDetailJson()}),
      );

      final detail = await _repository(
        adapter,
      ).fetchResult(teacherResultTopicId, teacherResultStudentId);

      expect(detail.result.studentId, teacherResultStudentId);
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(
        request.path,
        '/teacher/topics/$teacherResultTopicId/results/$teacherResultStudentId',
      );
      expect(request.queryParameters, isEmpty);
      expect(request.followRedirects, isFalse);
    });

    test('rejects a detail of another Student', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {
          'data': teacherTopicResultDetailJson(
            item: teacherTopicResultJson(studentId: _otherStudentId),
          ),
        }),
      );

      await expectLater(
        _repository(
          adapter,
        ).fetchResult(teacherResultTopicId, teacherResultStudentId),
        _throwsFailureKind(ApiFailureKind.invalidResponse),
      );
    });

    test('accepts a detail whose Student id differs only in case', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {'data': teacherTopicResultDetailJson()}),
      );

      final detail = await _repository(adapter).fetchResult(
        teacherResultTopicId.toUpperCase(),
        teacherResultStudentId.toUpperCase(),
      );

      expect(detail.result.studentId, teacherResultStudentId);
    });

    test('malformed successes are invalid responses', () async {
      for (final (status, body) in <(int, Object?)>[
        (201, teacherTopicResultListJson()),
        (200, {...teacherTopicResultListJson(), 'links': null}),
        (200, {'data': teacherTopicResultListJson()['data']}),
        (200, null),
      ]) {
        final adapter = _RecordingAdapter((_) => _jsonResponse(status, body));

        await expectLater(
          _repository(adapter).fetchResults(
            teacherResultTopicId,
            const TeacherTopicResultListQuery(),
          ),
          _throwsFailureKind(ApiFailureKind.invalidResponse),
          reason: '$status $body',
        );
      }
      for (final (status, body) in <(int, Object?)>[
        (201, {'data': teacherTopicResultDetailJson()}),
        (200, {'data': teacherTopicResultDetailJson(), 'message': 'Done.'}),
        (200, {'data': null}),
        (200, teacherTopicResultDetailJson()),
      ]) {
        final adapter = _RecordingAdapter((_) => _jsonResponse(status, body));

        await expectLater(
          _repository(
            adapter,
          ).fetchResult(teacherResultTopicId, teacherResultStudentId),
          _throwsFailureKind(ApiFailureKind.invalidResponse),
          reason: '$status $body',
        );
      }
    });

    test('server failures keep their status and code', () async {
      for (final (status, code) in [
        (404, ApiErrorCodes.resourceNotFound),
        (422, ApiErrorCodes.validationFailed),
        (401, ApiErrorCodes.authenticationRequired),
      ]) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(status, _errorJson(code)),
        );

        await expectLater(
          _repository(adapter).fetchResults(
            teacherResultTopicId,
            const TeacherTopicResultListQuery(),
          ),
          throwsA(
            isA<ApiRequestException>()
                .having((error) => error.failure.statusCode, 'status', status)
                .having((error) => error.failure.serverCode, 'code', code),
          ),
        );
      }
    });

    test('rejects non-canonical ids before any request', () {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, teacherTopicResultListJson()),
      );
      final source = _source(adapter);

      expect(
        () =>
            source.fetchResults('topic-1', const TeacherTopicResultListQuery()),
        throwsArgumentError,
      );
      expect(
        () => source.fetchResult(teacherResultTopicId, 'student-1'),
        throwsArgumentError,
      );
      expect(
        () => source.fetchResult(' $teacherResultTopicId', _otherStudentId),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });
  });
}

Matcher _throwsFailureKind(ApiFailureKind kind) {
  return throwsA(
    isA<ApiRequestException>().having(
      (error) => error.failure.kind,
      'kind',
      kind,
    ),
  );
}

TeacherTopicResultRepositoryImpl _repository(_RecordingAdapter adapter) {
  return TeacherTopicResultRepositoryImpl(remoteDataSource: _source(adapter));
}

TeacherTopicResultRemoteDataSource _source(_RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  dio.httpClientAdapter = adapter;
  return TeacherTopicResultRemoteDataSource(
    dio: dio,
    failureMapper: const DioFailureMapper(),
  );
}

Map<String, Object?> _errorJson(String code) {
  return {
    'message': 'Safe server error.',
    'code': code,
    'errors': <String, Object?>{},
    'request_id': 'req-results-1',
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
