import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:archive/archive.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() {
  group('BackupService - archive format', () {
    Uint8List _buildMinimalBackup() {
      final archive = Archive();
      archive.addFile(ArchiveFile(
          'manifest.json', '{"version":1,"appVersion":"1.0.0"}'.length,
          utf8.encode('{"version":1,"appVersion":"1.0.0"}')));
      archive.addFile(ArchiveFile(
          'synthesis/tasks.json', '[]'.length, utf8.encode('[]')));
      archive.addFile(ArchiveFile(
          'catcatch/tasks.json', '[]'.length, utf8.encode('[]')));
      return Uint8List.fromList(ZipEncoder().encode(archive)!);
    }

    test('backup zip can be decoded and entries read', () {
      final bytes = _buildMinimalBackup();
      final decoded = ZipDecoder().decodeBytes(bytes);
      final fileMap = <String, Uint8List>{};
      for (final f in decoded) {
        if (f.isFile) {
          fileMap[f.name] = Uint8List.fromList(f.content as List<int>);
        }
      }
      expect(fileMap.containsKey('manifest.json'), isTrue);
      expect(fileMap.containsKey('synthesis/tasks.json'), isTrue);
      expect(fileMap.containsKey('catcatch/tasks.json'), isTrue);
      final manifest = jsonDecode(utf8.decode(fileMap['manifest.json']!));
      expect((manifest as Map)['version'], 1);
    });

    test('task files use forward slash paths in archive', () {
      final bytes = _buildMinimalBackup();
      final decoded = ZipDecoder().decodeBytes(bytes);
      final names = decoded.where((f) => f.isFile).map((f) => f.name).toList();
      for (final name in names) {
        expect(name.contains('\\'), isFalse,
            reason: 'Archive entry $name contains backslash');
      }
    });

    test('known directories are correctly identified from paths', () {
      const knownDirs = ['pictures', 'tts_audio', 'videos', 'attachments',
                         'synthesis', 'catcatch'];
      final testCases = {
        'pictures/abc123.jpg': 'pictures',
        'synthesis/tasks.json': 'synthesis',
        'catcatch/tasks.json': 'catcatch',
        'videos/xyz.mp4': 'videos',
        'unknown/file.txt': null,
      };
      for (final entry in testCases.entries) {
        String? matchedDir;
        for (final dir in knownDirs) {
          if (entry.key.startsWith('$dir/')) {
            matchedDir = dir;
            break;
          }
        }
        expect(matchedDir, entry.value,
            reason: 'Failed to match ${entry.key}');
      }
    });

    test('legacy paths are remapped correctly', () {
      final legacyMap = {
        'files/pictures/img.jpg': 'pictures/img.jpg',
        'tasks/synthesis_tasks.json': 'synthesis/tasks.json',
        'tasks/catcatch_tasks.json': 'catcatch/tasks.json',
        'database/manifest_data.json': 'database/manifest_data.json',
      };
      const skipFiles = {'manifest.json', 'stroom_manifest.json',
          'database/manifest_data.json', 'preferences.json'};

      for (final entry in legacyMap.entries) {
        var key = entry.key;
        if (skipFiles.contains(key)) continue;
        if (key.startsWith('files/')) {
          key = key.substring('files/'.length);
        }
        if (key.startsWith('tasks/')) {
          key = key.substring('tasks/'.length);
          if (key == 'synthesis_tasks.json') key = 'synthesis/tasks.json';
          if (key == 'catcatch_tasks.json') key = 'catcatch/tasks.json';
        }
        expect(key, entry.value, reason: 'Legacy path ${entry.key} failed');
      }
    });
  });
}
