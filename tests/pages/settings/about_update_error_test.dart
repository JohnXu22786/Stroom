import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations_en.dart';
import 'package:stroom/l10n/app_localizations_zh.dart';
import 'package:stroom/pages/settings_page.dart';

void main() {
  test('localizes provider update errors in English', () {
    final strings = AppLocalizationsEn();

    expect(
      localizeAboutUpdateError(
        strings,
        strings.updateCheckNetworkError('SocketException'),
      ),
      strings.aboutUpdateNetworkError('SocketException'),
    );
    expect(
      localizeAboutUpdateError(strings, strings.updateCheckHttpFailed('502')),
      strings.aboutUpdateHttpError('502'),
    );
    expect(
      localizeAboutUpdateError(strings, strings.updateCheckInvalidResponse),
      strings.aboutUpdateInvalidResponse,
    );
  });

  test('localizes provider update errors in Chinese', () {
    final strings = AppLocalizationsZh();

    expect(
      localizeAboutUpdateError(
        strings,
        strings.updateCheckNetworkError('SocketException'),
      ),
      strings.aboutUpdateNetworkError('SocketException'),
    );
    expect(
      localizeAboutUpdateError(strings, strings.updateCheckHttpFailed('502')),
      strings.aboutUpdateHttpError('502'),
    );
    expect(
      localizeAboutUpdateError(strings, strings.updateCheckInvalidResponse),
      strings.aboutUpdateInvalidResponse,
    );
  });
}
