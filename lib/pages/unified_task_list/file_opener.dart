import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

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
  'ts',
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
  'aac',
  'opus',
  'ogg',
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

/// Open a file with the appropriate built-in viewer based on file extension.
///
/// - Text files → [TextPreviewEditPage]
/// - Video files → [VideoPlayerPage]
/// - Audio files → [AudioPlayerPage]
/// - Other files → OS default application
Future<void> openFile(String filePath, BuildContext context) async {
  try {
    final file = File(filePath);
    if (!file.existsSync()) {
      debugPrint('File not found: $filePath');
      return;
    }

    final ext = p.extension(filePath).replaceAll('.', '').toLowerCase();

    if (_textExtensions.contains(ext)) {
      await _openTextFile(filePath, context);
    } else if (_videoExtensions.contains(ext)) {
      _openVideoFile(filePath, context);
    } else if (_audioExtensions.contains(ext)) {
      _openAudioFile(filePath, context);
    } else {
      _openWithOsDefault(filePath);
    }
  } catch (e) {
    debugPrint('Failed to open file: $e');
  }
}

Future<void> _openTextFile(String filePath, BuildContext context) async {
  try {
    final file = File(filePath);
    // Async read — a multi-MB transcript must not block the UI thread.
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    final content = utf8.decode(bytes);
    final name = p.basenameWithoutExtension(filePath);
    final hash = _computeSimpleHash(bytes);
    final record = TextRecord(
      name: name,
      hash: hash,
      format: p.extension(filePath).replaceAll('.', ''),
      createdAt: file.statSync().changed,
      size: bytes.length,
      textLength: content.length,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TextPreviewEditPage(
          file: record,
          initialContent: content,
        ),
      ),
    );
  } catch (e) {
    debugPrint('Failed to open text file: $e');
    _openWithOsDefault(filePath);
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
