import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_attempt_remote_data_source.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_submit.dart';

import 'student_blitz_test_support.dart';

void main() {
  const fresh = StudentBlitzSubmitResponseExpectation.fresh;
  const replay = StudentBlitzSubmitResponseExpectation.completedReplay;

  test('posts the exact shared Submit request with its key', () async {
    final adapter = BlitzRecordingAdapter(
      (_) => blitzJsonResponse(200, _success()),
    );
    final result = await _repository(adapter).submitAttempt(
      studentBlitzAttemptId,
      studentBlitzId,
      blitzKey(1),
      expectation: fresh,
    );

    final request = adapter.request;
    expect(request.method, 'POST');
    expect(
      request.uri.toString(),
      'https://example.test/api/v1/student/attempts/'
      '$studentBlitzAttemptId/submit',
    );
    expect(request.uri.query, isEmpty);
    expect(request.data, const <String, Object?>{});
    expect(request.headers['Idempotency-Key'], blitzKey(1));
    expect(request.followRedirects, isFalse);
    expect(result.attempt.status, StudentBlitzAttemptStatus.submitted);
  });

  test('the response expectation is never sent', () async {
    for (final expectation in StudentBlitzSubmitResponseExpectation.values) {
      final adapter = BlitzRecordingAdapter(
        (_) => blitzJsonResponse(200, _success()),
      );
      await _repository(adapter).submitAttempt(
        studentBlitzAttemptId,
        studentBlitzId,
        blitzKey(1),
        expectation: expectation,
      );
      final request = adapter.request;
      expect(request.data, const <String, Object?>{});
      expect(request.uri.query, isEmpty);
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('expectation')),
      );
      expect(
        request.headers.values.map((value) => '$value'),
        everyElement(isNot(contains(expectation.name))),
      );
    }
  });

  test('a completed replay may return a later student_submit status', () async {
    final adapter = BlitzRecordingAdapter(
      (_) => blitzJsonResponse(200, _success(status: 'checked')),
    );
    final result = await _repository(adapter).submitAttempt(
      studentBlitzAttemptId,
      studentBlitzId,
      blitzKey(1),
      expectation: replay,
    );
    expect(result.attempt.status, StudentBlitzAttemptStatus.checked);
  });

  for (final (name, status, payload) in [
    ('a context-incompatible later status', 200, _success(status: 'checked')),
    ('a non-200 success', 201, _success()),
    ('a malformed envelope', 200, {'data': null}),
  ]) {
    test('$name on a fresh Submit is an invalid response', () async {
      final adapter = BlitzRecordingAdapter(
        (_) => blitzJsonResponse(status, payload),
      );
      await expectLater(
        _repository(adapter).submitAttempt(
          studentBlitzAttemptId,
          studentBlitzId,
          blitzKey(1),
          expectation: fresh,
        ),
        throwsA(
          isA<ApiRequestException>().having(
            (error) => error.failure.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });
  }

  test('invalid JSON is an invalid response', () async {
    final adapter = BlitzRecordingAdapter(
      (_) => ResponseBody.fromString(
        '{',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    await expectLater(
      _repository(adapter).submitAttempt(
        studentBlitzAttemptId,
        studentBlitzId,
        blitzKey(1),
        expectation: fresh,
      ),
      throwsA(
        isA<ApiRequestException>().having(
          (error) => error.failure.kind,
          'kind',
          ApiFailureKind.invalidResponse,
        ),
      ),
    );
  });

  for (final (status, code) in [
    (409, ApiErrorCodes.blitzTimeExpired),
    (409, ApiErrorCodes.attemptNotEditable),
    (409, ApiErrorCodes.idempotencyKeyReused),
    (500, ApiErrorCodes.serverError),
  ]) {
    test('$code is mapped once and never retried', () async {
      final adapter = BlitzRecordingAdapter(
        (_) => blitzErrorResponse(status, code),
      );
      await expectLater(
        _repository(adapter).submitAttempt(
          studentBlitzAttemptId,
          studentBlitzId,
          blitzKey(1),
          expectation: fresh,
        ),
        throwsA(
          isA<ApiRequestException>()
              .having((error) => error.failure.serverCode, 'code', code)
              .having((error) => error.failure.statusCode, 'status', status),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });
  }

  test('non-canonical identifiers are rejected before any request', () {
    final adapter = BlitzRecordingAdapter(
      (_) => blitzJsonResponse(200, _success()),
    );
    final source = _source(adapter);
    for (final (attemptId, blitzId, key) in [
      ('not-a-uuid', studentBlitzId, blitzKey(1)),
      (studentBlitzAttemptId, 'not-a-uuid', blitzKey(1)),
      (studentBlitzAttemptId, studentBlitzId, 'not-a-key'),
    ]) {
      expect(
        () => source.submitAttempt(attemptId, blitzId, key, expectation: fresh),
        throwsArgumentError,
      );
    }
    expect(adapter.requests, isEmpty);
  });
}

Map<String, Object?> _success({String status = 'submitted'}) => {
  'data': blitzAttemptJson(
    status: status,
    finalizationReason: 'student_submit',
    submittedAt: '2026-09-17T12:02:00Z',
    finalizedAt: '2026-09-17T12:02:00Z',
    serverNow: '2026-09-17T12:02:00Z',
    remainingSeconds: 0,
  ),
  'message': 'Blitz attempt submitted successfully.',
};

StudentBlitzAttemptRemoteDataSource _source(BlitzRecordingAdapter adapter) =>
    StudentBlitzAttemptRemoteDataSource(
      dio: blitzTestDio(adapter),
      failureMapper: const DioFailureMapper(),
    );

StudentBlitzAttemptRepositoryImpl _repository(BlitzRecordingAdapter adapter) =>
    StudentBlitzAttemptRepositoryImpl(remoteDataSource: _source(adapter));
