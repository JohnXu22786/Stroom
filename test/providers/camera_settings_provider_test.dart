import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/camera_settings_provider.dart';

void main() {
  group('CameraSettings', () {
    test('default values are correct - saveToGallery defaults to true', () {
      const settings = CameraSettings();
      expect(settings.saveToGallery, true);
    });

    test('copyWith updates saveToGallery', () {
      const settings = CameraSettings(saveToGallery: true);
      final updated = settings.copyWith(saveToGallery: false);
      expect(updated.saveToGallery, false);
      // original unchanged
      expect(settings.saveToGallery, true);
    });

    test('toJson/fromJson round-trip preserves saveToGallery', () {
      const settings = CameraSettings(saveToGallery: false);
      final json = settings.toJson();
      final restored = CameraSettings.fromJson(json);
      expect(restored.saveToGallery, false);
    });

    test('fromJson handles missing keys gracefully', () {
      final restored = CameraSettings.fromJson({});
      expect(restored.saveToGallery, true);
    });

    test('fromJson ignores unknown keys (backward compat)', () {
      final restored = CameraSettings.fromJson({
        'saveToGallery': false,
        'highQuality': true,
        'compressionQuality': 0.5,
      });
      expect(restored.saveToGallery, false);
      // highQuality and compressionQuality should simply be ignored
    });

    test('equality works', () {
      const a = CameraSettings(saveToGallery: true);
      const b = CameraSettings(saveToGallery: true);
      const c = CameraSettings(saveToGallery: false);
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('CameraSettingsNotifier', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('initial state has saveToGallery true', (tester) async {
      final notifier = CameraSettingsNotifier();
      // Wait for the async _load to complete
      await tester.pump();
      expect(notifier.state.saveToGallery, true);
    });

    testWidgets('setSaveToGallery updates state', (tester) async {
      final notifier = CameraSettingsNotifier();
      await tester.pump();
      await notifier.setSaveToGallery(false);
      expect(notifier.state.saveToGallery, false);
    });

    testWidgets('setSaveToGallery can toggle back to true', (tester) async {
      final notifier = CameraSettingsNotifier();
      await tester.pump();
      await notifier.setSaveToGallery(false);
      expect(notifier.state.saveToGallery, false);
      await notifier.setSaveToGallery(true);
      expect(notifier.state.saveToGallery, true);
    });

    testWidgets('multiple setSaveToGallery calls work', (tester) async {
      final notifier = CameraSettingsNotifier();
      await tester.pump();
      await notifier.setSaveToGallery(false);
      expect(notifier.state.saveToGallery, false);
      await notifier.setSaveToGallery(true);
      expect(notifier.state.saveToGallery, true);
      await notifier.setSaveToGallery(false);
      expect(notifier.state.saveToGallery, false);
    });
  });
}