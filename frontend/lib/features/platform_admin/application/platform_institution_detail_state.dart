import '../../../core/network/api_failure.dart';
import '../domain/platform_institution_detail.dart';

class PlatformInstitutionDetailKey {
  const PlatformInstitutionDetailKey({
    required this.sessionUserId,
    required this.sessionInstanceId,
    required this.institutionId,
  });

  final String sessionUserId;
  final int sessionInstanceId;
  final String institutionId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlatformInstitutionDetailKey &&
            other.sessionUserId == sessionUserId &&
            other.sessionInstanceId == sessionInstanceId &&
            other.institutionId == institutionId;
  }

  @override
  int get hashCode =>
      Object.hash(sessionUserId, sessionInstanceId, institutionId);
}

enum PlatformInstitutionDetailStatus { initial, loading, data, notFound, error }

class PlatformInstitutionDetailState {
  const PlatformInstitutionDetailState._({
    required this.status,
    required this.detail,
    required this.failure,
    required this.isRetryInFlight,
  });

  const PlatformInstitutionDetailState.initial()
    : this._(
        status: PlatformInstitutionDetailStatus.initial,
        detail: null,
        failure: null,
        isRetryInFlight: false,
      );

  const PlatformInstitutionDetailState.loading()
    : this._(
        status: PlatformInstitutionDetailStatus.loading,
        detail: null,
        failure: null,
        isRetryInFlight: false,
      );

  const PlatformInstitutionDetailState.data(PlatformInstitutionDetail detail)
    : this._(
        status: PlatformInstitutionDetailStatus.data,
        detail: detail,
        failure: null,
        isRetryInFlight: false,
      );

  const PlatformInstitutionDetailState.notFound()
    : this._(
        status: PlatformInstitutionDetailStatus.notFound,
        detail: null,
        failure: null,
        isRetryInFlight: false,
      );

  const PlatformInstitutionDetailState.error(
    ApiFailure failure, {
    bool isRetryInFlight = false,
  }) : this._(
         status: PlatformInstitutionDetailStatus.error,
         detail: null,
         failure: failure,
         isRetryInFlight: isRetryInFlight,
       );

  final PlatformInstitutionDetailStatus status;
  final PlatformInstitutionDetail? detail;
  final ApiFailure? failure;
  final bool isRetryInFlight;

  bool get isRequestInFlight {
    return status == PlatformInstitutionDetailStatus.loading || isRetryInFlight;
  }

  PlatformInstitutionDetailState retrying() {
    final currentFailure = failure;
    if (status != PlatformInstitutionDetailStatus.error ||
        currentFailure == null) {
      return this;
    }

    return PlatformInstitutionDetailState.error(
      currentFailure,
      isRetryInFlight: true,
    );
  }
}
