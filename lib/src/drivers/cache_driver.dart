/// The contract that any storage provider must implement.
/// This allows LeanRepo to be database-agnostic.
abstract class CacheDriver {
  /// Reads data from the cache.
  /// Returns null if the key doesn't exist.
  Future<String?> read(String key);

  /// Writes data to the cache.
  /// [ttl] (Time To Live) is optional metadata some drivers might support.
  Future<void> write(String key, String data, {Duration? ttl});

  /// Deletes a specific key from the cache.
  Future<void> delete(String key);

  /// Clears all keys starting with a specific prefix.
  /// Useful for "Clear all user data" features.
  Future<void> clear({String? prefix});
}
