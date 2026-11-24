import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../catcatch/models/media_kind.dart';
import '../../utils/text_manifest.dart';
import '../audio_player_page.dart';
import '../text_preview_edit_page.dart';
import '../video_gallery_shared.dart';

final Set<String> _textExtensions = {
  'txt',
  'md',
  'json',
  'xml',
  'csv',
  'log',
  'yaml',
  'yml',
  'ini',
  'cfg',
  'bat',
  'sh',
  'ps1',
  'py',
  'js',
  'jsx',
  'tsx',
  'html',
  'htm',
  'css',
  'scss',
  'sass',
  'less',
  'dart',
  'java',
  'cpp',
  'h',
  'hpp',
  'c',
  'sql',
  'rb',
  'php',
  'pl',
  'rs',
  'go',
  'swift',
  'kt',
  'toml',
  'lock',
  'env',
  'gitignore',
  'makefile',
  'cmake',
  'dockerfile',
  'conf',
  'properties',
  'm',
  'mm',
  'r',
  'scala',
  'clj',
  'lua',
  'hs',
  'erl',
  'ex',
  'exs',
  'vue',
  'svelte',
  'astro',
  'terraform',
  'tf',
  'hcl',
};

final Set<String> _videoExtensions = {
  'mp4',
  'mkv',
  'avi',
  'mov',
  'wmv',
  'flv',
  'webm',
  'm4v',
  '3gp',
  '3gpp',
  'ogv',
  'ts',
  'mts',
  'm2ts',
  'vob',
  'divx',
};

final Set<String> _audioExtensions = {
  'mp3',
  'wav',
  'm4a',
  'mka',
  'aac',
  'opus',
  'ogg',
  'weba',
  'flac',
  'wma',
  'aiff',
  'aif',
  'pcm',
  'wv',
  'caf',
  'ra',
  'mid',
  'midi',
};

enum FileOpenKind { text, video, audio, system }

bool shouldAbortFileOpenForMissingFile({
  required bool isWeb,
  required bool Function() existsSync,
}) {
  if (isWeb) return false;
  return !existsSync();
}

Future<Uint8List?> readFileBytesForOpen(
  String filePath, {
  required bool isWeb,
}) => isWeb
    ? TextManifest.readFile(_textManifestFileName(filePath))
    : File(filePath).readAsBytes();

String _textManifestFileName(String filePath) {
  const webTextPrefix = 'texts/';
  return filePath.startsWith(webTextPrefix)
      ? filePath.substring(webTextPrefix.length)
      : filePath;
}

/// Some containers can contain either audio or video. Probe their saved bytes
/// instead of treating their extensions as a media kind.
Future<FileOpenKind> fileOpenKind(String filePath, {bool? isWeb}) async {
  final isWebPlatform = isWeb ?? kIsWeb;
  final ext = p.extension(filePath).replaceAll('.', '').toLowerCase();
  if (_textExtensions.contains(ext)) return FileOpenKind.text;
  if (const {'mov', 'flv', 'avi', 'mpeg', 'mpg'}.contains(ext)) {
    // The native probe reads the saved file with dart:io. On web, route these
    // ambiguous containers to the browser video player instead.
    if (isWebPlatform) return FileOpenKind.video;
    final kind = await catCatchMediaKindFromPath(filePath);
    if (kind == CatCatchMediaKind.audio) return FileOpenKind.audio;
    if (kind == CatCatchMediaKind.video) return FileOpenKind.video;
    return FileOpenKind.system;
  }
  if (_videoExtensions.contains(ext)) return FileOpenKind.video;
  if (_audioExtensions.contains(ext)) return FileOpenKind.audio;
  return FileOpenKind.system;
}

/// Open a file with the appropriate built-in viewer based on file extension.
///
/// - Text files → [TextPreviewEditPage]
/// - Video files → [VideoPlayerPage]
/// - Audio files → [AudioPlayerPage]
/// - Other files → OS default application
Future<void> openFile(String filePath, BuildContext context) async {
  try {
    if (shouldAbortFileOpenForMissingFile(
      isWeb: kIsWeb,
      existsSync: () => File(filePath).existsSync(),
    )) {
      debugPrint('File not found: $filePath');
      return;
    }

    final kind = await fileOpenKind(filePath);
    if (!context.mounted) return;
    switch (kind) {
      case FileOpenKind.text:
        await _openTextFile(filePath, context);
      case FileOpenKind.video:
        _openVideoFile(filePath, context);
      case FileOpenKind.audio:
        _openAudioFile(filePath, context);
      case FileOpenKind.system:
        _openWithOsDefault(filePath);
    }
  } catch (e) {
    debugPrint('Failed to open file: $e');
  }
}

Future<void> _openTextFile(String filePath, BuildContext context) async {
  try {
    // Async read — a multi-MB transcript must not block the UI thread.
    final bytes = await readFileBytesForOpen(filePath, isWeb: kIsWeb);
    if (bytes == null) throw FileSystemException('File not found', filePath);
    if (!context.mounted) return;
    final content = utf8.decode(bytes);
    final name = p.basenameWithoutExtension(filePath);
    final hash = _computeSimpleHash(bytes);
    final record = TextRecord(
      name: name,
      hash: hash,
      format: p.extension(filePath).replaceAll('.', ''),
      createdAt: kIsWeb ? DateTime.now() : File(filePath).statSync().changed,
      size: bytes.length,
      textLength: content.length,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TextPreviewEditPage(
          file: record,
          initialContent: content,
          registerRecordOnSave: true,
        ),
      ),
    );
  } catch (e) {
    debugPrint('Failed to open text file: $e');
    if (!kIsWeb) _openWithOsDefault(filePath);
  }
}

void _openVideoFile(String filePath, BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VideoPlayerPage(
        filePath: filePath,
        displayName: p.basename(filePath),
      ),
    ),
  );
}

void _openAudioFile(String filePath, BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AudioPlayerPage(
        filePath: filePath,
        displayName: p.basenameWithoutExtension(filePath),
      ),
    ),
  );
}

void _openWithOsDefault(String filePath) {
  try {
    if (Platform.isWindows) {
      Process.run('cmd', ['/c', 'start', '', '"$filePath"'], runInShell: true);
    } else if (Platform.isMacOS) {
      Process.start('open', [filePath], mode: ProcessStartMode.detached);
    } else {
      Process.start('xdg-open', [filePath], mode: ProcessStartMode.detached);
    }
  } catch (e) {
    debugPrint('Failed to open file with OS default: $e');
  }
}

String _computeSimpleHash(Uint8List bytes) {
  return computeTextHash(bytes);
}
