import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';
import 'package:stroom/services/startup_preferences_android_options_io.dart'
    as android_preferences;

void main() {
  test('Android uses the legacy SharedPreferences backend and filename', () {
    expect(
      android_preferences.options.backend,
      SharedPreferencesAndroidBackendLibrary.SharedPreferences,
    );
    expect(
      android_preferences.options.originalSharedPreferencesOptions?.fileName,
      'FlutterSharedPreferences',
    );
  });
}
