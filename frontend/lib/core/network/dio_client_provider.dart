import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';

final dioProvider = Provider<Dio>((ref) {
  final appConfig = ref.watch(appConfigProvider);

  return createDioClient(appConfig);
});

Dio createDioClient(AppConfig appConfig) {
  return Dio(
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
}

abstract final class ApiClientTimeouts {
  static const connect = Duration(seconds: 10);
  static const send = Duration(seconds: 15);
  static const receive = Duration(seconds: 20);
}
