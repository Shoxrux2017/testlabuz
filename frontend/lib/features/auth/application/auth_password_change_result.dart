import '../../../core/network/api_failure.dart';

class AuthPasswordChangeResult {
  const AuthPasswordChangeResult._({
    required this.isSuccess,
    required this.isSuperseded,
    required this.canRetrySessionRefresh,
    this.failure,
  });

  const AuthPasswordChangeResult.success()
    : this._(
        isSuccess: true,
        isSuperseded: false,
        canRetrySessionRefresh: false,
      );

  const AuthPasswordChangeResult.failure(
    ApiFailure failure, {
    bool canRetrySessionRefresh = false,
  }) : this._(
         isSuccess: false,
         isSuperseded: false,
         canRetrySessionRefresh: canRetrySessionRefresh,
         failure: failure,
       );

  const AuthPasswordChangeResult.superseded()
    : this._(
        isSuccess: false,
        isSuperseded: true,
        canRetrySessionRefresh: false,
      );

  final bool isSuccess;
  final bool isSuperseded;
  final bool canRetrySessionRefresh;
  final ApiFailure? failure;
}
