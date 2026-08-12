import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/platform_admin/data/dto/platform_institution_edit_dto.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_edit_remote_data_source.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_edit_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_edit.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_edit_repository.dart';

void main() {
  group('PlatformInstitutionEditResponseDto', () {
    test('decodes exact 200 envelope and ignores unknown protected data', () {
      final dto = PlatformInstitutionEditResponseDto.fromJson(
        _editEnvelope(
          extra: {
            'settings': {'timezone': 'Asia/Tashkent'},
            'user_counts': {'total': 3},
            'created_by_user_id': 'hidden',
            'role': 'platform_owner',
          },
        ),
        requestedInstitutionId: _institutionId,
      );
      final result = dto.toDomain();

      expect(result.id, _institutionId);
      expect(result.name, 'Updated Name');
      expect(result.type, PlatformInstitutionType.school);
      expect(result.status, PlatformInstitutionStatus.active);
      expect(result.contactEmail, 'updated@example.uz');
      expect(result.contactPhone, '+998901234567');
      expect(result.address, 'Updated address');
      expect(result.description, isNull);
      expect(result.createdAt, DateTime.utc(2026, 8, 7, 15));
      expect(result.updatedAt, DateTime.utc(2026, 8, 10, 12));
      expect(result.message, 'Institution updated successfully.');
    });

    test('decodes all accepted enums and nullable optional fields', () {
      for (final type in PlatformInstitutionType.values) {
        for (final status in PlatformInstitutionStatus.values) {
          final dto = PlatformInstitutionEditResponseDto.fromJson(
            _editEnvelope(
              type: type.value,
              status: status.value,
              contactEmail: null,
              contactPhone: null,
              address: null,
              description: null,
            ),
            requestedInstitutionId: _institutionId,
          );

          expect(dto.type, type);
          expect(dto.status, status);
          expect(dto.contactEmail, isNull);
          expect(dto.contactPhone, isNull);
          expect(dto.address, isNull);
          expect(dto.description, isNull);
        }
      }
    });

    test(
      'rejects missing wrong unknown invalid-time and mismatched core data',
      () {
        final cases = [
          _editEnvelope(id: ''),
          _editEnvelope(id: '550e8400-e29b-41d4-a716-446655440099'),
          _editEnvelope(name: ''),
          _editEnvelope(type: 'academy'),
          _editEnvelope(status: 'archived'),
          _editEnvelope(createdAt: '2026-08-07 15:00:00'),
          _editEnvelope(updatedAt: 'not-a-time'),
          _editEnvelope(message: ''),
          _editEnvelope(contactEmail: false),
        ];

        for (final json in cases) {
          expect(
            () => PlatformInstitutionEditResponseDto.fromJson(
              json,
              requestedInstitutionId: _institutionId,
            ),
            throwsFormatException,
          );
        }
      },
    );
  });

  group('PlatformInstitutionEditRemoteDataSource', () {
    test(
      'uses exact PATCH endpoint body and no query idempotency or authority',
      () async {
        const routeId = 'id with/slash?admin=true';
        final adapter = RecordingAdapter(
          (_) => _jsonResponse(200, _editEnvelope(id: routeId)),
        );
        final dataSource = PlatformInstitutionEditRemoteDataSource(
          dio: _plainDio(adapter),
          failureMapper: const DioFailureMapper(),
        );

        final dto = await dataSource.updateInstitution(
          routeId,
          PlatformInstitutionEditRequest({
            'name': 'Updated Name',
            'contact_email': 'updated@example.uz',
            'description': null,
          }),
        );

        expect(dto.name, 'Updated Name');
        expect(adapter.requests, hasLength(1));
        expect(adapter.singleRequest.method, 'PATCH');
        expect(
          adapter.singleRequest.path,
          '/platform/institutions/id%20with%2Fslash%3Fadmin%3Dtrue',
        );
        expect(
          adapter.singleRequest.uri.path,
          '/api/v1/platform/institutions/id%20with%2Fslash%3Fadmin%3Dtrue',
        );
        expect(adapter.singleRequest.queryParameters, isEmpty);
        expect(adapter.singleRequest.data, {
          'name': 'Updated Name',
          'contact_email': 'updated@example.uz',
          'description': null,
        });
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
        expect(
          adapter.singleRequest.data.keys,
          isNot(
            containsAll([
              'id',
              'institution_id',
              'status',
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
              'users',
              'user_counts',
            ]),
          ),
        );
      },
    );

    test('success maps through repository preserving typed result', () async {
      final dataSource = PlatformInstitutionEditRemoteDataSource(
        dio: _plainDio(
          RecordingAdapter(
            (_) => _jsonResponse(
              200,
              _editEnvelope(type: 'college', status: 'inactive'),
            ),
          ),
        ),
        failureMapper: const DioFailureMapper(),
      );
      final repository = PlatformInstitutionEditRepositoryImpl(
        remoteDataSource: dataSource,
      );

      final result = await repository.updateInstitution(
        _institutionId,
        PlatformInstitutionEditRequest({'type': 'college'}),
      );

      expect(result.type, PlatformInstitutionType.college);
      expect(result.status, PlatformInstitutionStatus.inactive);
      expect(result.message, 'Institution updated successfully.');
    });

    test('empty request is blocked before PATCH', () async {
      final adapter = RecordingAdapter(
        (_) => _jsonResponse(200, _editEnvelope()),
      );
      final dataSource = PlatformInstitutionEditRemoteDataSource(
        dio: _plainDio(adapter),
        failureMapper: const DioFailureMapper(),
      );

      expect(
        () => dataSource.updateInstitution(
          _institutionId,
          PlatformInstitutionEditRequest(const {}),
        ),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });

    test(
      'non-200 2xx mismatch malformed and invalid success are unknown outcome',
      () async {
        final acceptedSource = PlatformInstitutionEditRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter((_) => _jsonResponse(202, _editEnvelope())),
          ),
          failureMapper: const DioFailureMapper(),
        );
        await expectLater(
          acceptedSource.updateInstitution(_institutionId, _request()),
          throwsA(isA<PlatformInstitutionEditOutcomeUnknownException>()),
        );

        final mismatchSource = PlatformInstitutionEditRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter(
              (_) => _jsonResponse(
                200,
                _editEnvelope(id: '550e8400-e29b-41d4-a716-446655440999'),
              ),
            ),
          ),
          failureMapper: const DioFailureMapper(),
        );
        await expectLater(
          mismatchSource.updateInstitution(_institutionId, _request()),
          throwsA(isA<PlatformInstitutionEditOutcomeUnknownException>()),
        );

        final malformedSource = PlatformInstitutionEditRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter((_) => _jsonResponse(200, {'data': {}})),
          ),
          failureMapper: const DioFailureMapper(),
        );
        await expectLater(
          malformedSource.updateInstitution(_institutionId, _request()),
          throwsA(isA<PlatformInstitutionEditOutcomeUnknownException>()),
        );

        final invalidEnumSource = PlatformInstitutionEditRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter(
              (_) => _jsonResponse(200, _editEnvelope(status: 'pending')),
            ),
          ),
          failureMapper: const DioFailureMapper(),
        );
        await expectLater(
          invalidEnumSource.updateInstitution(_institutionId, _request()),
          throwsA(isA<PlatformInstitutionEditOutcomeUnknownException>()),
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
        (statusCode: 500, code: ApiErrorCodes.serverError),
      ];

      for (final testCase in cases) {
        final dataSource = PlatformInstitutionEditRemoteDataSource(
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
          dataSource.updateInstitution(_institutionId, _request()),
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
        final dataSource = PlatformInstitutionEditRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter((options) {
              throw DioException(requestOptions: options, type: type);
            }),
          ),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          dataSource.updateInstitution(_institutionId, _request()),
          throwsA(isA<PlatformInstitutionEditOutcomeUnknownException>()),
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

PlatformInstitutionEditRequest _request() {
  return PlatformInstitutionEditRequest({'name': 'Updated Name'});
}

Map<String, Object?> _editEnvelope({
  String id = _institutionId,
  String name = 'Updated Name',
  String type = 'school',
  String status = 'active',
  Object? contactEmail = 'updated@example.uz',
  Object? contactPhone = '+998901234567',
  Object? address = 'Updated address',
  Object? description,
  String createdAt = '2026-08-07T15:00:00Z',
  String updatedAt = '2026-08-10T12:00:00Z',
  String message = 'Institution updated successfully.',
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
