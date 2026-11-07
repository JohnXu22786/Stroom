import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/mermaid_chart_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/folder_picker_dialog.dart';

Widget _buildTestApp({
  String? initialCode,
  Locale locale = const Locale('en', 'US'),
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: MermaidChartPage(
        initialCode: initialCode,
        initialShowPreview: false,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  testWidgets(
    'English editor chrome and discard confirmation preserve source',
    (tester) async {
      const source = 'graph TD\n  userText-->B';
      await tester.pumpWidget(_buildTestApp(initialCode: source));
      await tester.pumpAndSettle();

      expect(find.text('Mermaid Chart Editor'), findsOneWidget);
      expect(find.byTooltip('Switch view mode'), findsOneWidget);
      expect(find.byTooltip('Save to Text Storage'), findsOneWidget);
      expect(find.text('Mermaid code'), findsOneWidget);
      expect(
        (tester.widget<TextField>(find.byType(TextField))).controller!.text,
        source,
      );

      await tester.tap(find.byTooltip('Switch view mode'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Edit + Preview'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      await tester.tapAt(const Offset(10, 200));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '$source\n  C-->D');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(
        find.text('You have unsaved changes. Discard them?'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
    },
  );

  testWidgets('English save guidance and filename validation are localized', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(initialCode: 'graph TD\n  A-->B'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save to Text Storage'));
    await tester.pumpAndSettle();
    expect(find.text('Save chart'), findsOneWidget);
    expect(
      find.text('Choose or create a folder to save the .mmd chart file'),
      findsOneWidget,
    );
    expect(
      find.text('Enter a filename (.mmd added automatically)'),
      findsOneWidget,
    );
    expect(find.byType(FolderPickerDialog), findsOneWidget);

    final fileNameField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText ==
              'Enter a filename (.mmd added automatically)',
    );
    await tester.enterText(fileNameField, '');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Filename cannot be empty'), findsOneWidget);
    expect(find.byType(FolderPickerDialog), findsNothing);
  });

  testWidgets('English empty-content validation is localized', (tester) async {
    await tester.pumpWidget(_buildTestApp(initialCode: ''));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save to Text Storage'));
    await tester.pump();
    expect(
      find.text('Chart content is empty and cannot be saved'),
      findsOneWidget,
    );
    expect(find.byType(FolderPickerDialog), findsNothing);
  });

  testWidgets('Chinese locale preserves existing diagram text', (tester) async {
    const source = 'graph TD\n  用户自己的节点[保留已有标签]';
    await tester.pumpWidget(
      _buildTestApp(initialCode: source, locale: const Locale('zh', 'CN')),
    );
    await tester.pumpAndSettle();

    expect(find.text('图表制作'), findsOneWidget);
    expect(find.text('流程图'), findsOneWidget);
    expect(
      (tester.widget<TextField>(find.byType(TextField))).controller!.text,
      source,
    );
  });
}
