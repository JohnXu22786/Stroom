import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Narrow secret-store boundary used by account migration and later callers.
abstract interface class LlmCredentialStore {
  Future<String?> read(String reference);
  Future<void> write(String reference, String secret);
  Future<void> delete(String reference);
}

/// Uses platform-provided secure storage through flutter_secure_storage.
///
/// A platform may reject access at runtime. In particular, Linux needs a
/// working Secret Service/libsecret session and Web requires a secure browser
/// context with WebCrypto. Web storage protects data at rest for the origin;
/// it does not protect secrets from same-origin script execution. Callers must
/// treat any storage error as unavailable and keep legacy settings recoverable.
class PlatformLlmCredentialStore implements LlmCredentialStore {
  final FlutterSecureStorage _storage;

  PlatformLlmCredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String reference) async {
    try {
      return await _storage.read(key: reference);
    } catch (_) {
      throw const LlmCredentialStoreException();
    }
  }

  @override
  Future<void> write(String reference, String secret) async {
    try {
      await _storage.write(key: reference, value: secret);
    } catch (_) {
      throw const LlmCredentialStoreException();
    }
  }

  @override
  Future<void> delete(String reference) async {
    try {
      await _storage.delete(key: reference);
    } catch (_) {
      throw const LlmCredentialStoreException();
    }
  }
}

/// Deliberately carries no platform exception text or credential data.
class LlmCredentialStoreException implements Exception {
  const LlmCredentialStoreException();

  @override
  String toString() => 'Secure credential storage is unavailable.';
}
