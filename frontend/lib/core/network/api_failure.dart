import 'api_error_response.dart';

enum ApiFailureKind {
  server,
  validation,
  connection,
  timeout,
  cancelled,
  invalidResponse,
  unknown,
}

class ApiFailure {
  ApiFailure({
    required this.kind,
    required this.message,
    this.statusCode,
    this.serverCode,
    Map<String, List<String>> fieldErrors = const {},
    this.requestId,
  }) : fieldErrors = _freezeFieldErrors(fieldErrors);

  factory ApiFailure.fromServerError({
    required int? statusCode,
    required ApiErrorResponse error,
  }) {
    final kind = statusCode == 422 || error.code == 'validation_failed'
        ? ApiFailureKind.validation
        : ApiFailureKind.server;

    return ApiFailure(
      kind: kind,
      statusCode: statusCode,
      serverCode: error.code,
      message: error.message,
      fieldErrors: error.fieldErrors,
      requestId: error.requestId,
    );
  }

  factory ApiFailure.local({
    required ApiFailureKind kind,
    required String message,
    int? statusCode,
  }) {
    assert(
      kind != ApiFailureKind.server && kind != ApiFailureKind.validation,
      'Use ApiFailure.fromServerError for server API failures.',
    );

    return ApiFailure(kind: kind, message: message, statusCode: statusCode);
  }

  final ApiFailureKind kind;
  final int? statusCode;
  final String? serverCode;
  final String message;
  final Map<String, List<String>> fieldErrors;
  final String? requestId;

  static Map<String, List<String>> _freezeFieldErrors(
    Map<String, List<String>> fieldErrors,
  ) {
    final frozen = <String, List<String>>{};

    for (final entry in fieldErrors.entries) {
      frozen[entry.key] = List<String>.unmodifiable(entry.value);
    }

    return Map<String, List<String>>.unmodifiable(frozen);
  }
}
