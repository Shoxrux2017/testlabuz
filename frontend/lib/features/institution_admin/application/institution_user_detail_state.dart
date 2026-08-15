import '../../../core/network/api_failure.dart';
import '../domain/institution_user.dart';

enum InstitutionUserDetailStatus {
  initial,
  localUnavailableTarget,
  loading,
  data,
  refreshing,
  notFound,
  error,
}

class InstitutionUserDetailState {
  const InstitutionUserDetailState._({
    required this.status,
    required this.target,
    required this.user,
    required this.failure,
    required this.isRetryable,
  });

  const InstitutionUserDetailState.initial({String? target})
    : this._(
        status: InstitutionUserDetailStatus.initial,
        target: target,
        user: null,
        failure: null,
        isRetryable: false,
      );

  const InstitutionUserDetailState.localUnavailableTarget()
    : this._(
        status: InstitutionUserDetailStatus.localUnavailableTarget,
        target: null,
        user: null,
        failure: null,
        isRetryable: false,
      );

  const InstitutionUserDetailState.loading({required String target})
    : this._(
        status: InstitutionUserDetailStatus.loading,
        target: target,
        user: null,
        failure: null,
        isRetryable: false,
      );

  const InstitutionUserDetailState.data({
    required String target,
    required InstitutionUser user,
  }) : this._(
         status: InstitutionUserDetailStatus.data,
         target: target,
         user: user,
         failure: null,
         isRetryable: false,
       );

  const InstitutionUserDetailState.refreshing({
    required String target,
    required InstitutionUser user,
  }) : this._(
         status: InstitutionUserDetailStatus.refreshing,
         target: target,
         user: user,
         failure: null,
         isRetryable: false,
       );

  const InstitutionUserDetailState.notFound({required String target})
    : this._(
        status: InstitutionUserDetailStatus.notFound,
        target: target,
        user: null,
        failure: null,
        isRetryable: false,
      );

  const InstitutionUserDetailState.error({
    required String target,
    required ApiFailure failure,
    required bool isRetryable,
  }) : this._(
         status: InstitutionUserDetailStatus.error,
         target: target,
         user: null,
         failure: failure,
         isRetryable: isRetryable,
       );

  final InstitutionUserDetailStatus status;
  final String? target;
  final InstitutionUser? user;
  final ApiFailure? failure;
  final bool isRetryable;

  bool get hasData => user != null;
  bool get isRequestInFlight =>
      status == InstitutionUserDetailStatus.loading ||
      status == InstitutionUserDetailStatus.refreshing;
}
