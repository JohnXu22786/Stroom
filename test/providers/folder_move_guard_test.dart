import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/providers/image_provider.dart';
import 'package:stroom/providers/text_provider.dart';
import 'package:stroom/providers/tts_state_provider.dart';
import 'package:stroom/providers/video_provider.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/video_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
    FileManifest.invalidateCache();
    ImageManifest.invalidateCache();
    VideoManifest.invalidateCache();
  });

  group('folder move/copy self-target guard', () {
    test('text: moving a folder to its current parent is a no-op', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(textRecordsProvider.notifier);

      await notifier.createFolder('x');
      await notifier.createFolder('x/b');
      await notifier.addRecord(
        TextRecord(
          name: 'doc',
          hash: 'h1',
          format: 'txt',
          createdAt: DateTime.now(),
          size: 10,
          folder: 'x/b',
        ),
      );

      // 目标为当前父目录（无操作移动）—— 记录必须保持原位
      await notifier.moveFolder('x/b', 'x');

      final records = container.read(textRecordsProvider);
      expect(records.where((r) => r.folder == 'x/b').length, 1,
          reason: '无操作移动不得把记录移到根目录');
      final folders = await notifier.getFolders();
      expect(folders, contains('x/b'));
    });

    test('text: moving a root folder to root is a no-op', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(textRecordsProvider.notifier);

      await notifier.createFolder('x');
      await notifier.addRecord(
        TextRecord(
          name: 'doc',
          hash: 'h1',
          format: 'txt',
          createdAt: DateTime.now(),
          size: 10,
          folder: 'x',
        ),
      );

      await notifier.moveFolder('x', '');

      final records = container.read(textRecordsProvider);
      expect(records.where((r) => r.folder == 'x').length, 1);
    });

    test('text: copying a folder into itself creates no duplicates', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(textRecordsProvider.notifier);

      await notifier.createFolder('x');
      await notifier.createFolder('x/b');
      await notifier.addRecord(
        TextRecord(
          name: 'doc',
          hash: 'h1',
          format: 'txt',
          createdAt: DateTime.now(),
          size: 10,
          folder: 'x/b',
        ),
      );

      await notifier.copyFolder('x/b', 'x/b');

      final records = container.read(textRecordsProvider);
      expect(records.length, 1, reason: '复制到自身/子文件夹不得产生重复记录');
      expect(records.single.folder, 'x/b');
    });

    test('audio: moving a folder to its current parent is a no-op', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(audioRecordsProvider.notifier);

      await notifier.createFolder('x');
      await notifier.createFolder('x/b');
      await notifier.addRecord(
        AudioRecord(
          name: 'audio',
          hash: 'h1',
          format: 'wav',
          createdAt: DateTime.now(),
          size: 10,
          folder: 'x/b',
        ),
      );

      await notifier.moveFolder('x/b', 'x');

      final records = container.read(audioRecordsProvider);
      expect(records.where((r) => r.folder == 'x/b').length, 1);
    });

    test('image: moving a folder to its current parent is a no-op', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(imageRecordsProvider.notifier);

      await notifier.createFolder('x');
      await notifier.createFolder('x/b');
      await notifier.addRecord(
        ImageRecord(
          name: 'img',
          hash: 'h1',
          format: 'jpg',
          createdAt: DateTime.now(),
          size: 10,
          folder: 'x/b',
        ),
      );

      await notifier.moveFolder('x/b', 'x');

      final records = container.read(imageRecordsProvider);
      expect(records.where((r) => r.folder == 'x/b').length, 1);
    });

    test('text: renaming a folder to its current name is a no-op', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(textRecordsProvider.notifier);

      await notifier.createFolder('x/b');
      await notifier.addRecord(
        TextRecord(
          name: 'doc',
          hash: 'h1',
          format: 'txt',
          createdAt: DateTime.now(),
          size: 10,
          folder: 'x/b',
        ),
      );

      // 无操作重命名（对话框预填基础名后直接确认）
      await notifier.renameFolder('x/b', 'b');

      final records = container.read(textRecordsProvider);
      expect(records.where((r) => r.folder == 'x/b').length, 1,
          reason: '无操作重命名不得把记录移到根目录或删除');
      final folders = await notifier.getFolders();
      expect(folders, contains('x/b'));
    });

    test('audio: renaming a folder to its current name is a no-op', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(audioRecordsProvider.notifier);

      await notifier.createFolder('x/b');
      await notifier.addRecord(
        AudioRecord(
          name: 'audio',
          hash: 'h1',
          format: 'wav',
          createdAt: DateTime.now(),
          size: 10,
          folder: 'x/b',
        ),
      );

      await notifier.renameFolder('x/b', 'b');

      final records = container.read(audioRecordsProvider);
      expect(records.where((r) => r.folder == 'x/b').length, 1,
          reason: '无操作重命名不得删除记录');
    });

    test('image: renaming a folder to its current name is a no-op', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(imageRecordsProvider.notifier);

      await notifier.createFolder('x/b');
      await notifier.addRecord(
        ImageRecord(
          name: 'img',
          hash: 'h1',
          format: 'jpg',
          createdAt: DateTime.now(),
          size: 10,
          folder: 'x/b',
        ),
      );

      await notifier.renameFolder('x/b', 'b');

      final records = container.read(imageRecordsProvider);
      expect(records.where((r) => r.folder == 'x/b').length, 1);
    });

    test('video: renaming a folder to its current name is a no-op', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(videoRecordsProvider.notifier);

      await notifier.createFolder('x/b');
      await notifier.addRecord(
        VideoRecord(
          name: 'vid',
          hash: 'h1',
          format: 'mp4',
          createdAt: DateTime.now(),
          size: 10,
          folder: 'x/b',
        ),
      );

      await notifier.renameFolder('x/b', 'b');

      final records = container.read(videoRecordsProvider);
      expect(records.where((r) => r.folder == 'x/b').length, 1);
    });
  });
}
