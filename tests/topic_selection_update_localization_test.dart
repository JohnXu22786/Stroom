import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';

void main() {
  test(
    'assistant update check error is localized and retains its details',
    () async {
      const error = 'network unavailable';
      final english = await AppLocalizations.delegate.load(
        const Locale('en', 'US'),
      );
      final chinese = await AppLocalizations.delegate.load(
        const Locale('zh', 'CN'),
      );

      expect(
        english.topicAssistantUpdateCheckFailed(error),
        'Assistant update check failed: $error',
      );
      expect(chinese.topicAssistantUpdateCheckFailed(error), '检查助手更新失败：$error');
    },
  );
}
