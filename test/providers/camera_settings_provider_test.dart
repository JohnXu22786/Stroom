import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/camera_settings_provider.dart';

void main() {
  group('CameraSettings', () {
    test('default values are correct - compressionQuality defaults to 0.8', () {
      const settings = CameraSettings();
      expect(settings.compressionQuality, 0.8);
    });

    test('saveToGallery defaults to true', () {
      const settings = CameraSettings();
      expect(settings.saveToGallery, true);
      expect(settings.compressionQuality, 0.8);
    });

    test('copyWith updates compressionQuality', () {
      const settings = CameraSettings(compressionQuality: 0.8);
      final updated = settings.copyWith(compressionQuality: 0.5);
      expect(updated.compressionQuality, 0.5);
      // original unchanged
      expect(settings.compressionQuality, 0.8);
    });

    test('toJson includes saveToGallery and compressionQuality keys', () {
      const settings = CameraSettings(saveToGallery: true, compressionQuality: 0.5);
      final json = settings.toJson();
      expect(json['saveToGallery'], true);
      expect(json['compressionQuality'], 0.5);
    });

    test('toJson/fromJson round-trip preserves all fields', () {
      const settings = CameraSettings(saveToGallery: false, compressionQuality: 0.5);
      final json = settings.toJson();
      final restored = CameraSettings.fromJson(json);
      expect(restored.saveToGallery, false);
      expect(restored.compressionQuality, 0.5);
    });

    test('fromJson handles missing keys gracefully', () {
      final restored = CameraSettings.fromJson({});
      expect(restored.saveToGallery, true);
      expect(restored.compressionQuality, 0.8);
    });

    test('fromJson reads saveToGallery key', () {
      final restored = CameraSettings.fromJson({
        'saveToGallery': false,
        'compressionQuality': 0.5,
      });
      expect(restored.saveToGallery, false);
      expect(restored.compressionQuality, 0.5);
    });

    test('equality works', () {
      const a = CameraSettings(saveToGallery: true, compressionQuality: 0.8);
      const b = CameraSettings(saveToGallery: true, compressionQuality: 0.8);
      const c = CameraSettings(saveToGallery: false, compressionQuality: 0.5);
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('CameraSettingsNotifier', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('initial state has saveToGallery true and compressionQuality 0.8', (tester) async {
      final notifier = CameraSettingsNotifier();
      // Wait for the async _load to complete
      await tester.pump();
      expect(notifier.state.saveToGallery, true);
      expect(notifier.state.compressionQuality, 0.8);
    });

    testWidgets('setSaveToGallery updates state', (tester) async {
      final notifier = CameraSettingsNotifier();
      await tester.pump();
      await notifier.setSaveToGallery(false);
      expect(notifier.state.saveToGallery, false);
    });

    testWidgets('setCompressionQuality updates state', (tester) async {
      final notifier = CameraSettingsNotifier();
      await tester.pump();
      await notifier.setCompressionQuality(0.5);
      expect(notifier.state.compressionQuality, 0.5);
    });
  });
}
