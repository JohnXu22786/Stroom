import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations_de.dart';

void main() {
  test('generated German localization classes expose German messages', () {
    final german = AppLocalizationsDe();
    final germany = AppLocalizationsDeDe();

    expect(german.localeName, 'de');
    expect(german.languageNameGerman, 'Deutsch');
    expect(german.languageNameFrench, 'Französisch');
    expect(germany.localeName, 'de_DE');
    expect(germany.languageNameGerman, 'Deutsch');
    expect(germany.languageNameFrench, 'Französisch');
    expect(germany.galleryPermissionCancel, 'Abbrechen');
    expect(germany.mermaidCatalogTemplateFlowchart, contains('Beginn'));
    expect(
      germany.mermaidCatalogTemplateGantt,
      contains('Gantt-Diagramm für das Projekt'),
    );
    expect(
      germany.mermaidCatalogTemplateMindmap,
      contains('Projektmanagement'),
    );
    expect(
      germany.mermaidCatalogTemplateGitGraph,
      contains('commit id: "Version 1.0 veröffentlichen"'),
    );
  });
}
