import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_detail_remote_data_source.dart';

import 'institution_group_test_support.dart';

void main() {
  test('uses one exact bodyless queryless GET for canonical UUIDs', () async {
    for (final target in const [testGroupId, testGroupIdUpper]) {
      final adapter = RecordingAdapter(
        (_) => jsonResponse(200, {'data': groupResource(id: target)}),
      );
      final source = _source(adapter);
      await source.fetchGroup(target);

      expect(adapter.request.method, 'GET');
      expect(adapter.request.path, '/institution/groups/$target');
      expect(adapter.request.uri.path, '/api/v1/institution/groups/$target');
      expect(adapter.request.queryParameters, isEmpty);
      expect(adapter.request.data, isNull);
    }
  });

  test('rejects malformed target before network', () async {
    final adapter = RecordingAdapter(
      (_) => jsonResponse(200, {'data': groupResource()}),
    );
    await expectLater(
      _source(adapter).fetchGroup(' not-a-uuid '),
      throwsA(isA<ApiRequestException>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test('accepts only exact privacy-safe resource_not_found envelope', () async {
    final valid = _source(
      RecordingAdapter(
        (_) => jsonResponse(404, {
          'message': 'The requested resource was not found.',
          'code': ApiErrorCodes.resourceNotFound,
          'errors': <String, Object?>{},
          'request_id': 'request-1',
        }),
      ),
    );
    await expectLater(
      valid.fetchGroup(testGroupId),
      throwsA(
        isA<ApiRequestException>().having(
          (error) => error.failure.serverCode,
          'serverCode',
          ApiErrorCodes.resourceNotFound,
        ),
      ),
    );

    for (final malformed in <Object?>[
      null,
      {
        'message': 'Private.',
        'code': ApiErrorCodes.forbidden,
        'errors': <String, Object?>{},
      },
      {
        'message': 'Missing.',
        'code': ApiErrorCodes.resourceNotFound,
        'errors': {
          'group': ['private'],
        },
      },
      {
        'message': 'Missing.',
        'code': ApiErrorCodes.resourceNotFound,
        'errors': <String, Object?>{},
        'extra': true,
      },
    ]) {
      await expectLater(
        _source(
          RecordingAdapter((_) => jsonResponse(404, malformed)),
        ).fetchGroup(testGroupId),
        throwsA(
          isA<ApiRequestException>().having(
            (error) => error.failure.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    }
  });

  test('requires exact 200 and exact data-only success envelope', () async {
    for (final successCase in <({int status, Object? body})>[
      (status: 201, body: {'data': groupResource()}),
      (status: 200, body: {'data': groupResource(), 'message': 'Unexpected.'}),
      (
        status: 200,
        body: {
          'data': {...groupResource(), 'private': true},
        },
      ),
    ]) {
      await expectLater(
        _source(
          RecordingAdapter(
            (_) => jsonResponse(successCase.status, successCase.body),
          ),
        ).fetchGroup(testGroupId),
        throwsA(
          isA<ApiRequestException>().having(
            (error) => error.failure.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    }
  });
}

InstitutionGroupDetailRemoteDataSource _source(RecordingAdapter adapter) =>
    InstitutionGroupDetailRemoteDataSource(
      dio: testDio(adapter),
      failureMapper: const DioFailureMapper(),
    );
