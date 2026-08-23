import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/auth_request_options.dart';
import 'package:testlabuz_client/core/network/auth_token_interceptor.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/core/network/session_invalidation_signal.dart';
import 'package:testlabuz_client/core/storage/auth_token_store.dart';
import 'package:testlabuz_client/core/storage/secure_value_store.dart';

void main() {
  group('AuthTokenInterceptor', () {
    test('adds Bearer token to authenticated requests', () async {
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      await tokenStore.write('token-a');
      final adapter = RecordingAdapter((_) => _jsonResponse(200, {'data': {}}));
      final dio = _dioWithAuth(tokenStore: tokenStore, adapter: adapter);

      await dio.get<Object?>('/protected');

      expect(
        adapter.singleRequest.headers[AuthHttpHeaders.authorization],
        'Bearer token-a',
      );
      expect(adapter.singleRequest.headers['x-feature'], isNull);
    });

    test('does not add Authorization when no token exists', () async {
      final adapter = RecordingAdapter((_) => _jsonResponse(200, {'data': {}}));
      final dio = _dioWithAuth(
        tokenStore: AuthTokenStore(FakeSecureValueStore()),
        adapter: adapter,
      );

      await dio.get<Object?>('/protected');

      expect(
        adapter.singleRequest.headers.containsKey(
          AuthHttpHeaders.authorization,
        ),
        isFalse,
      );
    });

    test('preserves unrelated request headers', () async {
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      await tokenStore.write('token-a');
      final adapter = RecordingAdapter((_) => _jsonResponse(200, {'data': {}}));
      final dio = _dioWithAuth(tokenStore: tokenStore, adapter: adapter);

      await dio.get<Object?>(
        '/protected',
        options: Options(headers: {'x-feature': 'auth-test'}),
      );

      expect(adapter.singleRequest.headers['x-feature'], 'auth-test');
      expect(
        adapter.singleRequest.headers[AuthHttpHeaders.authorization],
        'Bearer token-a',
      );
    });

    test('does not add stale token to public login requests', () async {
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      await tokenStore.write('stale-token');
      final adapter = RecordingAdapter((_) => _jsonResponse(200, {'data': {}}));
      final dio = _dioWithAuth(tokenStore: tokenStore, adapter: adapter);

      await dio.post<Object?>(
        '/auth/login',
        data: {'login': 'teacher01', 'password': 'secret'},
        options: AuthRequestOptions.publicRequest(),
      );

      expect(
        adapter.singleRequest.headers.containsKey(
          AuthHttpHeaders.authorization,
        ),
        isFalse,
      );
    });

    test('emits invalidation for 401 authentication_required', () async {
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      await tokenStore.write('token-a');
      final signal = SessionInvalidationSignal();
      final events = <SessionInvalidationEvent>[];
      final subscription = signal.stream.listen(events.add);
      final adapter = RecordingAdapter(
        (_) => _jsonResponse(401, _error(ApiErrorCodes.authenticationRequired)),
      );
      final dio = _dioWithAuth(
        tokenStore: tokenStore,
        signal: signal,
        adapter: adapter,
      );

      await expectLater(
        dio.get<Object?>('/protected'),
        throwsA(isA<DioException>()),
      );
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(
        events.single.reason,
        SessionInvalidationReason.authenticationRequired,
      );
      expect(events.single.tokenVersion, tokenStore.version);
      expect(adapter.requestCount, 1);

      await subscription.cancel();
      await signal.dispose();
    });

    test('does not invalidate for public invalid_credentials', () async {
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      await tokenStore.write('token-a');
      final signal = SessionInvalidationSignal();
      final events = <SessionInvalidationEvent>[];
      final subscription = signal.stream.listen(events.add);
      final adapter = RecordingAdapter(
        (_) => _jsonResponse(401, _error(ApiErrorCodes.invalidCredentials)),
      );
      final dio = _dioWithAuth(
        tokenStore: tokenStore,
        signal: signal,
        adapter: adapter,
      );

      await expectLater(
        dio.post<Object?>(
          '/auth/login',
          data: {'login': 'teacher01', 'password': 'wrong'},
          options: AuthRequestOptions.publicRequest(),
        ),
        throwsA(isA<DioException>()),
      );
      await pumpEventQueue();

      expect(events, isEmpty);
      expect(adapter.requestCount, 1);

      await subscription.cancel();
      await signal.dispose();
    });

    test('does not invalidate for 403 forbidden', () async {
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      await tokenStore.write('token-a');
      final signal = SessionInvalidationSignal();
      final events = <SessionInvalidationEvent>[];
      final subscription = signal.stream.listen(events.add);
      final adapter = RecordingAdapter(
        (_) => _jsonResponse(403, _error(ApiErrorCodes.forbidden)),
      );
      final dio = _dioWithAuth(
        tokenStore: tokenStore,
        signal: signal,
        adapter: adapter,
      );

      await expectLater(
        dio.get<Object?>('/protected'),
        throwsA(isA<DioException>()),
      );
      await pumpEventQueue();

      expect(events, isEmpty);
      expect(adapter.requestCount, 1);

      await subscription.cancel();
      await signal.dispose();
    });

    test(
      'does not invalidate when an old token request is superseded',
      () async {
        final tokenStore = AuthTokenStore(FakeSecureValueStore());
        await tokenStore.write('token-a');
        final signal = SessionInvalidationSignal();
        final events = <SessionInvalidationEvent>[];
        final subscription = signal.stream.listen(events.add);
        final adapter = RecordingAdapter((_) async {
          await tokenStore.write('token-b');

          return _jsonResponse(
            401,
            _error(ApiErrorCodes.authenticationRequired),
          );
        });
        final dio = _dioWithAuth(
          tokenStore: tokenStore,
          signal: signal,
          adapter: adapter,
        );

        await expectLater(
          dio.get<Object?>('/protected'),
          throwsA(isA<DioException>()),
        );
        await pumpEventQueue();

        expect(events, isEmpty);
        expect(await tokenStore.read(), 'token-b');
        expect(adapter.requestCount, 1);

        await subscription.cancel();
        await signal.dispose();
      },
    );

    test('mapped failures do not include bearer token text', () async {
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      await tokenStore.write('secret-token');
      final adapter = RecordingAdapter(
        (_) => _jsonResponse(401, _error(ApiErrorCodes.authenticationRequired)),
      );
      final dio = _dioWithAuth(tokenStore: tokenStore, adapter: adapter);

      try {
        await dio.get<Object?>('/protected');
        fail('Expected DioException.');
      } on DioException catch (exception) {
        final failure = const DioFailureMapper().map(exception);

        expect(failure.message, isNot(contains('secret-token')));
        expect(failure.serverCode, ApiErrorCodes.authenticationRequired);
      }
    });

    test(
      'byte authentication_required invalidates only the current session',
      () async {
        final tokenStore = AuthTokenStore(FakeSecureValueStore());
        await tokenStore.write('token-a');
        final signal = SessionInvalidationSignal();
        final events = <SessionInvalidationEvent>[];
        final subscription = signal.stream.listen(events.add);
        final dio = _dioWithAuth(
          tokenStore: tokenStore,
          signal: signal,
          adapter: RecordingAdapter(
            (_) =>
                _byteErrorResponse(401, ApiErrorCodes.authenticationRequired),
          ),
        );

        await expectLater(
          dio.get<List<int>>(
            '/files/file-id/download',
            options: Options(responseType: ResponseType.bytes),
          ),
          throwsA(isA<DioException>()),
        );
        await pumpEventQueue();

        expect(events, hasLength(1));
        expect(events.single.tokenVersion, tokenStore.version);
        await subscription.cancel();
        await signal.dispose();
      },
    );

    test('stale token version ignores byte authentication error', () async {
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      await tokenStore.write('token-a');
      final signal = SessionInvalidationSignal();
      final events = <SessionInvalidationEvent>[];
      final subscription = signal.stream.listen(events.add);
      final dio = _dioWithAuth(
        tokenStore: tokenStore,
        signal: signal,
        adapter: RecordingAdapter((_) async {
          await tokenStore.write('token-b');
          return _byteErrorResponse(401, ApiErrorCodes.authenticationRequired);
        }),
      );

      await expectLater(
        dio.get<List<int>>(
          '/files/file-id/download',
          options: Options(responseType: ResponseType.bytes),
        ),
        throwsA(isA<DioException>()),
      );
      await pumpEventQueue();

      expect(events, isEmpty);
      await subscription.cancel();
      await signal.dispose();
    });

    test('non-401 and malformed byte errors do not invalidate', () async {
      for (final response in [
        _byteErrorResponse(403, ApiErrorCodes.authenticationRequired),
        ResponseBody.fromBytes(
          Uint8List.fromList([0xc3, 0x28]),
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      ]) {
        final tokenStore = AuthTokenStore(FakeSecureValueStore());
        await tokenStore.write('token-a');
        final signal = SessionInvalidationSignal();
        final events = <SessionInvalidationEvent>[];
        final subscription = signal.stream.listen(events.add);
        final dio = _dioWithAuth(
          tokenStore: tokenStore,
          signal: signal,
          adapter: RecordingAdapter((_) => response),
        );

        await expectLater(
          dio.get<List<int>>(
            '/files/file-id/download',
            options: Options(responseType: ResponseType.bytes),
          ),
          throwsA(isA<DioException>()),
        );
        await pumpEventQueue();

        expect(events, isEmpty);
        await subscription.cancel();
        await signal.dispose();
      }
    });
  });
}

Dio _dioWithAuth({
  required AuthTokenStore tokenStore,
  required RecordingAdapter adapter,
  SessionInvalidationSignal? signal,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
    ),
  );

  dio.interceptors.add(
    AuthTokenInterceptor(
      tokenStore: tokenStore,
      sessionInvalidationSignal: signal ?? SessionInvalidationSignal(),
    ),
  );
  dio.httpClientAdapter = adapter;

  return dio;
}

Map<String, Object?> _error(String code) {
  return {
    'message': 'Server rejected the request.',
    'code': code,
    'errors': <String, Object?>{},
    'request_id': 'req-1',
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

ResponseBody _byteErrorResponse(int statusCode, String code) {
  return ResponseBody.fromBytes(
    Uint8List.fromList(utf8.encode(jsonEncode(_error(code)))),
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

  int get requestCount => requests.length;

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
