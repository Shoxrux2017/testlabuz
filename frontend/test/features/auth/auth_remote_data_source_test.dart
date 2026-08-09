import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/auth_request_options.dart';
import 'package:testlabuz_client/core/network/auth_token_interceptor.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/core/network/session_invalidation_signal.dart';
import 'package:testlabuz_client/core/storage/auth_token_store.dart';
import 'package:testlabuz_client/core/storage/secure_value_store.dart';
import 'package:testlabuz_client/features/auth/data/auth_remote_data_source.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';

void main() {
  group('AuthRemoteDataSource', () {
    test('login sends public login field and not login_name', () async {
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      await tokenStore.write('stale-token');
      final adapter = RecordingAdapter(
        (_) => _jsonResponse(200, {
          'data': {
            'token': 'token-a',
            'token_type': 'Bearer',
            'user': _userJson(),
          },
        }),
      );
      final dataSource = AuthRemoteDataSource(
        dio: _dioWithAuth(tokenStore: tokenStore, adapter: adapter),
        failureMapper: const DioFailureMapper(),
      );

      final response = await dataSource.login(
        login: 'teacher01',
        password: 'secret',
      );

      expect(response.token, 'token-a');
      expect(adapter.singleRequest.path, '/auth/login');
      expect(adapter.singleRequest.data, {
        'login': 'teacher01',
        'password': 'secret',
      });
      expect(
        (adapter.singleRequest.data as Map<Object?, Object?>).containsKey(
          'login_name',
        ),
        isFalse,
      );
      expect(
        adapter.singleRequest.extra[AuthRequestOptions.skipAuthExtraKey],
        isTrue,
      );
      expect(
        adapter.singleRequest.headers.containsKey(
          AuthHttpHeaders.authorization,
        ),
        isFalse,
      );
    });

    test('me parses authenticated current user with institution', () async {
      final adapter = RecordingAdapter(
        (_) => _jsonResponse(200, {
          'data': _userJson(institution: _institutionJson()),
        }),
      );
      final dataSource = AuthRemoteDataSource(
        dio: _plainDio(adapter),
        failureMapper: const DioFailureMapper(),
      );

      final response = await dataSource.me();

      expect(response.user.role, UserRole.teacher);
      expect(response.user.institution?.timezone, 'Asia/Tashkent');
      expect(adapter.singleRequest.path, '/auth/me');
    });

    test('logout accepts 204 No Content', () async {
      final adapter = RecordingAdapter((_) => ResponseBody.fromBytes([], 204));
      final dataSource = AuthRemoteDataSource(
        dio: _plainDio(adapter),
        failureMapper: const DioFailureMapper(),
      );

      await dataSource.logout();

      expect(adapter.singleRequest.path, '/auth/logout');
      expect(adapter.singleRequest.method, 'POST');
    });

    test(
      'malformed success envelope maps to typed invalid response failure',
      () async {
        final adapter = RecordingAdapter(
          (_) => _jsonResponse(200, {'unexpected': {}}),
        );
        final dataSource = AuthRemoteDataSource(
          dio: _plainDio(adapter),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          dataSource.me(),
          throwsA(
            isA<ApiRequestException>().having(
              (exception) => exception.failure.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );
      },
    );
  });
}

Dio _dioWithAuth({
  required AuthTokenStore tokenStore,
  required RecordingAdapter adapter,
}) {
  final dio = _plainDio(adapter);
  dio.interceptors.add(
    AuthTokenInterceptor(
      tokenStore: tokenStore,
      sessionInvalidationSignal: SessionInvalidationSignal(),
    ),
  );

  return dio;
}

Dio _plainDio(RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
    ),
  );
  dio.httpClientAdapter = adapter;

  return dio;
}

Map<String, Object?> _userJson({Map<String, Object?>? institution}) {
  return {
    'id': 'user-1',
    'institution_id': 'institution-1',
    'role': 'teacher',
    'full_name': 'Teacher Name',
    'login_name': 'teacher01',
    'email': null,
    'phone': null,
    'is_active': true,
    'must_change_password': false,
    ...?institution == null ? null : {'institution': institution},
  };
}

Map<String, Object?> _institutionJson() {
  return {
    'id': 'institution-1',
    'name': 'Example School',
    'status': 'active',
    'timezone': 'Asia/Tashkent',
  };
}

ResponseBody _jsonResponse(int statusCode, Object? body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) _handler;
  final requests = <RequestOptions>[];

  RequestOptions get singleRequest => requests.single;

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

class FakeSecureValueStore implements SecureValueStore {
  final values = <String, String>{};

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return values[key];
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}
