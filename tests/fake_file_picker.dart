import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';

/// In-memory or path-backed [PlatformFile] for picker tests.
final class FakePlatformFile extends PlatformFile {
  FakePlatformFile({
    required this.name,
    this.bytes,
    this.localPath,
    this.reportedLength,
  }) : uri = localPath == null
           ? Uri.dataFromBytes(bytes ?? Uint8List(0))
           : Uri.file(localPath!);

  @override
  final String name;

  @override
  final Uri uri;

  final Uint8List? bytes;
  final String? localPath;
  final int? reportedLength;

  @override
  String? get path => localPath;

  @override
  XFile get xFile => localPath == null
      ? XFile.fromData(bytes ?? Uint8List(0), name: name)
      : XFile(localPath!);

  @override
  int? lengthSync() => reportedLength ?? bytes?.length;

  @override
  Future<int?> length() async => lengthSync();

  @override
  Future<Uint8List> readAsBytes() async {
    if (bytes != null) return bytes!;
    if (localPath != null) return XFile(localPath!).readAsBytes();
    return Uint8List(0);
  }

  @override
  Stream<Uint8List> readAsByteStream() async* {
    if (bytes != null) {
      yield bytes!;
      return;
    }
    if (localPath != null) {
      await for (final chunk in File(localPath!).openRead()) {
        yield Uint8List.fromList(chunk);
      }
    }
  }
}

/// Test double for the file picker's save dialog.
///
/// Records save arguments and returns [result] (or blocks on [completer] to
/// simulate a slow native dialog).
class FakeFilePicker extends FilePickerPlatform {
  FakeFilePicker({Uri? result, this.completer})
    : result = result ?? Uri.parse('file:///C:/saved/code.txt');

  Uri? result;
  final Completer<Uri?>? completer;
  Object? throwError;

  int saveCallCount = 0;
  String? lastDialogTitle;
  String? lastFileName;
  String? lastMimeType;
  Uint8List? lastBytes;

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
    saveCallCount++;
    lastDialogTitle = dialogTitle;
    lastFileName = fileName;
    lastMimeType = mimeType;
    lastBytes = bytes;
    if (throwError != null) throw throwError!;
    if (completer != null) return completer!.future;
    return result;
  }
}
