import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Returns a path for previewing an attachment in [directory].
///
/// Attachment names can come from imported conversation backups, so both
/// slash styles are treated as separators and only the basename is retained.
String attachmentPreviewPath(
  String directory,
  String attachmentId,
  String fileName,
) {
  final normalizedName = fileName.replaceAll('\\', '/');
  final basename = p.posix.basename(normalizedName);
  final safeBasename = basename
      .replaceAll(RegExp(r'[\x00-\x1f<>:"|?*]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '');
  final safeAttachmentId = sha256.convert(utf8.encode(attachmentId));
  final name =
      safeBasename.isEmpty || safeBasename == '.' || safeBasename == '..'
      ? 'preview'
      : safeBasename;
  final prefix = 'preview_${safeAttachmentId}_';
  final extension = p.posix.extension(name);
  final safeExtension = RegExp(r'^\.[a-zA-Z0-9]{1,16}$').hasMatch(extension)
      ? extension
      : '';
  final stem = safeExtension.isEmpty
      ? name
      : name.substring(0, name.length - safeExtension.length);
  final remainingBytes =
      255 - utf8.encode(prefix).length - utf8.encode(safeExtension).length;
  final truncatedStem = StringBuffer();
  var usedBytes = 0;
  for (final rune in stem.runes) {
    final character = String.fromCharCode(rune);
    final characterBytes = utf8.encode(character).length;
    if (usedBytes + characterBytes > remainingBytes) break;
    truncatedStem.write(character);
    usedBytes += characterBytes;
  }
  final previewName = '$prefix$truncatedStem$safeExtension';
  return p.join(directory, previewName);
}

/// Returns a unique preview path so concurrent previews of one attachment
/// cannot delete or overwrite each other's temporary copies.
String attachmentPreviewPathForPreview(
  String directory,
  String attachmentId,
  String fileName,
) {
  return attachmentPreviewPath(
    directory,
    '$attachmentId:${const Uuid().v4()}',
    fileName,
  );
}
