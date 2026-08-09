import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../storage/auth_token_store.dart';
import 'auth_token_interceptor.dart';
import 'session_invalidation_signal.dart';

final dioProvider = Provider<Dio>((ref) {
  final appConfig = ref.watch(appConfigProvider);
  final authTokenStore = ref.watch(authTokenStoreProvider);
  final sessionInvalidationSignal = ref.watch(
    sessionInvalidationSignalProvider,
  );

  return createDioClient(
    appConfig,
    interceptors: [
      AuthTokenInterceptor(
        tokenStore: authTokenStore,
        sessionInvalidationSignal: sessionInvalidationSignal,
      ),
    ],
  );
});

Dio createDioClient(
  AppConfig appConfig, {
  Iterable<Interceptor> interceptors = const [],
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: appConfig.apiBaseUrl,
      connectTimeout: ApiClientTimeouts.connect,
      sendTimeout: ApiClientTimeouts.send,
      receiveTimeout: ApiClientTimeouts.receive,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: const {Headers.acceptHeader: Headers.jsonContentType},
    ),
  );

  dio.interceptors.addAll(interceptors);

  return dio;
}

abstract final class ApiClientTimeouts {
  static const connect = Duration(seconds: 10);
  static const send = Duration(seconds: 15);
  static const receive = Duration(seconds: 20);
}
