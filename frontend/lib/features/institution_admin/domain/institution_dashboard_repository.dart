import 'institution_dashboard.dart';

abstract interface class InstitutionDashboardRepository {
  Future<InstitutionDashboard> fetchDashboard();
}
