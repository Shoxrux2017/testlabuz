import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';

import 'teacher_blitz_json_fixtures.dart';
import 'teacher_blitz_monitoring_fixtures.dart';

void main() {
  test('reads the exact monitoring route without query or body', () async {
    final adapter = _Adapter((_) => _json(200, monitoringJson()));
    final monitoring = await _repository(adapter).fetchMonitoring(blitzJsonId);
    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/teacher/blitz/$blitzJsonId/monitoring');
    expect(request.queryParameters, isEmpty);
    expect(request.data, isNull);
    expect(request.followRedirects, isFalse);
    expect(monitoring.blitz.id, blitzJsonId);
  });

  for (final (status, code) in [
    (409, ApiErrorCodes.taskNotActive),
    (409, ApiErrorCodes.taskClosed),
    (409, ApiErrorCodes.taskArchived),
    (404, ApiErrorCodes.resourceNotFound),
    (429, ApiErrorCodes.rateLimited),
  ]) {
    test('maps $status $code once, with no retry', () async {
      final adapter = _Adapter((_) => _json(status, _error(code)));
      await expectLater(
        _repository(adapter).fetchMonitoring(blitzJsonId),
        throwsA(
          isA<ApiRequestException>()
              .having((e) => e.failure.statusCode, 'status', status)
              .having((e) => e.failure.serverCode, 'code', code),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });
  }

  for (final (name, status, body) in [
    ('a malformed 200', 200, {'data': null}),
    ('a non-200 success', 201, monitoringJson()),
    (
      'another Blitz',
      200,
      monitoringJson(
        blitz: monitoringBlitzJson(id: 'b0000000-0000-0000-0000-000000000009'),
      ),
    ),
  ]) {
    test('$name is an invalid response', () async {
      final adapter = _Adapter((_) => _json(status, body));
      await expectLater(
        _repository(adapter).fetchMonitoring(blitzJsonId),
        throwsA(
          isA<ApiRequestException>().having(
            (e) => e.failure.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });
  }

  test('a non-canonical Blitz ID is rejected before any request', () {
    final adapter = _Adapter((_) => _json(200, monitoringJson()));
    expect(
      () => _source(adapter).fetchMonitoring('not-a-uuid'),
      throwsArgumentError,
    );
    expect(adapter.requests, isEmpty);
  });
}

Map<String, Object?> _error(String code) => {
  'message': 'Server says no.',
  'code': code,
  'errors': <String, Object?>{},
};

TeacherBlitzRemoteDataSource _source(_Adapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  )..httpClientAdapter = adapter;
  return TeacherBlitzRemoteDataSource(
    dio: dio,
    failureMapper: const DioFailureMapper(),
  );
}

TeacherBlitzRepositoryImpl _repository(_Adapter adapter) =>
    TeacherBlitzRepositoryImpl(remoteDataSource: _source(adapter));

ResponseBody _json(int status, Object? body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

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
