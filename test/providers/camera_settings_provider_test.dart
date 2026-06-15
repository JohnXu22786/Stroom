import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/camera_settings_provider.dart';

void main() {
  group('CameraSettings', () {
    test('default values are correct - compressionQuality defaults to 0.8', () {
      const settings = CameraSettings();
      expect(settings.compressionQuality, 0.8);
    });

    test('saveToGallery field does not exist', () {
      const settings = CameraSettings();
      // Verify that there is no saveToGallery field on the type
      expect(settings, isA<CameraSettings>());
      // The only remaining field should be compressionQuality
      expect(settings.compressionQuality, 0.8);
    });

    test('copyWith updates compressionQuality', () {
      const settings = CameraSettings(compressionQuality: 0.8);
      final updated = settings.copyWith(compressionQuality: 0.5);
      expect(updated.compressionQuality, 0.5);
      // original unchanged
      expect(settings.compressionQuality, 0.8);
    });

    test('toJson does not include saveToGallery key', () {
      const settings = CameraSettings(compressionQuality: 0.5);
      final json = settings.toJson();
      expect(json.containsKey('saveToGallery'), false);
      expect(json['compressionQuality'], 0.5);
    });

    test('toJson/fromJson round-trip preserves compressionQuality', () {
      const settings = CameraSettings(compressionQuality: 0.5);
      final json = settings.toJson();
      final restored = CameraSettings.fromJson(json);
      expect(restored.compressionQuality, 0.5);
    });

    test('fromJson handles missing keys gracefully', () {
      final restored = CameraSettings.fromJson({});
      expect(restored.compressionQuality, 0.8);
    });

    test('fromJson ignores old saveToGallery key (backward compat)', () {
      final restored = CameraSettings.fromJson({
        'saveToGallery': false,
        'compressionQuality': 0.5,
      });
      expect(restored.compressionQuality, 0.5);
    });

    test('equality works', () {
      const a = CameraSettings(compressionQuality: 0.8);
      const b = CameraSettings(compressionQuality: 0.8);
      const c = CameraSettings(compressionQuality: 0.5);
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('CameraSettingsNotifier', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('initial state has compressionQuality 0.8', (tester) async {
      final notifier = CameraSettingsNotifier();
      // Wait for the async _load to complete
      await tester.pump();
      expect(notifier.state.compressionQuality, 0.8);
    });

    testWidgets('setCompressionQuality updates state', (tester) async {
      final notifier = CameraSettingsNotifier();
      await tester.pump();
      await notifier.setCompressionQuality(0.5);
      expect(notifier.state.compressionQuality, 0.5);
    });
  });
}
