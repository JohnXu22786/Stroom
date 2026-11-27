import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/assistant_selection_page.dart';
import 'package:stroom/providers/assistant_provider.dart';

const _captureKey = ValueKey('assistant-card-scaled-grid-capture');
const _description =
    'Un assistant qui aide à organiser les idées, comparer les options '
    'et préparer des réponses claires pour chaque situation, tout en '
    'gardant chaque étape simple et accessible.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null) return;
    final fontDirectory = '$flutterRoot/bin/cache/artifacts/material_fonts';
    for (final (family, fileName) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
      ('NotoColorEmoji', '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf'),
    ]) {
      final path =
          fileName.startsWith('/') ? fileName : '$fontDirectory/$fileName';
      final bytes = File(path).readAsBytesSync();
      await (FontLoader(family)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });

  testWidgets('production card geometry stays stable through scaled reveal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (scale, description) in [
      (1.0, 'Helper.'),
      (2.0, _description),
    ]) {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: ProviderScope(
            overrides: [
              assistantProvider.overrideWith((ref) {
                final notifier = AssistantsNotifier();
                notifier.createAssistant(
                  name: 'Iris',
                  prompt: 'Prompt',
                  emoji: '🤖',
                  description: description,
                );
                return notifier;
              }),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('fr'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: ThemeData.light(useMaterial3: true).copyWith(
                textTheme: ThemeData.light(useMaterial3: true)
                    .textTheme
                    .apply(fontFamilyFallback: const ['NotoColorEmoji']),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const AssistantSelectionPage(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull, reason: 'scale: $scale');
      final cardSize = tester.getSize(find.byType(AssistantCard));
      if (scale == 1) {
        expect(cardSize.height, closeTo(cardSize.width / 0.85, 1));
      } else {
        expect(cardSize.height, greaterThan(cardSize.width / 0.85));
      }

      if (scale == 2) {
        final descriptionFinder = find.text(_description);
        final titleFinder = find.text('Iris');
        final initialDescriptionY = tester.getTopLeft(descriptionFinder).dy;
        final initialTitleX = tester.getTopLeft(titleFinder).dx;
        var bottomEndpointY = initialDescriptionY;
        for (var second = 1; second <= 70; second++) {
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          final descriptionY = tester.getTopLeft(descriptionFinder).dy;
          final titleX = tester.getTopLeft(titleFinder).dx;
          if ([1, 2, 33, 36, 67, 70].contains(second)) {
            expect(titleX, closeTo(initialTitleX, 1));
          }
          if (second == 1) {
            expect(descriptionY, closeTo(initialDescriptionY, 1));
          } else if (second == 2) {
            expect(descriptionY, lessThan(initialDescriptionY));
          } else if (second == 33) {
            bottomEndpointY = descriptionY;
            expect(bottomEndpointY, lessThan(initialDescriptionY));
          } else if (second == 34 || second == 35) {
            expect(descriptionY, closeTo(bottomEndpointY, 1));
          } else if (second == 36) {
            expect(descriptionY, greaterThan(bottomEndpointY));
          } else if (second == 67) {
            expect(descriptionY, closeTo(initialDescriptionY, 1));
          } else if (second == 68 || second == 69) {
            expect(descriptionY, closeTo(initialDescriptionY, 1));
          } else if (second == 70) {
            expect(descriptionY, lessThan(initialDescriptionY));
          }
        }
      }

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
