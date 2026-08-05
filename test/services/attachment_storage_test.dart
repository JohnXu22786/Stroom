import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stroom/services/attachment_storage.dart';

/// 测试用 PathProvider：把"应用文档目录"指向临时目录，让
/// AttachmentStorage 的磁盘读写落到真实临时文件上（无需平台通道）。
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final String root;

  @override
  Future<String> getApplicationDocumentsPath() async => root;

  @override
  Future<String> getTemporaryPath() async => root;
}

void main() {
  late Directory tmpRoot;

  setUp(() {
    tmpRoot = Directory.systemTemp.createTempSync('stroom_att_storage_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tmpRoot.path);
  });

  tearDown(() {
    try {
      tmpRoot.deleteSync(recursive: true);
    } catch (_) {
      // 非关键清理
    }
  });

  group('AttachmentStorage 编辑后附件存储', () {
    test('saveEditedFile 返回 temp_edited/ 前缀路径，readFile 可读回（显示修复）', () async {
      // 回归：编辑后的图片之前被存到系统临时目录，但 storagePath 是
      // temp_edited/xxx —— AttachmentStorage.readFile 解析到附件目录，
      // 文件不存在 → 气泡显示“无法加载文件”。
      // 现在编辑后的文件与普通附件同目录存储，路径标记仍保留，
      // readFile/deleteFile 必须能通过 basename 正确解析。
      final edited = Uint8List.fromList(List.generate(1024, (i) => i % 251));

      final path = await AttachmentStorage.saveEditedFile('photo.jpg', edited);

      expect(path.startsWith('temp_edited/'), isTrue,
          reason: '编辑后附件必须保留 temp_edited/ 标记供清理逻辑识别');
      final onDisk =
          File(p.join(tmpRoot.path, 'attachments', p.basename(path)));
      expect(await onDisk.exists(), isTrue, reason: '文件必须落在附件存储目录（而非系统临时目录）');

      final readBack = await AttachmentStorage.readFile(path);
      expect(readBack, isNotNull);
      expect(readBack, edited);
    });

    test('saveEditedFile 路径与普通附件同目录（可被统一 readFile/deleteFile 处理）', () async {
      final normal = await AttachmentStorage.saveFile(
          'a.png', Uint8List.fromList([1, 2, 3]));
      final edited = await AttachmentStorage.saveEditedFile(
          'a.png', Uint8List.fromList([4, 5, 6]));

      expect(p.dirname(normal), 'attachments');
      expect(p.dirname(edited), 'temp_edited');
      // 两者都通过 basename 解析到附件目录
      final normalFile =
          File(p.join(tmpRoot.path, 'attachments', p.basename(normal)));
      final editedFile =
          File(p.join(tmpRoot.path, 'attachments', p.basename(edited)));
      expect(await normalFile.exists(), isTrue);
      expect(await editedFile.exists(), isTrue);
    });

    test('deleteFile 删除编辑后附件（消息删除时的清理路径）', () async {
      final path = await AttachmentStorage.saveEditedFile(
          'photo.png', Uint8List.fromList([9, 9, 9]));

      expect(await AttachmentStorage.readFile(path), isNotNull);

      final deleted = await AttachmentStorage.deleteFile(path);

      expect(deleted, isTrue);
      expect(await AttachmentStorage.readFile(path), isNull);
    });

    test('readFile 对不存在的 temp_edited 路径返回 null', () async {
      final result = await AttachmentStorage.readFile('temp_edited/ghost.png');
      expect(result, isNull);
    });
  });
}
