import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

class AppConfig {
  AppConfig({required Uri apiBaseUri}) : apiBaseUri = _validate(apiBaseUri);

  factory AppConfig.fromEnvironment() {
    return AppConfig.fromApiBaseUrl(
      const String.fromEnvironment('API_BASE_URL'),
    );
  }

  factory AppConfig.fromApiBaseUrl(String apiBaseUrl) {
    final trimmed = apiBaseUrl.trim();

    if (trimmed.isEmpty) {
      throw const AppConfigException('API_BASE_URL is required.');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      throw const AppConfigException('API_BASE_URL must be a valid URI.');
    }

    return AppConfig(apiBaseUri: uri);
  }

  final Uri apiBaseUri;

  String get apiBaseUrl => apiBaseUri.toString();

  static Uri _validate(Uri uri) {
    if (!uri.isAbsolute || uri.host.isEmpty) {
      throw const AppConfigException('API_BASE_URL must be an absolute URI.');
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const AppConfigException('API_BASE_URL must use http or https.');
    }

    if (uri.userInfo.isNotEmpty) {
      throw const AppConfigException(
        'API_BASE_URL must not include credentials.',
      );
    }

    if (uri.hasQuery || uri.hasFragment) {
      throw const AppConfigException(
        'API_BASE_URL must not include a query or fragment.',
      );
    }

    if (uri.path != '/api/v1') {
      throw const AppConfigException('API_BASE_URL path must be /api/v1.');
    }

    return uri;
  }
}

class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}
