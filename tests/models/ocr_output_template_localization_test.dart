import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations_es.dart';
import 'package:stroom/models/ocr_output_template.dart';

void main() {
  test('Spanish OCR template selector labels identify Markdown and tables', () {
    for (final strings in [AppLocalizationsEs(), AppLocalizationsEsEs()]) {
      final templates = localizedOcrOutputTemplates(strings);

      expect(
        templates.firstWhere((template) => template.id == 'markdown').label,
        'Markdown',
      );
      expect(
        templates.firstWhere((template) => template.id == 'table').label,
        'Tablas',
      );
    }
  });
}
