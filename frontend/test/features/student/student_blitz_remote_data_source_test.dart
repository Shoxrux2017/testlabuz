import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_remote_data_source.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_repository_impl.dart';

import 'student_blitz_test_support.dart';

void main() {
  test('active list sends an exact bodyless, queryless GET', () async {
    final adapter = BlitzRecordingAdapter(
      (_) => blitzJsonResponse(200, {
        'data': [activeBlitzJson(id: otherStudentBlitzId), activeBlitzJson()],
      }),
    );
    final items = await _repository(adapter).fetchActiveBlitz();

    expect(items.map((item) => item.id), [otherStudentBlitzId, studentBlitzId]);
    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/student/blitz/active');
    expect(adapter.request.uri.path, '/api/v1/student/blitz/active');
    expect(adapter.request.queryParameters, isEmpty);
    expect(adapter.request.data, isNull);
    expect(adapter.request.followRedirects, isFalse);
  });

  test('detail sends an exact GET and unwraps the exact envelope', () async {
    final adapter = BlitzRecordingAdapter(
      (_) => blitzJsonResponse(200, {'data': blitzDetailJson()}),
    );
    final blitzId = studentBlitzId.toUpperCase();
    final detail = await _repository(adapter).fetchBlitz(blitzId);

    expect(detail.id, studentBlitzId);
    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/student/blitz/$blitzId');
    expect(adapter.request.uri.path, '/api/v1/student/blitz/$blitzId');
    expect(adapter.request.queryParameters, isEmpty);
    expect(adapter.request.data, isNull);
    expect(adapter.request.followRedirects, isFalse);
  });

  test('non-canonical Blitz IDs fail before transport', () {
    final adapter = BlitzRecordingAdapter(
      (_) => blitzJsonResponse(200, {'data': blitzDetailJson()}),
    );
    for (final invalid in [
      '',
      'active',
      '../x',
      '$studentBlitzId/attempts',
      ' $studentBlitzId',
    ]) {
      expect(() => _source(adapter).fetchBlitz(invalid), throwsArgumentError);
    }
    expect(adapter.requests, isEmpty);
  });

  test('success needs status 200 and an exact envelope', () async {
    for (final (status, detailBody, listBody) in [
      (201, {'data': blitzDetailJson()}, {'data': <Object?>[]}),
      (204, null, null),
      (
        200,
        {'data': blitzDetailJson(), 'message': 'ok'},
        {'data': <Object?>[], 'meta': <String, Object?>{}},
      ),
      (200, blitzDetailJson(), <Object?>[]),
    ]) {
      await expectLater(
        _repository(
          BlitzRecordingAdapter((_) => blitzJsonResponse(status, detailBody)),
        ).fetchBlitz(studentBlitzId),
        throwsA(_failureKind(ApiFailureKind.invalidResponse)),
      );
      await expectLater(
        _repository(
          BlitzRecordingAdapter((_) => blitzJsonResponse(status, listBody)),
        ).fetchActiveBlitz(),
        throwsA(_failureKind(ApiFailureKind.invalidResponse)),
      );
    }
  });

  test('malformed JSON is an invalid response', () async {
    final adapter = BlitzRecordingAdapter(
      (_) => ResponseBody.fromString(
        '{"data": [',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    await expectLater(
      _repository(adapter).fetchActiveBlitz(),
      throwsA(_failureKind(ApiFailureKind.invalidResponse)),
    );
  });

  test('known conflicts keep their stable machine codes', () async {
    for (final (status, code) in [
      (409, ApiErrorCodes.blitzNotActive),
      (409, ApiErrorCodes.blitzTimeExpired),
      (404, ApiErrorCodes.resourceNotFound),
      (401, ApiErrorCodes.authenticationRequired),
    ]) {
      final adapter = BlitzRecordingAdapter(
        (_) => blitzErrorResponse(status, code),
      );
      await expectLater(
        _repository(adapter).fetchBlitz(studentBlitzId),
        throwsA(
          isA<ApiRequestException>()
              .having((error) => error.failure.statusCode, 'status', status)
              .having((error) => error.failure.serverCode, 'code', code),
        ),
      );
      expect(adapter.requests, hasLength(1));
    }
  });
}

StudentBlitzRepositoryImpl _repository(BlitzRecordingAdapter adapter) =>
    StudentBlitzRepositoryImpl(remoteDataSource: _source(adapter));

StudentBlitzRemoteDataSource _source(BlitzRecordingAdapter adapter) =>
    StudentBlitzRemoteDataSource(
      dio: blitzTestDio(adapter),
      failureMapper: const DioFailureMapper(),
    );

TypeMatcher<ApiRequestException> _failureKind(ApiFailureKind kind) =>
    isA<ApiRequestException>().having(
      (error) => error.failure.kind,
      'kind',
      kind,
    );
