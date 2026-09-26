import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_attempt_remote_data_source.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';

import 'student_blitz_test_support.dart';

const _key = 'c1000000-0000-4000-8000-000000000001';

void main() {
  for (final (request, body) in [
    (
      StudentBlitzAttemptRequest.startNormal(idempotencyKey: _key),
      {'intent': 'start_normal'},
    ),
    (
      StudentBlitzAttemptRequest.resume(
        attemptId: studentBlitzAttemptId,
        idempotencyKey: _key,
      ),
      {'intent': 'resume', 'attempt_id': studentBlitzAttemptId},
    ),
    (
      StudentBlitzAttemptRequest.startReplacement(idempotencyKey: _key),
      {'intent': 'start_replacement'},
    ),
  ]) {
    test('${request.intent.apiValue} POSTs its exact body and key', () async {
      final adapter = BlitzRecordingAdapter(
        (_) => blitzJsonResponse(201, {
          'data': blitzAttemptJson(),
          'message': 'Blitz attempt started successfully.',
        }),
      );
      final blitzId = studentBlitzId.toUpperCase();
      await _repository(adapter).start(blitzId, request);

      expect(adapter.request.method, 'POST');
      expect(adapter.request.path, '/student/blitz/$blitzId/attempts');
      expect(
        adapter.request.uri.path,
        '/api/v1/student/blitz/$blitzId/attempts',
      );
      expect(adapter.request.data, body);
      expect(adapter.request.queryParameters, isEmpty);
      expect(adapter.request.followRedirects, isFalse);
      expect(adapter.request.headers['Idempotency-Key'], _key);
      expect(
        adapter.request.headers.keys.where(
          (header) => header.toLowerCase() == 'idempotency-key',
        ),
        hasLength(1),
      );
    });
  }

  test('201 and 200 map to created and resumed with exact messages', () async {
    final request = StudentBlitzAttemptRequest.startNormal(
      idempotencyKey: _key,
    );
    final created = await _repository(
      BlitzRecordingAdapter(
        (_) => blitzJsonResponse(201, {
          'data': blitzAttemptJson(),
          'message': 'Blitz attempt started successfully.',
        }),
      ),
    ).start(studentBlitzId, request);
    expect(created.resultKind, StudentBlitzAttemptStartResultKind.created);
    final resumed = await _repository(
      BlitzRecordingAdapter(
        (_) => blitzJsonResponse(200, {
          'data': blitzAttemptJson(),
          'message': 'Blitz attempt resumed successfully.',
        }),
      ),
    ).start(studentBlitzId, request);
    expect(resumed.resultKind, StudentBlitzAttemptStartResultKind.resumed);
  });

  test('a malformed possible success is uncertain and never retried', () async {
    for (final (status, body) in [
      (
        201,
        {
          'data': blitzAttemptJson(),
          'message': 'Blitz attempt resumed successfully.',
        },
      ),
      (202, {'data': blitzAttemptJson(), 'message': 'Accepted.'}),
      (201, {'data': blitzAttemptJson(attemptNumber: 3)}),
      (
        200,
        {
          'data': blitzAttemptJson()..['score'] = 1,
          'message': 'Blitz attempt resumed successfully.',
        },
      ),
    ]) {
      final adapter = BlitzRecordingAdapter(
        (_) => blitzJsonResponse(status, body),
      );
      await expectLater(
        _repository(adapter).start(
          studentBlitzId,
          StudentBlitzAttemptRequest.startNormal(idempotencyKey: _key),
        ),
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

  test('deterministic conflicts keep their machine codes', () async {
    for (final code in [
      ApiErrorCodes.blitzNotActive,
      ApiErrorCodes.blitzTimeExpired,
      ApiErrorCodes.attemptNotEditable,
      ApiErrorCodes.attemptsExhausted,
      ApiErrorCodes.idempotencyKeyReused,
    ]) {
      final adapter = BlitzRecordingAdapter(
        (_) => blitzErrorResponse(409, code),
      );
      await expectLater(
        _repository(adapter).start(
          studentBlitzId,
          StudentBlitzAttemptRequest.startNormal(idempotencyKey: _key),
        ),
        throwsA(
          isA<ApiRequestException>().having(
            (error) => error.failure.serverCode,
            'code',
            code,
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    }
  });

  test('a non-canonical Blitz ID fails before transport', () {
    final adapter = BlitzRecordingAdapter(
      (_) => blitzJsonResponse(201, <String, Object?>{}),
    );
    for (final invalid in [
      '',
      'active',
      '$studentBlitzId/x',
      ' $studentBlitzId',
    ]) {
      expect(
        () => _source(adapter).start(
          invalid,
          StudentBlitzAttemptRequest.startNormal(idempotencyKey: _key),
        ),
        throwsArgumentError,
      );
    }
    expect(adapter.requests, isEmpty);
  });
}

StudentBlitzAttemptRepositoryImpl _repository(BlitzRecordingAdapter adapter) =>
    StudentBlitzAttemptRepositoryImpl(remoteDataSource: _source(adapter));

StudentBlitzAttemptRemoteDataSource _source(BlitzRecordingAdapter adapter) =>
    StudentBlitzAttemptRemoteDataSource(
      dio: blitzTestDio(adapter),
      failureMapper: const DioFailureMapper(),
    );
