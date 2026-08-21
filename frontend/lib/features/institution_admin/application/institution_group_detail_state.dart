import '../../../core/network/api_failure.dart';
import '../domain/institution_group.dart';

enum InstitutionGroupDetailStatus {
  initial,
  localUnavailableTarget,
  loading,
  data,
  refreshing,
  notFound,
  error,
}

class InstitutionGroupDetailState {
  const InstitutionGroupDetailState._({
    required this.status,
    required this.target,
    required this.group,
    required this.failure,
    required this.isRetryable,
  });

  const InstitutionGroupDetailState.initial({String? target})
    : this._(
        status: InstitutionGroupDetailStatus.initial,
        target: target,
        group: null,
        failure: null,
        isRetryable: false,
      );

  const InstitutionGroupDetailState.localUnavailableTarget()
    : this._(
        status: InstitutionGroupDetailStatus.localUnavailableTarget,
        target: null,
        group: null,
        failure: null,
        isRetryable: false,
      );

  const InstitutionGroupDetailState.loading({required String target})
    : this._(
        status: InstitutionGroupDetailStatus.loading,
        target: target,
        group: null,
        failure: null,
        isRetryable: false,
      );

  const InstitutionGroupDetailState.data({
    required String target,
    required InstitutionGroup group,
  }) : this._(
         status: InstitutionGroupDetailStatus.data,
         target: target,
         group: group,
         failure: null,
         isRetryable: false,
       );

  const InstitutionGroupDetailState.refreshing({
    required String target,
    required InstitutionGroup group,
  }) : this._(
         status: InstitutionGroupDetailStatus.refreshing,
         target: target,
         group: group,
         failure: null,
         isRetryable: false,
       );

  const InstitutionGroupDetailState.notFound({required String target})
    : this._(
        status: InstitutionGroupDetailStatus.notFound,
        target: target,
        group: null,
        failure: null,
        isRetryable: false,
      );

  const InstitutionGroupDetailState.error({
    required String target,
    required ApiFailure failure,
    required bool isRetryable,
  }) : this._(
         status: InstitutionGroupDetailStatus.error,
         target: target,
         group: null,
         failure: failure,
         isRetryable: isRetryable,
       );

  final InstitutionGroupDetailStatus status;
  final String? target;
  final InstitutionGroup? group;
  final ApiFailure? failure;
  final bool isRetryable;

  bool get isRequestInFlight =>
      status == InstitutionGroupDetailStatus.loading ||
      status == InstitutionGroupDetailStatus.refreshing;
}
