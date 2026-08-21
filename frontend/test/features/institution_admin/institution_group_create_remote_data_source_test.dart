import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_group_create_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_create_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_create.dart';

import 'institution_group_test_support.dart';

void main() {
  test(
    'issues one exact JSON POST without query tenant or idempotency data',
    () async {
      final adapter = RecordingAdapter(
        (_) => jsonResponse(201, {
          'data': groupResource(),
          'message': InstitutionGroupCreateDto.successMessage,
        }),
      );
      final source = _source(adapter);

      await source.createGroup(_request());

      expect(adapter.requests, hasLength(1));
      expect(adapter.request.method, 'POST');
      expect(adapter.request.path, '/institution/groups');
      expect(adapter.request.uri.path, '/api/v1/institution/groups');
      expect(adapter.request.queryParameters, isEmpty);
      expect(adapter.request.data, {
        'name': 'Advanced Mathematics',
        'level': 'Grade 10',
        'subject_direction': 'Mathematics',
        'description': 'Olympiad preparation',
      });
      expect(adapter.request.data, isNot(contains('institution_id')));
      expect(
        adapter.request.headers.keys.where(
          (key) => key.toLowerCase().contains('idempotency'),
        ),
        isEmpty,
      );
    },
  );

  test('preserves only exact allowed definite error pairs', () async {
    final cases = <({int status, String code, Map<String, Object?> errors})>[
      (status: 401, code: ApiErrorCodes.authenticationRequired, errors: {}),
      (status: 403, code: ApiErrorCodes.forbidden, errors: {}),
      (status: 403, code: ApiErrorCodes.passwordChangeRequired, errors: {}),
      (status: 403, code: ApiErrorCodes.userInactive, errors: {}),
      (status: 403, code: ApiErrorCodes.institutionInactive, errors: {}),
      (
        status: 422,
        code: ApiErrorCodes.validationFailed,
        errors: {
          'name': ['Private backend copy.'],
        },
      ),
      (status: 429, code: ApiErrorCodes.rateLimited, errors: {}),
    ];

    for (final failureCase in cases) {
      final source = _source(
        RecordingAdapter(
          (_) => jsonResponse(failureCase.status, {
            'message': 'Private backend message.',
            'code': failureCase.code,
            'errors': failureCase.errors,
            'request_id': 'request-1',
          }),
        ),
      );
      await expectLater(
        source.createGroup(_request()),
        throwsA(
          isA<ApiRequestException>()
              .having(
                (error) => error.failure.statusCode,
                'statusCode',
                failureCase.status,
              )
              .having(
                (error) => error.failure.serverCode,
                'serverCode',
                failureCase.code,
              ),
        ),
      );
    }
  });

  test('maps malformed success and ambiguous failures to unknown', () async {
    final cases = <({int status, Object? body})>[
      (
        status: 200,
        body: {
          'data': groupResource(),
          'message': InstitutionGroupCreateDto.successMessage,
        },
      ),
      (status: 201, body: {'data': groupResource()}),
      (status: 201, body: {'data': groupResource(), 'message': 'Wrong.'}),
      (
        status: 403,
        body: {
          'message': 'Private.',
          'code': ApiErrorCodes.forbidden,
          'errors': <String, Object?>{},
          'extra': true,
        },
      ),
      (
        status: 500,
        body: {
          'message': 'Private.',
          'code': ApiErrorCodes.serverError,
          'errors': <String, Object?>{},
        },
      ),
    ];

    for (final failureCase in cases) {
      final adapter = RecordingAdapter(
        (_) => jsonResponse(failureCase.status, failureCase.body),
      );
      await expectLater(
        _source(adapter).createGroup(_request()),
        throwsA(isA<InstitutionGroupCreateOutcomeUnknownException>()),
      );
      expect(adapter.requests, hasLength(1));
    }
  });

  test(
    'never replays timeout connection cancellation or unknown failures',
    () async {
      for (final type in const [
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
        DioExceptionType.cancel,
        DioExceptionType.unknown,
      ]) {
        final adapter = RecordingAdapter((options) {
          throw DioException(requestOptions: options, type: type);
        });
        await expectLater(
          _source(adapter).createGroup(_request()),
          throwsA(isA<InstitutionGroupCreateOutcomeUnknownException>()),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );
}

InstitutionGroupCreateRemoteDataSource _source(RecordingAdapter adapter) =>
    InstitutionGroupCreateRemoteDataSource(
      dio: testDio(adapter),
      failureMapper: const DioFailureMapper(),
    );

InstitutionGroupCreateRequest _request() => const InstitutionGroupCreateRequest(
  snapshot: InstitutionGroupCreateSnapshot(
    name: 'Advanced Mathematics',
    level: 'Grade 10',
    subjectDirection: 'Mathematics',
    description: 'Olympiad preparation',
  ),
);
