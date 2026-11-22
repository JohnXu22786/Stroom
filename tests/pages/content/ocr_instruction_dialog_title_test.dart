import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/ocr/ocr_instruction_dialog.dart';
import 'package:stroom/providers/ocr_instructions_provider.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('long localized management title stays within a 320 dp dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });

    final title = AppLocalizations.delegate
        .load(const Locale('de', 'DE'))
        .then((strings) => strings.ocrManageInstructions);
    final localizedTitle = await title;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ocrInstructionsProvider.overrideWith((ref) {
            final notifier = OcrInstructionsNotifier(ref);
            notifier.state = const [];
            return notifier;
          }),
        ],
        child: MaterialApp(
          locale: const Locale('de', 'DE'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const OcrInstructionManageDialog(),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final titleFinder = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == localizedTitle,
    );
    expect(titleFinder, findsOneWidget);
    expect(find.text(localizedTitle), findsOneWidget);
    expect(tester.getSemantics(titleFinder).label, localizedTitle);
  });
}
