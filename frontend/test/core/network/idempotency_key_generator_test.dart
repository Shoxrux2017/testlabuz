import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/idempotency_key_generator.dart';

void main() {
  test('secure generator emits distinct canonical RFC 4122 UUID v4 keys', () {
    final generator = SecureIdempotencyKeyGenerator();
    final keys = List.generate(1024, (_) => generator.generate());
    final canonicalV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(keys.every(canonicalV4.hasMatch), isTrue);
    expect(keys.toSet(), hasLength(keys.length));
  });
}
