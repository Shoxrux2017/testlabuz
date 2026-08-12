import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_detail_remote_data_source.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_detail_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution.dart';

void main() {
  group('PlatformInstitutionDetailRemoteDataSource', () {
    test(
      'uses exact encoded GET endpoint with no body query or client authority',
      () async {
        const institutionId = 'id with/slash?admin=true';
        final adapter = RecordingAdapter(
          (_) => _jsonResponse(200, _detailJson()),
        );
        final dataSource = PlatformInstitutionDetailRemoteDataSource(
          dio: _plainDio(adapter),
          failureMapper: const DioFailureMapper(),
        );

        final dto = await dataSource.fetchInstitutionDetail(institutionId);

        expect(dto.name, 'Example School');
        expect(adapter.requests, hasLength(1));
        expect(adapter.singleRequest.method, 'GET');
        expect(
          adapter.singleRequest.path,
          '/platform/institutions/id%20with%2Fslash%3Fadmin%3Dtrue',
        );
        expect(
          adapter.singleRequest.uri.path,
          '/api/v1/platform/institutions/id%20with%2Fslash%3Fadmin%3Dtrue',
        );
        expect(adapter.singleRequest.data, isNull);
        expect(adapter.singleRequest.queryParameters, isEmpty);
        expect(
          adapter.singleRequest.queryParameters.keys,
          isNot(
            containsAll([
              'institution_id',
              'role',
              'user_id',
              'include',
              'expand',
              'dashboard',
              'statistics',
              'admin',
            ]),
          ),
        );
      },
    );

    test(
      'success maps through repository preserving focused detail fields',
      () async {
        final dataSource = PlatformInstitutionDetailRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter(
              (_) => _jsonResponse(
                200,
                _detailJson(
                  name: 'Detail College',
                  type: 'college',
                  status: 'inactive',
                  contactEmail: null,
                  contactPhone: null,
                  address: null,
                  description: null,
                  userCounts: {'total': 3, 'active': 1},
                ),
              ),
            ),
          ),
          failureMapper: const DioFailureMapper(),
        );
        final repository = PlatformInstitutionDetailRepositoryImpl(
          remoteDataSource: dataSource,
        );

        final detail = await repository.fetchInstitutionDetail(
          '550e8400-e29b-41d4-a716-446655440000',
        );

        expect(detail.name, 'Detail College');
        expect(detail.type, PlatformInstitutionType.college);
        expect(detail.status, PlatformInstitutionStatus.inactive);
        expect(detail.contactEmail, isNull);
        expect(detail.contactPhone, isNull);
        expect(detail.address, isNull);
        expect(detail.description, isNull);
        expect(detail.userCounts.total, 3);
        expect(detail.userCounts.active, 1);
      },
    );

    test('preserves stable backend failures as typed ApiFailure', () async {
      final cases = [
        (statusCode: 401, code: ApiErrorCodes.authenticationRequired),
        (statusCode: 403, code: ApiErrorCodes.passwordChangeRequired),
        (statusCode: 403, code: ApiErrorCodes.userInactive),
        (statusCode: 403, code: ApiErrorCodes.institutionInactive),
        (statusCode: 403, code: ApiErrorCodes.forbidden),
        (statusCode: 404, code: ApiErrorCodes.resourceNotFound),
        (statusCode: 422, code: ApiErrorCodes.validationFailed),
        (statusCode: 500, code: 'server_error'),
      ];

      for (final testCase in cases) {
        final dataSource = PlatformInstitutionDetailRemoteDataSource(
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
          dataSource.fetchInstitutionDetail(
            '550e8400-e29b-41d4-a716-446655440000',
          ),
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
      'maps network timeout and decode failures without raw payload leakage',
      () async {
        final networkSource = PlatformInstitutionDetailRemoteDataSource(
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
          networkSource.fetchInstitutionDetail(
            '550e8400-e29b-41d4-a716-446655440000',
          ),
          throwsA(
            isA<ApiRequestException>().having(
              (exception) => exception.failure.kind,
              'kind',
              ApiFailureKind.connection,
            ),
          ),
        );

        final timeoutSource = PlatformInstitutionDetailRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter((options) {
              throw DioException(
                requestOptions: options,
                type: DioExceptionType.receiveTimeout,
              );
            }),
          ),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          timeoutSource.fetchInstitutionDetail(
            '550e8400-e29b-41d4-a716-446655440000',
          ),
          throwsA(
            isA<ApiRequestException>().having(
              (exception) => exception.failure.kind,
              'kind',
              ApiFailureKind.timeout,
            ),
          ),
        );

        final decodeSource = PlatformInstitutionDetailRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter((_) => _jsonResponse(200, {'data': {}})),
          ),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          decodeSource.fetchInstitutionDetail(
            '550e8400-e29b-41d4-a716-446655440000',
          ),
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

Map<String, Object?> _detailJson({
  String id = '550e8400-e29b-41d4-a716-446655440000',
  String name = 'Example School',
  String type = 'school',
  String status = 'active',
  Object? contactEmail = 'info@example.uz',
  Object? contactPhone = '+998901234567',
  Object? address = 'Samarkand',
  Object? description = 'Optional notes',
  String createdAt = '2026-08-07T15:00:00Z',
  String updatedAt = '2026-08-07T16:30:00Z',
  Map<String, Object?> userCounts = const {'total': 42, 'active': 40},
}) {
  return {
    'data': {
      'id': id,
      'name': name,
      'type': type,
      'status': status,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'address': address,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'user_counts': userCounts,
    },
  };
}

Map<String, Object?> _errorJson({required String code}) {
  return {
    'message': 'Backend internals must not be rendered.',
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
