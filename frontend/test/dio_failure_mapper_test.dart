import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';

void main() {
  group('DioFailureMapper', () {
    const mapper = DioFailureMapper();

    test('maps valid JSON API errors', () {
      final failure = mapper.map(
        _dioException(
          type: DioExceptionType.badResponse,
          response: _response(
            statusCode: 403,
            data: {
              'message': 'Forbidden.',
              'code': 'forbidden',
              'errors': {},
              'request_id': 'req_456',
            },
          ),
        ),
      );

      expect(failure.kind, ApiFailureKind.server);
      expect(failure.statusCode, 403);
      expect(failure.serverCode, 'forbidden');
      expect(failure.requestId, 'req_456');
    });

    test('maps malformed server bodies without throwing', () {
      final failure = mapper.map(
        _dioException(
          type: DioExceptionType.badResponse,
          response: _response(
            statusCode: 502,
            data: '<html>bad gateway</html>',
          ),
        ),
      );

      expect(failure.kind, ApiFailureKind.invalidResponse);
      expect(failure.statusCode, 502);
      expect(failure.serverCode, isNull);
    });

    test('maps connection failures separately from server codes', () {
      final failure = mapper.map(
        _dioException(type: DioExceptionType.connectionError),
      );

      expect(failure.kind, ApiFailureKind.connection);
      expect(failure.serverCode, isNull);
    });

    test('maps connection timeouts', () {
      final failure = mapper.map(
        _dioException(type: DioExceptionType.connectionTimeout),
      );

      expect(failure.kind, ApiFailureKind.timeout);
    });

    test('maps receive timeouts', () {
      final failure = mapper.map(
        _dioException(type: DioExceptionType.receiveTimeout),
      );

      expect(failure.kind, ApiFailureKind.timeout);
    });

    test('maps cancellations', () {
      final failure = mapper.map(_dioException(type: DioExceptionType.cancel));

      expect(failure.kind, ApiFailureKind.cancelled);
    });

    test('maps unexpected failures', () {
      final failure = mapper.map(
        _dioException(
          type: DioExceptionType.unknown,
          error: StateError('unexpected'),
        ),
      );

      expect(failure.kind, ApiFailureKind.unknown);
      expect(failure.serverCode, isNull);
    });
  });
}

DioException _dioException({
  required DioExceptionType type,
  Response<Object?>? response,
  Object? error,
}) {
  return DioException(
    requestOptions: RequestOptions(path: '/test'),
    response: response,
    type: type,
    error: error,
  );
}

Response<Object?> _response({required int statusCode, required Object? data}) {
  return Response<Object?>(
    requestOptions: RequestOptions(path: '/test'),
    statusCode: statusCode,
    data: data,
  );
}
