import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/image_thumbnail_loader.dart';

/// Creates a small valid PNG (8x8 green) via the real engine.
///
/// Must be called from `tester.runAsync` — engine image work never
/// completes inside the widget-test FakeAsync zone.
Future<Uint8List> _createEnginePng() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, 8, 8),
    ui.Paint()..color = const ui.Color(0xFF00FF00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

ImageRecord _makeRecord({String id = 'id', String hash = 'hash'}) {
  return ImageRecord(
    id: id,
    name: 'test',
    hash: hash,
    format: 'png',
    createdAt: DateTime(2024, 1, 1),
    size: 100,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode(); // 同时启用 WebFileStore 内存模式
    ImageManifest.invalidateCache();
    ImageThumbnailLoader.clear();
    ImageThumbnailLoader.generationCount = 0;
  });

  group('ImageThumbnailLoader', () {
    testWidgets(
        'returns persisted thumbnail bytes and serves them from '
        'memory cache on later calls (no repeated disk reads)', (tester) async {
      final record = _makeRecord(hash: 'cache_hit');
      final thumb = Uint8List.fromList([1, 2, 3, 4]);
      await tester.runAsync(() async {
        await ImageManifest.writeFile('${record.hash}_thumb.png', thumb);
      });

      final first = await ImageThumbnailLoader.loadThumbnail(record);
      expect(first, equals(thumb));

      // 删掉磁盘文件后再次调用仍能命中 → 证明第二次调用没有重新读盘，
      // 防止网格滚动/重建时反复读盘造成的卡顿
      await tester.runAsync(() async {
        await ImageManifest.deleteFile('${record.hash}_thumb.png');
      });
      final second = await ImageThumbnailLoader.loadThumbnail(record);
      expect(second, equals(thumb));
    });

    testWidgets(
        'generates and persists a thumbnail when the thumb file is '
        'missing (full-image fallback regression)', (tester) async {
      final record = _makeRecord(hash: 'gen_me');
      final png = await tester.runAsync(_createEnginePng);
      await tester.runAsync(() async {
        await ImageManifest.writeFile(record.storagePath, png!);
      });

      final result = await tester.runAsync(
        () => ImageThumbnailLoader.loadThumbnail(record),
      );

      expect(result, isNotNull);
      expect(result!.isNotEmpty, isTrue);
      expect(result, isNot(equals(png)),
          reason: 'thumb must be a re-encoded small PNG, not the original');
      // PNG 魔数
      expect(result.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      // 已持久化到磁盘：删除内存缓存后仍可从磁盘读到
      ImageThumbnailLoader.invalidate(record.hash);
      await tester.runAsync(() async {
        final fromDisk =
            await ImageManifest.readFile('${record.hash}_thumb.png');
        expect(fromDisk, equals(result));
      });
    });

    testWidgets(
        'concurrent calls for the same hash share a single '
        'generation (no duplicate decode/write)', (tester) async {
      final record = _makeRecord(hash: 'dedup');
      final png = await tester.runAsync(_createEnginePng);
      await tester.runAsync(() async {
        await ImageManifest.writeFile(record.storagePath, png!);
      });

      final results = await tester.runAsync(() async {
        return Future.wait([
          ImageThumbnailLoader.loadThumbnail(record),
          ImageThumbnailLoader.loadThumbnail(record),
          ImageThumbnailLoader.loadThumbnail(record),
          ImageThumbnailLoader.loadThumbnail(record),
          ImageThumbnailLoader.loadThumbnail(record),
        ]);
      });

      expect(results, isNotNull);
      final list = results!;
      expect(list.every((r) => r != null && r.isNotEmpty), isTrue);
      for (var i = 1; i < list.length; i++) {
        expect(list[i], equals(list[0]));
      }
      expect(ImageThumbnailLoader.generationCount, 1,
          reason: 'five concurrent calls must trigger exactly one generation');
    });

    testWidgets('returns null when both thumb and full image are missing',
        (tester) async {
      final record = _makeRecord(hash: 'missing');
      final result = await ImageThumbnailLoader.loadThumbnail(record);
      expect(result, isNull);
    });

    testWidgets(
        'invalidate(hash) drops the memory cache entry so the next '
        'call re-reads from disk', (tester) async {
      final record = _makeRecord(hash: 'invalidate');
      final thumb = Uint8List.fromList([9, 8, 7]);
      await tester.runAsync(() async {
        await ImageManifest.writeFile('${record.hash}_thumb.png', thumb);
      });

      expect(await ImageThumbnailLoader.loadThumbnail(record), equals(thumb));

      ImageThumbnailLoader.invalidate(record.hash);
      await tester.runAsync(() async {
        await ImageManifest.deleteFile('${record.hash}_thumb.png');
      });

      expect(await ImageThumbnailLoader.loadThumbnail(record), isNull,
          reason: 'after invalidate the stale memory entry must not be used');
    });

    testWidgets(
        'generateThumbnail returns null for undecodable bytes instead '
        'of falling back to the original (avoids caching full images)',
        (tester) async {
      final result = await tester.runAsync(
        () => ImageThumbnailLoader.generateThumbnail(
          Uint8List.fromList(List<int>.generate(64, (i) => 0x42)),
        ),
      );
      expect(result, isNull);
    });

    testWidgets('generateThumbnail decodes a real image to a bounded PNG',
        (tester) async {
      final png = await tester.runAsync(_createEnginePng);
      final result = await tester.runAsync(
        () => ImageThumbnailLoader.generateThumbnail(png!, maxDimension: 256),
      );
      expect(result, isNotNull);
      expect(result!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    testWidgets(
        'undecodable full image: returns null, writes no thumb file, '
        'and the negative cache prevents repeated full-image reads',
        (tester) async {
      final record = _makeRecord(hash: 'undecodable');
      final garbage = Uint8List.fromList(List<int>.generate(256, (i) => i));
      await tester.runAsync(() async {
        await ImageManifest.writeFile(record.storagePath, garbage);
      });

      final first = await tester.runAsync(
        () => ImageThumbnailLoader.loadThumbnail(record),
      );
      expect(first, isNull);
      // 原图字节绝不能进入缓存：若缓存了原图，下面的第二次调用会直接命中
      // 并返回非 null，而不是走负缓存返回 null
      // 也没有写出孤儿缩略图文件
      await tester.runAsync(() async {
        expect(
          await ImageManifest.readFile('${record.hash}_thumb.png'),
          isNull,
        );
      });

      // 第二次调用命中负缓存：不再读原图/重试解码
      final second = await tester.runAsync(
        () => ImageThumbnailLoader.loadThumbnail(record),
      );
      expect(second, isNull);
      expect(ImageThumbnailLoader.generationCount, 1, reason: '负缓存应阻止第二次解码尝试');

      // invalidate 清除负缓存后允许重试
      ImageThumbnailLoader.invalidate(record.hash);
      await tester.runAsync(
        () => ImageThumbnailLoader.loadThumbnail(record),
      );
      expect(ImageThumbnailLoader.generationCount, 2,
          reason: 'invalidate 后允许重试');
    });

    testWidgets(
        'clear() resets the in-memory cache so the next call re-reads disk',
        (tester) async {
      final record = _makeRecord(hash: 'clear_test');
      final thumb = Uint8List.fromList([1, 2, 3]);
      await tester.runAsync(() async {
        await ImageManifest.writeFile('${record.hash}_thumb.png', thumb);
      });

      await ImageThumbnailLoader.loadThumbnail(record);
      ImageThumbnailLoader.clear();

      // 删掉磁盘文件：若 clear() 没清空内存缓存，这里仍会命中并返回 thumb；
      // 返回 null 才证明内存状态已被重置、重新走了磁盘读
      await tester.runAsync(() async {
        await ImageManifest.deleteFile('${record.hash}_thumb.png');
      });
      expect(await ImageThumbnailLoader.loadThumbnail(record), isNull,
          reason: 'clear() 必须重置内存缓存（陈旧缓存会返回非 null）');

      // 恢复磁盘文件：clear() 后下一次调用应重新从磁盘读取
      await tester.runAsync(() async {
        await ImageManifest.writeFile('${record.hash}_thumb.png', thumb);
      });
      expect(await ImageThumbnailLoader.loadThumbnail(record), equals(thumb),
          reason: 'clear() 后重新从磁盘加载');
    });
  });
}
