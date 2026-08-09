import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/storage/auth_token_store.dart';
import 'package:testlabuz_client/core/storage/secure_value_store.dart';

void main() {
  group('AuthTokenStore', () {
    test('reads none when no access token is stored', () async {
      final store = AuthTokenStore(FakeSecureValueStore());

      expect(await store.read(), isNull);
    });

    test('writes and reads the secure access token', () async {
      final secureStore = FakeSecureValueStore();
      final store = AuthTokenStore(secureStore);

      await store.write('token-a');

      expect(await store.read(), 'token-a');
      expect(secureStore.values, hasLength(1));
      expect(secureStore.values.values.single, 'token-a');
    });

    test('overwrites an existing access token', () async {
      final store = AuthTokenStore(FakeSecureValueStore());

      await store.write('token-a');
      await store.write('token-b');

      expect(await store.read(), 'token-b');
    });

    test('deletes the stored token idempotently', () async {
      final store = AuthTokenStore(FakeSecureValueStore());

      await store.write('token-a');
      await store.delete();
      await store.delete();

      expect(await store.read(), isNull);
    });

    test('does not store role or profile fields beside the token', () async {
      final secureStore = FakeSecureValueStore();
      final store = AuthTokenStore(secureStore);

      await store.write('token-a');

      expect(secureStore.values.keys, hasLength(1));
      expect(secureStore.values.keys.single, isNot(contains('role')));
      expect(secureStore.values.keys.single, isNot(contains('institution')));
      expect(secureStore.values.keys.single, isNot(contains('profile')));
    });

    test('deletes only when the token version is still current', () async {
      final store = AuthTokenStore(FakeSecureValueStore());

      await store.write('token-a');
      final staleVersion = store.version;
      await store.write('token-b');

      expect(await store.deleteIfVersion(staleVersion), isFalse);
      expect(await store.read(), 'token-b');
      expect(await store.deleteIfVersion(store.version), isTrue);
      expect(await store.read(), isNull);
    });
  });
}

class FakeSecureValueStore implements SecureValueStore {
  final values = <String, String>{};

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return values[key];
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}
