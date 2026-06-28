import 'dart:collection';
import 'dart:typed_data';

/// In-memory LRU cache for image bytes.
///
/// Caches both thumbnails and full-size image bytes to avoid
/// repeated disk/IndexedDB reads when the same image is displayed
/// multiple times (e.g., scrolling back in gallery, re-opening preview).
///
/// Eviction policy: LRU based on entry count and total byte size.
///
/// Thread safety: [getOrFetch] deduplicates concurrent in-flight requests
/// so that multiple callers with the same key share a single fetch.
class ImageBytesCache {
  ImageBytesCache._();

  /// Maximum number of entries in the cache.
  static const int maxEntries = 100;

  /// Maximum total byte size (~50 MB) before eviction kicks in.
  static const int maxSizeBytes = 50 * 1024 * 1024;

  static final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  static int _currentSize = 0;

  /// Tracks in-flight fetches to deduplicate concurrent requests.
  static final Map<String, Future<Uint8List?>> _inFlight = {};

  /// Retrieve cached bytes for [key], or null if not cached.
  static Uint8List? get(String key) {
    final bytes = _cache[key];
    if (bytes != null) {
      // Promote to most recently used (move to end)
      _cache.remove(key);
      _cache[key] = bytes;
    }
    return bytes;
  }

  /// Store [bytes] under [key].
  ///
  /// If the cache exceeds [maxEntries] or [maxSizeBytes], the least
  /// recently used entries are evicted until both constraints are met.
  static void put(String key, Uint8List bytes) {
    // If key already exists, remove old entry first
    final existing = _cache.remove(key);
    if (existing != null) {
      _currentSize -= existing.length;
    }

    // Evict until we have room
    _evictIfNeeded(bytes.length);

    _cache[key] = bytes;
    _currentSize += bytes.length;
  }

  /// Remove a single entry from the cache.
  static void remove(String key) {
    final removed = _cache.remove(key);
    if (removed != null) {
      _currentSize -= removed.length;
    }
  }

  /// Clear all cached entries and cancel in-flight dedup tracking.
  static void clear() {
    _cache.clear();
    _inFlight.clear();
    _currentSize = 0;
  }

  /// Return bytes from cache, or call [fetcher] to load them,
  /// cache the result, and return it.
  ///
  /// If [fetcher] returns null, the result is not cached.
  ///
  /// **Concurrent callers**: when two or more callers invoke
  /// `getOrFetch` with the same key before the first fetch completes,
  /// they share a single fetch. The result is broadcast to all callers.
  static Future<Uint8List?> getOrFetch(
    String key,
    Future<Uint8List?> Function() fetcher,
  ) async {
    // Check cache first
    final cached = _cache[key];
    if (cached != null) {
      // Promote to MRU
      _cache.remove(key);
      _cache[key] = cached;
      return cached;
    }

    // Check if there's already an in-flight fetch for this key
    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    // Start new fetch
    final future = fetcher();
    _inFlight[key] = future;
    try {
      final bytes = await future;
      if (bytes != null) {
        put(key, bytes);
      }
      return bytes;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Evict the oldest entries until both entry-count and size
  /// constraints can accommodate [newBytesLength].
  static void _evictIfNeeded(int newBytesLength) {
    while (_cache.length >= maxEntries ||
        (_currentSize + newBytesLength > maxSizeBytes && _cache.isNotEmpty)) {
      final oldest = _cache.keys.first;
      final removed = _cache.remove(oldest);
      if (removed != null) {
        _currentSize -= removed.length;
      }
    }
  }

  /// Current number of cached entries (exposed for testing).
  static int get count => _cache.length;

  /// Current total byte size (exposed for testing).
  static int get currentSize => _currentSize;
}
