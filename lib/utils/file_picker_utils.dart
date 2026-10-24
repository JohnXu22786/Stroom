import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Opens a save dialog filtered to [extensions] and writes [bytes] to the
/// selected location.
///
/// Desktop file_picker 13 save dialogs no longer forward extension filters to
/// their platform interface, so use file_selector there. Browser and mobile
/// save flows keep file_picker's byte-save behavior; the suggested filename
/// includes the selected extension.
Future<Uri?> saveFileWithType({
  required String fileName,
  required Uint8List bytes,
  required List<String> extensions,
  String? dialogTitle,
  String mimeType = 'application/octet-stream',
  String? initialDirectory,
}) async {
  final isDesktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);
  if (!isDesktop) {
    return FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
    );
  }

  final location = await getSaveLocation(
    acceptedTypeGroups: [XTypeGroup(extensions: extensions)],
    initialDirectory: initialDirectory,
    suggestedName: fileName,
  );
  if (location == null) return null;

  await XFile.fromData(
    bytes,
    mimeType: mimeType,
    name: fileName,
  ).saveTo(location.path);
  return Uri.file(location.path);
}

/// Formats a save location for a user-facing message.
///
/// Local save dialogs return `file:` URIs while web save flows may return a
/// `blob:` or `data:` URI. Preserve the familiar filesystem path for local
/// files and show the URI for browser-managed downloads.
String filePickerLocationLabel(Uri location) {
  if (location.scheme == 'file') return location.toFilePath();
  return location.toString();
}
