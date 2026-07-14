/// Pluggable server-side HTML cache (ARCHITECTURE.md §10; S-8).
library;

/// Cache interface for server-rendered HTML.
abstract interface class HydralineCache {
  Future<String?> get(String key);
  Future<void> set(String key, String html, {Duration? ttl, String? etag});
}

/// Simple in-memory cache for development and low-traffic scenarios.
class InMemoryCache implements HydralineCache {
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
  Future<void> set(
    String key,
    String html, {
    Duration? ttl,
    String? etag,
  }) async {
    _store[key] = _Entry(
      html,
      ttl != null ? DateTime.now().add(ttl) : null,
      etag,
    );
  }
}

class _Entry {
  const _Entry(this.html, this.expiresAt, this.etag);

  final String html;
  final DateTime? expiresAt;
  final String? etag;
}
