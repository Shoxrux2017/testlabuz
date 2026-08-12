import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/platform_admin/data/dto/platform_institution_lifecycle_dto.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_lifecycle_remote_data_source.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_lifecycle_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_lifecycle_repository.dart';

void main() {
  group('PlatformInstitutionLifecycleResponseDto', () {
    test('decodes exact target envelope and ignores protected extras', () {
      final dto = PlatformInstitutionLifecycleResponseDto.fromJson(
        _lifecycleEnvelope(
          extra: {
            'settings': {'timezone': 'Asia/Tashkent'},
            'user_counts': {'total': 3},
            'created_by_user_id': 'hidden',
            'deactivated_at': '2026-08-10T12:00:00Z',
            'role': 'platform_owner',
          },
        ),
        requestedInstitutionId: _institutionId,
        targetStatus: PlatformInstitutionStatus.active,
      );
      final result = dto.toDomain();

      expect(result.id, _institutionId);
      expect(result.name, 'Example School');
      expect(result.type, PlatformInstitutionType.school);
      expect(result.status, PlatformInstitutionStatus.active);
      expect(result.contactEmail, 'info@example.uz');
      expect(result.contactPhone, '+998901234567');
      expect(result.address, 'Samarkand');
      expect(result.description, isNull);
      expect(result.createdAt, DateTime.utc(2026, 8, 7, 15));
      expect(result.updatedAt, DateTime.utc(2026, 8, 10, 12));
      expect(result.message, 'Institution activated successfully.');
    });

    test('decodes all accepted types and nullable optional fields', () {
      for (final type in PlatformInstitutionType.values) {
        final dto = PlatformInstitutionLifecycleResponseDto.fromJson(
          _lifecycleEnvelope(
            type: type.value,
            status: 'inactive',
            contactEmail: null,
            contactPhone: null,
            address: null,
            description: null,
            message: 'Institution deactivated successfully.',
          ),
          requestedInstitutionId: _institutionId,
          targetStatus: PlatformInstitutionStatus.inactive,
        );

        expect(dto.type, type);
        expect(dto.status, PlatformInstitutionStatus.inactive);
        expect(dto.contactEmail, isNull);
        expect(dto.contactPhone, isNull);
        expect(dto.address, isNull);
        expect(dto.description, isNull);
      }
    });

    test('rejects missing mismatched wrong-status invalid core data', () {
      final cases = [
        _lifecycleEnvelope(id: ''),
        _lifecycleEnvelope(id: '550e8400-e29b-41d4-a716-446655440099'),
        _lifecycleEnvelope(name: ''),
        _lifecycleEnvelope(type: 'academy'),
        _lifecycleEnvelope(status: 'inactive'),
        _lifecycleEnvelope(createdAt: '2026-08-07 15:00:00'),
        _lifecycleEnvelope(updatedAt: 'not-a-time'),
        _lifecycleEnvelope(message: ''),
        _lifecycleEnvelope(contactEmail: false),
      ];

      for (final json in cases) {
        expect(
          () => PlatformInstitutionLifecycleResponseDto.fromJson(
            json,
            requestedInstitutionId: _institutionId,
            targetStatus: PlatformInstitutionStatus.active,
          ),
          throwsFormatException,
        );
      }
    });
  });

  group('PlatformInstitutionLifecycleRemoteDataSource', () {
    test(
      'activate uses exact POST endpoint body and no extra authority',
      () async {
        const routeId = 'id with/slash?admin=true';
        final adapter = RecordingAdapter(
          (_) => _jsonResponse(
            200,
            _lifecycleEnvelope(id: routeId, status: 'active'),
          ),
        );
        final dataSource = PlatformInstitutionLifecycleRemoteDataSource(
          dio: _plainDio(adapter),
          failureMapper: const DioFailureMapper(),
        );

        final dto = await dataSource.activateInstitution(routeId);

        expect(dto.status, PlatformInstitutionStatus.active);
        expect(adapter.requests, hasLength(1));
        expect(adapter.singleRequest.method, 'POST');
        expect(
          adapter.singleRequest.path,
          '/platform/institutions/id%20with%2Fslash%3Fadmin%3Dtrue/activate',
        );
        expect(
          adapter.singleRequest.uri.path,
          '/api/v1/platform/institutions/id%20with%2Fslash%3Fadmin%3Dtrue/activate',
        );
        expect(adapter.singleRequest.queryParameters, isEmpty);
        expect(adapter.singleRequest.data, const <String, Object?>{});
        expect(adapter.singleRequest.data, isNot(isA<FormData>()));
        expect(
          adapter.singleRequest.headers.keys,
          isNot(
            containsAll([
              'Idempotency-Key',
              'ETag',
              'If-Match',
              'X-Institution-Id',
              'X-User-Role',
            ]),
          ),
        );
        expect(adapter.singleRequest.data.keys, isEmpty);
      },
    );

    test(
      'deactivate uses exact POST endpoint and maps repository result',
      () async {
        final adapter = RecordingAdapter(
          (_) => _jsonResponse(
            200,
            _lifecycleEnvelope(
              status: 'inactive',
              message: 'Institution deactivated successfully.',
            ),
          ),
        );
        final dataSource = PlatformInstitutionLifecycleRemoteDataSource(
          dio: _plainDio(adapter),
          failureMapper: const DioFailureMapper(),
        );
        final repository = PlatformInstitutionLifecycleRepositoryImpl(
          remoteDataSource: dataSource,
        );

        final result = await repository.deactivateInstitution(_institutionId);

        expect(result.status, PlatformInstitutionStatus.inactive);
        expect(result.message, 'Institution deactivated successfully.');
        expect(adapter.singleRequest.method, 'POST');
        expect(
          adapter.singleRequest.path,
          '/platform/institutions/$_institutionId/deactivate',
        );
        expect(adapter.singleRequest.data, const <String, Object?>{});
      },
    );

    test(
      'non-200 2xx malformed mismatch and wrong target are unknown',
      () async {
        final acceptedSource = PlatformInstitutionLifecycleRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter((_) => _jsonResponse(202, _lifecycleEnvelope())),
          ),
          failureMapper: const DioFailureMapper(),
        );
        await expectLater(
          acceptedSource.activateInstitution(_institutionId),
          throwsA(isA<PlatformInstitutionLifecycleOutcomeUnknownException>()),
        );

        final mismatchSource = PlatformInstitutionLifecycleRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter(
              (_) => _jsonResponse(
                200,
                _lifecycleEnvelope(id: '550e8400-e29b-41d4-a716-446655440999'),
              ),
            ),
          ),
          failureMapper: const DioFailureMapper(),
        );
        await expectLater(
          mismatchSource.activateInstitution(_institutionId),
          throwsA(isA<PlatformInstitutionLifecycleOutcomeUnknownException>()),
        );

        final malformedSource = PlatformInstitutionLifecycleRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter((_) => _jsonResponse(200, {'data': {}})),
          ),
          failureMapper: const DioFailureMapper(),
        );
        await expectLater(
          malformedSource.activateInstitution(_institutionId),
          throwsA(isA<PlatformInstitutionLifecycleOutcomeUnknownException>()),
        );

        final wrongTargetSource = PlatformInstitutionLifecycleRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter(
              (_) => _jsonResponse(200, _lifecycleEnvelope(status: 'inactive')),
            ),
          ),
          failureMapper: const DioFailureMapper(),
        );
        await expectLater(
          wrongTargetSource.activateInstitution(_institutionId),
          throwsA(isA<PlatformInstitutionLifecycleOutcomeUnknownException>()),
        );
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
        (statusCode: 409, code: 'lifecycle_conflict'),
        (statusCode: 500, code: ApiErrorCodes.serverError),
      ];

      for (final testCase in cases) {
        final dataSource = PlatformInstitutionLifecycleRemoteDataSource(
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
          dataSource.activateInstitution(_institutionId),
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

    test('maps transport timeout or disconnect as unknown outcome', () async {
      for (final type in [
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        final dataSource = PlatformInstitutionLifecycleRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter((options) {
              throw DioException(requestOptions: options, type: type);
            }),
          ),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          dataSource.deactivateInstitution(_institutionId),
          throwsA(isA<PlatformInstitutionLifecycleOutcomeUnknownException>()),
        );
      }
    });
  });
}

Dio _plainDio(RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: const {Headers.acceptHeader: Headers.jsonContentType},
    ),
  );
  dio.httpClientAdapter = adapter;

  return dio;
}

Map<String, Object?> _lifecycleEnvelope({
  String id = _institutionId,
  String name = 'Example School',
  String type = 'school',
  String status = 'active',
  Object? contactEmail = 'info@example.uz',
  Object? contactPhone = '+998901234567',
  Object? address = 'Samarkand',
  Object? description,
  String createdAt = '2026-08-07T15:00:00Z',
  String updatedAt = '2026-08-10T12:00:00Z',
  String message = 'Institution activated successfully.',
  Map<String, Object?> extra = const {},
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
      ...extra,
    },
    'message': message,
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

const _institutionId = '550e8400-e29b-41d4-a716-446655440000';
