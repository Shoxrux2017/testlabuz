import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/platform_admin/data/dto/platform_institution_create_dto.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_create_remote_data_source.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_create_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_create.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_create_repository.dart';

void main() {
  group('PlatformInstitutionCreateResponseDto', () {
    test(
      'decodes exact 201 envelope fields and ignores unknown protected data',
      () {
        final dto = PlatformInstitutionCreateResponseDto.fromJson(
          _createEnvelope(
            extra: {
              'settings': {'timezone': 'Asia/Tashkent'},
              'user_counts': {'total': 1},
              'created_by_user_id': 'hidden',
              'role': 'platform_owner',
            },
          ),
        );
        final result = dto.toDomain();

        expect(result.id, '550e8400-e29b-41d4-a716-446655440000');
        expect(result.name, 'Example School');
        expect(result.type, PlatformInstitutionType.school);
        expect(result.status, PlatformInstitutionStatus.active);
        expect(result.contactEmail, 'info@example.uz');
        expect(result.contactPhone, '+998901234567');
        expect(result.address, 'Samarkand');
        expect(result.description, 'Optional notes');
        expect(result.createdAt, DateTime.utc(2026, 8, 7, 15));
        expect(result.updatedAt, DateTime.utc(2026, 8, 7, 16));
        expect(result.message, 'Institution created successfully.');
      },
    );

    test(
      'decodes all accepted types statuses and nullable optional fields',
      () {
        for (final type in PlatformInstitutionType.values) {
          for (final status in PlatformInstitutionStatus.values) {
            final dto = PlatformInstitutionCreateResponseDto.fromJson(
              _createEnvelope(
                type: type.value,
                status: status.value,
                contactEmail: null,
                contactPhone: null,
                address: null,
                description: null,
              ),
            );

            expect(dto.type, type);
            expect(dto.status, status);
            expect(dto.contactEmail, isNull);
            expect(dto.contactPhone, isNull);
            expect(dto.address, isNull);
            expect(dto.description, isNull);
          }
        }
      },
    );

    test('rejects missing null wrong unknown enum and invalid time fields', () {
      final cases = [
        _createEnvelope(id: ''),
        _createEnvelope(name: ''),
        _createEnvelope(type: 'academy'),
        _createEnvelope(status: 'archived'),
        _createEnvelope(createdAt: '2026-08-07 15:00:00'),
        _createEnvelope(updatedAt: 'not-a-time'),
        _createEnvelope(message: ''),
        _createEnvelope(contactEmail: false),
      ];

      for (final json in cases) {
        expect(
          () => PlatformInstitutionCreateResponseDto.fromJson(json),
          throwsFormatException,
        );
      }
    });
  });

  group('PlatformInstitutionCreateRemoteDataSource', () {
    test(
      'uses exact POST endpoint body and no query idempotency or authority',
      () async {
        final adapter = RecordingAdapter(
          (_) => _jsonResponse(201, _createEnvelope()),
        );
        final dataSource = PlatformInstitutionCreateRemoteDataSource(
          dio: _plainDio(adapter),
          failureMapper: const DioFailureMapper(),
        );

        final dto = await dataSource.createInstitution(_request());

        expect(dto.name, 'Example School');
        expect(adapter.requests, hasLength(1));
        expect(adapter.singleRequest.method, 'POST');
        expect(adapter.singleRequest.path, '/platform/institutions');
        expect(adapter.singleRequest.uri.path, '/api/v1/platform/institutions');
        expect(adapter.singleRequest.queryParameters, isEmpty);
        expect(adapter.singleRequest.data, {
          'name': 'Example School',
          'type': 'school',
          'contact_email': 'info@example.uz',
          'contact_phone': '+998901234567',
          'address': 'Samarkand',
          'description': 'Optional notes',
          'status': 'active',
        });
        expect(adapter.singleRequest.data.keys, hasLength(7));
        expect(adapter.singleRequest.data, isNot(isA<FormData>()));
        expect(
          adapter.singleRequest.headers.keys,
          isNot(contains('Idempotency-Key')),
        );
        expect(
          adapter.singleRequest.data.keys,
          isNot(
            containsAll([
              'id',
              'institution_id',
              'created_by_user_id',
              'deactivated_at',
              'created_at',
              'updated_at',
              'settings',
              'timezone',
              'learning_material_max_mb',
              'student_submission_max_mb',
              'acceptable_score_difference',
              'blitz_timer_start_mode',
              'student_result_release_mode',
              'parent_result_release_mode',
              'role',
              'user_counts',
            ]),
          ),
        );
      },
    );

    test('success maps through repository preserving typed result', () async {
      final dataSource = PlatformInstitutionCreateRemoteDataSource(
        dio: _plainDio(
          RecordingAdapter(
            (_) => _jsonResponse(
              201,
              _createEnvelope(type: 'college', status: 'inactive'),
            ),
          ),
        ),
        failureMapper: const DioFailureMapper(),
      );
      final repository = PlatformInstitutionCreateRepositoryImpl(
        remoteDataSource: dataSource,
      );

      final result = await repository.createInstitution(
        _request(
          type: PlatformInstitutionType.college,
          status: PlatformInstitutionStatus.inactive,
        ),
      );

      expect(result.type, PlatformInstitutionType.college);
      expect(result.status, PlatformInstitutionStatus.inactive);
      expect(result.message, 'Institution created successfully.');
    });

    test('does not accept 200 or malformed 201 as confirmed success', () async {
      final okSource = PlatformInstitutionCreateRemoteDataSource(
        dio: _plainDio(
          RecordingAdapter((_) => _jsonResponse(200, _createEnvelope())),
        ),
        failureMapper: const DioFailureMapper(),
      );
      await expectLater(
        okSource.createInstitution(_request()),
        throwsA(isA<PlatformInstitutionCreateOutcomeUnknownException>()),
      );

      final malformedSource = PlatformInstitutionCreateRemoteDataSource(
        dio: _plainDio(
          RecordingAdapter(
            (_) => _jsonResponse(201, {
              'data': {'id': 'not-a-uuid'},
              'message': 'Institution created successfully.',
            }),
          ),
        ),
        failureMapper: const DioFailureMapper(),
      );
      await expectLater(
        malformedSource.createInstitution(_request()),
        throwsA(isA<PlatformInstitutionCreateOutcomeUnknownException>()),
      );
    });

    test('preserves stable backend failures as typed ApiFailure', () async {
      final cases = [
        (statusCode: 401, code: ApiErrorCodes.authenticationRequired),
        (statusCode: 403, code: ApiErrorCodes.passwordChangeRequired),
        (statusCode: 403, code: ApiErrorCodes.userInactive),
        (statusCode: 403, code: ApiErrorCodes.forbidden),
        (statusCode: 422, code: ApiErrorCodes.validationFailed),
        (statusCode: 500, code: ApiErrorCodes.serverError),
      ];

      for (final testCase in cases) {
        final dataSource = PlatformInstitutionCreateRemoteDataSource(
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
          dataSource.createInstitution(_request()),
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
      final dataSource = PlatformInstitutionCreateRemoteDataSource(
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
        dataSource.createInstitution(_request()),
        throwsA(isA<PlatformInstitutionCreateOutcomeUnknownException>()),
      );
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

PlatformInstitutionCreateRequest _request({
  PlatformInstitutionType type = PlatformInstitutionType.school,
  PlatformInstitutionStatus status = PlatformInstitutionStatus.active,
}) {
  return PlatformInstitutionCreateRequest(
    name: 'Example School',
    type: type,
    contactEmail: 'info@example.uz',
    contactPhone: '+998901234567',
    address: 'Samarkand',
    description: 'Optional notes',
    status: status,
  );
}

Map<String, Object?> _createEnvelope({
  String id = '550e8400-e29b-41d4-a716-446655440000',
  String name = 'Example School',
  String type = 'school',
  String status = 'active',
  Object? contactEmail = 'info@example.uz',
  Object? contactPhone = '+998901234567',
  Object? address = 'Samarkand',
  Object? description = 'Optional notes',
  String createdAt = '2026-08-07T15:00:00Z',
  String updatedAt = '2026-08-07T16:00:00Z',
  String message = 'Institution created successfully.',
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
