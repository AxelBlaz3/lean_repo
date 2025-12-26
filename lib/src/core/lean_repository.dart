import 'dart:convert';
import 'package:lean_repo/src/strategies/cache_strategy.dart';

import '../drivers/cache_driver.dart';
import 'resource.dart';

/// Function signature for converting JSON string to a specific type
typedef JsonDeserializer<T> = T Function(Map<String, dynamic> json);

/// Function signature for fetching fresh data
typedef Fetcher<T> = Future<T> Function();

/// Function signature for turning the object back into a Map for storage
typedef JsonSerializer<T> = Map<String, dynamic> Function(T data);

class LeanRepository {
  final CacheDriver _cacheDriver;

  LeanRepository({required CacheDriver cacheDriver})
    : _cacheDriver = cacheDriver;

  /// The main method to retrieve data.
  ///
  /// 1. Emits cached data immediately if available.
  /// 2. Fetches fresh data from [fetch].
  /// 3. Updates cache and emits fresh data.
  ///
  /// [key] : Unique identifier for storage.
  /// [fromJson] : Factory to convert Map -> Object.
  /// [toJson] : Factory to convert Object -> Map (for storage).
  /// [fetch] : The async network call.
  Stream<Resource<T>> stream<T>({
    required String key,
    required JsonDeserializer<T> fromJson,
    required JsonSerializer<T> toJson,
    required Fetcher<T> fetch,
    CacheStrategy strategy = CacheStrategy.staleWhileRevalidate,
  }) async* {
    // --- PHASE 1: CACHE READ ---
    // We skip reading cache ONLY if the strategy is 'networkOnly'
    if (strategy != CacheStrategy.networkOnly) {
      try {
        final cachedString = await _cacheDriver.read(key);
        if (cachedString != null) {
          final data = fromJson(json.decode(cachedString));
          yield Resource.success(data, SourceType.cache);

          // If strategy is 'cacheFirst' or 'cacheOnly' and we found data, WE STOP HERE.
          if (strategy == CacheStrategy.cacheFirst ||
              strategy == CacheStrategy.cacheOnly) {
            return;
          }
        } else {
          // If cache is empty, we MUST emit loading so the UI shows a spinner
          yield Resource.loading();
        }
      } catch (e) {
        print('LeanRepo Cache Error: $e');
      }
    }

    // [NEW] If strategy is 'cacheOnly', we stop here regardless of result
    if (strategy == CacheStrategy.cacheOnly) return;

    // --- PHASE 2: NETWORK FETCH ---
    try {
      final freshData = await fetch();

      // Save to cache (so it's there next time)
      final jsonMap = toJson(freshData);
      _cacheDriver.write(key, json.encode(jsonMap));

      yield Resource.success(freshData, SourceType.network);
    } catch (e) {
      yield Resource.failed(e);
    }
  }
}
