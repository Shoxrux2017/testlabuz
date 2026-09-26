import '../../../core/network/api_failure.dart';
import '../domain/teacher_blitz_monitoring.dart';

enum TeacherBlitzMonitoringStatus {
  initial,
  loading,
  data,
  refreshing,
  error,
  notFound,
  notActive,
  closed,
  archived,
}

class TeacherBlitzMonitoringState {
  const TeacherBlitzMonitoringState({
    this.status = TeacherBlitzMonitoringStatus.initial,
    this.monitoring,
    this.failure,
    this.isStale = false,
    this.livePollingEnabled = false,
    this.pollingPausedByRateLimit = false,
    this.lastRefreshWasAutomatic = false,
  });

  final TeacherBlitzMonitoringStatus status;
  final TeacherBlitzMonitoring? monitoring;
  final ApiFailure? failure;

  /// True only when [monitoring] is retained after a failed read.
  final bool isStale;
  final bool livePollingEnabled;
  final bool pollingPausedByRateLimit;
  final bool lastRefreshWasAutomatic;

  bool get isLoading =>
      status == TeacherBlitzMonitoringStatus.loading ||
      status == TeacherBlitzMonitoringStatus.refreshing;

  /// Live monitoring is over for this route: the Blitz left Active or is
  /// no longer available.
  bool get hasEnded => switch (status) {
    TeacherBlitzMonitoringStatus.notFound ||
    TeacherBlitzMonitoringStatus.notActive ||
    TeacherBlitzMonitoringStatus.closed ||
    TeacherBlitzMonitoringStatus.archived => true,
    _ => false,
  };

  /// The latest successful snapshot, not a retained stale one.
  TeacherBlitzMonitoring? get currentMonitoring =>
      !isStale &&
          (status == TeacherBlitzMonitoringStatus.data ||
              status == TeacherBlitzMonitoringStatus.refreshing)
      ? monitoring
      : null;

  TeacherBlitzMonitoringState withLivePolling(bool enabled) {
    if (enabled == livePollingEnabled) {
      return this;
    }
    return TeacherBlitzMonitoringState(
      status: status,
      monitoring: monitoring,
      failure: failure,
      isStale: isStale,
      livePollingEnabled: enabled,
      pollingPausedByRateLimit: pollingPausedByRateLimit,
      lastRefreshWasAutomatic: lastRefreshWasAutomatic,
    );
  }
}
