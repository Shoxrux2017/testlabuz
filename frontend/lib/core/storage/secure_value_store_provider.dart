import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'flutter_secure_value_store.dart';
import 'secure_value_store.dart';

final secureValueStoreProvider = Provider<SecureValueStore>((ref) {
  return const FlutterSecureValueStore(FlutterSecureStorage());
});
