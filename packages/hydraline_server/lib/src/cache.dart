/// Pluggable server-side HTML cache.
library;

/// Cache interface for server-rendered HTML.
abstract interface class HydralineCache {
  /// Creates the built-in [InMemoryCache], evicting the oldest entry once
  /// [maxSize] entries are stored.
  factory HydralineCache.inMemory({int maxSize}) = InMemoryCache;

  Future<String?> get(String key);
  Future<void> set(String key, String html, {Duration? ttl});

  /// Removes a cached entry (no-op when absent).
  Future<void> invalidate(String key);
}

/// Simple in-memory cache for development and low-traffic scenarios.
class InMemoryCache implements HydralineCache {
  InMemoryCache({this.maxSize = 500});

  /// Maximum number of entries; the oldest entry is evicted past this.
  final int maxSize;

  final Map<String, _Entry> _store = {};

  @override
  Future<String?> get(String key) async {
    final entry = _store[key];
    if (entry == null) {
      return null;
    }
    if (entry.expiresAt != null && DateTime.now().isAfter(entry.expiresAt!)) {
      _store.remove(key);
      return null;
    }
    return entry.html;
  }

  @override
  Future<void> set(String key, String html, {Duration? ttl}) async {
    _store.remove(key);
    _store[key] = _Entry(html, ttl != null ? DateTime.now().add(ttl) : null);
    while (_store.length > maxSize) {
      _store.remove(_store.keys.first);
    }
  }

  @override
  Future<void> invalidate(String key) async {
    _store.remove(key);
  }
}

class _Entry {
  const _Entry(this.html, this.expiresAt);

  final String html;
  final DateTime? expiresAt;
}
