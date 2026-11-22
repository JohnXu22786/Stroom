import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/l10n/app_localizations_zh.dart';
import 'package:stroom/pages/voice_batch_add_page.dart';
import 'package:stroom/widgets/stroom_menu_style.dart';

// Synthetic extended labels exercise wrapping without changing other copy.
class _LongOrderLocalizations extends AppLocalizationsZh {
  _LongOrderLocalizations() : super('zh_CN');

  @override
  String get voiceBatchNameThenId => 'Name first, identifier second, complete';

  @override
  String get voiceBatchIdThenName => 'Identifier first, name second, complete';
}

class _LongOrderLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _LongOrderLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'zh';

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      _LongOrderLocalizations();

  @override
  bool shouldReload(_LongOrderLocalizationsDelegate old) => false;
}

void main() {
  testWidgets('separator dropdown uses the shared rounded surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh', 'CN'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VoiceBatchAddPage(existingVoices: []),
      ),
    );

    final dropdownFinder = find.byType(DropdownButton<String>);
    final dropdown = tester.widget<DropdownButton<String>>(dropdownFinder);
    final colors = Theme.of(tester.element(dropdownFinder)).colorScheme;

    expect(dropdown.dropdownColor, colors.surfaceContainerHigh);
    expect(dropdown.borderRadius, StroomMenuStyle.borderRadius);

    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();
    expect(find.text('逗号 (,)'), findsOneWidget);

    await tester.tap(find.text('逗号 (,)'));
    await tester.pumpAndSettle();
    expect(find.text('逗号 (,)'), findsOneWidget);
  });

  testWidgets('field order choices reflow and preserve selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh', 'CN'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          const _LongOrderLocalizationsDelegate(),
          ...AppLocalizations.localizationsDelegates,
        ],
        home: VoiceBatchAddPage(existingVoices: []),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    final firstChoice = find.text(l10n.voiceBatchNameThenId);
    final secondChoice = find.text(l10n.voiceBatchIdThenName);
    expect(
      tester.getRect(secondChoice).top,
      greaterThan(tester.getRect(firstChoice).top),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(secondChoice);
    await tester.enterText(find.byType(TextField), 'Name,Identifier');
    await tester.pumpAndSettle();

    expect(find.text('Identifier'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(tester.getRect(secondChoice).top, tester.getRect(firstChoice).top);
    expect(tester.takeException(), isNull);
  });
}
