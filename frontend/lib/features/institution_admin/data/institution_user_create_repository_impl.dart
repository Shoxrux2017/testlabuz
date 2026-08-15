import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/institution_user.dart';
import '../domain/institution_user_create.dart';
import '../domain/institution_user_create_repository.dart';
import 'institution_user_create_remote_data_source.dart';

final institutionUserCreateRepositoryProvider =
    Provider<InstitutionUserCreateRepository>((ref) {
      return InstitutionUserCreateRepositoryImpl(
        remoteDataSource: ref.watch(
          institutionUserCreateRemoteDataSourceProvider,
        ),
      );
    });

class InstitutionUserCreateRepositoryImpl
    implements InstitutionUserCreateRepository {
  const InstitutionUserCreateRepositoryImpl({required this.remoteDataSource});

  final InstitutionUserCreateRemoteDataSource remoteDataSource;

  @override
  Future<InstitutionUser> createUser(
    InstitutionUserCreateRequest request,
  ) async {
    final dto = await remoteDataSource.createUser(request);
    final user = dto.user.toDomain();
    if (!request.snapshot.matches(user) ||
        !user.isActive ||
        !user.mustChangePassword ||
        user.lastLoginAt != null ||
        user.deactivatedAt != null) {
      throw const InstitutionUserCreateOutcomeUnknownException();
    }

    return user;
  }
}
