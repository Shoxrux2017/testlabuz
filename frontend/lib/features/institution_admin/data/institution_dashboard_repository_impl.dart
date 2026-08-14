import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/institution_dashboard.dart';
import '../domain/institution_dashboard_repository.dart';
import 'institution_dashboard_remote_data_source.dart';

final institutionDashboardRepositoryProvider =
    Provider<InstitutionDashboardRepository>((ref) {
      return InstitutionDashboardRepositoryImpl(
        remoteDataSource: ref.watch(
          institutionDashboardRemoteDataSourceProvider,
        ),
      );
    });

class InstitutionDashboardRepositoryImpl
    implements InstitutionDashboardRepository {
  const InstitutionDashboardRepositoryImpl({required this.remoteDataSource});

  final InstitutionDashboardRemoteDataSource remoteDataSource;

  @override
  Future<InstitutionDashboard> fetchDashboard() async {
    final dto = await remoteDataSource.fetchDashboard();

    return dto.toDomain();
  }
}
