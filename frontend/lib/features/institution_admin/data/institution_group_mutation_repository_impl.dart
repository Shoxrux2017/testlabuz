import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/institution_group.dart';
import '../domain/institution_group_mutation.dart';
import '../domain/institution_group_mutation_repository.dart';
import 'institution_group_mutation_remote_data_source.dart';

final institutionGroupMutationRepositoryProvider =
    Provider<InstitutionGroupMutationRepository>((ref) {
      return InstitutionGroupMutationRepositoryImpl(
        remoteDataSource: ref.watch(
          institutionGroupMutationRemoteDataSourceProvider,
        ),
      );
    });

class InstitutionGroupMutationRepositoryImpl
    implements InstitutionGroupMutationRepository {
  const InstitutionGroupMutationRepositoryImpl({
    required this.remoteDataSource,
  });

  final InstitutionGroupMutationRemoteDataSource remoteDataSource;

  @override
  Future<InstitutionGroup> updateGroup(
    String groupId,
    InstitutionGroup selected,
    InstitutionGroupEditRequest request,
  ) async {
    final dto = await remoteDataSource.updateGroup(groupId, request);
    final returned = dto.group.toDomain();
    if (!_targetAndIdentityMatch(groupId, selected, returned) ||
        returned.status != InstitutionGroupStatus.active ||
        returned.archivedAt != null ||
        !request.matches(returned)) {
      throw const InstitutionGroupMutationOutcomeUnknownException();
    }
    return returned;
  }

  @override
  Future<InstitutionGroup> archiveGroup(
    String groupId,
    InstitutionGroup selected,
  ) async {
    final dto = await remoteDataSource.archiveGroup(groupId);
    final returned = dto.group.toDomain();
    if (!_targetAndIdentityMatch(groupId, selected, returned) ||
        returned.status != InstitutionGroupStatus.archived ||
        returned.archivedAt == null) {
      throw const InstitutionGroupMutationOutcomeUnknownException();
    }
    return returned;
  }

  bool _targetAndIdentityMatch(
    String groupId,
    InstitutionGroup selected,
    InstitutionGroup returned,
  ) {
    return groupId.toLowerCase() == selected.id.toLowerCase() &&
        groupId.toLowerCase() == returned.id.toLowerCase() &&
        institutionGroupImmutableIdentityMatches(selected, returned);
  }
}
