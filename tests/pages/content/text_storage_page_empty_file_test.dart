import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/text_storage_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/widgets/folder_picker_dialog.dart';

import '../../fake_file_picker.dart';

class _EmptyTextPicker extends FilePickerPlatform {
  _EmptyTextPicker(this.input);

  final PlatformFile input;
  Uint8List? savedBytes;
  String? savedName;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async =>
      [input];

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    savedName = fileName;
    savedBytes = bytes;
    return Uri.parse('content://saved/$fileName');
  }
}

class _TextFilesPicker extends FilePickerPlatform {
  _TextFilesPicker(this.inputs);

  final List<PlatformFile> inputs;
  List<String>? lastAllowedExtensions;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    lastAllowedExtensions = allowedExtensions;
    return inputs;
  }
}

Widget _buildApp({
  Locale locale = const Locale('zh', 'CN'),
  double textScaleFactor = 1,
  ThemeMode themeMode = ThemeMode.light,
  bool allowMotion = false,
}) =>
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(colorSchemeSeed: Colors.blue),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.blue,
          brightness: Brightness.dark,
        ),
        themeMode: themeMode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: !allowMotion,
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: child!,
        ),
        home: const TextStoragePage(),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FilePickerPlatform originalPicker;

  setUp(() async {
    originalPicker = FilePickerPlatform.instance;
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    ManifestDatabase.beforeJsonRecordRegistrationForTesting = null;
    TextManifest.invalidateCache();
  });

  tearDown(() {
    FilePickerPlatform.instance = originalPicker;
    ManifestDatabase.beforeJsonRecordRegistrationForTesting = null;
  });

  testWidgets('imports a zero-byte text file', (tester) async {
    final picker = _EmptyTextPicker(
      FakePlatformFile(name: 'empty.txt', bytes: Uint8List(0)),
    );
    FilePickerPlatform.instance = picker;
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('导入'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final records = await TextManifest.loadRecords();
    expect(records, hasLength(1));
    expect(records.single.name, 'empty');
    expect(records.single.size, 0);
    expect(records.single.textLength, 0);
    expect(await TextManifest.readText(records.single.storagePath), '');
  });

  testWidgets('imports HTML text files using the supported format allowlist',
      (tester) async {
    const content = '<h1>Notes</h1>';
    final picker = _TextFilesPicker([
      FakePlatformFile(
        name: 'notes.html',
        bytes: Uint8List.fromList(content.codeUnits),
      ),
    ]);
    FilePickerPlatform.instance = picker;
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('导入'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(picker.lastAllowedExtensions, contains('html'));
    expect(picker.lastAllowedExtensions, contains('mmd'));
    final records = await TextManifest.loadRecords();
    expect(records, hasLength(1));
    expect(records.single.name, 'notes');
    expect(records.single.format, 'html');
    expect(await TextManifest.readText(records.single.storagePath), content);
  });

  testWidgets('file format label uses the shared bounded text behavior', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final record = TextRecord(
      id: 'format-label',
      name: 'format-label',
      hash: 'format-label-hash',
      format: 'html',
      createdAt: DateTime.utc(2024),
      size: 0,
    );
    await TextManifest.addRecord(record);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final label = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == 'HTML',
    );
    expect(label, findsOneWidget);
    expect(tester.getSize(label).width, lessThanOrEqualTo(44));
    expect(find.text('HTML'), findsOneWidget);
    expect(find.byType(FittedBox), findsNothing);
    final start = tester.getTopLeft(find.text('HTML'));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getTopLeft(find.text('HTML')), start);

    for (final locale in [const Locale('en'), const Locale('de')]) {
      for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
        for (final scale in [1.0, 2.0, 4.0]) {
          await tester.pumpWidget(
            _buildApp(
              locale: locale,
              textScaleFactor: scale,
              themeMode: themeMode,
            ),
          );
          await tester.pumpAndSettle();
          expect(label, findsOneWidget);
          expect(find.text('HTML'), findsOneWidget);
          final badge = find.byKey(
            const Key('text-storage-format-badge-format-label'),
          );
          expect(badge, findsOneWidget);
          final badgeSize = tester.getSize(badge);
          if (scale == 1) {
            expect(badgeSize, const Size(60, 60));
          } else if (scale == 4) {
            final text = tester.widget<Text>(find.text('HTML'));
            expect(text.overflow, TextOverflow.clip);
            final painter = TextPainter(
              text: TextSpan(text: 'HTML', style: text.style),
              textDirection: TextDirection.ltr,
              textScaler: TextScaler.linear(scale),
              locale: locale,
              maxLines: 1,
              ellipsis: '…',
            )..layout(maxWidth: 44);
            expect(badgeSize.width, 60);
            expect(badgeSize.height, greaterThanOrEqualTo(painter.height + 16));

            final badgeRect = tester.getRect(badge);
            final nameRect = tester.getRect(find.text('format-label.html'));
            final actionRect = tester.getRect(
              find.byKey(const Key('fm_file_popup_format-label')),
            );
            expect(nameRect.left, greaterThanOrEqualTo(badgeRect.right));
            expect(nameRect.right, lessThanOrEqualTo(actionRect.left));
          }
        }
      }
    }
  });

  testWidgets('text storage actions grow to fit scaled labels', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [320.0, 800.0]) {
      tester.view.physicalSize = Size(width, 640);
      for (final scale in [1.0, 4.0]) {
        for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
          await tester.pumpWidget(
            _buildApp(
              locale: const Locale('fr', 'FR'),
              textScaleFactor: scale,
              themeMode: themeMode,
            ),
          );
          await tester.pumpAndSettle();

          final buttons = find.byType(ElevatedButton);
          expect(buttons, findsNWidgets(2));
          final buttonRects = buttons
              .evaluate()
              .map((element) => tester.getRect(find.byWidget(element.widget)))
              .toList();
          expect(buttonRects[0].height, buttonRects[1].height);

          final expectedHeight = scale == 1 ? 48.0 : greaterThan(48.0);
          expect(buttonRects[0].height, expectedHeight);
          final icons = [
            find.byIcon(Icons.add_circle_outline),
            find.byIcon(Icons.file_download_outlined),
          ];
          for (var index = 0; index < 2; index++) {
            final label = ['Nouveau', 'Importer'][index];
            final textRect = tester.getRect(find.text(label));
            final iconRect = tester.getRect(icons[index]);
            final buttonRect = buttonRects[index];
            expect(textRect.top, greaterThanOrEqualTo(buttonRect.top));
            expect(textRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
            expect(iconRect.top, greaterThanOrEqualTo(buttonRect.top));
            expect(iconRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
            expect(textRect.left, greaterThanOrEqualTo(iconRect.right));
          }
          expect(tester.takeException(), isNull);
        }
      }
    }

    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpWidget(
      _buildApp(
        locale: const Locale('fr', 'FR'),
        textScaleFactor: 4,
        allowMotion: true,
      ),
    );
    await tester.pump();
    for (final label in ['Nouveau', 'Importer']) {
      final start = tester.getTopLeft(find.text(label));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getTopLeft(find.text(label)).dx, lessThan(start.dx));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('captures the clipped format reveal at 2x text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final record = TextRecord(
      id: 'format-label-reveal',
      name: 'format-label-reveal',
      hash: 'format-label-reveal-hash',
      format: 'yaml',
      createdAt: DateTime.utc(2024),
      size: 0,
    );
    await TextManifest.addRecord(record);

    await tester.pumpWidget(
      _buildApp(
        textScaleFactor: 2,
        themeMode: ThemeMode.dark,
        allowMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('YAML'), findsOneWidget);
    final text = find.text('YAML');
    expect(tester.widget<Text>(text).style?.fontSize, 12);
    final start = tester.getTopLeft(text);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(start.dx - tester.getTopLeft(text).dx, closeTo(7.2, 1.5));
  });

  testWidgets('shows saved files after a later import item fails',
      (tester) async {
    final picker = _TextFilesPicker([
      FakePlatformFile(name: 'first.txt', bytes: Uint8List.fromList([65])),
      FakePlatformFile(name: 'invalid.txt', bytes: Uint8List.fromList([0xff])),
    ]);
    FilePickerPlatform.instance = picker;
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('导入'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.textContaining('导入失败：'), findsOneWidget);
    expect(find.text('first.txt'), findsOneWidget);
    final records = await TextManifest.loadRecords();
    expect(records, hasLength(1));
    expect(await TextManifest.readText(records.single.storagePath), 'A');
  });

  testWidgets('exports an empty text record as zero bytes', (tester) async {
    final picker = _EmptyTextPicker(
      FakePlatformFile(name: 'unused.txt', bytes: Uint8List(0)),
    );
    FilePickerPlatform.instance = picker;
    final record = TextRecord(
      id: 'empty-export',
      name: 'empty-export',
      hash: computeTextHash(Uint8List(0)),
      format: 'txt',
      createdAt: DateTime.utc(2024),
      size: 0,
      textLength: 0,
    );
    await TextManifest.writeText(record.storagePath, '');
    await TextManifest.addRecord(record);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fm_file_popup_empty-export')));
    await tester.pumpAndSettle();
    final originalPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.tap(find.text('导出到本地'));
      await tester.pumpAndSettle();
    } finally {
      debugDefaultTargetPlatformOverride = originalPlatform;
    }

    expect(picker.savedName, 'empty-export.txt');
    expect(picker.savedBytes, isNotNull);
    expect(picker.savedBytes, isEmpty);
    expect(find.textContaining('读取失败'), findsNothing);
  });

  testWidgets('keeps batch copy selection when text record registration fails',
      (tester) async {
    await TextManifest.saveTextRecord(
      TextRecord(
        id: 'source',
        name: 'source',
        hash: 'source-hash',
        format: 'txt',
        createdAt: DateTime.utc(2024),
        size: 1,
      ),
      'x',
    );
    await TextManifest.addFolder('destination');
    ManifestDatabase.beforeJsonRecordRegistrationForTesting = () {
      throw StateError('disk error');
    };

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const Key('fm_file_source')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fm_selection_copy_btn')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(FolderPickerDialog),
        matching: find.text('destination'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('批量复制失败: Bad state: disk error'), findsOneWidget);
    expect(find.text('已选择 1 项'), findsOneWidget);
  });
}
