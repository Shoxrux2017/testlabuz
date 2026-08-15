import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_user_create_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_create_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_create_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_create.dart';

void main() {
  test('returns only an exact confirmed created-user snapshot', () async {
    final repository = InstitutionUserCreateRepositoryImpl(
      remoteDataSource: _FakeRemoteDataSource(_dto()),
    );

    final user = await repository.createUser(_request());

    expect(user.id, _userId);
    expect(user.mustChangePassword, isTrue);
    expect(user.lastLoginAt, isNull);
  });

  test(
    'treats every lifecycle or public-snapshot mismatch as unknown',
    () async {
      final invalid = <Map<String, Object?>>[
        _resource(overrides: {'role': 'student'}),
        _resource(overrides: {'full_name': 'Different Name'}),
        _resource(overrides: {'login_name': 'different'}),
        _resource(overrides: {'email': 'different@example.uz'}),
        _resource(overrides: {'phone': '+998900000000'}),
        _resource(
          overrides: {
            'is_active': false,
            'deactivated_at': '2026-08-15T09:00:00Z',
          },
        ),
        _resource(overrides: {'must_change_password': false}),
        _resource(overrides: {'last_login_at': '2026-08-15T09:00:00Z'}),
        _resource(
          overrides: {
            'is_active': false,
            'deactivated_at': '2026-08-15T09:00:00Z',
          },
        ),
      ];

      for (final resource in invalid) {
        final repository = InstitutionUserCreateRepositoryImpl(
          remoteDataSource: _FakeRemoteDataSource(_dto(resource)),
        );
        await expectLater(
          repository.createUser(_request()),
          throwsA(isA<InstitutionUserCreateOutcomeUnknownException>()),
          reason: '$resource',
        );
      }
    },
  );
}

InstitutionUserCreateRequest _request() => const InstitutionUserCreateRequest(
  snapshot: InstitutionUserCreateSnapshot(
    role: InstitutionUserRole.teacher,
    fullName: 'Teacher Name',
    loginName: 'teacher01',
    email: null,
    phone: null,
  ),
  password: 'password1',
);

InstitutionUserCreateDto _dto([Map<String, Object?>? resource]) =>
    InstitutionUserCreateDto.fromJson({
      'data': resource ?? _resource(),
      'message': InstitutionUserCreateDto.successMessage,
    });

const _userId = '00000000-0000-0000-0000-000000000001';

Map<String, Object?> _resource({Map<String, Object?> overrides = const {}}) => {
  'id': _userId,
  'role': 'teacher',
  'full_name': 'Teacher Name',
  'login_name': 'teacher01',
  'email': null,
  'phone': null,
  'is_active': true,
  'must_change_password': true,
  'last_login_at': null,
  'deactivated_at': null,
  'created_at': '2026-08-15T08:00:00Z',
  'updated_at': '2026-08-15T08:00:00Z',
  ...overrides,
};

class _FakeRemoteDataSource implements InstitutionUserCreateRemoteDataSource {
  const _FakeRemoteDataSource(this.dto);

  final InstitutionUserCreateDto dto;

  @override
  Future<InstitutionUserCreateDto> createUser(
    InstitutionUserCreateRequest request,
  ) async => dto;

  @override
  Dio get dio => throw UnimplementedError();

  @override
  DioFailureMapper get failureMapper => throw UnimplementedError();
}
