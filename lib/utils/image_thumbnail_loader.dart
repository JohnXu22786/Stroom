import 'dart:collection';
import 'dart:math' as math;
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
//
// 宽高比：缩略图生成按原图宽高比缩放（最大边 ≤ maxDimension），绝不做
// 强制拉伸 —— 早期实现同时传 targetWidth/targetHeight=256 会把全景图/
// 长截图压成正方形（缩略图变形）。持久化文件名带 v2 后缀：旧版变形的
// `_thumb.png` 不再被读取，下次加载自动按正确比例重新生成。
// ====================================================================

/// 图片缩略图的持久化文件名（按图片 hash 内容寻址）。
///
/// v2：缩略图生成保持原图宽高比。v1（`{hash}_thumb.png`）被强制缩放到
/// 256×256 导致变形，已废弃 —— 磁盘上残留的 v1 文件不会被读取，
/// 缺失的 v2 会在加载时按正确比例重新生成。
String imageThumbFileName(String hash) => '${hash}_thumb_v2.png';

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

  /// 加载 [record] 的缩略图字节：
  /// 内存缓存 → 磁盘 `_thumb_v2.png` → 缺失时读原图生成并持久化。
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
      existing = await ImageManifest.readFile(imageThumbFileName(record.hash));
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

    var persisted = false;
    try {
      await ImageManifest.writeFile(imageThumbFileName(record.hash), thumb);
      persisted = true;
    } catch (e) {
      // 持久化失败仅影响下次加载的缓存命中，不阻塞本次显示
      debugPrint('ImageThumbnailLoader persist thumb failed: $e');
    }
    // 旧版（变形）命名残留文件已无用途：仅当 v2 成功落盘后才清理，
    // 避免写入失败时把磁盘上仅剩的缩略图也一并删掉
    if (persisted) {
      await ImageManifest.deleteFile('${record.hash}_thumb.png');
    }
    _cache.put(record.hash, thumb);
    return thumb;
  }

  /// 生成缩略图（最大边 [maxDimension]px，保持宽高比，小图不放大）。
  ///
  /// 与旧实现的关键差异：解码失败返回 null（旧的回退原图会让网格
  /// 以全分辨率渲染多 MB 原图）。引擎解码在后台线程执行，不阻塞 UI。
  ///
  /// 宽高比：通过 [ui.instantiateImageCodecWithSize] 先取得原图固有尺寸，
  /// 按「最大边 ≤ maxDimension」算出目标尺寸后再解码（两端平台同一套
  /// 数学，Web 端也能精确控制尺寸）。绝不能直接传
  /// targetWidth=targetHeight=max，引擎会把图片强制缩放到精确尺寸 ——
  /// 全景图/长截图会被压成正方形（缩略图变形）。
  static Future<Uint8List?> generateThumbnail(
    Uint8List imageData, {
    int maxDimension = 256,
  }) async {
    ui.Codec? codec;
    ui.Image? image;
    ui.ImmutableBuffer? buffer;
    try {
      generationCount++;
      if (maxDimension <= 0) return null;
      buffer = await ui.ImmutableBuffer.fromUint8List(imageData);
      // 传入的 buffer 由 instantiateImageCodecWithSize 负责释放
      // （两端实现均在 finally 中 dispose），调用方不得重复释放。
      codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (int intrinsicWidth, int intrinsicHeight) {
          if (intrinsicWidth <= 0 || intrinsicHeight <= 0) {
            return ui.TargetImageSize();
          }
          // 最大边缩放到 maxDimension（小图保持原尺寸，不放大）。
          // 两个目标尺寸均按原图宽高比计算：比例一致时引擎不会变形。
          final scale = maxDimension /
              (intrinsicWidth > intrinsicHeight
                  ? intrinsicWidth
                  : intrinsicHeight);
          if (scale >= 1) {
            return ui.TargetImageSize(
              width: intrinsicWidth,
              height: intrinsicHeight,
            );
          }
          return ui.TargetImageSize(
            width: math.max(1, (intrinsicWidth * scale).round()),
            height: math.max(1, (intrinsicHeight * scale).round()),
          );
        },
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
      // Codec 持有解码缓冲，Image 持有解码后的原生内存：
      // 两条路径都必须释放，否则网格批量生成时内存持续累积。
      image?.dispose();
      codec?.dispose();
      // buffer 由 instantiateImageCodecWithSize 释放，这里不能再调
      // dispose()（调试模式下会触发 assert）。极端情况（原始字节无法
      // 解码、原生端 descriptor 创建失败）下可能泄漏一个缓冲区，
      // 由负缓存兜底：同一 hash 每会话至多一次。
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
