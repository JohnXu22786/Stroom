import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/locale_provider.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/startup/startup_sequence_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('streams the version-safety block before later startup checks',
      () async {
    for (final locale in [
      const Locale('en', 'US'),
      const Locale('zh', 'CN'),
      const Locale('zh', 'TW'),
    ]) {
      SharedPreferences.setMockInitialValues({
        'data_format_versions': jsonEncode({
          for (final part in DataParts.all)
            part: part == 'chat'
                ? DataParts.currentVersions[part]! + 1
                : DataParts.currentVersions[part],
        }),
      });

      final strings = appLocalizationsForLocale(resolveSystemLocale(locale));
      final controller = StartupSequenceController(
        localizations: () => strings,
      );
      final progress = <StartupCheckProgress>[];
      final subscription = controller.progress.listen(progress.add);

      final outcome = await controller.run();
      final currentChatVersion = DataParts.currentVersions['chat']!;
      final newerVersion =
          'chat v${currentChatVersion + 1} > v$currentChatVersion';

      expect(
        outcome.blockedMessage,
        strings.startupSafetyNewerDataVersion(newerVersion),
      );
      expect(
        strings.startupSafetyStatusUnreadableAfterChecks,
        isNot(strings.startupSafetyStatusUnreadable),
      );
      expect(
        progress.map((event) => event.message),
        contains('正在检查数据安全...'),
      );
      expect(progress.last.isWorking, isFalse);
      expect(progress.last.blockedMessage, outcome.blockedMessage);
      expect(
        progress.map((event) => event.message),
        isNot(contains('正在检查数据格式版本...')),
        reason:
            'a newer data version must stop the sequence before repair/migration',
      );
      await expectLater(controller.run(), throwsStateError);
      await subscription.cancel();
      controller.dispose();
    }
  });
}
