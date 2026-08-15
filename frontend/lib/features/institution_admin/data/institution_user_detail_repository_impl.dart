import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../domain/institution_user.dart';
import '../domain/institution_user_detail_repository.dart';
import 'dto/institution_user_detail_dto.dart';
import 'institution_user_detail_remote_data_source.dart';

final institutionUserDetailRepositoryProvider =
    Provider<InstitutionUserDetailRepository>((ref) {
      return InstitutionUserDetailRepositoryImpl(
        remoteDataSource: ref.watch(
          institutionUserDetailRemoteDataSourceProvider,
        ),
      );
    });

class InstitutionUserDetailRepositoryImpl
    implements InstitutionUserDetailRepository {
  const InstitutionUserDetailRepositoryImpl({required this.remoteDataSource});

  final InstitutionUserDetailRemoteDataSource remoteDataSource;

  @override
  Future<InstitutionUser> fetchUser(String userId) async {
    final InstitutionUserDetailDto dto = await remoteDataSource.fetchUser(
      userId,
    );
    final user = dto.user.toDomain();

    if (user.id.toLowerCase() != userId.toLowerCase()) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Institution User detail target does not match response.',
        ),
      );
    }

    return user;
  }
}
