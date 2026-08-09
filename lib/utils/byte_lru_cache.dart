import 'dart:collection';
import 'dart:typed_data';

// ====================================================================
// ByteLruCache — 按字节数（可选条目数）设上限的 LRU 字节缓存
// ====================================================================
//
// 缩略图加载器（小字节、条目多）与相册全屏预览器（大字节、条目少）
// 都依赖同一套"有界 LRU + 字节记账"逻辑：命中时刷新顺序，插入超限时
// 淘汰最旧条目，并且总是保留最近一条（单张超大图不会被自身挤出）。
// 抽出为独立类统一实现并单测，避免两处各写一份难以验证的记账代码。
// ====================================================================

class ByteLruCache {
  ByteLruCache({required this.maxBytes, this.maxEntries});

  /// 总字节数上限。插入后超出时从最旧条目开始淘汰。
  final int maxBytes;

  /// 条目数上限（null 表示不限制）。
  final int? maxEntries;

  final LinkedHashMap<String, Uint8List> _map = LinkedHashMap();
  int _totalBytes = 0;

  /// 当前条目数。
  int get length => _map.length;

  /// 当前缓存的总字节数。
  int get totalBytes => _totalBytes;

  /// 命中并刷新 LRU 顺序（移到最新）；未命中返回 null。
  Uint8List? get(String key) {
    final value = _map.remove(key);
    if (value == null) return null;
    _map[key] = value;
    return value;
  }

  /// 查看但不刷新 LRU 顺序；未命中返回 null。
  Uint8List? peek(String key) => _map[key];

  /// 写入条目（同 key 覆盖），超限时淘汰最旧条目。
  void put(String key, Uint8List bytes) {
    remove(key);
    _map[key] = bytes;
    _totalBytes += bytes.length;
    _evict();
  }

  /// 移除条目并修正字节记账。
  void remove(String key) {
    final old = _map.remove(key);
    if (old != null) _totalBytes -= old.length;
  }

  void clear() {
    _map.clear();
    _totalBytes = 0;
  }

  void _evict() {
    // 字段无法类型提升，先取到局部变量
    final maxEntries = this.maxEntries;
    // 保留至少 1 条：单张超过上限的大图不会被自己挤出
    while (_map.length > 1 &&
        (_totalBytes > maxBytes ||
            (maxEntries != null && _map.length > maxEntries))) {
      final evicted = _map.remove(_map.keys.first);
      _totalBytes -= evicted!.length;
    }
  }
}
