import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_user_detail_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_detail_remote_data_source.dart';

void main() {
  test('maps the shared detail DTO to the exact domain User', () async {
    final repository = InstitutionUserDetailRepositoryImpl(
      remoteDataSource: _FakeRemoteDataSource(
        InstitutionUserDetailDto.fromJson({'data': _resource()}),
      ),
    );

    final user = await repository.fetchUser(_userId);

    expect(user.id, _userId);
    expect(user.role.value, 'student');
    expect(user.fullName, 'Student Name');
  });

  test(
    'rejects a valid resource whose UUID differs from the requested target',
    () async {
      final repository = InstitutionUserDetailRepositoryImpl(
        remoteDataSource: _FakeRemoteDataSource(
          InstitutionUserDetailDto.fromJson({
            'data': _resource(id: '00000000-0000-0000-0000-000000000002'),
          }),
        ),
      );

      await expectLater(
        repository.fetchUser(_userId),
        throwsA(
          isA<ApiRequestException>().having(
            (error) => error.failure.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    },
  );

  test('accepts only case-equivalent forms of the requested UUID', () async {
    final repository = InstitutionUserDetailRepositoryImpl(
      remoteDataSource: _FakeRemoteDataSource(
        InstitutionUserDetailDto.fromJson({
          'data': _resource(id: _letterUserIdLower),
        }),
      ),
    );

    final user = await repository.fetchUser(_letterUserIdUpper);

    expect(user.id, _letterUserIdLower);
  });

  test('preserves typed remote failures unchanged', () async {
    final exception = ApiRequestException(
      ApiFailure.local(
        kind: ApiFailureKind.connection,
        message: 'Private transport detail.',
      ),
    );
    final repository = InstitutionUserDetailRepositoryImpl(
      remoteDataSource: _FakeRemoteDataSource.failure(exception),
    );

    await expectLater(repository.fetchUser(_userId), throwsA(same(exception)));
  });
}

const _userId = '00000000-0000-0000-0000-000000000001';
const _letterUserIdLower = 'a0b1c2d3-e4f5-6789-abcd-ef0123456789';
const _letterUserIdUpper = 'A0B1C2D3-E4F5-6789-ABCD-EF0123456789';

Map<String, Object?> _resource({String id = _userId}) => {
  'id': id,
  'role': 'student',
  'full_name': 'Student Name',
  'login_name': 'student01',
  'email': null,
  'phone': null,
  'is_active': true,
  'must_change_password': false,
  'last_login_at': null,
  'deactivated_at': null,
  'created_at': '2026-08-07T14:00:00Z',
  'updated_at': '2026-08-07T16:00:00Z',
};

class _FakeRemoteDataSource implements InstitutionUserDetailRemoteDataSource {
  _FakeRemoteDataSource(this.dto) : exception = null;

  _FakeRemoteDataSource.failure(this.exception) : dto = null;

  final InstitutionUserDetailDto? dto;
  final ApiRequestException? exception;

  @override
  Future<InstitutionUserDetailDto> fetchUser(String userId) async {
    final failure = exception;
    if (failure != null) {
      throw failure;
    }

    return dto!;
  }

  @override
  Dio get dio => throw UnimplementedError();

  @override
  DioFailureMapper get failureMapper => throw UnimplementedError();
}
