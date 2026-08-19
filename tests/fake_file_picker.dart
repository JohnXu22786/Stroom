import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
// The platform interface lives under the package's src/ (not exported
// publicly); extending it is the supported way to fake the save dialog.
// ignore_for_file: implementation_imports
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';

/// Test double for the system file save dialog ([FilePicker.saveFile]).
///
/// Records the arguments of every call and returns [result] (or blocks on
/// [completer] when set, to simulate a slow native dialog). Install it with:
///
/// ```dart
/// final original = FilePickerPlatform.instance;
/// FilePickerPlatform.instance = fake;
/// addTearDown(() => FilePickerPlatform.instance = original);
/// ```
class FakeFilePicker extends FilePickerPlatform {
  FakeFilePicker({this.result = 'C:/saved/code.txt', this.completer});

  /// The path returned by [saveFile]; `null` simulates a user cancel.
  String? result;

  /// When set, [saveFile] waits on this future instead of returning
  /// [result] — lets tests hold the "dialog open" state.
  final Completer<String?>? completer;

  /// When set, [saveFile] throws this error (simulates a platform failure).
  Object? throwError;

  int saveCallCount = 0;
  String? lastDialogTitle;
  String? lastFileName;
  FileType? lastType;
  List<String>? lastAllowedExtensions;
  Uint8List? lastBytes;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    saveCallCount++;
    lastDialogTitle = dialogTitle;
    lastFileName = fileName;
    lastType = type;
    lastAllowedExtensions = allowedExtensions;
    lastBytes = bytes;
    if (throwError != null) throw throwError!;
    if (completer != null) return completer!.future;
    return result;
  }
}
