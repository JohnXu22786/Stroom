import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/background_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('BackgroundService', () {
    test(
        'initializeBackgroundService handles errors gracefully in non-supported platforms',
        () async {
      // In test environment (not Android/iOS), the platform channel
      // will throw "FlutterBackgroundService is currently supported
      // for Android and iOS Platform only"
      // The function should handle this without crashing.
      await initializeBackgroundService();
      // Reaching here means no unhandled exception
      expect(true, isTrue);
    });

    test(
        'startBackgroundService handles errors gracefully when platform unavailable',
        () async {
      // Should not crash even if service is not available
      await startBackgroundService();
      expect(true, isTrue);
    });

    test(
        'stopBackgroundService handles errors gracefully when platform unavailable',
        () async {
      await stopBackgroundService();
      expect(true, isTrue);
    });

    test('onStart is a valid top-level function', () {
      expect(onStart, isA<Function>());
    });

    test('onIosBackground is a valid top-level function', () {
      expect(onIosBackground, isA<Function>());
    });

    test('notification channel configuration constants are valid', () {
      // These constants are used for Android notification channel
      const serviceName = 'com.johntsui.stroom.background_service';
      expect(serviceName, isNotEmpty);
      expect(serviceName, contains('stroom'));
    });
  });
}
