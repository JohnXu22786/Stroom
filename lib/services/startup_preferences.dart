import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

/// Reads individual preferences during startup without loading the full cache.
///
/// Android is configured to use the same legacy SharedPreferences file as the
/// rest of the app. Tests and platforms without the async API fall back to the
/// cached API.
class StartupPreferences {
  StartupPreferences._();

  // SharedPreferences' legacy API stores keys with this prefix. Async reads
  // address the platform store directly, so they must include it themselves.
  static const _legacyKeyPrefix = 'flutter.';

  static const _androidOptions = SharedPreferencesAsyncAndroidOptions(
    backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
    originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(
      fileName: 'FlutterSharedPreferences',
    ),
  );

  static SharedPreferencesAsync _asyncPreferences() => SharedPreferencesAsync(
        options: _androidOptions,
      );

  static Future<String?> getString(String key) async {
    try {
      return await _asyncPreferences().getString('$_legacyKeyPrefix$key');
    } catch (_) {
      return (await SharedPreferences.getInstance()).getString(key);
    }
  }

  static Future<bool> containsKey(String key) async {
    try {
      return await _asyncPreferences().containsKey('$_legacyKeyPrefix$key');
    } catch (_) {
      return (await SharedPreferences.getInstance()).containsKey(key);
    }
  }
}
