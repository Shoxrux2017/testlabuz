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
  test('uses one encoded, bodyless authenticated-client GET', () async {
    final adapter = _RecordingAdapter(
      (_) => _jsonResponse(200, {'data': _resource()}),
    );
    final source = InstitutionUserDetailRemoteDataSource(
      dio: _dio(adapter),
      failureMapper: const DioFailureMapper(),
    );

    await source.fetchUser(_userIdUpper);

    expect(adapter.requests, hasLength(1));
    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/institution/users/$_userIdUpper');
    expect(adapter.request.uri.path, '/api/v1/institution/users/$_userIdUpper');
    expect(adapter.request.queryParameters, isEmpty);
    expect(adapter.request.data, isNull);
  });

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

  test('preserves the accepted 404 code and maps transient failures', () async {
    final source = InstitutionUserDetailRemoteDataSource(
      dio: _dio(
        _RecordingAdapter(
          (_) => _jsonResponse(404, {
            'message': 'private detail',
            'code': ApiErrorCodes.resourceNotFound,
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

    final retryable = InstitutionUserDetailRemoteDataSource(
      dio: _dio(
        _RecordingAdapter((options) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }),
      ),
      failureMapper: const DioFailureMapper(),
    );
    await expectLater(
      retryable.fetchUser(_userId),
      throwsA(
        isA<ApiRequestException>().having(
          (error) => error.failure.kind,
          'kind',
          ApiFailureKind.connection,
        ),
      ),
    );
  });
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
