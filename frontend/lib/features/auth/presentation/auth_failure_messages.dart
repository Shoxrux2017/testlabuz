import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';

String authFailureMessage(ApiFailure failure) {
  return switch (failure.serverCode) {
    ApiErrorCodes.invalidCredentials => 'Login or password is incorrect.',
    ApiErrorCodes.userInactive => 'This account is inactive.',
    ApiErrorCodes.institutionInactive => 'This institution is inactive.',
    ApiErrorCodes.authenticationRequired => 'Please sign in again.',
    ApiErrorCodes.rateLimited =>
      'Too many attempts. Please wait and try again.',
    ApiErrorCodes.currentPasswordInvalid => 'Current password is incorrect.',
    ApiErrorCodes.validationFailed => 'Check the highlighted fields.',
    _ => _localFailureMessage(failure),
  };
}

String _localFailureMessage(ApiFailure failure) {
  return switch (failure.kind) {
    ApiFailureKind.connection =>
      'Could not reach the server. Check your connection and try again.',
    ApiFailureKind.timeout => 'The request timed out. Please try again.',
    ApiFailureKind.invalidResponse =>
      'The server returned an unexpected response.',
    ApiFailureKind.cancelled => 'The request was cancelled.',
    ApiFailureKind.unknown => 'Something went wrong. Please try again.',
    ApiFailureKind.validation || ApiFailureKind.server => failure.message,
  };
}

String? firstFieldError(ApiFailure? failure, String field) {
  final errors = failure?.fieldErrors[field];
  if (errors == null || errors.isEmpty) {
    return null;
  }

  return errors.first;
}
