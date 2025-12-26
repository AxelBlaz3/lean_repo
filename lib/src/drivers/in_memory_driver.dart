import 'cache_driver.dart';

class InMemoryDriver implements CacheDriver {
  final Map<String, String> _cache = {};

  @override
  Future<String?> read(String key) async {
    return _cache[key];
  }

  @override
  Future<void> write(String key, String data, {Duration? ttl}) async {
    _cache[key] = data;
  }

  @override
  Future<void> delete(String key) async {
    _cache.remove(key);
  }

  @override
  Future<void> clear({String? prefix}) async {
    if (prefix == null) {
      _cache.clear();
    } else {
      _cache.removeWhere((key, _) => key.startsWith(prefix));
    }
  }
}
