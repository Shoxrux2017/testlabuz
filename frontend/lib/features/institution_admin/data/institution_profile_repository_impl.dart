import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/institution_profile.dart';
import '../domain/institution_profile_repository.dart';
import '../domain/institution_profile_update.dart';
import 'institution_profile_remote_data_source.dart';

final institutionProfileRepositoryProvider =
    Provider<InstitutionProfileRepository>((ref) {
      return InstitutionProfileRepositoryImpl(
        remoteDataSource: ref.watch(institutionProfileRemoteDataSourceProvider),
      );
    });

class InstitutionProfileRepositoryImpl implements InstitutionProfileRepository {
  const InstitutionProfileRepositoryImpl({required this.remoteDataSource});

  final InstitutionProfileRemoteDataSource remoteDataSource;

  @override
  Future<InstitutionProfile> fetchProfile() async {
    final response = await remoteDataSource.fetchProfile();

    return response.profile.toDomain();
  }

  @override
  Future<InstitutionProfileUpdateResult> updateProfile(
    InstitutionProfileUpdateRequest request,
  ) async {
    final response = await remoteDataSource.updateProfile(request);

    return InstitutionProfileUpdateResult(profile: response.profile.toDomain());
  }
}
