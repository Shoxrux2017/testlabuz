import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('accepts a valid HTTPS API v1 URL', () {
      final config = AppConfig.fromApiBaseUrl(
        'https://api.testlabuz.example/api/v1',
      );

      expect(config.apiBaseUrl, 'https://api.testlabuz.example/api/v1');
    });

    test('accepts a valid HTTP local API v1 URL', () {
      final config = AppConfig.fromApiBaseUrl('http://127.0.0.1:8000/api/v1');

      expect(config.apiBaseUrl, 'http://127.0.0.1:8000/api/v1');
    });

    test('rejects an empty API base URL', () {
      expect(
        () => AppConfig.fromApiBaseUrl(''),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects a relative API base URL', () {
      expect(
        () => AppConfig.fromApiBaseUrl('/api/v1'),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects unsupported schemes', () {
      expect(
        () => AppConfig.fromApiBaseUrl('ftp://api.testlabuz.example/api/v1'),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects embedded credentials', () {
      expect(
        () => AppConfig.fromApiBaseUrl(
          'https://user:pass@api.testlabuz.example/api/v1',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects query strings', () {
      expect(
        () => AppConfig.fromApiBaseUrl(
          'https://api.testlabuz.example/api/v1?debug=true',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects fragments', () {
      expect(
        () => AppConfig.fromApiBaseUrl(
          'https://api.testlabuz.example/api/v1#client',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects missing API v1 path', () {
      expect(
        () => AppConfig.fromApiBaseUrl('https://api.testlabuz.example'),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects a wrong API base path', () {
      expect(
        () => AppConfig.fromApiBaseUrl('https://api.testlabuz.example/api/v2'),
        throwsA(isA<AppConfigException>()),
      );
    });
  });
}
