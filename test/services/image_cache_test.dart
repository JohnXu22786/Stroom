import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/image_cache.dart';

void main() {
  group('ImageBytesCache', () {
    setUp(() {
      ImageBytesCache.clear();
    });

    test('put and get stores and retrieves bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      ImageBytesCache.put('key1', bytes);
      final result = ImageBytesCache.get('key1');
      expect(result, equals(bytes));
    });

    test('get returns null for missing key', () {
      final result = ImageBytesCache.get('nonexistent');
      expect(result, isNull);
    });

    test('remove deletes a cached entry', () {
      final bytes = Uint8List.fromList([4, 5, 6]);
      ImageBytesCache.put('key1', bytes);
      ImageBytesCache.remove('key1');
      expect(ImageBytesCache.get('key1'), isNull);
    });

    test('clear removes all entries', () {
      ImageBytesCache.put('key1', Uint8List.fromList([1]));
      ImageBytesCache.put('key2', Uint8List.fromList([2]));
      ImageBytesCache.clear();
      expect(ImageBytesCache.get('key1'), isNull);
      expect(ImageBytesCache.get('key2'), isNull);
    });

    test('LRU eviction evicts oldest entry when max entries exceeded', () {
      // Fill cache to max
      for (int i = 0; i < ImageBytesCache.maxEntries; i++) {
        ImageBytesCache.put('key$i', Uint8List.fromList([i]));
      }
      // All entries should be present
      for (int i = 0; i < ImageBytesCache.maxEntries; i++) {
        expect(ImageBytesCache.get('key$i'), isNotNull);
      }
      // Add one more entry
      ImageBytesCache.put('overflow', Uint8List.fromList([255]));
      // The first entry should be evicted
      expect(ImageBytesCache.get('key0'), isNull);
      // The new entry should be present
      expect(ImageBytesCache.get('overflow'), isNotNull);
    });

    test('size-based eviction removes entries when total exceeds max size', () {
      // Fill with entries that total just under max size
      final halfSize = ImageBytesCache.maxSizeBytes ~/ 2;
      final bytes1 = Uint8List(halfSize);
      final bytes2 = Uint8List(halfSize - 1);
      ImageBytesCache.put('key1', bytes1);
      ImageBytesCache.put('key2', bytes2);
      // Both should be present
      expect(ImageBytesCache.get('key1'), isNotNull);
      expect(ImageBytesCache.get('key2'), isNotNull);

      // Add a large entry that exceeds max size
      final largeBytes = Uint8List(ImageBytesCache.maxSizeBytes ~/ 2);
      ImageBytesCache.put('key3', largeBytes);
      // key1 should be evicted (oldest)
      expect(ImageBytesCache.get('key1'), isNull);
    });

    test('getOrFetch returns cached value on cache hit', () async {
      final bytes = Uint8List.fromList([10, 20, 30]);
      ImageBytesCache.put('key1', bytes);
      int fetchCallCount = 0;
      final result = await ImageBytesCache.getOrFetch('key1', () async {
        fetchCallCount++;
        return Uint8List.fromList([99, 99]);
      });
      expect(result, equals(bytes));
      expect(fetchCallCount, 0);
    });

    test('getOrFetch calls fetcher on cache miss and caches result', () async {
      int fetchCallCount = 0;
      final result = await ImageBytesCache.getOrFetch('newKey', () async {
        fetchCallCount++;
        return Uint8List.fromList([7, 8, 9]);
      });
      expect(result, equals(Uint8List.fromList([7, 8, 9])));
      expect(fetchCallCount, 1);
      // Second call should use cache
      final result2 = await ImageBytesCache.getOrFetch('newKey', () async {
        fetchCallCount++;
        return Uint8List.fromList([99, 99]);
      });
      expect(result2, equals(Uint8List.fromList([7, 8, 9])));
      expect(fetchCallCount, 1);
    });

    test('getOrFetch handles null from fetcher (not cached)', () async {
      final result = await ImageBytesCache.getOrFetch('nullKey', () async {
        return null;
      });
      expect(result, isNull);
      // Should not be cached
      expect(ImageBytesCache.get('nullKey'), isNull);
    });

    test('getOrFetch deduplicates concurrent requests', () async {
      int fetchCallCount = 0;
      final results = await Future.wait([
        ImageBytesCache.getOrFetch('concurrent', () async {
          fetchCallCount++;
          // Simulate a slow fetch
          await Future.delayed(const Duration(milliseconds: 50));
          return Uint8List.fromList([1, 2, 3]);
        }),
        ImageBytesCache.getOrFetch('concurrent', () async {
          fetchCallCount++;
          // This should not be called — dedup reuses the first in-flight future
          await Future.delayed(const Duration(milliseconds: 50));
          return Uint8List.fromList([4, 5, 6]);
        }),
      ]);
      expect(fetchCallCount, 1);
      expect(results[0], equals(Uint8List.fromList([1, 2, 3])));
      expect(results[1], equals(Uint8List.fromList([1, 2, 3])));
    });

    test('put replaces existing entry and adjusts currentSize', () {
      final small = Uint8List.fromList([1, 2, 3]);
      final large = Uint8List(100);
      ImageBytesCache.put('key', small);
      final sizeAfterSmall = ImageBytesCache.currentSize;
      ImageBytesCache.put('key', large); // Replace with larger
      final result = ImageBytesCache.get('key');
      expect(result, equals(large));
      expect(ImageBytesCache.currentSize,
          lessThan(sizeAfterSmall + large.length)); // old size subtracted
    });

    test('getOrFetch cleans up _inFlight when fetcher throws', () async {
      try {
        await ImageBytesCache.getOrFetch('errorKey', () async {
          throw Exception('simulated error');
        });
      } catch (_) {
        // Expected
      }
      // Subsequent call should work (not stuck in _inFlight)
      int fetchCallCount = 0;
      final result = await ImageBytesCache.getOrFetch('errorKey', () async {
        fetchCallCount++;
        return Uint8List.fromList([1, 2]);
      });
      expect(result, equals(Uint8List.fromList([1, 2])));
      expect(fetchCallCount, 1);
    });

    test('count and currentSize reflect cache state', () {
      expect(ImageBytesCache.count, 0);
      expect(ImageBytesCache.currentSize, 0);

      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      ImageBytesCache.put('key1', bytes);
      expect(ImageBytesCache.count, 1);
      expect(ImageBytesCache.currentSize, bytes.length);

      ImageBytesCache.put('key2', Uint8List.fromList([6, 7]));
      expect(ImageBytesCache.count, 2);

      ImageBytesCache.remove('key1');
      expect(ImageBytesCache.count, 1);

      ImageBytesCache.clear();
      expect(ImageBytesCache.count, 0);
      expect(ImageBytesCache.currentSize, 0);
    });

    test('LRU eviction preserves remaining entries', () {
      for (int i = 0; i < ImageBytesCache.maxEntries; i++) {
        ImageBytesCache.put('key$i', Uint8List.fromList([i]));
      }
      // All present before overflow
      for (int i = 0; i < ImageBytesCache.maxEntries; i++) {
        expect(ImageBytesCache.get('key$i'), isNotNull);
      }
      // Add overflow
      ImageBytesCache.put('overflow', Uint8List.fromList([255]));
      // key0 evicted
      expect(ImageBytesCache.get('key0'), isNull);
      // keys 1..99 still present
      for (int i = 1; i < ImageBytesCache.maxEntries; i++) {
        expect(ImageBytesCache.get('key$i'), isNotNull);
      }
    });

    test('getOrFetch promotes cached entry to MRU position', () async {
      // Fill cache to max
      for (int i = 0; i < ImageBytesCache.maxEntries; i++) {
        ImageBytesCache.put('key$i', Uint8List.fromList([i]));
      }
      // Access key0 via getOrFetch (should promote it to MRU)
      await ImageBytesCache.getOrFetch('key0', () async {
        return Uint8List.fromList([99]);
      });
      // Add one more entry
      ImageBytesCache.put('overflow', Uint8List.fromList([255]));
      // key1 should be evicted (it's now the LRU), NOT key0
      expect(ImageBytesCache.get('key0'), isNotNull);
      expect(ImageBytesCache.get('key1'), isNull);
    });

    test('remove does not error when key not in cache', () {
      // Should not throw
      ImageBytesCache.remove('nonexistent');
    });

    test('clear on empty cache does not error', () {
      ImageBytesCache.clear();
      // Should not throw
      ImageBytesCache.clear();
    });
  });
}
