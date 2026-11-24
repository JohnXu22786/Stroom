import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/voice_batch_add_page.dart';

Widget _buildTestApp() => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const VoiceBatchAddPage(existingVoices: []),
    );

Future<void> _selectCustomSeparator(WidgetTester tester) async {
  await tester.tap(find.text('Tab'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Custom…').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty custom separator cannot split a row into characters', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await _selectCustomSeparator(tester);
    await tester.enterText(find.byType(TextField).last, 'Alice,voice-1');
    await tester.pumpAndSettle();

    final confirm = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Add selected voices'),
    );
    expect(confirm.onPressed, isNull);
    expect(
      tester
          .widget<TextField>(find.byType(TextField).first)
          .decoration
          ?.errorText,
      'Enter a custom separator',
    );
  });

  testWidgets('non-empty custom separator still parses name and ID', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await _selectCustomSeparator(tester);
    await tester.enterText(find.byType(TextField).first, ',');
    await tester.enterText(find.byType(TextField).last, 'Alice,voice-1');
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('voice-1'), findsOneWidget);
  });
}
