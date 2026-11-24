import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/l10n/app_localizations_zh.dart';
import 'package:stroom/pages/voice_batch_add_page.dart';
import 'package:stroom/widgets/constrained_text.dart';
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
  // Unit owner: vertical_separator_hint.
  // Functional suite mapping: feature-ui.
  testWidgets('custom separator hint reveals clipping without animating input',
      (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('de', 'DE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VoiceBatchAddPage(existingVoices: []),
      ),
    );
    await tester.pumpAndSettle();
    // Ignore the page title's pre-existing narrow German app-bar overflow.
    tester.takeException();

    final dropdown = find.byType(DropdownButton<String>);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(dropdown))!;
    await tester.tap(find.text(l10n.voiceCustomSeparator).last);
    await tester.pumpAndSettle();

    final field = find.byType(TextField).first;
    final textField = tester.widget<TextField>(field);
    final hint = textField.decoration!.hint! as ConstrainedText;
    final hintFinder = find.byWidget(hint);
    expect(hint.data, l10n.voiceBatchCustomSeparatorHint);
    expect(tester.getSemantics(hintFinder).label, hint.data);
    final hintContext = tester.element(hintFinder);
    final hintPainter = TextPainter(
      text: TextSpan(
        text: hint.data,
        style: DefaultTextStyle.of(hintContext).style.merge(hint.style),
      ),
      textDirection: Directionality.of(hintContext),
      textScaler: MediaQuery.textScalerOf(hintContext),
      locale: Localizations.localeOf(hintContext),
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: tester.getSize(hintFinder).width);
    expect(hintPainter.didExceedMaxLines, isTrue);
    expect(tester.takeException(), isNull);

    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(hintFinder).label, hint.data);
    expect(tester.takeException(), isNull);

    await tester.showKeyboard(field);
    final editableText = find.descendant(
      of: field,
      matching: find.byType(EditableText),
    );
    expect(
      tester.widget<EditableText>(editableText).focusNode.hasFocus,
      isTrue,
    );
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(field, '::');
    await tester.pumpAndSettle();
    final editable = tester.widget<EditableText>(editableText);
    expect(editable.controller.text, '::');
    expect(editable.controller.selection.extentOffset, 2);
    expect(
      tester.widget<TextField>(field).decoration!.hint,
      isA<ConstrainedText>(),
    );

    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.enterText(field, '');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('long German separator stays within a narrow card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('de', 'DE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VoiceBatchAddPage(existingVoices: []),
      ),
    );
    await tester.pumpAndSettle();
    // The existing German page title reports a separate app-bar overflow.
    // Clear it so this regression assertion covers the separator card.
    tester.takeException();

    final dropdown = find.byType(DropdownButton<String>);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'while selector is open');
    await tester.tap(find.text('Senkrechter Strich (|)').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'after selecting separator');
    final card = find.byType(Card).first;
    expect(
      tester.getRect(dropdown).right,
      lessThanOrEqualTo(tester.getRect(card).right),
    );
    expect(
      find.bySemanticsLabel('Senkrechter Strich (|)'),
      findsOneWidget,
    );
  });

  testWidgets('wide separator control stays inline after selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('de', 'DE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VoiceBatchAddPage(existingVoices: []),
      ),
    );
    await tester.pumpAndSettle();

    final dropdown = find.byType(DropdownButton<String>);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Senkrechter Strich (|)').last);
    await tester.pumpAndSettle();

    final label = find.text('Trennzeichen:');
    expect(tester.getRect(dropdown).center.dy, tester.getRect(label).center.dy);
    expect(tester.takeException(), isNull);
    expect(find.text('Senkrechter Strich (|)'), findsOneWidget);
  });

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

  testWidgets('changing to fewer columns resets the selected column safely', (
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

    final input = find.byType(TextField).first;
    await tester.enterText(input, 'name1,id1,extra,last\nname2,id2,extra,last');
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(input))!;
    await tester.tap(find.text(l10n.voiceBatchColumn(3, 'extra')));
    await tester.pumpAndSettle();

    await tester.enterText(input, 'Name,Identifier');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Identifier'), findsOneWidget);
  });

  testWidgets(
    'custom separator is preserved when input has another delimiter',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: VoiceBatchAddPage(existingVoices: []),
        ),
      );

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.voiceCustomSeparator).last);
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.first, '::');
      await tester.enterText(fields.last, 'voice::id,tag');
      await tester.pumpAndSettle();

      expect(find.text('voice'), findsOneWidget);
      expect(find.text('id,tag'), findsOneWidget);
    },
  );
}
