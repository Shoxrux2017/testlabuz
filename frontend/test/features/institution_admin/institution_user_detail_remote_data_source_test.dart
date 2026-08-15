import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_detail_remote_data_source.dart';

void main() {
  test(
    'uses one encoded, bodyless client GET for each canonical UUID',
    () async {
      for (final target in const [_userId, _userIdUpper]) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(200, {'data': _resource()}),
        );
        final source = InstitutionUserDetailRemoteDataSource(
          dio: _dio(adapter),
          failureMapper: const DioFailureMapper(),
        );

        await source.fetchUser(target);

        expect(adapter.requests, hasLength(1));
        expect(adapter.request.method, 'GET');
        expect(adapter.request.path, '/institution/users/$target');
        expect(adapter.request.uri.path, '/api/v1/institution/users/$target');
        expect(adapter.request.queryParameters, isEmpty);
        expect(adapter.request.data, isNull);
        expect(
          adapter.request.headers.keys.where(
            (key) => key.toLowerCase().contains('institution'),
          ),
          isEmpty,
        );
      }
    },
  );

  test('blocks malformed targets before issuing a request', () async {
    final adapter = _RecordingAdapter(
      (_) => _jsonResponse(200, {'data': _resource()}),
    );
    final source = InstitutionUserDetailRemoteDataSource(
      dio: _dio(adapter),
      failureMapper: const DioFailureMapper(),
    );

    await expectLater(
      source.fetchUser('not-a-uuid'),
      throwsA(isA<ApiRequestException>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test(
    'preserves only an exact accepted resource-not-found envelope',
    () async {
      final source = InstitutionUserDetailRemoteDataSource(
        dio: _dio(
          _RecordingAdapter(
            (_) => _jsonResponse(404, {
              'message': 'The requested resource was not found.',
              'code': ApiErrorCodes.resourceNotFound,
              'errors': <String, Object?>{},
              'request_id': 'request-1',
            }),
          ),
        ),
        failureMapper: const DioFailureMapper(),
      );
      await expectLater(
        source.fetchUser(_userId),
        throwsA(
          isA<ApiRequestException>()
              .having((error) => error.failure.statusCode, 'statusCode', 404)
              .having(
                (error) => error.failure.serverCode,
                'serverCode',
                ApiErrorCodes.resourceNotFound,
              ),
        ),
      );
    },
  );

  test('maps every malformed or wrong-code 404 to invalidResponse', () async {
    final malformedEnvelopes = <Object?>[
      null,
      <String, Object?>{},
      {
        'message': 'The requested resource was not found.',
        'code': ApiErrorCodes.resourceNotFound,
      },
      {
        'message': 'The requested resource was not found.',
        'code': ApiErrorCodes.resourceNotFound,
        'errors': <Object?>[],
      },
      {
        'message': 'The requested resource was not found.',
        'code': ApiErrorCodes.resourceNotFound,
        'errors': {
          'user': ['private detail'],
        },
      },
      {
        'message': '',
        'code': ApiErrorCodes.resourceNotFound,
        'errors': <String, Object?>{},
      },
      {
        'message': 'Forbidden.',
        'code': ApiErrorCodes.forbidden,
        'errors': <String, Object?>{},
      },
      {
        'message': 'The requested resource was not found.',
        'code': ApiErrorCodes.resourceNotFound,
        'errors': <String, Object?>{},
        'private': true,
      },
      {
        'message': 'The requested resource was not found.',
        'code': ApiErrorCodes.resourceNotFound,
        'errors': <String, Object?>{},
        'request_id': null,
      },
    ];

    for (final envelope in malformedEnvelopes) {
      final source = InstitutionUserDetailRemoteDataSource(
        dio: _dio(_RecordingAdapter((_) => _jsonResponse(404, envelope))),
        failureMapper: const DioFailureMapper(),
      );

      await expectLater(
        source.fetchUser(_userId),
        throwsA(
          isA<ApiRequestException>()
              .having(
                (error) => error.failure.kind,
                'kind',
                ApiFailureKind.invalidResponse,
              )
              .having((error) => error.failure.statusCode, 'statusCode', 404),
        ),
        reason: '$envelope',
      );
    }
  });

  test('maps accepted HTTP failures without exposing their payload', () async {
    final cases = <({int status, String code, ApiFailureKind kind})>[
      (
        status: 401,
        code: ApiErrorCodes.authenticationRequired,
        kind: ApiFailureKind.server,
      ),
      (status: 403, code: ApiErrorCodes.forbidden, kind: ApiFailureKind.server),
      (
        status: 422,
        code: ApiErrorCodes.validationFailed,
        kind: ApiFailureKind.validation,
      ),
      (
        status: 500,
        code: ApiErrorCodes.serverError,
        kind: ApiFailureKind.server,
      ),
    ];

    for (final failureCase in cases) {
      final source = InstitutionUserDetailRemoteDataSource(
        dio: _dio(
          _RecordingAdapter(
            (_) => _jsonResponse(failureCase.status, {
              'message': 'Private backend message.',
              'code': failureCase.code,
              'errors': <String, Object?>{},
            }),
          ),
        ),
        failureMapper: const DioFailureMapper(),
      );

      await expectLater(
        source.fetchUser(_userId),
        throwsA(
          isA<ApiRequestException>()
              .having((error) => error.failure.kind, 'kind', failureCase.kind)
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
    'maps malformed 200 envelopes and resources to invalidResponse',
    () async {
      final invalidSuccesses = <Object?>[
        {'data': _resource(), 'message': 'Unexpected message.'},
        {
          'data': {..._resource(), 'institution_id': 'private'},
        },
        {
          'data': {..._resource(), 'role': 'institution_admin'},
        },
      ];

      for (final body in invalidSuccesses) {
        final source = InstitutionUserDetailRemoteDataSource(
          dio: _dio(_RecordingAdapter((_) => _jsonResponse(200, body))),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          source.fetchUser(_userId),
          throwsA(
            isA<ApiRequestException>().having(
              (error) => error.failure.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );
      }
    },
  );

  test(
    'maps timeout and connection failures to typed local failures',
    () async {
      for (final failureCase in const [
        (type: DioExceptionType.receiveTimeout, kind: ApiFailureKind.timeout),
        (
          type: DioExceptionType.connectionError,
          kind: ApiFailureKind.connection,
        ),
      ]) {
        final source = InstitutionUserDetailRemoteDataSource(
          dio: _dio(
            _RecordingAdapter((options) {
              throw DioException(
                requestOptions: options,
                type: failureCase.type,
              );
            }),
          ),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          source.fetchUser(_userId),
          throwsA(
            isA<ApiRequestException>().having(
              (error) => error.failure.kind,
              'kind',
              failureCase.kind,
            ),
          ),
        );
      }
    },
  );
}

const _userId = '550e8400-e29b-41d4-a716-446655440000';
const _userIdUpper = 'A0B1C2D3-E4F5-6789-ABCD-EF0123456789';

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

Map<String, Object?> _resource({String id = _userId}) => {
  'id': id,
  'role': 'teacher',
  'full_name': 'Teacher Name',
  'login_name': 'teacher01',
  'email': null,
  'phone': null,
  'is_active': true,
  'must_change_password': false,
  'last_login_at': null,
  'deactivated_at': null,
  'created_at': '2026-08-07T14:00:00Z',
  'updated_at': '2026-08-07T16:00:00Z',
};

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
