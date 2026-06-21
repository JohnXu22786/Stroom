import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/notification_provider.dart';
import 'package:stroom/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationSettingsNotifier', () {
    test('default state should be false (off)', () {
      final notifier = NotificationSettingsNotifier();
      // Should default to false (off), not true (on)
      expect(notifier.state, false);
    });
  });

  group('NotificationService default', () {
    test('isEnabled default should be false', () async {
      SharedPreferences.setMockInitialValues({});
      final service = NotificationService();
      // With no stored preference, the fallback value should be false
      expect(await service.isEnabled, false);
    });
  });
}
