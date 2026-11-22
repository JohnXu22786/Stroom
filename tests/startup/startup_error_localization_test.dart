import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';

void main() {
  test(
    'startup and render fallback messages are localized for every locale',
    () {
      for (final locale in AppLocalizations.supportedLocales) {
        final strings = lookupAppLocalizations(locale);

        expect(strings.startupErrorTitle, isNotEmpty);
        expect(strings.startupErrorDetails('failure'), contains('failure'));
        expect(strings.renderErrorTitle, isNotEmpty);
        expect(strings.renderErrorDebugTitle, isNotEmpty);
        expect(strings.renderErrorRestartMessage, isNotEmpty);
        if (locale.languageCode == 'en') {
          expect(strings.startupErrorTitle, 'App startup failed');
          expect(strings.renderErrorTitle, 'Interface rendering error');
        } else if (locale.languageCode == 'zh') {
          expect(strings.startupErrorTitle, '应用启动失败');
          expect(strings.renderErrorTitle, '界面渲染异常');
        }
      }
    },
  );
}
