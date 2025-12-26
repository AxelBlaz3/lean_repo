enum CacheStrategy {
  /// 1. The "Default" (and best) Experience
  /// - Returns Cached data immediately (if available).
  /// - Silently fetches Fresh data in the background.
  /// - Emits the Fresh data when ready.
  staleWhileRevalidate,

  /// 2. The "Data Saver"
  /// - Checks Cache. If data exists, returns it and STOPS.
  /// - Only hits the network if Cache is empty.
  cacheFirst,

  /// 3. The "Critical Data"
  /// - Ignores Cache completely.
  /// - Fetches from Network -> Updates Cache -> Returns Data.
  /// - Use this for things that must be 100% accurate (e.g. Wallet Balance).
  networkOnly,

  /// 4. The "Offline Mode"
  /// - Returns Cache.
  /// - Never hits the network.
  cacheOnly,
}
