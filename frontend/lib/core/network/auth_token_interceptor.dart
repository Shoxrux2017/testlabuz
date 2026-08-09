import 'package:dio/dio.dart';

import '../storage/auth_token_store.dart';
import 'api_error_codes.dart';
import 'api_error_response.dart';
import 'auth_request_options.dart';
import 'session_invalidation_signal.dart';

class AuthTokenInterceptor extends Interceptor {
  AuthTokenInterceptor({
    required this.tokenStore,
    required this.sessionInvalidationSignal,
  });

  final AuthTokenStore tokenStore;
  final SessionInvalidationSignal sessionInvalidationSignal;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (AuthRequestOptions.skipsAuth(options)) {
      handler.next(options);
      return;
    }

    final snapshot = await tokenStore.readSnapshot();
    final token = snapshot.token;

    if (token != null && token.isNotEmpty) {
      options.headers[AuthHttpHeaders.authorization] = 'Bearer $token';
      options.extra[AuthRequestOptions.authTokenVersionExtraKey] =
          snapshot.version;
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_isCurrentAuthenticatedSessionExpired(err)) {
      final tokenVersion =
          err.requestOptions.extra[AuthRequestOptions.authTokenVersionExtraKey];

      if (tokenVersion is int && tokenVersion == tokenStore.version) {
        sessionInvalidationSignal.authenticationRequired(
          tokenVersion: tokenVersion,
        );
      }
    }

    handler.next(err);
  }

  bool _isCurrentAuthenticatedSessionExpired(DioException err) {
    if (AuthRequestOptions.skipsAuth(err.requestOptions)) {
      return false;
    }

    if (err.response?.statusCode != 401) {
      return false;
    }

    final apiError = ApiErrorResponse.tryParse(err.response?.data);

    return apiError?.code == ApiErrorCodes.authenticationRequired;
  }
}
