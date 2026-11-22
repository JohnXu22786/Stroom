import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

SharedPreferencesAsync createAndroidPreferences() => SharedPreferencesAsync(
      options: const SharedPreferencesAsyncAndroidOptions(
        backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
        originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(
          fileName: 'FlutterSharedPreferences',
        ),
      ),
    );
