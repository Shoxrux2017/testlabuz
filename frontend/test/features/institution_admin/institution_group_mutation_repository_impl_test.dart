import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_group_mutation_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_mutation_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_mutation_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_mutation.dart';

import 'institution_group_test_support.dart';

void main() {
  test(
    'update validates identity, active lifecycle, and submitted fields only',
    () async {
      final source = _FakeMutationSource(
        updateResult: _dto(
          name: '10-B',
          level: 'Changed concurrently',
          teachersCount: 7,
        ),
      );
      final repository = InstitutionGroupMutationRepositoryImpl(
        remoteDataSource: source,
      );

      final result = await repository.updateGroup(
        testGroupId,
        testGroup(),
        InstitutionGroupEditRequest({'name': '10-B'}),
      );

      expect(result.name, '10-B');
      expect(result.level, 'Changed concurrently');
      expect(result.teachersCount, 7);
    },
  );

  test(
    'update identity, lifecycle, or submitted-field mismatch is unknown',
    () async {
      for (final dto in <InstitutionGroupMutationDto>[
        _dto(id: testGroupIdUpper, name: '10-B'),
        _dto(name: '10-B', createdAt: '2026-08-14T08:00:00Z'),
        _dto(
          name: '10-B',
          status: 'archived',
          archivedAt: '2026-08-21T10:00:00Z',
        ),
        _dto(name: 'Different'),
      ]) {
        final repository = InstitutionGroupMutationRepositoryImpl(
          remoteDataSource: _FakeMutationSource(updateResult: dto),
        );
        await expectLater(
          repository.updateGroup(
            testGroupId,
            testGroup(),
            InstitutionGroupEditRequest({'name': '10-B'}),
          ),
          throwsA(isA<InstitutionGroupMutationOutcomeUnknownException>()),
        );
      }
    },
  );

  test(
    'archive accepts idempotent archived resource with immutable identity',
    () async {
      final repository = InstitutionGroupMutationRepositoryImpl(
        remoteDataSource: _FakeMutationSource(
          archiveResult: _dto(
            status: 'archived',
            archivedAt: '2026-08-21T10:00:00Z',
          ),
        ),
      );

      final result = await repository.archiveGroup(testGroupId, testGroup());
      expect(result.status, InstitutionGroupStatus.archived);
      expect(result.archivedAt, isNotNull);
    },
  );

  test('archive active resource is unknown', () async {
    final repository = InstitutionGroupMutationRepositoryImpl(
      remoteDataSource: _FakeMutationSource(archiveResult: _dto()),
    );
    await expectLater(
      repository.archiveGroup(testGroupId, testGroup()),
      throwsA(isA<InstitutionGroupMutationOutcomeUnknownException>()),
    );
  });
}

InstitutionGroupMutationDto _dto({
  String id = testGroupId,
  String name = 'Advanced Mathematics',
  String? level = 'Grade 10',
  String status = 'active',
  String? archivedAt,
  int teachersCount = 0,
  String createdAt = '2026-08-15T08:00:00Z',
}) {
  return InstitutionGroupMutationDto.fromJson({
    'data': {
      ...groupResource(
        id: id,
        name: name,
        level: level,
        status: status,
        archivedAt: archivedAt,
        teachersCount: teachersCount,
      ),
      'created_at': createdAt,
    },
    'message': 'expected',
  }, expectedMessage: 'expected');
}

class _FakeMutationSource extends InstitutionGroupMutationRemoteDataSource {
  _FakeMutationSource({this.updateResult, this.archiveResult})
    : super(dio: Dio(), failureMapper: const DioFailureMapper());

  final InstitutionGroupMutationDto? updateResult;
  final InstitutionGroupMutationDto? archiveResult;

  @override
  Future<InstitutionGroupMutationDto> updateGroup(
    String groupId,
    InstitutionGroupEditRequest request,
  ) async => updateResult!;

  @override
  Future<InstitutionGroupMutationDto> archiveGroup(String groupId) async =>
      archiveResult!;
}
