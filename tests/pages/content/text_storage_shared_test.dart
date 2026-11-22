import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/text_storage_shared.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/constrained_text.dart';

Widget _buildTestApp({
  String initialFolder = '',
  Locale locale = const Locale('zh', 'CN'),
  double textScale = 1,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    home: TextCreatePage(initialFolder: initialFolder),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: false,
      ),
      child: child!,
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

  group('TextCreatePage', () {
    testWidgets(
      'uses constrained field labels without replacing native inputs',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildTestApp());
        await tester.pump();

        final fields = tester.widgetList<TextField>(find.byType(TextField));
        expect(fields, hasLength(2));
        expect(
          fields.map((field) => field.decoration!.label),
          everyElement(isA<ConstrainedText>()),
        );
        expect(
          tester
              .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>),
              )
              .decoration
              .label,
          isA<ConstrainedText>(),
        );
        final titleField = find.byType(TextField).first;
        final titleController =
            tester.widget<TextField>(titleField).controller!;

        await tester.tap(titleField);
        await tester.enterText(titleField, 'draft title');
        titleController.value = titleController.value.copyWith(
          selection: const TextSelection.collapsed(offset: 5),
        );

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pump();
        await tester.tap(find.text('md').last);
        await tester.pump();

        expect(titleController.text, 'draft title');
        expect(
          titleController.selection,
          const TextSelection.collapsed(offset: 5),
        );
        expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'keeps fitting labels still and clips overflowing field labels',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _buildTestApp(locale: const Locale('pt', 'BR'), textScale: 1),
        );
        await tester.pump();

        final titleLabel = find.byWidgetPredicate(
          (widget) => widget is ConstrainedText && widget.data == 'Título',
        );
        expect(titleLabel, findsOneWidget);
        final titleText = find.descendant(
          of: titleLabel,
          matching: find.text('Título'),
        );
        final titleStart = tester.getTopLeft(titleText);
        await tester.pump(const Duration(seconds: 3));
        expect(tester.getTopLeft(titleText), titleStart);

        await tester.pumpWidget(
          _buildTestApp(locale: const Locale('pt', 'BR'), textScale: 2.5),
        );
        await tester.pump();
        final formatLabel = find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedText && widget.data == 'Conteúdo do texto',
        );
        expect(formatLabel, findsOneWidget);
        final formatText = find.descendant(
          of: formatLabel,
          matching: find.text('Conteúdo do texto'),
        );
        final formatContext = tester.element(formatLabel);
        final naturalFormat = TextPainter(
          text: TextSpan(
            text: 'Conteúdo do texto',
            style: DefaultTextStyle.of(formatContext).style,
          ),
          textDirection: Directionality.of(formatContext),
          textScaler: MediaQuery.textScalerOf(formatContext),
          maxLines: 1,
        )..layout();
        expect(
          naturalFormat.width,
          greaterThan(tester.getSize(formatLabel).width),
          reason: 'the localized content label should exceed its field slot',
        );
        expect(
          find.descendant(of: formatLabel, matching: find.byType(ClipRect)),
          findsOneWidget,
        );
        expect(formatText, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('rejects same-folder duplicate name and format', (
      tester,
    ) async {
      await TextManifest.saveTextRecord(
        TextRecord(
          name: 'existing',
          hash: 'existing-hash',
          format: 'txt',
          createdAt: DateTime.utc(2024),
          size: 1,
          folder: 'docs',
        ),
        'existing content',
      );
      await tester.pumpWidget(_buildTestApp(initialFolder: 'docs'));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, '标题').first,
        'existing',
      );
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(find.text('文件 “existing.txt” 已存在'), findsOneWidget);
      expect(await TextManifest.loadRecords(), hasLength(1));
    });

    testWidgets('allows same-folder duplicate name with another format', (
      tester,
    ) async {
      await TextManifest.saveTextRecord(
        TextRecord(
          name: 'shared-name',
          hash: 'existing-hash',
          format: 'txt',
          createdAt: DateTime.utc(2024),
          size: 1,
          folder: 'docs',
        ),
        'existing content',
      );
      await tester.pumpWidget(_buildTestApp(initialFolder: 'docs'));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, '标题').first,
        'shared-name',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump();
      await tester.tap(find.text('md').last);
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final records = await TextManifest.loadRecords();
      expect(records, hasLength(2));
      expect(
        records.map((record) => record.format),
        containsAll(['txt', 'md']),
      );
    });

    testWidgets('saves selected html format and source unchanged', (
      tester,
    ) async {
      const source = '<h1>Raw HTML</h1>\n<script>keep()</script>';
      await tester.pumpWidget(_buildTestApp(initialFolder: 'docs'));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, '标题').first,
        'page',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump();
      await tester.tap(find.text('html').last);
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, source);
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final records = await TextManifest.loadRecords();
      expect(records, hasLength(1));
      expect(records.single.format, 'html');
      expect(records.single.name, 'page');
      expect(await TextManifest.readText(records.single.storagePath), source);
    });

    testWidgets('allows same name and format in another folder', (
      tester,
    ) async {
      await TextManifest.saveTextRecord(
        TextRecord(
          name: 'shared-name',
          hash: 'existing-hash',
          format: 'txt',
          createdAt: DateTime.utc(2024),
          size: 1,
          folder: 'docs',
        ),
        'existing content',
      );
      await tester.pumpWidget(_buildTestApp(initialFolder: 'archive'));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, '标题').first,
        'shared-name',
      );
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final records = await TextManifest.loadRecords();
      expect(records, hasLength(2));
      expect(
        records.map((record) => record.folder),
        containsAll(['docs', 'archive']),
      );
    });

    test(
      'concurrent same-folder duplicate saves persist only one record',
      () async {
        final now = DateTime.utc(2024);
        final results = await Future.wait([
          TextManifest.saveTextRecordIfUnique(
            TextRecord(
              name: 'racing-name',
              hash: 'first-hash',
              format: 'txt',
              createdAt: now,
              size: 1,
              folder: 'docs',
            ),
            'first content',
          ),
          TextManifest.saveTextRecordIfUnique(
            TextRecord(
              name: 'racing-name',
              hash: 'second-hash',
              format: 'txt',
              createdAt: now,
              size: 1,
              folder: 'docs',
            ),
            'second content',
          ),
        ]);

        expect(results.where((saved) => saved), hasLength(1));
        expect(await TextManifest.loadRecords(), hasLength(1));
      },
    );

    testWidgets('shows format dropdown with txt and md options',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Should show a format selector with 'txt' as default
      expect(find.text('txt'), findsOneWidget);

      // Tap the dropdown to see options
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump();

      // Should show txt, md, and mmd options
      expect(find.text('txt'), findsWidgets);
      expect(find.text('md'), findsOneWidget);
      expect(find.text('mmd'), findsOneWidget);
    });

    testWidgets('can switch to md format', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Open dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump();

      // Select md
      await tester.tap(find.text('md').last);
      await tester.pump();

      // Should now show md as selected
      expect(find.text('md'), findsOneWidget);
    });

    testWidgets('can switch to mmd format', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Open dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump();

      // Select mmd
      await tester.tap(find.text('mmd').last);
      await tester.pump();

      // Should now show mmd as selected
      expect(find.text('mmd'), findsOneWidget);
    });

    testWidgets('saves with mmd format when selected', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter title
      await tester.enterText(
        find.widgetWithText(TextField, '标题').first,
        'test_mmd_file',
      );
      await tester.pump();

      // Enter content
      await tester.enterText(
        find.byType(TextField).last,
        'graph TD\n  A[Start] --> B[End]',
      );
      await tester.pump();

      // Switch to mmd format
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump();
      await tester.tap(find.text('mmd').last);
      await tester.pump();

      // Save
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify the record was saved with mmd format
      final records = await TextManifest.loadRecords();
      expect(records.length, equals(1));
      expect(records[0].name, equals('test_mmd_file'));
      expect(records[0].format, equals('mmd'));
    });

    testWidgets('saves with md format when selected', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter title
      await tester.enterText(
        find.widgetWithText(TextField, '标题').first,
        'test_md_file',
      );
      await tester.pump();

      // Enter content
      await tester.enterText(
        find.byType(TextField).last,
        '# Hello\n\nThis is **markdown**',
      );
      await tester.pump();

      // Switch to md format
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump();
      await tester.tap(find.text('md').last);
      await tester.pump();

      // Save
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify the record was saved with md format
      final records = await TextManifest.loadRecords();
      expect(records.length, equals(1));
      expect(records[0].name, equals('test_md_file'));
      expect(records[0].format, equals('md'));
    });

    testWidgets('rejects empty title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Try to save without a title
      await tester.tap(find.text('保存'));
      await tester.pump();

      // Should show error snackbar
      expect(find.text('请输入标题'), findsOneWidget);
    });

    testWidgets('rejects invalid filename without saving', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, '标题').first,
        'invalid/name',
      );
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(find.text('文件名不能包含 Windows 非法字符'), findsOneWidget);
      expect(await TextManifest.loadRecords(), isEmpty);
    });

    testWidgets('allows saving with empty content', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter title
      await tester.enterText(
        find.widgetWithText(TextField, '标题').first,
        'empty_content',
      );
      await tester.pump();

      // Leave content empty and save
      await tester.tap(find.text('保存'));
      // Use pump() instead of pumpAndSettle() to avoid overflow errors
      // during the save process
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should save successfully
      final records = await TextManifest.loadRecords();
      expect(records.length, equals(1));
      expect(records[0].name, equals('empty_content'));
      expect(records[0].textLength, equals(0));
      expect(records[0].size, equals(0));
    });
  });
}
