import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/auth_request_options.dart';
import 'package:testlabuz_client/core/network/auth_token_interceptor.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/core/network/session_invalidation_signal.dart';
import 'package:testlabuz_client/core/storage/auth_token_store.dart';
import 'package:testlabuz_client/core/storage/secure_value_store.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_dashboard_remote_data_source.dart';

void main() {
  group('InstitutionDashboardRemoteDataSource', () {
    test(
      'uses one exact authenticated GET without body query or tenant input',
      () async {
        final tokenStore = AuthTokenStore(FakeSecureValueStore());
        await tokenStore.write('dashboard-token');
        final signal = SessionInvalidationSignal();
        addTearDown(signal.dispose);
        final adapter = RecordingAdapter(
          (_) => _jsonResponse(200, _dashboardJson()),
        );
        final dataSource = InstitutionDashboardRemoteDataSource(
          dio: _dioWithAuth(
            adapter: adapter,
            tokenStore: tokenStore,
            signal: signal,
          ),
          failureMapper: const DioFailureMapper(),
        );

        final dto = await dataSource.fetchDashboard();

        expect(dto.teachers, 30);
        expect(adapter.requests, hasLength(1));
        final request = adapter.singleRequest;
        expect(request.method, 'GET');
        expect(request.path, '/institution/dashboard');
        expect(request.uri.path, '/api/v1/institution/dashboard');
        expect(request.queryParameters, isEmpty);
        expect(request.uri.query, isEmpty);
        expect(request.data, isNull);
        expect(request.extra[AuthRequestOptions.skipAuthExtraKey], isNot(true));
        expect(
          request.headers[AuthHttpHeaders.authorization],
          'Bearer dashboard-token',
        );
        expect(request.headers.keys, isNot(contains('institution_id')));
        expect(request.headers.keys, isNot(contains('X-Institution-Id')));
      },
    );

    test('preserves typed server and transport failures', () async {
      final serverCases = [
        (statusCode: 401, code: ApiErrorCodes.authenticationRequired),
        (statusCode: 403, code: ApiErrorCodes.passwordChangeRequired),
        (statusCode: 403, code: ApiErrorCodes.userInactive),
        (statusCode: 403, code: ApiErrorCodes.institutionInactive),
        (statusCode: 403, code: ApiErrorCodes.forbidden),
        (statusCode: 422, code: ApiErrorCodes.validationFailed),
        (statusCode: 500, code: ApiErrorCodes.serverError),
      ];

      for (final testCase in serverCases) {
        final dataSource = InstitutionDashboardRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter(
              (_) =>
                  _jsonResponse(testCase.statusCode, _errorJson(testCase.code)),
            ),
          ),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          dataSource.fetchDashboard(),
          throwsA(
            isA<ApiRequestException>()
                .having(
                  (exception) => exception.failure.statusCode,
                  'statusCode',
                  testCase.statusCode,
                )
                .having(
                  (exception) => exception.failure.serverCode,
                  'serverCode',
                  testCase.code,
                ),
          ),
        );
      }

      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.cancel,
      ]) {
        final dataSource = InstitutionDashboardRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter((options) {
              throw DioException(requestOptions: options, type: type);
            }),
          ),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          dataSource.fetchDashboard(),
          throwsA(isA<ApiRequestException>()),
        );
      }
    });

    test('maps malformed success shapes to invalidResponse', () async {
      final invalidResponses = <Object?>[
        const {},
        {'data': const {}},
        {
          'data': {'users': const {}},
        },
        {
          'data': {
            'users': {'teachers': 1, 'students': 2, 'parents': '3'},
          },
        },
      ];

      for (final response in invalidResponses) {
        final dataSource = InstitutionDashboardRemoteDataSource(
          dio: _plainDio(RecordingAdapter((_) => _jsonResponse(200, response))),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          dataSource.fetchDashboard(),
          throwsA(
            isA<ApiRequestException>().having(
              (exception) => exception.failure.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );
      }
    });

    test('current-token 401 emits central invalidation exactly once', () async {
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      await tokenStore.write('current-token');
      final signal = SessionInvalidationSignal();
      addTearDown(signal.dispose);
      final events = <SessionInvalidationEvent>[];
      final subscription = signal.stream.listen(events.add);
      addTearDown(subscription.cancel);
      final dataSource = InstitutionDashboardRemoteDataSource(
        dio: _dioWithAuth(
          adapter: RecordingAdapter(
            (_) => _jsonResponse(
              401,
              _errorJson(ApiErrorCodes.authenticationRequired),
            ),
          ),
          tokenStore: tokenStore,
          signal: signal,
        ),
        failureMapper: const DioFailureMapper(),
      );

      await expectLater(dataSource.fetchDashboard(), throwsException);
      await _flush();

      expect(events, hasLength(1));
      expect(events.single.tokenVersion, tokenStore.version);
    });

    test('stale-token 401 cannot invalidate a newer token version', () async {
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      await tokenStore.write('old-token');
      final responseCompleter = Completer<ResponseBody>();
      final requestStarted = Completer<void>();
      final signal = SessionInvalidationSignal();
      addTearDown(signal.dispose);
      final events = <SessionInvalidationEvent>[];
      final subscription = signal.stream.listen(events.add);
      addTearDown(subscription.cancel);
      final dataSource = InstitutionDashboardRemoteDataSource(
        dio: _dioWithAuth(
          adapter: RecordingAdapter((_) {
            requestStarted.complete();

            return responseCompleter.future;
          }),
          tokenStore: tokenStore,
          signal: signal,
        ),
        failureMapper: const DioFailureMapper(),
      );

      final request = dataSource.fetchDashboard();
      await requestStarted.future;
      await tokenStore.write('new-token');
      responseCompleter.complete(
        _jsonResponse(401, _errorJson(ApiErrorCodes.authenticationRequired)),
      );

      await expectLater(request, throwsException);
      await _flush();
      expect(events, isEmpty);
    });
  });
}

Dio _dioWithAuth({
  required RecordingAdapter adapter,
  required AuthTokenStore tokenStore,
  required SessionInvalidationSignal signal,
}) {
  final dio = _plainDio(adapter);
  dio.interceptors.add(
    AuthTokenInterceptor(
      tokenStore: tokenStore,
      sessionInvalidationSignal: signal,
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

Map<String, Object?> _dashboardJson() {
  return {
    'data': {
      'users': {'teachers': 30, 'students': 600, 'parents': 450},
    },
  };
}

Map<String, Object?> _errorJson(String code) {
  return {
    'message': 'Raw backend dashboard detail.',
    'code': code,
    'errors': {},
    'request_id': 'req-private',
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

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
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
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}
