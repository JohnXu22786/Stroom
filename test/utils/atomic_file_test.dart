import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/atomic_file.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('atomic_file_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AtomicFile', () {
    test('writeString creates the file with full content', () async {
      final file = File('${tempDir.path}/tasks.json');
      await AtomicFile.writeString(file, '{"a":1}');
      expect(await file.readAsString(), '{"a":1}');
    });

    test('overwrites existing content atomically', () async {
      final file = File('${tempDir.path}/tasks.json');
      await AtomicFile.writeString(file, 'old-content');
      await AtomicFile.writeString(file, 'new-content');
      expect(await file.readAsString(), 'new-content');
    });

    test('leaves no .tmp file behind after success', () async {
      final file = File('${tempDir.path}/tasks.json');
      await AtomicFile.writeString(file, 'data');
      final leftovers =
          tempDir.listSync().where((e) => e.path.endsWith('.tmp')).toList();
      expect(leftovers, isEmpty);
    });

    test('writeBytes writes exact bytes', () async {
      final file = File('${tempDir.path}/data.bin');
      await AtomicFile.writeBytes(file, [1, 2, 3, 255]);
      expect(await file.readAsBytes(), [1, 2, 3, 255]);
    });

    test('fails silently when target directory does not exist', () async {
      final file = File('${tempDir.path}/missing_dir/tasks.json');
      // 不应抛异常（调用方通常只记日志；目标文件保持不存在）。
      await AtomicFile.writeString(file, 'data');
      expect(await file.exists(), isFalse);
    });

    test(
        'throws when even the fallback direct write fails (rare double '
        'fault)', () async {
      final file = File('${tempDir.path}/tasks.json');
      // 目标路径是目录：rename 与直接写都无法成功 → 异常传播给调用方，
      // 且不残留 .tmp 文件。
      await Directory('${tempDir.path}/tasks.json').create();
      await expectLater(
        AtomicFile.writeString(file, 'data'),
        throwsA(isA<FileSystemException>()),
      );
      final leftovers =
          tempDir.listSync().where((e) => e.path.endsWith('.tmp')).toList();
      expect(leftovers, isEmpty);
      await Directory('${tempDir.path}/tasks.json').delete();
    });
  });
}
