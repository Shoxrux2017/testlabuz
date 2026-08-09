import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';

void main() {
  group('API error parsing', () {
    test('preserves 422 validation details and request ID', () {
      final response = ApiErrorResponse.tryParse({
        'message': 'The given data was invalid.',
        'code': 'validation_failed',
        'errors': {
          'email': ['The email field is required.'],
          'password': [
            'The password field is required.',
            'The password must be at least 8 characters.',
          ],
        },
        'request_id': 'req_123',
      });

      expect(response, isNotNull);
      expect(response!.code, 'validation_failed');
      expect(response.fieldErrors['email'], ['The email field is required.']);
      expect(response.fieldErrors['password'], hasLength(2));
      expect(response.requestId, 'req_123');

      final failure = ApiFailure.fromServerError(
        statusCode: 422,
        error: response,
      );

      expect(failure.kind, ApiFailureKind.validation);
      expect(failure.serverCode, 'validation_failed');
      expect(failure.requestId, 'req_123');
    });

    test('preserves representative stable server codes unchanged', () {
      final cases = <int, String>{
        401: 'authentication_required',
        403: 'forbidden',
        404: 'resource_not_found',
        429: 'rate_limited',
        500: 'server_error',
      };

      for (final MapEntry(key: statusCode, value: serverCode)
          in cases.entries) {
        final response = ApiErrorResponse.tryParse({
          'message': 'Request failed.',
          'code': serverCode,
          'errors': {},
        });

        expect(response, isNotNull);

        final failure = ApiFailure.fromServerError(
          statusCode: statusCode,
          error: response!,
        );

        expect(failure.statusCode, statusCode);
        expect(failure.serverCode, serverCode);
        expect(failure.fieldErrors, isEmpty);
      }
    });

    test('accepts an empty validation errors object', () {
      final response = ApiErrorResponse.tryParse({
        'message': 'The given data was invalid.',
        'code': 'validation_failed',
        'errors': {},
      });

      expect(response, isNotNull);
      expect(response!.fieldErrors, isEmpty);
    });
  });
}
