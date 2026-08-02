import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/context_management_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('ContextManagementSettingsNotifier - compaction threshold', () {
    test(
        'setCompactionThreshold rejects values below 1000 (falls back to '
        'model context)', () async {
      final notifier = ContextManagementSettingsNotifier();
      await notifier.setCompactionThreshold(500);
      expect(notifier.state.compactionThreshold, isNull);
    });

    test('setCompactionThreshold rejects 0 and negative values', () async {
      final notifier = ContextManagementSettingsNotifier();
      await notifier.setCompactionThreshold(0);
      expect(notifier.state.compactionThreshold, isNull);
      await notifier.setCompactionThreshold(-100);
      expect(notifier.state.compactionThreshold, isNull);
    });

    test('setCompactionThreshold accepts values >= 1000', () async {
      final notifier = ContextManagementSettingsNotifier();
      await notifier.setCompactionThreshold(48000);
      expect(notifier.state.compactionThreshold, 48000);
    });

    test('setCompactionThreshold(null) clears the threshold', () async {
      final notifier = ContextManagementSettingsNotifier();
      await notifier.setCompactionThreshold(48000);
      await notifier.setCompactionThreshold(null);
      expect(notifier.state.compactionThreshold, isNull);
    });

    test('rejected value clears the threshold (falls back to model context)',
        () async {
      final notifier = ContextManagementSettingsNotifier();
      await notifier.setCompactionThreshold(48000);
      await notifier.setCompactionThreshold(5);
      // provider 层对 <1000 视为无效并清空（回退模型 context）；
      // UI 输入框层在失焦时回退显示上次有效值，不推送无效值。
      expect(notifier.state.compactionThreshold, isNull);
    });
  });

  group('ContextManagementSettings - effectiveCompactionThreshold', () {
    test('custom threshold wins when enabled and set', () {
      const settings = ContextManagementSettings(
        customCompactionThresholdEnabled: true,
        compactionThreshold: 48000,
      );
      expect(settings.effectiveCompactionThreshold(128000), 48000);
    });

    test('model context is used when custom is disabled', () {
      const settings = ContextManagementSettings(
        customCompactionThresholdEnabled: false,
      );
      expect(settings.effectiveCompactionThreshold(128000), 128000);
    });

    test('model context is used when custom enabled but value is null', () {
      const settings = ContextManagementSettings(
        customCompactionThresholdEnabled: true,
        compactionThreshold: null,
      );
      expect(settings.effectiveCompactionThreshold(128000), 128000);
    });
  });
}
