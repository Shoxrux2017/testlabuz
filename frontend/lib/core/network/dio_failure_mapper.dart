import 'package:dio/dio.dart';

import 'api_error_response.dart';
import 'api_failure.dart';

class DioFailureMapper {
  const DioFailureMapper();

  ApiFailure map(DioException exception) {
    return switch (exception.type) {
      DioExceptionType.badResponse => _mapBadResponse(exception.response),
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => ApiFailure.local(
        kind: ApiFailureKind.timeout,
        message: 'Request timed out.',
      ),
      DioExceptionType.cancel => ApiFailure.local(
        kind: ApiFailureKind.cancelled,
        message: 'Request was cancelled.',
      ),
      DioExceptionType.connectionError => ApiFailure.local(
        kind: ApiFailureKind.connection,
        message: 'Connection failed.',
      ),
      DioExceptionType.badCertificate ||
      DioExceptionType.unknown => ApiFailure.local(
        kind: ApiFailureKind.unknown,
        message: 'Unexpected client error.',
      ),
    };
  }

  ApiFailure _mapBadResponse(Response<Object?>? response) {
    final apiError = ApiErrorResponse.tryParse(response?.data);

    if (apiError == null) {
      return ApiFailure.local(
        kind: ApiFailureKind.invalidResponse,
        statusCode: response?.statusCode,
        message: 'Invalid server response.',
      );
    }

    return ApiFailure.fromServerError(
      statusCode: response?.statusCode,
      error: apiError,
    );
  }
}
