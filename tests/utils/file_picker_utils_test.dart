import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart'
    as selector_platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
