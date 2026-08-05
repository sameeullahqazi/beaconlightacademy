import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  // Private constructor
  SecureStorageService._();

  // Singleton instance
  static final SecureStorageService _instance = SecureStorageService._();

  // Getter to access the singleton instance
  static SecureStorageService get instance => _instance;

  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read({required String key}) async {
    return await _storage.read(key: key);
  }

  ///Does not support Windows platform
  Future<Map<String, String>?> readAll() async {
    return await _storage.readAll();
  }

  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  ///Does not support Windows platform
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
