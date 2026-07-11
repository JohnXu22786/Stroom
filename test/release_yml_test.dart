import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tests for release.yml macOS x64 runner fix.
///
/// Verifies that:
/// - macos-13 is replaced with macos-15 for the macos-x64 job
/// - The build command includes --dart-define=EXCLUDED_ARCHS=arm64
void main() {
  group('release.yml macOS x64 runner', () {
    late String ymlContent;
    late List<String> lines;

    setUp(() {
      ymlContent = File('.github/workflows/release.yml').readAsStringSync();
      lines = ymlContent.split('\n');
    });

    test('macos-x64 job uses macos-15 runner (not macos-13)', () {
      // Find the macos-x64 job definition
      bool inMacosX64Job = false;
      String? runsOnLine;

      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trim() == 'macos-x64:') {
          inMacosX64Job = true;
          continue;
        }
        if (inMacosX64Job) {
          if (lines[i].trimLeft().startsWith('runs-on:')) {
            runsOnLine = lines[i].trim();
            break;
          }
          // If we hit another top-level key, we're out of the job
          if (lines[i].trim().isNotEmpty &&
              !lines[i].startsWith(' ') &&
              !lines[i].startsWith('    ')) {
            break;
          }
        }
      }

      expect(runsOnLine, isNotNull,
          reason: 'Could not find runs-on in macos-x64 job');
      expect(runsOnLine, contains('macos-15'),
          reason: 'macos-x64 job should use macos-15 runner');
      expect(runsOnLine, isNot(contains('macos-13')),
          reason: 'macos-x64 job should NOT use macos-13 runner');
    });

    test('macos-x64 build command includes EXCLUDED_ARCHS=arm64', () {
      bool inMacosX64Job = false;
      bool foundBuildCommand = false;
      bool hasExcludedArchs = false;

      for (int i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trim();
        if (trimmed == 'macos-x64:') {
          inMacosX64Job = true;
          continue;
        }
        if (inMacosX64Job) {
          // Check if this line contains the flutter build command
          if (trimmed.contains('flutter build macos') &&
              trimmed.contains('--release')) {
            foundBuildCommand = true;
            hasExcludedArchs =
                trimmed.contains('EXCLUDED_ARCHS=arm64');
          }
          // Stop at next top-level key
          if (trimmed.isNotEmpty &&
              !lines[i].startsWith(' ') &&
              !trimmed.startsWith('-') &&
              foundBuildCommand) {
            break;
          }
        }
      }

      expect(foundBuildCommand, isTrue,
          reason: 'macos-x64 job should have a flutter build command');
      expect(hasExcludedArchs, isTrue,
          reason:
              'macos-x64 build should include --dart-define=EXCLUDED_ARCHS=arm64');
    });

    test('macos-13 does not appear in release.yml', () {
      // Ensure no macos-13 references remain in the release workflow
      expect(ymlContent, isNot(contains('macos-13')),
          reason:
              'No macos-13 references should remain in release.yml');
    });

    test('macos-x64 job build command still has dart-define=APP_VERSION', () {
      // Find the macos-x64 job's build command and verify APP_VERSION is there
      bool inMacosX64Job = false;
      bool appVersionInBuildCommand = false;

      for (int i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trim();
        if (trimmed == 'macos-x64:') {
          inMacosX64Job = true;
          continue;
        }
        if (inMacosX64Job) {
          if (trimmed.contains('flutter build macos') &&
              trimmed.contains('--release')) {
            appVersionInBuildCommand = trimmed.contains('APP_VERSION');
            break;
          }
        }
      }

      expect(appVersionInBuildCommand, isTrue,
          reason:
              'macos-x64 build command should include --dart-define=APP_VERSION');
    });
  });
}
