import 'platform_dashboard.dart';

abstract interface class PlatformDashboardRepository {
  Future<PlatformDashboard> fetchDashboard();
}
