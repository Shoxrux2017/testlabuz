import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/institution_group_membership.dart';
import '../domain/institution_group_membership_list.dart';
import '../domain/institution_group_membership_mutation.dart';
import '../domain/institution_group_membership_query.dart';
import '../domain/institution_group_membership_repository.dart';
import 'institution_group_membership_remote_data_source.dart';

final institutionGroupMembershipRepositoryProvider =
    Provider<InstitutionGroupMembershipRepository>((ref) {
      return InstitutionGroupMembershipRepositoryImpl(
        remoteDataSource: ref.watch(
          institutionGroupMembershipRemoteDataSourceProvider,
        ),
      );
    });

class InstitutionGroupMembershipRepositoryImpl
    implements InstitutionGroupMembershipRepository {
  const InstitutionGroupMembershipRepositoryImpl({
    required this.remoteDataSource,
  });

  final InstitutionGroupMembershipRemoteDataSource remoteDataSource;

  @override
  Future<InstitutionGroupMembershipListPage> fetchMemberships({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required InstitutionGroupMembershipQuery query,
  }) async {
    final dto = await remoteDataSource.fetchMemberships(
      groupId: groupId,
      kind: kind,
      query: query,
    );
    return dto.toDomain();
  }

  @override
  Future<List<InstitutionGroupMembership>> assignMemberships({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required InstitutionGroupMembershipAssignmentRequest request,
  }) async {
    final dto = await remoteDataSource.assignMemberships(
      groupId: groupId,
      kind: kind,
      request: request,
    );
    return dto.toDomain();
  }

  @override
  Future<void> removeMembership({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required String memberId,
  }) => remoteDataSource.removeMembership(
    groupId: groupId,
    kind: kind,
    memberId: memberId,
  );
}
