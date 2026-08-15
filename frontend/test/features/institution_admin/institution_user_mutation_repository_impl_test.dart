import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_user_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_user_mutation_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_mutation_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_mutation_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_mutation.dart';

void main() {
  test(
    'accepts UUID case equivalence and exact intended edit values',
    () async {
      final remote = _FakeRemote(
        _dto(id: _userId.toUpperCase(), fullName: 'Updated'),
      );
      final repository = InstitutionUserMutationRepositoryImpl(
        remoteDataSource: remote,
      );

      final result = await repository.updateUser(
        _userId,
        _selected(),
        InstitutionUserEditRequest({'full_name': 'Updated'}),
      );

      expect(result.id, _userId.toUpperCase());
      expect(result.fullName, 'Updated');
    },
  );

  test(
    'rejects changed-field, target, and immutable identity mismatches',
    () async {
      final cases = [
        _dto(fullName: 'Different'),
        _dto(id: '00000000-0000-0000-0000-000000000002', fullName: 'Updated'),
        _dto(fullName: 'Updated', loginName: 'other-login'),
        _dto(fullName: 'Updated', role: InstitutionUserRole.parent),
        _dto(fullName: 'Updated', createdAt: DateTime.utc(2026, 8, 8, 15)),
      ];
      for (final dto in cases) {
        final repository = InstitutionUserMutationRepositoryImpl(
          remoteDataSource: _FakeRemote(dto),
        );
        await expectLater(
          repository.updateUser(
            _userId,
            _selected(),
            InstitutionUserEditRequest({'full_name': 'Updated'}),
          ),
          throwsA(isA<InstitutionUserMutationOutcomeUnknownException>()),
        );
      }
    },
  );

  test(
    'lifecycle requires exact desired state and valid immutable identity',
    () async {
      final repository = InstitutionUserMutationRepositoryImpl(
        remoteDataSource: _FakeRemote(_dto(active: true)),
      );
      await expectLater(
        repository.changeLifecycle(
          _userId,
          _selected(),
          InstitutionUserLifecycleAction.deactivate,
        ),
        throwsA(isA<InstitutionUserMutationOutcomeUnknownException>()),
      );
    },
  );
}

class _FakeRemote extends InstitutionUserMutationRemoteDataSource {
  _FakeRemote(this.dto)
    : super(dio: Dio(), failureMapper: const DioFailureMapper());

  final InstitutionUserMutationDto dto;

  @override
  Future<InstitutionUserMutationDto> updateUser(
    String userId,
    InstitutionUserEditRequest request,
  ) async => dto;

  @override
  Future<InstitutionUserMutationDto> changeLifecycle(
    String userId,
    InstitutionUserLifecycleAction action,
  ) async => dto;
}

InstitutionUserMutationDto _dto({
  String id = _userId,
  String fullName = 'Teacher Name',
  String loginName = 'teacher01',
  InstitutionUserRole role = InstitutionUserRole.teacher,
  bool active = true,
  DateTime? createdAt,
}) => InstitutionUserMutationDto(
  user: InstitutionUserDto(
    id: id,
    role: role,
    fullName: fullName,
    loginName: loginName,
    email: null,
    phone: null,
    isActive: active,
    mustChangePassword: false,
    lastLoginAt: null,
    deactivatedAt: active ? null : DateTime.utc(2026, 8, 15, 8),
    createdAt: createdAt ?? DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 15, 8),
  ),
);

InstitutionUser _selected() => InstitutionUser(
  id: _userId,
  role: InstitutionUserRole.teacher,
  fullName: 'Teacher Name',
  loginName: 'teacher01',
  email: null,
  phone: null,
  isActive: true,
  mustChangePassword: false,
  lastLoginAt: null,
  deactivatedAt: null,
  createdAt: DateTime.utc(2026, 8, 7, 15),
  updatedAt: DateTime.utc(2026, 8, 7, 16),
);

const _userId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
