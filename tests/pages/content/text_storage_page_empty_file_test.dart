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
      inputs;
}

Widget _buildApp() => const ProviderScope(
      child: MaterialApp(
        locale: Locale('zh', 'CN'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: TextStoragePage(),
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
