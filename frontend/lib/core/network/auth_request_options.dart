import 'package:dio/dio.dart';

abstract final class AuthRequestOptions {
  static const skipAuthExtraKey = 'testlabuz.skipAuth';
  static const authTokenVersionExtraKey = 'testlabuz.authTokenVersion';

  static Options publicRequest() {
    return Options(extra: const {skipAuthExtraKey: true});
  }

  static bool skipsAuth(RequestOptions options) {
    return options.extra[skipAuthExtraKey] == true;
  }
}

abstract final class AuthHttpHeaders {
  static const authorization = 'Authorization';
}
