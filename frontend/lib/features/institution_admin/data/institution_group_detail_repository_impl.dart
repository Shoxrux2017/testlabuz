import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../domain/institution_group.dart';
import '../domain/institution_group_detail_repository.dart';
import 'institution_group_detail_remote_data_source.dart';

final institutionGroupDetailRepositoryProvider =
    Provider<InstitutionGroupDetailRepository>((ref) {
      return InstitutionGroupDetailRepositoryImpl(
        remoteDataSource: ref.watch(
          institutionGroupDetailRemoteDataSourceProvider,
        ),
      );
    });

class InstitutionGroupDetailRepositoryImpl
    implements InstitutionGroupDetailRepository {
  const InstitutionGroupDetailRepositoryImpl({required this.remoteDataSource});

  final InstitutionGroupDetailRemoteDataSource remoteDataSource;

  @override
  Future<InstitutionGroup> fetchGroup(String groupId) async {
    final dto = await remoteDataSource.fetchGroup(groupId);
    final group = dto.group.toDomain();
    if (group.id.toLowerCase() != groupId.toLowerCase()) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Institution Group detail target does not match response.',
        ),
      );
    }

    return group;
  }
}
