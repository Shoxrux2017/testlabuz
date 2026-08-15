import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_create_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_create.dart';

void main() {
  test(
    'issues exactly one POST with six body fields and no tenant authority',
    () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(201, _successEnvelope()),
      );
      final source = _source(adapter);

      await source.createUser(_request());

      expect(adapter.requests, hasLength(1));
      expect(adapter.request.method, 'POST');
      expect(adapter.request.path, '/institution/users');
      expect(adapter.request.uri.path, '/api/v1/institution/users');
      expect(adapter.request.queryParameters, isEmpty);
      expect(adapter.request.data, _request().toJson());
      expect(adapter.request.data, isNot(contains('institution_id')));
      expect(
        adapter.request.headers.keys.where(
          (key) => key.toLowerCase().contains('institution'),
        ),
        isEmpty,
      );
      expect(
        adapter.request.headers.keys.where(
          (key) => key.toLowerCase().contains('idempotency'),
        ),
        isEmpty,
      );
    },
  );

  test('preserves only exact documented definite error envelopes', () async {
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
          'login_name': ['Private backend copy.'],
        },
      ),
      (status: 429, code: ApiErrorCodes.rateLimited, errors: {}),
    ];

    for (final failureCase in cases) {
      final source = _source(
        _RecordingAdapter(
          (_) => _jsonResponse(failureCase.status, {
            'message': 'Private backend message.',
            'code': failureCase.code,
            'errors': failureCase.errors,
            'request_id': 'request-1',
          }),
        ),
      );

      await expectLater(
        source.createUser(_request()),
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

  test(
    'classifies malformed success and every ambiguous failure as unknown',
    () async {
      final cases = <({int status, Object? body})>[
        (status: 200, body: _successEnvelope()),
        (status: 201, body: {'data': _resource()}),
        (
          status: 201,
          body: {
            'data': {..._resource(), 'password': 'private'},
            'message': 'Institution user created successfully.',
          },
        ),
        (
          status: 201,
          body: {
            'data': {..._resource(), 'id': 'not-a-uuid'},
            'message': 'Institution user created successfully.',
          },
        ),
        (
          status: 201,
          body: {
            'data': {..._resource(), 'role': 'institution_admin'},
            'message': 'Institution user created successfully.',
          },
        ),
        (status: 403, body: _error(ApiErrorCodes.forbidden, extra: true)),
        (status: 403, body: _error(ApiErrorCodes.validationFailed)),
        (
          status: 422,
          body: {
            'message': 'Invalid.',
            'code': ApiErrorCodes.validationFailed,
            'errors': <Object?>[],
          },
        ),
        (status: 500, body: _error(ApiErrorCodes.serverError)),
      ];

      for (final failureCase in cases) {
        final source = _source(
          _RecordingAdapter(
            (_) => _jsonResponse(failureCase.status, failureCase.body),
          ),
        );
        await expectLater(
          source.createUser(_request()),
          throwsA(isA<InstitutionUserCreateOutcomeUnknownException>()),
          reason: '${failureCase.status}: ${failureCase.body}',
        );
      }
    },
  );

  test(
    'classifies timeout and connection failure as unknown without retry',
    () async {
      for (final type in const [
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
        DioExceptionType.cancel,
        DioExceptionType.unknown,
      ]) {
        final adapter = _RecordingAdapter((options) {
          throw DioException(requestOptions: options, type: type);
        });
        final source = _source(adapter);

        await expectLater(
          source.createUser(_request()),
          throwsA(isA<InstitutionUserCreateOutcomeUnknownException>()),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );
}

InstitutionUserCreateRemoteDataSource _source(_RecordingAdapter adapter) =>
    InstitutionUserCreateRemoteDataSource(
      dio: _dio(adapter),
      failureMapper: const DioFailureMapper(),
    );

InstitutionUserCreateRequest _request() => const InstitutionUserCreateRequest(
  snapshot: InstitutionUserCreateSnapshot(
    role: InstitutionUserRole.teacher,
    fullName: 'Teacher Name',
    loginName: 'teacher01',
    email: null,
    phone: null,
  ),
  password: 'password1',
);

Map<String, Object?> _successEnvelope() => {
  'data': _resource(),
  'message': 'Institution user created successfully.',
};

Map<String, Object?> _error(String code, {bool extra = false}) => {
  'message': 'Private backend message.',
  'code': code,
  'errors': <String, Object?>{},
  if (extra) 'private': true,
};

Map<String, Object?> _resource() => {
  'id': '00000000-0000-0000-0000-000000000001',
  'role': 'teacher',
  'full_name': 'Teacher Name',
  'login_name': 'teacher01',
  'email': null,
  'phone': null,
  'is_active': true,
  'must_change_password': true,
  'last_login_at': null,
  'deactivated_at': null,
  'created_at': '2026-08-15T08:00:00Z',
  'updated_at': '2026-08-15T08:00:00Z',
};

Dio _dio(_RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

ResponseBody _jsonResponse(int statusCode, Object? body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) _handler;
  final requests = <RequestOptions>[];

  RequestOptions get request => requests.single;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
