import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_admin_remote_data_source.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_admin_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_create.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_lifecycle.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_update.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_query.dart';

void main() {
  group('PlatformInstitutionAdminRemoteDataSource', () {
    test('uses exact GET path and approved query parameters only', () async {
      final adapter = RecordingAdapter(
        (_) => _jsonResponse(200, _listEnvelope()),
      );
      final dataSource = PlatformInstitutionAdminRemoteDataSource(
        dio: _plainDio(adapter),
        failureMapper: const DioFailureMapper(),
      );

      final dto = await dataSource.fetchAdmins(
        institutionId: '550e8400-e29b-41d4-a716-446655440000',
        query: const PlatformInstitutionAdminListQuery.initial()
            .withSearchInput('Ali')
            .withStatus(PlatformInstitutionAdminStatus.active)
            .copyWith(
              page: 2,
              perPage: 50,
              sort: PlatformInstitutionAdminListSort.updatedAt,
              direction: PlatformSortDirection.desc,
            ),
      );

      expect(dto.admins.single.loginName, 'Admin.MixedCase');
      expect(adapter.requests, hasLength(1));
      expect(adapter.singleRequest.method, 'GET');
      expect(
        adapter.singleRequest.path,
        '/platform/institutions/550e8400-e29b-41d4-a716-446655440000/admins',
      );
      expect(
        adapter.singleRequest.uri.path,
        '/api/v1/platform/institutions/550e8400-e29b-41d4-a716-446655440000/admins',
      );
      expect(adapter.singleRequest.queryParameters, {
        'page': 2,
        'per_page': 50,
        'sort': 'updated_at',
        'direction': 'desc',
        'search': 'Ali',
        'status': 'active',
      });
      expect(adapter.singleRequest.data, isNull);
    });

    test(
      'uses exact POST path body and no query idempotency or authority',
      () async {
        final adapter = RecordingAdapter(
          (_) => _jsonResponse(201, _createEnvelope()),
        );
        final dataSource = PlatformInstitutionAdminRemoteDataSource(
          dio: _plainDio(adapter),
          failureMapper: const DioFailureMapper(),
        );

        final dto = await dataSource.createAdmin(
          institutionId: '550e8400-e29b-41d4-a716-446655440000',
          request: _request(),
        );

        expect(dto.admin.loginName, 'Admin.MixedCase');
        expect(adapter.requests, hasLength(1));
        expect(adapter.singleRequest.method, 'POST');
        expect(
          adapter.singleRequest.path,
          '/platform/institutions/550e8400-e29b-41d4-a716-446655440000/admins',
        );
        expect(adapter.singleRequest.queryParameters, isEmpty);
        expect(adapter.singleRequest.data, {
          'full_name': 'Ali Valiyev',
          'login_name': 'Admin.MixedCase',
          'email': 'ali@example.uz',
          'phone': null,
          'password': 'valid-password',
        });
        expect(adapter.singleRequest.data.keys, hasLength(5));
        expect(
          adapter.singleRequest.headers.keys,
          isNot(contains('Idempotency-Key')),
        );
        expect(
          adapter.singleRequest.data.keys,
          isNot(
            containsAll([
              'role',
              'institution_id',
              'is_active',
              'must_change_password',
              'last_login_at',
              'deactivated_at',
              'created_by_user_id',
              'password_confirmation',
            ]),
          ),
        );
      },
    );

    test('success maps through repository preserving typed result', () async {
      final dataSource = PlatformInstitutionAdminRemoteDataSource(
        dio: _plainDio(
          RecordingAdapter((_) => _jsonResponse(201, _createEnvelope())),
        ),
        failureMapper: const DioFailureMapper(),
      );
      final PlatformInstitutionAdminRepository repository =
          PlatformInstitutionAdminRepositoryImpl(remoteDataSource: dataSource);

      final result = await repository.createAdmin(
        institutionId: '550e8400-e29b-41d4-a716-446655440000',
        request: _request(),
      );

      expect(result.admin.fullName, 'Ali Valiyev');
      expect(result.admin.isActive, isTrue);
      expect(result.admin.mustChangePassword, isTrue);
      expect(result.admin.lastLoginAt, isNull);
      expect(result.admin.deactivatedAt, isNull);
      expect(result.message, 'Institution administrator created.');
    });

    test(
      'PATCH sends only changed update fields and never protected authority',
      () async {
        final adapter = RecordingAdapter(
          (_) => _jsonResponse(200, _updateEnvelope()),
        );
        final dataSource = PlatformInstitutionAdminRemoteDataSource(
          dio: _plainDio(adapter),
          failureMapper: const DioFailureMapper(),
        );
        final request = PlatformInstitutionAdminUpdateRequest({
          PlatformInstitutionAdminEditField.email: null,
          PlatformInstitutionAdminEditField.phone: '+998901234567',
        });

        final dto = await dataSource.updateAdmin(
          adminId: '550e8400-e29b-41d4-a716-446655440001',
          request: request,
        );

        expect(dto.admin.id, '550e8400-e29b-41d4-a716-446655440001');
        expect(adapter.requests, hasLength(1));
        expect(adapter.singleRequest.method, 'PATCH');
        expect(
          adapter.singleRequest.path,
          '/platform/institution-admins/550e8400-e29b-41d4-a716-446655440001',
        );
        expect(adapter.singleRequest.queryParameters, isEmpty);
        expect(adapter.singleRequest.data, {
          'email': null,
          'phone': '+998901234567',
        });
        expect(adapter.singleRequest.data.keys, hasLength(2));
        expect(
          adapter.singleRequest.headers.keys,
          isNot(contains('Idempotency-Key')),
        );
        expect(
          adapter.singleRequest.data.keys,
          isNot(
            containsAll([
              'login_name',
              'password',
              'role',
              'institution_id',
              'is_active',
              'must_change_password',
              'last_login_at',
              'deactivated_at',
              'created_by_user_id',
            ]),
          ),
        );
      },
    );

    test('empty update request is rejected before HTTP', () async {
      final adapter = RecordingAdapter(
        (_) => _jsonResponse(200, _updateEnvelope()),
      );
      final dataSource = PlatformInstitutionAdminRemoteDataSource(
        dio: _plainDio(adapter),
        failureMapper: const DioFailureMapper(),
      );

      expect(
        () => dataSource.updateAdmin(
          adminId: '550e8400-e29b-41d4-a716-446655440001',
          request: PlatformInstitutionAdminUpdateRequest(const {}),
        ),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });

    test(
      'lifecycle POSTs exact state endpoint with empty body and no idempotency',
      () async {
        final adapter = RecordingAdapter((options) {
          final active = options.path.endsWith('/activate');
          return _jsonResponse(
            200,
            _lifecycleEnvelope(
              action: active
                  ? PlatformInstitutionAdminLifecycleAction.activate
                  : PlatformInstitutionAdminLifecycleAction.deactivate,
            ),
          );
        });
        final dataSource = PlatformInstitutionAdminRemoteDataSource(
          dio: _plainDio(adapter),
          failureMapper: const DioFailureMapper(),
        );

        final activated = await dataSource.activateAdmin(
          adminId: '550e8400-e29b-41d4-a716-446655440001',
        );
        final deactivated = await dataSource.deactivateAdmin(
          adminId: '550e8400-e29b-41d4-a716-446655440001',
        );

        expect(activated.admin.isActive, isTrue);
        expect(deactivated.admin.isActive, isFalse);
        expect(adapter.requests, hasLength(2));
        expect(adapter.requests[0].method, 'POST');
        expect(
          adapter.requests[0].path,
          '/platform/institution-admins/550e8400-e29b-41d4-a716-446655440001/activate',
        );
        expect(adapter.requests[0].data, isEmpty);
        expect(
          adapter.requests[0].headers.keys,
          isNot(contains('Idempotency-Key')),
        );
        expect(
          adapter.requests[1].path,
          '/platform/institution-admins/550e8400-e29b-41d4-a716-446655440001/deactivate',
        );
        expect(adapter.requests[1].data, isEmpty);
        expect(
          adapter.requests[1].headers.keys,
          isNot(contains('Idempotency-Key')),
        );
      },
    );

    test(
      'does not accept non-201 malformed or invariant mismatch as success',
      () async {
        final cases = [
          _jsonResponse(200, _createEnvelope()),
          _jsonResponse(201, _createEnvelope(admin: _adminResource(id: 'bad'))),
          _jsonResponse(
            201,
            _createEnvelope(admin: _adminResource(isActive: false)),
          ),
          _jsonResponse(
            201,
            _createEnvelope(admin: _adminResource(mustChangePassword: false)),
          ),
          _jsonResponse(
            201,
            _createEnvelope(
              admin: _adminResource(lastLoginAt: '2026-08-07T17:00:00Z'),
            ),
          ),
          _jsonResponse(
            201,
            _createEnvelope(
              admin: _adminResource(deactivatedAt: '2026-08-07T17:00:00Z'),
            ),
          ),
          _jsonResponse(
            201,
            _createEnvelope(admin: _adminResource(loginName: 'other-admin')),
          ),
          _jsonResponse(201, {'data': _adminResource(), 'message': ''}),
        ];

        for (final response in cases) {
          final dataSource = PlatformInstitutionAdminRemoteDataSource(
            dio: _plainDio(RecordingAdapter((_) => response)),
            failureMapper: const DioFailureMapper(),
          );

          await expectLater(
            dataSource.createAdmin(
              institutionId: '550e8400-e29b-41d4-a716-446655440000',
              request: _request(),
            ),
            throwsA(
              isA<PlatformInstitutionAdminCreateOutcomeUnknownException>(),
            ),
          );
        }
      },
    );

    test(
      'update and lifecycle malformed successes become unknown outcomes',
      () async {
        final updateCases = [
          _jsonResponse(204, _updateEnvelope()),
          _jsonResponse(200, _updateEnvelope(admin: _adminResource(id: 'bad'))),
          _jsonResponse(200, {'data': _adminResource(), 'message': ''}),
          _jsonResponse(
            200,
            _updateEnvelope(
              admin: _adminResource(isActive: false, deactivatedAt: null),
            ),
          ),
        ];

        for (final response in updateCases) {
          final dataSource = PlatformInstitutionAdminRemoteDataSource(
            dio: _plainDio(RecordingAdapter((_) => response)),
            failureMapper: const DioFailureMapper(),
          );

          await expectLater(
            dataSource.updateAdmin(
              adminId: '550e8400-e29b-41d4-a716-446655440001',
              request: PlatformInstitutionAdminUpdateRequest({
                PlatformInstitutionAdminEditField.fullName: 'Updated',
              }),
            ),
            throwsA(
              isA<PlatformInstitutionAdminMutationOutcomeUnknownException>(),
            ),
          );
        }

        final lifecycleCases = [
          _jsonResponse(
            200,
            _lifecycleEnvelope(
              action: PlatformInstitutionAdminLifecycleAction.activate,
              admin: _adminResource(isActive: false),
            ),
          ),
          _jsonResponse(
            200,
            _lifecycleEnvelope(
              action: PlatformInstitutionAdminLifecycleAction.deactivate,
              admin: _adminResource(isActive: false, deactivatedAt: null),
            ),
          ),
          _jsonResponse(
            200,
            _lifecycleEnvelope(
              action: PlatformInstitutionAdminLifecycleAction.deactivate,
              message: 'Wrong message',
            ),
          ),
        ];

        for (final response in lifecycleCases) {
          final dataSource = PlatformInstitutionAdminRemoteDataSource(
            dio: _plainDio(RecordingAdapter((_) => response)),
            failureMapper: const DioFailureMapper(),
          );

          await expectLater(
            dataSource.deactivateAdmin(
              adminId: '550e8400-e29b-41d4-a716-446655440001',
            ),
            throwsA(
              isA<PlatformInstitutionAdminMutationOutcomeUnknownException>(),
            ),
          );
        }
      },
    );

    test('preserves stable backend failures as typed ApiFailure', () async {
      final cases = [
        (statusCode: 401, code: ApiErrorCodes.authenticationRequired),
        (statusCode: 403, code: ApiErrorCodes.passwordChangeRequired),
        (statusCode: 403, code: ApiErrorCodes.userInactive),
        (statusCode: 403, code: ApiErrorCodes.forbidden),
        (statusCode: 404, code: ApiErrorCodes.resourceNotFound),
        (statusCode: 422, code: ApiErrorCodes.validationFailed),
        (statusCode: 500, code: ApiErrorCodes.serverError),
      ];

      for (final testCase in cases) {
        final dataSource = PlatformInstitutionAdminRemoteDataSource(
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
          dataSource.createAdmin(
            institutionId: '550e8400-e29b-41d4-a716-446655440000',
            request: _request(),
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

    test('maps create timeout or disconnect as unknown outcome', () async {
      final dataSource = PlatformInstitutionAdminRemoteDataSource(
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
        dataSource.createAdmin(
          institutionId: '550e8400-e29b-41d4-a716-446655440000',
          request: _request(),
        ),
        throwsA(isA<PlatformInstitutionAdminCreateOutcomeUnknownException>()),
      );
    });

    test(
      'maps update timeout or disconnect as unknown without replay',
      () async {
        final dataSource = PlatformInstitutionAdminRemoteDataSource(
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
          dataSource.updateAdmin(
            adminId: '550e8400-e29b-41d4-a716-446655440001',
            request: PlatformInstitutionAdminUpdateRequest({
              PlatformInstitutionAdminEditField.fullName: 'Updated',
            }),
          ),
          throwsA(
            isA<PlatformInstitutionAdminMutationOutcomeUnknownException>(),
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
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: const {Headers.acceptHeader: Headers.jsonContentType},
    ),
  );
  dio.httpClientAdapter = adapter;

  return dio;
}

PlatformInstitutionAdminCreateRequest _request() {
  return const PlatformInstitutionAdminCreateRequest(
    fullName: 'Ali Valiyev',
    loginName: 'Admin.MixedCase',
    email: 'ali@example.uz',
    phone: null,
    password: 'valid-password',
  );
}

Map<String, Object?> _listEnvelope() {
  return {
    'data': [_adminResource()],
    'meta': {
      'pagination': {'page': 1, 'per_page': 20, 'total': 1, 'last_page': 1},
    },
  };
}

Map<String, Object?> _createEnvelope({Map<String, Object?>? admin}) {
  return {
    'data': admin ?? _adminResource(),
    'message': 'Institution administrator created.',
  };
}

Map<String, Object?> _updateEnvelope({Map<String, Object?>? admin}) {
  return {
    'data': admin ?? _adminResource(),
    'message': 'Institution admin updated successfully.',
  };
}

Map<String, Object?> _lifecycleEnvelope({
  required PlatformInstitutionAdminLifecycleAction action,
  Map<String, Object?>? admin,
  String? message,
}) {
  final active = action == PlatformInstitutionAdminLifecycleAction.activate;
  return {
    'data':
        admin ??
        _adminResource(
          isActive: active,
          deactivatedAt: active ? null : '2026-08-07T17:00:00Z',
        ),
    'message': message ?? action.successMessage,
  };
}

Map<String, Object?> _adminResource({
  String id = '550e8400-e29b-41d4-a716-446655440001',
  String fullName = 'Ali Valiyev',
  String loginName = 'Admin.MixedCase',
  Object? email = 'ali@example.uz',
  Object? phone,
  Object? isActive = true,
  Object? mustChangePassword = true,
  Object? lastLoginAt,
  Object? deactivatedAt,
  String createdAt = '2026-08-07T15:00:00Z',
  String updatedAt = '2026-08-07T16:00:00Z',
}) {
  return {
    'id': id,
    'full_name': fullName,
    'login_name': loginName,
    'email': email,
    'phone': phone,
    'is_active': isActive,
    'must_change_password': mustChangePassword,
    'last_login_at': lastLoginAt,
    'deactivated_at': deactivatedAt,
    'created_at': createdAt,
    'updated_at': updatedAt,
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
