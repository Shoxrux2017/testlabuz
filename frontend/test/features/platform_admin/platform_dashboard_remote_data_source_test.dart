import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_dashboard_remote_data_source.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_dashboard_repository_impl.dart';

void main() {
  group('PlatformDashboardRemoteDataSource', () {
    test(
      'uses exact GET endpoint without query body or client scope',
      () async {
        final adapter = RecordingAdapter(
          (_) => _jsonResponse(200, _dashboardJson()),
        );
        final dataSource = PlatformDashboardRemoteDataSource(
          dio: _plainDio(adapter),
          failureMapper: const DioFailureMapper(),
        );

        final dto = await dataSource.fetchDashboard();

        expect(dto.institutions.total, 20);
        expect(adapter.requests, hasLength(1));
        expect(adapter.singleRequest.method, 'GET');
        expect(adapter.singleRequest.path, '/platform/dashboard');
        expect(adapter.singleRequest.uri.path, '/api/v1/platform/dashboard');
        expect(adapter.singleRequest.queryParameters, isEmpty);
        expect(adapter.singleRequest.data, isNull);
        expect(adapter.singleRequest.uri.query, isEmpty);
        expect(
          adapter.singleRequest.queryParameters.keys,
          isNot(
            containsAll([
              'institution_id',
              'role',
              'user_id',
              'metrics',
              'limit',
              'page',
              'sort',
              'include',
            ]),
          ),
        );
      },
    );

    test('maps success through repository to exact domain model', () async {
      final dataSource = PlatformDashboardRemoteDataSource(
        dio: _plainDio(
          RecordingAdapter((_) => _jsonResponse(200, _dashboardJson())),
        ),
        failureMapper: const DioFailureMapper(),
      );
      final repository = PlatformDashboardRepositoryImpl(
        remoteDataSource: dataSource,
      );

      final dashboard = await repository.fetchDashboard();

      expect(dashboard.institutions.total, 20);
      expect(dashboard.users.active, 2720);
      expect(dashboard.recentInstitutions.single.name, 'Example School');
    });

    test('preserves stable backend failures as typed ApiFailure', () async {
      final cases = [
        (statusCode: 401, code: ApiErrorCodes.authenticationRequired),
        (statusCode: 403, code: ApiErrorCodes.passwordChangeRequired),
        (statusCode: 403, code: ApiErrorCodes.userInactive),
        (statusCode: 403, code: ApiErrorCodes.institutionInactive),
        (statusCode: 403, code: ApiErrorCodes.forbidden),
        (statusCode: 422, code: ApiErrorCodes.validationFailed),
        (statusCode: 500, code: 'server_error'),
      ];

      for (final testCase in cases) {
        final dataSource = PlatformDashboardRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter(
              (_) => _jsonResponse(
                testCase.statusCode,
                _errorJson(code: testCase.code),
              ),
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
    });

    test(
      'maps network and decode failures without raw response leakage',
      () async {
        final networkSource = PlatformDashboardRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter((options) {
              throw DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              );
            }),
          ),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          networkSource.fetchDashboard(),
          throwsA(
            isA<ApiRequestException>().having(
              (exception) => exception.failure.kind,
              'kind',
              ApiFailureKind.connection,
            ),
          ),
        );

        final decodeSource = PlatformDashboardRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter((_) => _jsonResponse(200, {'data': {}})),
          ),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          decodeSource.fetchDashboard(),
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
      'institutions': {'total': 20, 'active': 18, 'inactive': 2},
      'users': {'total': 2800, 'active': 2720},
      'recent_institutions': [
        {
          'id': '00000000-0000-0000-0000-000000000001',
          'name': 'Example School',
          'type': 'school',
          'status': 'active',
          'created_at': '2026-08-01T10:00:00Z',
        },
      ],
    },
  };
}

Map<String, Object?> _errorJson({required String code}) {
  return {
    'message': 'Backend message not used for dashboard logic.',
    'code': code,
    'errors': {},
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
