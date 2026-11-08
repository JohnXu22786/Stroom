import 'package:shared_preferences_android/shared_preferences_android.dart';

const options = SharedPreferencesAsyncAndroidOptions(
  backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
  originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(
    fileName: 'FlutterSharedPreferences',
  ),
);
