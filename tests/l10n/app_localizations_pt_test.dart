import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations_pt.dart';

void main() {
  test(
    'generated Portuguese localization includes current English messages',
    () {
      final base = AppLocalizationsPt();
      final brazil = AppLocalizationsPtBr();

      for (final strings in [base, brazil]) {
        expect(strings.languageNameKorean, 'Coreano');
        expect(strings.languageNameFrench, 'Francês');
        expect(
          strings.updateApkInstallerUnavailable,
          'Não foi possível encontrar um aplicativo para instalar este APK. Abra-o manualmente.',
        );
        expect(
          strings.updateApkInstallPermissionDenied,
          'Permita que o Stroom instale aplicativos desconhecidos nas configurações do sistema.',
        );
      }
    },
  );
}
