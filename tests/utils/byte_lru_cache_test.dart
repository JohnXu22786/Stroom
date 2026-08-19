import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/byte_lru_cache.dart';

Uint8List _bytes(int n) => Uint8List.fromList(List<int>.filled(n, n));

void main() {
  group('ByteLruCache', () {
    test('get returns value and refreshes LRU order', () {
      final cache = ByteLruCache(maxBytes: 1000, maxEntries: 3);
      cache.put('a', _bytes(10));
      cache.put('b', _bytes(10));
      cache.put('c', _bytes(10));

      // 访问 a → 顺序变为 b, c, a
      expect(cache.get('a'), isNotNull);

      // 插入 d 超出条目上限 → 淘汰最旧的 b
      cache.put('d', _bytes(10));
      expect(cache.get('a'), isNotNull, reason: 'a 刚被访问，应保留');
      expect(cache.get('b'), isNull, reason: 'b 最久未用，应被淘汰');
      expect(cache.get('c'), isNotNull);
      expect(cache.get('d'), isNotNull);
    });

    test('put with existing key replaces without double-counting bytes', () {
      final cache = ByteLruCache(maxBytes: 100);
      cache.put('k', _bytes(60));
      cache.put('k', _bytes(40));
      expect(cache.totalBytes, 40);
      expect(cache.length, 1);

      // 再放入 60 → 总 100 未超限；再放 10 → 超限，淘汰最旧的 k
      cache.put('m', _bytes(60));
      expect(cache.totalBytes, 100);
      cache.put('n', _bytes(10));
      expect(cache.totalBytes, 70);
      expect(cache.get('k'), isNull);
      expect(cache.get('m'), isNotNull);
      expect(cache.get('n'), isNotNull);
    });

    test('evicts oldest entries until total bytes fit under the cap', () {
      final cache = ByteLruCache(maxBytes: 100);
      cache.put('a', _bytes(40));
      cache.put('b', _bytes(40));
      expect(cache.totalBytes, 80);
      cache.put('c', _bytes(40)); // 120 > 100 → 淘汰 a
      expect(cache.length, 2);
      expect(cache.totalBytes, 80);
      expect(cache.get('a'), isNull);
      expect(cache.get('b'), isNotNull);
      expect(cache.get('c'), isNotNull);
    });

    test('keeps the most recent entry even when it exceeds the byte cap', () {
      final cache = ByteLruCache(maxBytes: 50);
      cache.put('huge', _bytes(200));
      expect(cache.length, 1);
      expect(cache.get('huge'), isNotNull, reason: '单张超大条目不能被自己挤出');
    });

    test('remove decrements byte accounting', () {
      final cache = ByteLruCache(maxBytes: 1000);
      cache.put('a', _bytes(30));
      cache.put('b', _bytes(30));
      cache.remove('a');
      expect(cache.totalBytes, 30);
      expect(cache.length, 1);
      cache.remove('missing');
      expect(cache.totalBytes, 30);
    });

    test('peek returns value without refreshing LRU order', () {
      final cache = ByteLruCache(maxBytes: 1000, maxEntries: 2);
      cache.put('a', _bytes(10));
      cache.put('b', _bytes(10));
      expect(cache.peek('a'), isNotNull);
      cache.put('c', _bytes(10)); // 淘汰最旧的 a
      expect(cache.peek('a'), isNull);
      expect(cache.peek('b'), isNotNull);
    });

    test('clear resets everything', () {
      final cache = ByteLruCache(maxBytes: 100);
      cache.put('a', _bytes(10));
      cache.put('b', _bytes(10));
      cache.clear();
      expect(cache.length, 0);
      expect(cache.totalBytes, 0);
      expect(cache.get('a'), isNull);
    });
  });
}
