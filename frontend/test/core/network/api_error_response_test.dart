import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';

void main() {
  test('Map parsing behavior remains unchanged', () {
    final parsed = ApiErrorResponse.tryParse({
      'message': 'Request rejected.',
      'code': 'validation_failed',
      'errors': {
        'title': ['Required.'],
      },
      'request_id': 'req-1',
    });

    expect(parsed?.message, 'Request rejected.');
    expect(parsed?.code, 'validation_failed');
    expect(parsed?.fieldErrors, {
      'title': ['Required.'],
    });
    expect(parsed?.requestId, 'req-1');
  });

  test('small strict UTF-8 JSON object bytes use the Map parser', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'message': 'Authentication required.',
          'code': 'authentication_required',
          'errors': <String, Object?>{},
        }),
      ),
    );

    expect(ApiErrorResponse.tryParse(bytes)?.code, 'authentication_required');
  });

  test('malformed, non-object, oversized, and document bytes are rejected', () {
    expect(ApiErrorResponse.tryParse(Uint8List.fromList([0xc3, 0x28])), isNull);
    expect(ApiErrorResponse.tryParse(utf8.encode('[1,2,3]')), isNull);
    expect(ApiErrorResponse.tryParse(utf8.encode('"error"')), isNull);
    expect(ApiErrorResponse.tryParse(Uint8List(64 * 1024 + 1)), isNull);
    expect(
      ApiErrorResponse.tryParse(
        Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x37]),
      ),
      isNull,
    );
  });
}
