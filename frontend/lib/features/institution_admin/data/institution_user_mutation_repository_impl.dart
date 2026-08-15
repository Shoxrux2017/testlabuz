import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/institution_user.dart';
import '../domain/institution_user_mutation.dart';
import '../domain/institution_user_mutation_repository.dart';
import 'institution_user_mutation_remote_data_source.dart';

final institutionUserMutationRepositoryProvider =
    Provider<InstitutionUserMutationRepository>((ref) {
      return InstitutionUserMutationRepositoryImpl(
        remoteDataSource: ref.watch(
          institutionUserMutationRemoteDataSourceProvider,
        ),
      );
    });

class InstitutionUserMutationRepositoryImpl
    implements InstitutionUserMutationRepository {
  const InstitutionUserMutationRepositoryImpl({required this.remoteDataSource});

  final InstitutionUserMutationRemoteDataSource remoteDataSource;

  @override
  Future<InstitutionUser> updateUser(
    String userId,
    InstitutionUser selected,
    InstitutionUserEditRequest request,
  ) async {
    final dto = await remoteDataSource.updateUser(userId, request);
    final returned = dto.user.toDomain();
    if (!_targetAndIdentityMatch(userId, selected, returned) ||
        !request.matches(returned)) {
      throw const InstitutionUserMutationOutcomeUnknownException();
    }
    return returned;
  }

  @override
  Future<InstitutionUser> changeLifecycle(
    String userId,
    InstitutionUser selected,
    InstitutionUserLifecycleAction action,
  ) async {
    final dto = await remoteDataSource.changeLifecycle(userId, action);
    final returned = dto.user.toDomain();
    if (!_targetAndIdentityMatch(userId, selected, returned) ||
        returned.isActive != action.desiredActive) {
      throw const InstitutionUserMutationOutcomeUnknownException();
    }
    return returned;
  }

  bool _targetAndIdentityMatch(
    String userId,
    InstitutionUser selected,
    InstitutionUser returned,
  ) {
    return userId.toLowerCase() == selected.id.toLowerCase() &&
        userId.toLowerCase() == returned.id.toLowerCase() &&
        institutionUserImmutableIdentityMatches(selected, returned);
  }
}
