import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_mutation_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_mutation.dart';

void main() {
  test(
    'PATCH sends one changed-fields object without tenant or retry authority',
    () async {
      final adapter = _RecordingAdapter((_) => _jsonResponse(200, _success()));
      final source = _source(adapter);

      await source.updateUser(
        _userId,
        InstitutionUserEditRequest({'email': null}),
      );

      expect(adapter.requests, hasLength(1));
      expect(adapter.request.method, 'PATCH');
      expect(adapter.request.uri.path, '/api/v1/institution/users/$_userId');
      expect(adapter.request.queryParameters, isEmpty);
      expect(adapter.request.data, {'email': null});
      expect(adapter.request.contentType, Headers.jsonContentType);
      expect(adapter.request.followRedirects, isFalse);
      expect(
        adapter.request.headers.keys.join(' '),
        isNot(contains('Institution')),
      );
      expect(
        adapter.request.headers.keys.join(' '),
        isNot(contains('Idempotency')),
      );
    },
  );

  test(
    'lifecycle POST has exactly zero body bytes and no data argument',
    () async {
      for (final action in InstitutionUserLifecycleAction.values) {
        final active = action == InstitutionUserLifecycleAction.activate;
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(
            200,
            _success(
              active: active,
              message: active
                  ? 'Institution user activated successfully.'
                  : 'Institution user deactivated successfully.',
            ),
          ),
        );
        await _source(adapter).changeLifecycle(_userId, action);

        expect(adapter.request.method, 'POST');
        expect(
          adapter.request.uri.path,
          endsWith('/${action.endpointSegment}'),
        );
        expect(adapter.request.queryParameters, isEmpty);
        expect(adapter.request.data, isNull);
        expect(adapter.request.followRedirects, isFalse);
        expect(adapter.requestStreamBytes, 0);
      }
    },
  );

  test(
    'strict success rejects wrong status, message, envelope and resource',
    () async {
      final cases = <({int status, Object? body})>[
        (status: 201, body: _success()),
        (status: 302, body: _success()),
        (status: 200, body: {..._success(), 'meta': {}}),
        (status: 200, body: _success(message: 'Updated.')),
        (
          status: 200,
          body: {
            'data': {..._resource(), 'password': 'private'},
            'message': 'Institution user updated successfully.',
          },
        ),
        (status: 500, body: _error(ApiErrorCodes.serverError)),
      ];
      for (final testCase in cases) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(testCase.status, testCase.body),
        );
        await expectLater(
          _source(adapter).updateUser(
            _userId,
            InstitutionUserEditRequest({'full_name': 'Updated Name'}),
          ),
          throwsA(isA<InstitutionUserMutationOutcomeUnknownException>()),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test('only exact documented 4xx errors are definite', () async {
    final cases = <({int status, String code, Map<String, Object?> errors})>[
      (
        status: 401,
        code: ApiErrorCodes.authenticationRequired,
        errors: const {},
      ),
      (status: 403, code: ApiErrorCodes.forbidden, errors: const {}),
      (
        status: 403,
        code: ApiErrorCodes.passwordChangeRequired,
        errors: const {},
      ),
      (status: 403, code: ApiErrorCodes.userInactive, errors: const {}),
      (status: 403, code: ApiErrorCodes.institutionInactive, errors: const {}),
      (status: 404, code: ApiErrorCodes.resourceNotFound, errors: const {}),
      (
        status: 422,
        code: ApiErrorCodes.validationFailed,
        errors: const {
          'email': ['Private.'],
        },
      ),
      (status: 429, code: ApiErrorCodes.rateLimited, errors: const {}),
    ];
    for (final testCase in cases) {
      final exact = _source(
        _RecordingAdapter(
          (_) => _jsonResponse(
            testCase.status,
            _error(testCase.code, errors: testCase.errors),
          ),
        ),
      );
      await expectLater(
        exact.updateUser(_userId, InstitutionUserEditRequest({'email': 'bad'})),
        throwsA(
          isA<ApiRequestException>().having(
            (value) => value.failure.serverCode,
            'code',
            testCase.code,
          ),
        ),
        reason: '${testCase.status} ${testCase.code}',
      );
    }
  });

  test('non-contract status and malformed error remain unprovable', () async {
    for (final testCase in <({int status, Object? body})>[
      (status: 400, body: _error(ApiErrorCodes.validationFailed)),
      (status: 409, body: _error(ApiErrorCodes.validationFailed)),
      (status: 500, body: _error(ApiErrorCodes.serverError)),
      (
        status: 401,
        body: {..._error(ApiErrorCodes.authenticationRequired), 'extra': true},
      ),
      (status: 403, body: _error(ApiErrorCodes.authenticationRequired)),
    ]) {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(testCase.status, testCase.body),
      );
      await expectLater(
        _source(
          adapter,
        ).changeLifecycle(_userId, InstitutionUserLifecycleAction.deactivate),
        throwsA(isA<InstitutionUserMutationOutcomeUnknownException>()),
      );
      expect(adapter.requests, hasLength(1));
    }
  });

  test('every transport uncertainty remains unprovable', () async {
    for (final type in const [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.transformTimeout,
      DioExceptionType.connectionError,
      DioExceptionType.cancel,
      DioExceptionType.badCertificate,
      DioExceptionType.unknown,
    ]) {
      final adapter = _RecordingAdapter((options) {
        throw DioException(requestOptions: options, type: type);
      });
      await expectLater(
        _source(
          adapter,
        ).changeLifecycle(_userId, InstitutionUserLifecycleAction.deactivate),
        throwsA(isA<InstitutionUserMutationOutcomeUnknownException>()),
      );
      expect(adapter.requests, hasLength(1));
    }
  });
}

const _userId = '00000000-0000-0000-0000-000000000001';

InstitutionUserMutationRemoteDataSource _source(_RecordingAdapter adapter) =>
    InstitutionUserMutationRemoteDataSource(
      dio: _dio(adapter),
      failureMapper: const DioFailureMapper(),
    );

Map<String, Object?> _success({
  bool active = true,
  String message = 'Institution user updated successfully.',
}) => {'data': _resource(active: active), 'message': message};

Map<String, Object?> _resource({bool active = true}) => {
  'id': _userId,
  'role': 'teacher',
  'full_name': 'Updated Name',
  'login_name': 'teacher01',
  'email': null,
  'phone': null,
  'is_active': active,
  'must_change_password': false,
  'last_login_at': null,
  'deactivated_at': active ? null : '2026-08-15T08:00:00Z',
  'created_at': '2026-08-07T15:00:00Z',
  'updated_at': '2026-08-15T08:00:00Z',
};

Map<String, Object?> _error(
  String code, {
  Map<String, Object?> errors = const {},
}) => {'message': 'Private.', 'code': code, 'errors': errors};

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
  var requestStreamBytes = 0;

  RequestOptions get request => requests.single;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      await for (final bytes in requestStream) {
        requestStreamBytes += bytes.length;
      }
    }
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
