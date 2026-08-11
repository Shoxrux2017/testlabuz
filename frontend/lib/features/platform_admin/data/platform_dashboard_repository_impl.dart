import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/platform_dashboard.dart';
import '../domain/platform_dashboard_repository.dart';
import 'platform_dashboard_remote_data_source.dart';

final platformDashboardRepositoryProvider =
    Provider<PlatformDashboardRepository>((ref) {
      return PlatformDashboardRepositoryImpl(
        remoteDataSource: ref.watch(platformDashboardRemoteDataSourceProvider),
      );
    });

class PlatformDashboardRepositoryImpl implements PlatformDashboardRepository {
  const PlatformDashboardRepositoryImpl({required this.remoteDataSource});

  final PlatformDashboardRemoteDataSource remoteDataSource;

  @override
  Future<PlatformDashboard> fetchDashboard() async {
    final dto = await remoteDataSource.fetchDashboard();

    return dto.toDomain();
  }
}
