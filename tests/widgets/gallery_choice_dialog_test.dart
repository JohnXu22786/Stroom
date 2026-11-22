import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/widgets/gallery_choice_dialog.dart';

Future<void> _openGalleryChoiceSheet(
  WidgetTester tester, {
  Locale locale = const Locale('en', 'US'),
  double textScale = 1,
  ThemeData? theme,
  ValueChanged<GalleryChoiceResult?>? onResult,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  await tester.binding.setSurfaceSize(const Size(320, 640));
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: theme ?? ThemeData.light(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await showGalleryChoiceDialog(context);
              onResult?.call(result);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'narrow sheet displays complete choice descriptions as wrapping text',
    (tester) async {
      await _openGalleryChoiceSheet(tester);

      final l10n = AppLocalizations.of(tester.element(find.text('Open')))!;
      for (final description in [
        l10n.galleryChoiceDeviceDescription,
        l10n.galleryChoiceAppDescription,
      ]) {
        final text = find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == description,
        );
        expect(text, findsOneWidget);
        expect(tester.widget<Text>(text).maxLines, isNull);
        expect(find.byType(ConstrainedText), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large German text keeps app-gallery choice scrollable and selectable',
    (tester) async {
      GalleryChoiceResult? result;
      await _openGalleryChoiceSheet(
        tester,
        locale: const Locale('de', 'DE'),
        textScale: 1.8,
        theme: ThemeData.dark(),
        onResult: (value) => result = value,
      );

      // The long localized content has no layout error before interaction.
      expect(find.text('App-Galerie'), findsOneWidget);
      final description = find.text(
        AppLocalizations.of(tester.element(find.text('Open')))!
            .galleryChoiceDeviceDescription,
      );
      expect(description, findsOneWidget);
      expect(tester.widget<Text>(description).maxLines, isNull);
      expect(tester.getSize(description).height, greaterThan(40));
      expect(tester.takeException(), isNull);

      // Exercise the existing app-gallery InkWell directly; it remains operable
      // even when the sheet needs scrolling at this scale.
      final option = find.ancestor(
        of: find.text('App-Galerie'),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(find.text('App-Galerie'));
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(result, const GalleryChoiceResult(choice: GalleryChoice.app));
    },
  );
}
