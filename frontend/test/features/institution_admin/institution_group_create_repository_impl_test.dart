import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_group_create_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_create_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_create_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_create.dart';

import 'institution_group_test_support.dart';

void main() {
  test('returns only an exact active zero-membership snapshot', () async {
    final repository = InstitutionGroupCreateRepositoryImpl(
      remoteDataSource: _FakeCreateSource(_dto(groupResource())),
    );
    final group = await repository.createGroup(_request());
    expect(group.id, testGroupId);
    expect(group.teachersCount, 0);
    expect(group.studentsCount, 0);
  });

  test('treats snapshot and create lifecycle mismatches as unknown', () async {
    final invalid = <Map<String, Object?>>[
      groupResource(name: 'Different'),
      groupResource(level: 'Different'),
      groupResource(subjectDirection: 'Different'),
      groupResource(description: 'Different'),
      groupResource(teachersCount: 1),
      groupResource(studentsCount: 1),
      groupResource(status: 'archived', archivedAt: '2026-08-15T10:00:00Z'),
    ];

    for (final resource in invalid) {
      final repository = InstitutionGroupCreateRepositoryImpl(
        remoteDataSource: _FakeCreateSource(_dto(resource)),
      );
      await expectLater(
        repository.createGroup(_request()),
        throwsA(isA<InstitutionGroupCreateOutcomeUnknownException>()),
      );
    }
  });
}

InstitutionGroupCreateRequest _request() => const InstitutionGroupCreateRequest(
  snapshot: InstitutionGroupCreateSnapshot(
    name: 'Advanced Mathematics',
    level: 'Grade 10',
    subjectDirection: 'Mathematics',
    description: 'Olympiad preparation',
  ),
);

InstitutionGroupCreateDto _dto(Map<String, Object?> resource) =>
    InstitutionGroupCreateDto.fromJson({
      'data': resource,
      'message': InstitutionGroupCreateDto.successMessage,
    });

class _FakeCreateSource implements InstitutionGroupCreateRemoteDataSource {
  const _FakeCreateSource(this.dto);

  final InstitutionGroupCreateDto dto;

  @override
  Future<InstitutionGroupCreateDto> createGroup(
    InstitutionGroupCreateRequest request,
  ) async => dto;

  @override
  Dio get dio => throw UnimplementedError();

  @override
  DioFailureMapper get failureMapper => throw UnimplementedError();
}
