import 'api_failure.dart';

class ApiRequestException implements Exception {
  const ApiRequestException(this.failure);

  final ApiFailure failure;

  @override
  String toString() {
    final code = failure.serverCode;
    final suffix = code == null ? '' : ' ($code)';

    return 'ApiRequestException$suffix: ${failure.message}';
  }
}
