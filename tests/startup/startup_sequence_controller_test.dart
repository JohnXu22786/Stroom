import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/providers/locale_provider.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/startup/startup_check_service.dart';
import 'package:stroom/startup/startup_sequence_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'streams the version-safety block before later startup checks',
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
          contains(strings.startupProgressDataSafety),
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
    },
  );

  test(
    'localizes startup stages and validation summary for the selected locale',
    () async {
      for (final locale in [
        const Locale('en', 'US'),
        const Locale('zh', 'CN'),
      ]) {
        SharedPreferences.setMockInitialValues({
          'data_format_versions': jsonEncode(DataParts.currentVersions),
          'provider_entries': jsonEncode([
            {'id': 'provider', 'type': '', 'name': ''},
            {
              'id': 'unknown',
              'type': 'custom-provider\nv2',
              'name': 'Provider',
              'configs': [],
            },
          ]),
          'conversations': jsonEncode([
            {'id': 'conversation'},
          ]),
        });
        final strings = appLocalizationsForLocale(locale);
        final controller = StartupSequenceController(
          localizations: () => strings,
        );
        final progress = <StartupCheckProgress>[];
        final subscription = controller.progress.listen(progress.add);

        final outcome = await controller.run();
        final statuses = progress.map((event) => event.message).toList();
        expect(
          statuses,
          containsAll([
            strings.startupProgressDataSafety,
            strings.startupProgressFormatVersion,
            strings.startupProgressDataFormat,
            strings.startupProgressDataIntegrity,
            strings.startupProgressResults,
          ]),
        );
        expect(
          statuses.last,
          strings.startupProgressCompleteWithWarnings(outcome.warning!),
        );
        expect(
          outcome.warning,
          contains(strings.startupWarningWarningCount(4)),
        );
        expect(
          outcome.warning,
          contains(strings.startupIssueProviderTypeMissing('0')),
        );
        expect(
          outcome.warning,
          contains(strings.startupIssueProviderNameMissing('0')),
        );
        expect(
          outcome.warning,
          contains(strings.startupIssueConversationMessagesMissing('0')),
        );
        expect(
          outcome.warning,
          contains(
            strings.startupIssueUnknownProviderType('1', 'custom-provider\nv2'),
          ),
        );
        expect(progress.last.isWorking, isFalse);

        await subscription.cancel();
        controller.dispose();
      }
    },
  );

  test('localizes validation diagnostics without changing raw messages',
      () async {
    for (final locale in [
      const Locale('en', 'US'),
      const Locale('zh', 'CN'),
    ]) {
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([
          null,
          {'id': 1, 'type': '', 'name': '', 'configs': 'bad'},
          {
            'id': 'provider',
            'type': 'custom-provider\nv2',
            'name': 'Provider',
            'configs': [
              null,
              {'models': 'bad'}
            ],
          },
        ]),
        'conversations': jsonEncode([
          null,
          {'id': 1, 'messages': 'bad'},
          {'id': 'conversation'},
        ]),
      });
      final strings = appLocalizationsForLocale(locale);

      final issues = [
        ...await StartupCheckService.validateDataFormats(),
        ...await StartupCheckService.checkDataIntegrity(),
      ];
      final displayMessages = issues
          .map((issue) => startupIssueDisplayMessage(issue.message, strings))
          .toList();

      expect(issues.first.message, 'provider_entries[0]: 条目为 null 或类型无效');
      expect(issues.first.dataKey, 'provider_entries');
      expect(
        issues.last.message,
        'provider_entries[2]: 未知的供应商类型 "custom-provider\nv2"，'
        '应用可能无法正常使用该供应商',
      );
      expect(issues.last.dataKey, 'provider_entries');
      expect(
        displayMessages,
        containsAll([
          strings.startupIssueProviderEntryInvalid('0'),
          strings.startupIssueProviderIdMissing('1'),
          strings.startupIssueProviderTypeMissing('1'),
          strings.startupIssueProviderNameMissing('1'),
          strings.startupIssueProviderListInvalid('1', 'configs'),
          strings.startupIssueProviderNestedItemInvalid('2', 'configs[0]'),
          strings.startupIssueProviderListInvalid('2', 'configs[1].models'),
          strings.startupIssueConversationInvalid('0'),
          strings.startupIssueConversationIdMissing('1'),
          strings.startupIssueConversationMessagesInvalid('1'),
          strings.startupIssueConversationMessagesMissing('2'),
          strings.startupIssueUnknownProviderType('2', 'custom-provider\nv2'),
        ]),
      );
    }
  });

  test(
    'localizes the no-warning completion status for the selected locale',
    () async {
      for (final locale in [
        const Locale('en', 'US'),
        const Locale('zh', 'CN'),
      ]) {
        SharedPreferences.setMockInitialValues({
          'data_format_versions': jsonEncode(DataParts.currentVersions),
          'provider_entries': '[]',
          'conversations': '[]',
        });
        final strings = appLocalizationsForLocale(locale);
        final controller = StartupSequenceController(
          localizations: () => strings,
        );
        final progress = <StartupCheckProgress>[];
        final subscription = controller.progress.listen(progress.add);

        final outcome = await controller.run();

        expect(outcome.warning, isNull);
        expect(progress.last.message, strings.startupProgressReady);
        expect(progress.last.isWorking, isFalse);
        await subscription.cancel();
        controller.dispose();
      }
    },
  );
}
