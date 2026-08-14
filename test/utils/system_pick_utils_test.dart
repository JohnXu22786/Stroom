import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stroom/utils/system_pick_utils.dart';

void main() {
  group('SystemPickDirectories.folderName', () {
    test('桌面平台：文档/音乐/图片使用标准目录名', () {
      for (final platform in [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        expect(
          SystemPickDirectories.folderName(platform, SystemFolder.documents),
          'Documents',
        );
        expect(
          SystemPickDirectories.folderName(platform, SystemFolder.music),
          'Music',
        );
        expect(
          SystemPickDirectories.folderName(platform, SystemFolder.pictures),
          'Pictures',
        );
      }
    });

    test('视频目录：Windows/Linux 是 Videos，macOS 是 Movies', () {
      expect(
        SystemPickDirectories.folderName(
          TargetPlatform.windows,
          SystemFolder.videos,
        ),
        'Videos',
      );
      expect(
        SystemPickDirectories.folderName(
          TargetPlatform.linux,
          SystemFolder.videos,
        ),
        'Videos',
      );
      expect(
        SystemPickDirectories.folderName(
          TargetPlatform.macOS,
          SystemFolder.videos,
        ),
        'Movies',
      );
    });

    test('移动端不支持指定初始目录，一律返回 null', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        for (final folder in SystemFolder.values) {
          expect(
            SystemPickDirectories.folderName(platform, folder),
            isNull,
            reason: '$platform/$folder 应返回 null',
          );
        }
      }
    });
  });

  group('SystemPickDirectories.resolvePath', () {
    late Directory home;

    setUp(() {
      home = Directory.systemTemp.createTempSync('pick_dirs_test_');
    });

    tearDown(() {
      try {
        home.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('目标目录存在时返回它', () {
      final target = Directory(p.join(home.path, 'Pictures'))..createSync();
      expect(
        SystemPickDirectories.resolvePath(home.path, 'Pictures'),
        target.path,
      );
    });

    test('目标目录不存在时回退到主目录', () {
      expect(
        SystemPickDirectories.resolvePath(home.path, 'Music'),
        home.path,
      );
    });

    test('主目录也不存在时返回 null', () {
      final missingHome = p.join(home.path, 'missing');
      expect(
        SystemPickDirectories.resolvePath(missingHome, 'Documents'),
        isNull,
      );
    });

    test('空主目录或空目录名返回 null', () {
      expect(SystemPickDirectories.resolvePath('', 'Documents'), isNull);
      expect(SystemPickDirectories.resolvePath(home.path, ''), isNull);
    });
  });

  group('平台检测', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('Android 视为移动端', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(SystemPickDirectories.isMobile, isTrue);
      expect(SystemPickDirectories.isDesktop, isFalse);
    });

    test('Windows 视为桌面端', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(SystemPickDirectories.isDesktop, isTrue);
      expect(SystemPickDirectories.isMobile, isFalse);
    });
  });
}
