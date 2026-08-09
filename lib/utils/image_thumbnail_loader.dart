import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import 'byte_lru_cache.dart';
import 'image_manifest.dart';

// ====================================================================
// ImageThumbnailLoader — 缩略图字节加载器（内存 LRU 缓存 + 并发去重）
// ====================================================================
//
// 性能背景：相册网格的每个单元格都通过 FutureBuilder 异步读取缩略图。
// 旧的实现每次构建都直接读盘；缩略图文件缺失（老版本导入、编辑后保存的
// 新图）时还会回退读取整张原图并按全分辨率解码 —— 一屏 20+ 个单元同时
// 发起就是磁盘 I/O 风暴 + 主线程解码卡顿，这就是"图片加载缓慢"的根源。
//
// 本加载器统一三个职责：
// 1. 内存 LRU 缓存（[ByteLruCache]，字节+条目双上限）：同一张缩略图
//    一次会话内只读一次磁盘，滚动/重建/切文件夹后立即命中；
// 2. 并发去重：同一 hash 的并发请求共享同一个 Future，避免重复读盘
//    与重复生成（网格首次构建时一屏单元几乎同时请求）；
// 3. 按需生成并持久化：缩略图缺失时读取原图、生成 256px PNG 缩略图、
//    写回磁盘（与导入时的行为一致），下次直接命中，网格不再回退原图。
//
// 生成失败（无法解码的格式/损坏文件）返回 null 并记入有界负缓存，
// 调用方显示格式图标 —— 绝不把原图字节当作缩略图缓存（多 MB 原图进
// LRU 会挤爆内存），也不在每次网格重建时重复读原图重试解码。
// ====================================================================

class ImageThumbnailLoader {
  ImageThumbnailLoader._();

  /// 内存缓存上限：缩略图 ≤256px PNG，单条通常 <100KB，
  /// 16MB / 200 条双上限足够覆盖常见相册规模。
  static const int _maxCacheBytes = 16 * 1024 * 1024;
  static const int _maxCacheEntries = 200;

  /// 负缓存上限：无法解码的 hash 至多记 200 条（内容寻址，失败可确定）。
  static const int _maxFailedEntries = 200;

  /// hash → 缩略图字节（LRU：访问时移到末尾，超限淘汰最旧的）。
  static final ByteLruCache _cache =
      ByteLruCache(maxBytes: _maxCacheBytes, maxEntries: _maxCacheEntries);

  /// hash → 进行中的加载 Future（并发去重）。
  static final Map<String, Future<Uint8List?>> _inflight = {};

  /// 生成失败过的 hash（有界负缓存：避免每次网格重建都重读原图重试）。
  static final LinkedHashSet<String> _failed = LinkedHashSet();

  /// 执行过的缩略图生成尝试次数（测试探针：断言并发去重只尝试一次、
  /// 负缓存阻止重复尝试）。
  @visibleForTesting
  static int generationCount = 0;

  /// 同步返回内存缓存中的缩略图字节；未加载过返回 null（不触发磁盘读）。
  /// 用于加载占位图等"有缓存立即显示、无缓存异步加载"的场景。
  static Uint8List? peek(ImageRecord record) => _cache.peek(record.hash);

  /// 加载 [record] 的缩略图字节：
  /// 内存缓存 → 磁盘 `_thumb.png` → 缺失时读原图生成并持久化。
  ///
  /// 失败/无法生成返回 null。同一 hash 的并发调用共享同一个 Future。
  static Future<Uint8List?> loadThumbnail(ImageRecord record) async {
    final cached = _cache.get(record.hash);
    if (cached != null) return cached;

    // 本会话内已确认无法生成（内容寻址，同一 hash 必然同样失败）
    if (_failed.contains(record.hash)) return null;

    final inflight = _inflight[record.hash];
    if (inflight != null) return inflight;

    final future = _loadThumbnailInner(record);
    _inflight[record.hash] = future;
    try {
      return await future;
    } finally {
      // 身份守卫：加载期间 invalidate() 后同 hash 可能注册了新的
      // Future，不能把它一并移除
      if (_inflight[record.hash] == future) {
        _inflight.remove(record.hash);
      }
    }
  }

  static Future<Uint8List?> _loadThumbnailInner(ImageRecord record) async {
    // 1) 磁盘上已有缩略图 → 读回并缓存
    Uint8List? existing;
    try {
      existing = await ImageManifest.readFile('${record.hash}_thumb.png');
    } catch (e) {
      debugPrint('ImageThumbnailLoader read thumb failed: $e');
    }
    if (existing != null && existing.isNotEmpty) {
      _cache.put(record.hash, existing);
      return existing;
    }

    // 2) 缺失 → 读原图生成并持久化（尽力而为，失败不影响显示路径）
    Uint8List? full;
    try {
      full = await ImageManifest.readFile(record.storagePath);
    } catch (e) {
      debugPrint('ImageThumbnailLoader read full failed: $e');
    }
    if (full == null || full.isEmpty) return null;

    final thumb = await generateThumbnail(full);
    if (thumb == null || thumb.isEmpty) {
      _addFailed(record.hash);
      return null;
    }

    // 加载期间 invalidate() 被调用（记录已删除）：
    // 不再持久化/缓存，避免已删除记录写回孤儿缩略图文件
    if (!_inflight.containsKey(record.hash)) return null;

    try {
      await ImageManifest.writeFile('${record.hash}_thumb.png', thumb);
    } catch (e) {
      // 持久化失败仅影响下次加载的缓存命中，不阻塞本次显示
      debugPrint('ImageThumbnailLoader persist thumb failed: $e');
    }
    _cache.put(record.hash, thumb);
    return thumb;
  }

  /// 生成缩略图（最大 [maxDimension]px，保持宽高比）。
  ///
  /// 与旧实现的关键差异：解码失败返回 null（旧的回退原图会让网格
  /// 以全分辨率渲染多 MB 原图）。引擎解码在后台线程执行，不阻塞 UI。
  static Future<Uint8List?> generateThumbnail(
    Uint8List imageData, {
    int maxDimension = 256,
  }) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      generationCount++;
      codec = await ui.instantiateImageCodec(
        imageData,
        targetWidth: maxDimension,
        targetHeight: maxDimension,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      return null;
    } finally {
      // Codec 持有原生编码缓冲，Image 持有解码后的原生内存：
      // 两条路径都必须释放，否则网格批量生成时内存持续累积
      image?.dispose();
      codec?.dispose();
    }
  }

  static void _addFailed(String hash) {
    _failed.add(hash);
    if (_failed.length > _maxFailedEntries) {
      _failed.remove(_failed.first);
    }
  }

  /// 丢弃某个 hash 的内存缓存与负缓存（记录被删除后调用，
  /// 防止陈旧字节驻留；进行中的加载也一并作废，避免写回孤儿文件）。
  static void invalidate(String hash) {
    _cache.remove(hash);
    _failed.remove(hash);
    _inflight.remove(hash);
  }

  /// 清空全部内存状态（测试用）。
  static void clear() {
    _cache.clear();
    _inflight.clear();
    _failed.clear();
  }
}
