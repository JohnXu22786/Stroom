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

  group('AttachmentStorage 图片压缩缓存', () {
    test('saveCompressedImage/readCompressedImage 往返（JPEG 与 PNG 扩展名）',
        () async {
      final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
      final pngBytes =
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      await AttachmentStorage.saveCompressedImage(
        conversationId: 'conv-1',
        hash: 'hash-jpeg',
        bytes: jpegBytes,
        mimeType: 'image/jpeg',
      );
      await AttachmentStorage.saveCompressedImage(
        conversationId: 'conv-1',
        hash: 'hash-png',
        bytes: pngBytes,
        mimeType: 'image/png',
      );

      // 物理布局：<附件目录>/temp_compressed/<convId>/<hash>.<ext>
      final jpegFile = File(p.join(tmpRoot.path, 'attachments',
          'temp_compressed', 'conv-1', 'hash-jpeg.jpg'));
      final pngFile = File(p.join(tmpRoot.path, 'attachments',
          'temp_compressed', 'conv-1', 'hash-png.png'));
      expect(await jpegFile.exists(), isTrue, reason: 'JPEG 缓存按 .jpg 落盘');
      expect(await pngFile.exists(), isTrue, reason: 'PNG 缓存按 .png 落盘');

      final jpegBack = await AttachmentStorage.readCompressedImage(
          conversationId: 'conv-1', hash: 'hash-jpeg');
      expect(jpegBack, isNotNull);
      expect(jpegBack!.bytes, jpegBytes);
      expect(jpegBack.mimeType, 'image/jpeg');

      final pngBack = await AttachmentStorage.readCompressedImage(
          conversationId: 'conv-1', hash: 'hash-png');
      expect(pngBack, isNotNull);
      expect(pngBack!.bytes, pngBytes);
      expect(pngBack.mimeType, 'image/png');
    });

    test('读取不存在的缓存 / 魔数与扩展名不符的损坏缓存返回 null', () async {
      final missing = await AttachmentStorage.readCompressedImage(
          conversationId: 'conv-1', hash: 'ghost');
      expect(missing, isNull);

      // 扩展名 .jpg 但内容不是 JPEG 魔数 → 视为损坏跳过
      await AttachmentStorage.saveCompressedImage(
        conversationId: 'conv-1',
        hash: 'corrupt',
        bytes: Uint8List.fromList([0x89, 0x50, 1, 2, 3]),
        mimeType: 'image/jpeg',
      );
      final corrupt = await AttachmentStorage.readCompressedImage(
          conversationId: 'conv-1', hash: 'corrupt');
      expect(corrupt, isNull, reason: '魔数与扩展名不一致的缓存必须视为未命中');
    });

    test('deleteCompressedImage 清理两种扩展名', () async {
      await AttachmentStorage.saveCompressedImage(
        conversationId: 'conv-1',
        hash: 'both',
        bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        mimeType: 'image/jpeg',
      );
      // 完整 8 字节 PNG 魔数：确保 .png 变体是"有效缓存"而非损坏文件，
      // 否则删除前/后的读取都会因魔数校验失败而返回 null，
      // .png 删除分支的回归将无法被测试捕获。
      await AttachmentStorage.saveCompressedImage(
        conversationId: 'conv-1',
        hash: 'both',
        bytes: Uint8List.fromList(
            [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01]),
        mimeType: 'image/png',
      );

      // 删除前两个变体都真实可读（证明都是有效缓存）
      expect(
          await AttachmentStorage.readCompressedImage(
              conversationId: 'conv-1', hash: 'both'),
          isNotNull);

      final deleted = await AttachmentStorage.deleteCompressedImage(
          conversationId: 'conv-1', hash: 'both');

      expect(deleted, isTrue);
      expect(
          await AttachmentStorage.readCompressedImage(
              conversationId: 'conv-1', hash: 'both'),
          isNull,
          reason: '同一 hash 的 .jpg 与 .png 缓存都应被删除');
    });

    test('deleteConversationCompressedImages 只清理指定对话的缓存目录', () async {
      await AttachmentStorage.saveCompressedImage(
        conversationId: 'conv-a',
        hash: 'h1',
        bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]),
        mimeType: 'image/jpeg',
      );
      await AttachmentStorage.saveCompressedImage(
        conversationId: 'conv-b',
        hash: 'h1',
        bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]),
        mimeType: 'image/jpeg',
      );

      await AttachmentStorage.deleteConversationCompressedImages('conv-a');

      expect(
          await AttachmentStorage.readCompressedImage(
              conversationId: 'conv-a', hash: 'h1'),
          isNull,
          reason: '被删除对话的缓存必须清空');
      expect(
          await AttachmentStorage.readCompressedImage(
              conversationId: 'conv-b', hash: 'h1'),
          isNotNull,
          reason: '其他对话的缓存不受影响（缓存按对话隔离）');
      final convADir = Directory(
          p.join(tmpRoot.path, 'attachments', 'temp_compressed', 'conv-a'));
      expect(await convADir.exists(), isFalse, reason: '对话目录整体删除');
    });

    test('conversationId / hash 缺失时保存与删除均为 no-op', () async {
      final path = await AttachmentStorage.saveCompressedImage(
        conversationId: null,
        hash: 'h',
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/jpeg',
      );
      expect(path, isNull);
      expect(
          await AttachmentStorage.readCompressedImage(
              conversationId: null, hash: 'h'),
          isNull);
      expect(
          await AttachmentStorage.deleteCompressedImage(
              conversationId: null, hash: 'h'),
          isFalse);
    });
  });
}
