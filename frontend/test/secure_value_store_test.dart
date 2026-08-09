import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/storage/secure_value_store.dart';

void main() {
  group('SecureValueStore', () {
    test('callers can depend on the abstraction for write and read', () async {
      final store = FakeSecureValueStore();

      await _saveSensitiveValue(store, key: 'sample', value: 'secret-value');

      expect(await store.read(key: 'sample'), 'secret-value');
    });

    test('callers can depend on the abstraction for delete', () async {
      final store = FakeSecureValueStore();

      await _saveSensitiveValue(store, key: 'sample', value: 'secret-value');
      await store.delete(key: 'sample');

      expect(await store.read(key: 'sample'), isNull);
    });
  });
}

Future<void> _saveSensitiveValue(
  SecureValueStore store, {
  required String key,
  required String value,
}) {
  return store.write(key: key, value: value);
}

class FakeSecureValueStore implements SecureValueStore {
  final _values = <String, String>{};

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return _values[key];
  }

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }
}
