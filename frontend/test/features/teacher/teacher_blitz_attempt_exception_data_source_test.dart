import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_attempt_exception.dart';

import 'teacher_blitz_json_fixtures.dart';
import 'teacher_blitz_monitoring_fixtures.dart';

const _key = '3f1c2a4b-5d6e-4f70-8a9b-0c1d2e3f4a5b';

void main() {
  test('posts the exact grant route, key and body once', () async {
    final adapter = _Adapter((_) => _json(201, grantJson()));
    final exception = await _grant(adapter);
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(
      request.path,
      '/teacher/blitz/$blitzJsonId/students/$monitoringStudentA/'
      'attempt-exception',
    );
    expect(request.queryParameters, isEmpty);
    expect(request.followRedirects, isFalse);
    expect(request.headers['Idempotency-Key'], _key);
    expect(request.data, {
      'reason_type': 'technical',
      'reason': 'The device lost power.',
    });
    expect(exception.studentId, monitoringStudentA);
    expect(
      exception.replacementState,
      TeacherBlitzAttemptExceptionReplacementState.available,
    );
  });

  test(
    'a historical replay whose replacement can no longer start is a success',
    () async {
      final adapter = _Adapter(
        (_) => _json(201, grantJson(replacementAttemptAvailable: false)),
      );
      final exception = await _grant(adapter);
      expect(
        exception.replacementState,
        TeacherBlitzAttemptExceptionReplacementState.noLongerAvailable,
      );
    },
  );

  for (final (status, code) in [
    (409, ApiErrorCodes.blitzAttemptExceptionAlreadyGranted),
    (409, ApiErrorCodes.blitzAttemptExceptionNotAllowed),
    (409, ApiErrorCodes.blitzNormalAttemptRequired),
    (409, ApiErrorCodes.idempotencyKeyReused),
    (404, ApiErrorCodes.resourceNotFound),
    (422, ApiErrorCodes.validationFailed),
  ]) {
    test('the exact $code rejection is definite', () async {
      final adapter = _Adapter((_) => _json(status, _error(code, status)));
      await expectLater(
        _grant(adapter),
        throwsA(
          isA<ApiRequestException>().having(
            (e) => e.failure.serverCode,
            'code',
            code,
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });
  }

  for (final (name, status, body) in [
    ('a server error', 500, _error(ApiErrorCodes.serverError, 500)),
    (
      'an undocumented conflict',
      409,
      _error(ApiErrorCodes.businessConflict, 409),
    ),
    ('a malformed success', 201, {'data': null, 'message': 'x'}),
    ('a 200 success', 200, grantJson()),
    (
      'a grant for another Student',
      201,
      grantJson(studentId: monitoringStudentB),
    ),
  ]) {
    test('$name leaves the outcome unknown without a retry', () async {
      final adapter = _Adapter((_) => _json(status, body));
      await expectLater(
        _grant(adapter),
        throwsA(isA<TeacherBlitzAttemptExceptionOutcomeUnknownException>()),
      );
      expect(adapter.requests, hasLength(1));
    });
  }

  test('non-canonical identifiers are rejected before any request', () {
    final adapter = _Adapter((_) => _json(201, grantJson()));
    final source = _source(adapter);
    for (final (blitzId, studentId, key) in [
      ('x', monitoringStudentA, _key),
      (blitzJsonId, 'x', _key),
      (blitzJsonId, monitoringStudentA, 'x'),
    ]) {
      expect(
        () => source.grantAttemptException(
          blitzId,
          studentId,
          _request(),
          idempotencyKey: key,
        ),
        throwsArgumentError,
      );
    }
    expect(adapter.requests, isEmpty);
  });
}

TeacherBlitzAttemptExceptionRequest _request() =>
    TeacherBlitzAttemptExceptionRequest(
      reasonType: TeacherBlitzAttemptExceptionReasonType.technical,
      reason: 'The device lost power.',
    );

Future<TeacherBlitzAttemptException> _grant(_Adapter adapter) =>
    TeacherBlitzRepositoryImpl(
      remoteDataSource: _source(adapter),
    ).grantAttemptException(
      blitzJsonId,
      monitoringStudentA,
      _request(),
      idempotencyKey: _key,
    );

Map<String, Object?> _error(String code, int status) => {
  'message': 'Server says no.',
  'code': code,
  'errors': status == 422
      ? <String, Object?>{
          'reason': ['The reason is required.'],
        }
      : <String, Object?>{},
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
