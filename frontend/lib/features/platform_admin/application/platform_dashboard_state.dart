import '../../../core/network/api_failure.dart';
import '../domain/platform_dashboard.dart';

enum PlatformDashboardStatus { initial, loading, data, error }

class PlatformDashboardState {
  const PlatformDashboardState._({
    required this.status,
    required this.dashboard,
    required this.failure,
    required this.isRetryInFlight,
  });

  const PlatformDashboardState.initial()
    : this._(
        status: PlatformDashboardStatus.initial,
        dashboard: null,
        failure: null,
        isRetryInFlight: false,
      );

  const PlatformDashboardState.loading()
    : this._(
        status: PlatformDashboardStatus.loading,
        dashboard: null,
        failure: null,
        isRetryInFlight: false,
      );

  const PlatformDashboardState.data(PlatformDashboard dashboard)
    : this._(
        status: PlatformDashboardStatus.data,
        dashboard: dashboard,
        failure: null,
        isRetryInFlight: false,
      );

  const PlatformDashboardState.error(
    ApiFailure failure, {
    bool isRetryInFlight = false,
  }) : this._(
         status: PlatformDashboardStatus.error,
         dashboard: null,
         failure: failure,
         isRetryInFlight: isRetryInFlight,
       );

  final PlatformDashboardStatus status;
  final PlatformDashboard? dashboard;
  final ApiFailure? failure;
  final bool isRetryInFlight;

  bool get hasData => dashboard != null;
  bool get isInstitutionEmpty => dashboard?.isInstitutionEmpty ?? false;

  PlatformDashboardState retrying() {
    final currentFailure = failure;
    if (status != PlatformDashboardStatus.error || currentFailure == null) {
      return this;
    }

    return PlatformDashboardState.error(currentFailure, isRetryInFlight: true);
  }
}
