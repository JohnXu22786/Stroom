import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart'
    as selector_platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stroom/utils/file_picker_utils.dart';

import '../fake_file_picker.dart';

class _FakeFileSelector extends selector_platform.FileSelectorPlatform {
  _FakeFileSelector(this.location);

  final FileSaveLocation? location;
  List<XTypeGroup>? acceptedTypeGroups;
  selector_platform.SaveDialogOptions? options;

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    selector_platform.SaveDialogOptions options =
        const selector_platform.SaveDialogOptions(),
  }) async {
    this.acceptedTypeGroups = acceptedTypeGroups;
    this.options = options;
    return location;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TargetPlatform? originalPlatform;
  late FilePickerPlatform originalFilePicker;
  late selector_platform.FileSelectorPlatform originalFileSelector;

  setUp(() {
    originalPlatform = debugDefaultTargetPlatformOverride;
    originalFilePicker = FilePickerPlatform.instance;
    originalFileSelector = selector_platform.FileSelectorPlatform.instance;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = originalPlatform;
    FilePickerPlatform.instance = originalFilePicker;
    selector_platform.FileSelectorPlatform.instance = originalFileSelector;
  });

  test('file exports keep free names and reserve collision-free suffixes',
      () async {
    final directory = await Directory.systemTemp.createTemp('tts_export_');
    addTearDown(() => directory.delete(recursive: true));
    final existing = File('${directory.path}/speech.wav');
    await existing.writeAsBytes([9, 8, 7]);
    final existingFolder = Directory('${directory.path}/other.wav');
    await existingFolder.create();

    final paths = await resolveNonClobberingExportPaths(
      files: [
        'speech.wav',
        'other.wav',
        'speech (1).wav/child.wav',
        'plain.wav',
      ],
      directory: directory.path,
      folders: ['other (1).wav'],
      pathExists: (path) async =>
          await FileSystemEntity.type(path, followLinks: false) !=
          FileSystemEntityType.notFound,
    );

    expect(paths, [
      '${directory.path}${Platform.pathSeparator}speech (2).wav',
      '${directory.path}${Platform.pathSeparator}other (2).wav',
      '${directory.path}${Platform.pathSeparator}speech (1).wav'
          '${Platform.pathSeparator}child.wav',
      '${directory.path}${Platform.pathSeparator}plain.wav',
    ]);

    await expectLater(
      writeUserVisibleExportFile(existing.path, Uint8List.fromList([1, 2, 3])),
      throwsA(isA<FileSystemException>()),
    );
    expect(await existing.readAsBytes(), [9, 8, 7]);
    await writeUserVisibleExportFile(paths[1], Uint8List.fromList([1, 2, 3]));
    expect(await File(paths[1]).readAsBytes(), [1, 2, 3]);
  });

  test('failed export writes remove the exclusively created destination',
      () async {
    final directory = await Directory.systemTemp.createTemp('failed_export_');
    addTearDown(() => directory.delete(recursive: true));
    final destination = '${directory.path}/partial.bin';

    await expectLater(
      writeUserVisibleExportFile(
        destination,
        Uint8List.fromList([1, 2, 3]),
        writeBytes: (file, bytes) async {
          await file.writeAsBytes(bytes.take(1).toList());
          throw FileSystemException('simulated write failure', file.path);
        },
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(await FileSystemEntity.type(destination),
        FileSystemEntityType.notFound);
  });

  test('file exports reserve names using Unicode case folding', () async {
    final directory = await Directory.systemTemp.createTemp('unicode_export_');
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}/σ.txt').writeAsBytes([1]);

    final paths = await resolveNonClobberingExportPaths(
      files: const ['σ.txt', 'ς (1).txt'],
      directory: directory.path,
      pathExists: (path) async =>
          await FileSystemEntity.type(path, followLinks: false) !=
          FileSystemEntityType.notFound,
    );

    expect(paths, [
      '${directory.path}${Platform.pathSeparator}σ (2).txt',
      '${directory.path}${Platform.pathSeparator}ς (1).txt',
    ]);
  });

  test('image, video, and text exports preserve same-named destination files',
      () async {
    final directory = await Directory.systemTemp.createTemp('batch_export_');
    addTearDown(() => directory.delete(recursive: true));

    final names = <(String, String)>[
      ('photo.jpg', 'photo (1).jpg'),
      ('clip.mp4', 'clip (1).mp4'),
      ('notes.txt', 'notes (1).txt'),
    ];
    for (final (name, suffixedName) in names) {
      final existing = File('${directory.path}/$name');
      await existing.writeAsString('keep $name');
      final outputPaths = await resolveNonClobberingExportPaths(
        files: [name],
        directory: directory.path,
        pathExists: (path) async =>
            await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.notFound,
      );

      expect(outputPaths.single, endsWith(suffixedName));
      await writeUserVisibleExportFile(
        outputPaths.single,
        Uint8List.fromList('new $name'.codeUnits),
      );

      expect(await existing.readAsString(), 'keep $name');
      expect(await File(outputPaths.single).readAsString(), 'new $name');
    }
  });

  test('folder exports preserve existing files at nested paths', () async {
    final directory = await Directory.systemTemp.createTemp('folder_export_');
    addTearDown(() => directory.delete(recursive: true));
    final folder = Directory('${directory.path}/photos/nested');
    await folder.create(recursive: true);
    final existing = File('${folder.path}/scene.jpg');
    await existing.writeAsString('keep existing photo');

    final outputPaths = await resolveNonClobberingExportPaths(
      files: ['photos/nested/scene.jpg'],
      directory: directory.path,
      folders: ['photos', 'photos/nested'],
      pathExists: (path) async =>
          await FileSystemEntity.type(path, followLinks: false) !=
          FileSystemEntityType.notFound,
    );

    expect(
      outputPaths.single,
      endsWith(p.join('photos', 'nested', 'scene (1).jpg')),
    );
    await writeUserVisibleExportFile(
      outputPaths.single,
      Uint8List.fromList('new photo'.codeUnits),
    );

    expect(await existing.readAsString(), 'keep existing photo');
    expect(await File(outputPaths.single).readAsString(), 'new photo');
  });

  test('folder export directories reject symlinked path components', () async {
    final destination = await Directory.systemTemp.createTemp('export_root_');
    final outside = await Directory.systemTemp.createTemp('export_outside_');
    addTearDown(() => destination.delete(recursive: true));
    addTearDown(() => outside.delete(recursive: true));
    await Link(p.join(destination.path, 'photos')).create(outside.path);

    await expectLater(
      createUserVisibleExportDirectory(destination.path, 'photos/nested'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await Directory(outside.path).list().toList(), isEmpty);
  });

  test('folder export directories stay inside the selected destination',
      () async {
    final destination = await Directory.systemTemp.createTemp('export_root_');
    addTearDown(() => destination.delete(recursive: true));

    await createUserVisibleExportDirectory(destination.path, 'photos/nested');

    expect(
      await Directory(p.join(destination.path, 'photos', 'nested')).exists(),
      isTrue,
    );
    await expectLater(
      createUserVisibleExportDirectory(destination.path, '../outside'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('desktop save applies the extension filter and writes selected bytes',
      () async {
    final directory = await Directory.systemTemp.createTemp('picker_save_');
    addTearDown(() => directory.delete(recursive: true));
    final destination = '${directory.path}${Platform.pathSeparator}backup.zip';
    final fileSelector = _FakeFileSelector(FileSaveLocation(destination));
    selector_platform.FileSelectorPlatform.instance = fileSelector;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final bytes = Uint8List.fromList([1, 2, 3]);

    final result = await saveFileWithType(
      fileName: 'backup.zip',
      bytes: bytes,
      extensions: ['zip'],
      dialogTitle: 'Save backup',
      initialDirectory: directory.path,
    );

    expect(result, Uri.file(destination));
    expect(await File(destination).readAsBytes(), bytes);
    expect(fileSelector.acceptedTypeGroups, hasLength(1));
    expect(fileSelector.acceptedTypeGroups!.single.extensions, ['zip']);
    expect(fileSelector.options!.suggestedName, 'backup.zip');
    expect(fileSelector.options!.initialDirectory, directory.path);
    expect(FilePickerPlatform.instance, same(originalFilePicker));
  });

  test('cancelled desktop save does not create a file', () async {
    final fileSelector = _FakeFileSelector(null);
    selector_platform.FileSelectorPlatform.instance = fileSelector;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final bytes = Uint8List.fromList([4, 5]);

    final result = await saveFileWithType(
      fileName: 'image.png',
      bytes: bytes,
      extensions: ['png'],
    );

    expect(result, isNull);
  });

  test('mobile save keeps FilePicker byte-save behavior', () async {
    final picker = FakeFilePicker(result: Uri.parse('content://saved/file'));
    FilePickerPlatform.instance = picker;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final bytes = Uint8List.fromList([6, 7]);

    final result = await saveFileWithType(
      fileName: 'audio.wav',
      bytes: bytes,
      extensions: ['wav'],
      mimeType: 'audio/wav',
      dialogTitle: 'Save audio',
      initialDirectory: '/storage/music',
    );

    expect(result, Uri.parse('content://saved/file'));
    expect(picker.saveCallCount, 1);
    expect(picker.lastFileName, 'audio.wav');
    expect(picker.lastBytes, bytes);
    expect(picker.lastMimeType, 'audio/wav');
    expect(picker.lastDialogTitle, 'Save audio');
  });

  test('location label uses a local path for files and a URI for web saves',
      () {
    expect(filePickerLocationLabel(Uri.file('/tmp/archive.zip')),
        '/tmp/archive.zip');
    expect(
      filePickerLocationLabel(Uri.parse('blob:https://example.test/id')),
      'blob:https://example.test/id',
    );
  });

  test('export archive keeps visible nested paths and empty folders', () {
    final bytes = encodeUserVisibleExportArchive(
      files: {
        '旅行/2026/海边/photo.jpg': Uint8List.fromList([1, 2, 3]),
      },
      folders: const ['旅行/空目录'],
    );

    final entries = ZipDecoder().decodeBytes(bytes);
    final names = entries.map((entry) => entry.name).toSet();
    expect(names, contains('旅行/2026/海边/photo.jpg'));
    expect(names, contains('旅行/空目录/'));
    expect(names, isNot(contains('hash123.jpg')));
  });

  test('rejects folder paths that are case-insensitive aliases', () {
    expect(
      () => validateUserVisibleExportPaths(
        files: const [],
        folders: const ['Report', 'report'],
      ),
      throwsStateError,
    );
  });

  test('rejects export paths that collide after Windows trims trailing spaces',
      () {
    expect(
      () => validateUserVisibleExportPaths(files: const ['report ']),
      throwsArgumentError,
    );
    expect(
      () => validateUserVisibleExportPaths(
        files: const ['report', 'report '],
      ),
      throwsArgumentError,
    );
  });

  test('rejects export paths Windows trims after a trailing period', () {
    final bytes = Uint8List.fromList([1]);
    expect(
      () => encodeUserVisibleExportArchive(
        files: {'report.txt': bytes, 'report.txt.': bytes},
      ),
      throwsArgumentError,
    );
    expect(
      () => validateUserVisibleExportPaths(
        files: const ['folder./report.txt'],
      ),
      throwsArgumentError,
    );
    expect(
      () => validateUserVisibleExportPaths(
        files: const [],
        folders: const ['folder.'],
      ),
      throwsArgumentError,
    );
  });

  test('rejects reserved Windows device names in files and folders', () {
    for (final file in const [
      'CON',
      'con.txt',
      'AUX.log',
      'COM1.csv',
      'LPT9',
      'CON:stream',
      'CONIN\$',
    ]) {
      expect(
        () => validateUserVisibleExportPaths(files: [file]),
        throwsArgumentError,
        reason: 'File path component "$file" is reserved on Windows',
      );
    }
    for (final folder in const ['CON', 'nested/NUL.txt', 'CONOUT\$.log']) {
      expect(
        () => validateUserVisibleExportPaths(
          files: const [],
          folders: [folder],
        ),
        throwsArgumentError,
        reason: 'Folder path component "$folder" is reserved on Windows',
      );
    }
  });

  test('rejects Windows forbidden characters in file and folder components',
      () {
    for (final file in const [
      'bad?.txt',
      'bad*.txt',
      'bad".txt',
      'bad<.txt',
      'bad>.txt',
      'bad|.txt',
      'bad:.txt',
      'bad\u0001.txt',
    ]) {
      expect(
        () => validateUserVisibleExportPaths(files: [file]),
        throwsArgumentError,
        reason:
            'File path component "$file" contains a Windows-forbidden character',
      );
    }
    for (final folder in const [
      'nested/bad?',
      'nested/bad*',
      'nested/bad"',
      'nested/bad<',
      'nested/bad>',
      'nested/bad|',
      'nested/bad:',
      'nested/bad\u0001',
    ]) {
      expect(
        () => validateUserVisibleExportPaths(
          files: const [],
          folders: [folder],
        ),
        throwsArgumentError,
        reason:
            'Folder path component "$folder" contains a Windows-forbidden character',
      );
    }
  });

  test('allows distinct Unicode export names without case expansion', () {
    expect(
      () => validateUserVisibleExportPaths(
        files: const ['straße.txt', 'strasse.txt'],
      ),
      returnsNormally,
    );
    expect(
      () => validateUserVisibleExportPaths(
        files: const ['ﬃ.txt', 'ffi.txt'],
      ),
      returnsNormally,
    );
  });

  test('rejects Unicode export paths that are case-insensitive aliases', () {
    expect(
      () => validateUserVisibleExportPaths(
        files: const ['Report.txt', 'report.txt'],
      ),
      throwsStateError,
    );
    expect(
      () => validateUserVisibleExportPaths(
        files: const ['σ.txt', 'ς.txt'],
      ),
      throwsStateError,
    );
    expect(
      () => validateUserVisibleExportPaths(
        files: const ['ᾀ.txt', 'ἈΙ.txt'],
      ),
      throwsStateError,
    );
    expect(
      () => validateUserVisibleExportPaths(
        files: const ['caf\u00e9.txt', 'cafe\u0301.txt'],
      ),
      throwsStateError,
    );
    expect(
      () => validateUserVisibleExportPaths(
        files: const ['Report.txt'],
        folders: const ['report.txt'],
      ),
      throwsStateError,
    );
  });
}
