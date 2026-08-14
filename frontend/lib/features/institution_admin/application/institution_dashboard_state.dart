import '../../../core/network/api_failure.dart';
import '../domain/institution_dashboard.dart';

enum InstitutionDashboardStatus { initial, loading, data, error }

class InstitutionDashboardState {
  const InstitutionDashboardState._({
    required this.status,
    required this.dashboard,
    required this.failure,
    required this.isRetryInFlight,
  });

  const InstitutionDashboardState.initial()
    : this._(
        status: InstitutionDashboardStatus.initial,
        dashboard: null,
        failure: null,
        isRetryInFlight: false,
      );

  const InstitutionDashboardState.loading()
    : this._(
        status: InstitutionDashboardStatus.loading,
        dashboard: null,
        failure: null,
        isRetryInFlight: false,
      );

  const InstitutionDashboardState.data(InstitutionDashboard dashboard)
    : this._(
        status: InstitutionDashboardStatus.data,
        dashboard: dashboard,
        failure: null,
        isRetryInFlight: false,
      );

  const InstitutionDashboardState.error(
    ApiFailure failure, {
    bool isRetryInFlight = false,
  }) : this._(
         status: InstitutionDashboardStatus.error,
         dashboard: null,
         failure: failure,
         isRetryInFlight: isRetryInFlight,
       );

  final InstitutionDashboardStatus status;
  final InstitutionDashboard? dashboard;
  final ApiFailure? failure;
  final bool isRetryInFlight;

  bool get hasData => dashboard != null;
  bool get hasNoUsers => dashboard?.hasNoUsers ?? false;

  InstitutionDashboardState retrying() {
    final currentFailure = failure;
    if (status != InstitutionDashboardStatus.error || currentFailure == null) {
      return this;
    }

    return InstitutionDashboardState.error(
      currentFailure,
      isRetryInFlight: true,
    );
  }
}
