import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_value_store.dart';
import 'secure_value_store_provider.dart';

final authTokenStoreProvider = Provider<AuthTokenStore>((ref) {
  return AuthTokenStore(ref.watch(secureValueStoreProvider));
});

class AuthTokenStore {
  AuthTokenStore(this._secureValueStore);

  static const _accessTokenKey = 'auth_access_token';

  final SecureValueStore _secureValueStore;
  int _version = 0;

  int get version => _version;

  Future<String?> read() {
    return _secureValueStore.read(key: _accessTokenKey);
  }

  Future<AuthTokenSnapshot> readSnapshot() async {
    final token = await read();

    return AuthTokenSnapshot(token: token, version: _version);
  }

  Future<void> write(String token) async {
    if (token.isEmpty) {
      throw ArgumentError.value('', 'token', 'Token must not be empty.');
    }

    await _secureValueStore.write(key: _accessTokenKey, value: token);
    _version += 1;
  }

  Future<void> delete() async {
    await _secureValueStore.delete(key: _accessTokenKey);
    _version += 1;
  }

  Future<bool> deleteIfVersion(int expectedVersion) async {
    if (_version != expectedVersion) {
      return false;
    }

    await delete();

    return true;
  }
}

class AuthTokenSnapshot {
  const AuthTokenSnapshot({required this.token, required this.version});

  final String? token;
  final int version;
}
