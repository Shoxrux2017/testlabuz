import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_group_membership_list_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_group_membership_mutation_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_membership_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_membership_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_mutation.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_query.dart';

import 'institution_group_test_support.dart';

void main() {
  test(
    'repository converts strict list and assignment DTOs to domain',
    () async {
      final remote = _FakeRemote();
      final repository = InstitutionGroupMembershipRepositoryImpl(
        remoteDataSource: remote,
      );
      final page = await repository.fetchMemberships(
        groupId: testGroupId,
        kind: InstitutionGroupMemberKind.teacher,
        query: const InstitutionGroupMembershipQuery.initial(),
      );
      expect(page.memberships.single.id, testTeacherId);

      final assigned = await repository.assignMemberships(
        groupId: testGroupId,
        kind: InstitutionGroupMemberKind.teacher,
        request: InstitutionGroupMembershipAssignmentRequest([testTeacherId]),
      );
      expect(assigned.single.startedAt, DateTime.utc(2026, 8, 21, 10, 15));

      await repository.removeMembership(
        groupId: testGroupId,
        kind: InstitutionGroupMemberKind.teacher,
        memberId: testTeacherId,
      );
      expect(remote.removedIds, [testTeacherId]);
    },
  );
}

class _FakeRemote extends InstitutionGroupMembershipRemoteDataSource {
  _FakeRemote()
    : super(
        dio: testDio(RecordingAdapter((_) => throw StateError('unused'))),
        failureMapper: const DioFailureMapper(),
      );

  final removedIds = <String>[];

  @override
  Future<InstitutionGroupMembershipListDto> fetchMemberships({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required InstitutionGroupMembershipQuery query,
  }) async => InstitutionGroupMembershipListDto.fromJson({
    'data': [membershipResource()],
    'meta': {
      'pagination': {
        'page': query.page,
        'per_page': query.perPage,
        'total': 1,
        'last_page': 1,
      },
    },
  }, requestedQuery: query);

  @override
  Future<InstitutionGroupMembershipMutationDto> assignMemberships({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required InstitutionGroupMembershipAssignmentRequest request,
  }) async => InstitutionGroupMembershipMutationDto.fromJson(
    {
      'data': [membershipResource()],
      'message': 'Teachers assigned to group successfully.',
    },
    kind: kind,
    submittedIds: request.memberIds,
  );

  @override
  Future<void> removeMembership({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required String memberId,
  }) async {
    removedIds.add(memberId);
  }
}
