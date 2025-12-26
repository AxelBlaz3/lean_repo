# LeanRepo

[![Pub Version](https://img.shields.io/pub/v/lean_repo?color=blue)](https://pub.dev/packages/lean_repo)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

**The boilerplate-killer for caching and network synchronization in Dart & Flutter.**

Stop writing the same `if (cache != null)` logic in every repository. `LeanRepo` provides a standardized, type-safe way to handle the "Cache then Network" flow (Stale-While-Revalidate) and other common synchronization strategies.

It is **database-agnostic**. Use it with Hive, SQLite, SharedPreferences, or just in-memory.

## 📑 Index

* [Features](#-features)
* [Installation](#-installation)
* [Usage](#-usage)
* [Recommended Architecture](#️-recommended-architecture)
* [Strategies](#-strategies)
* [Custom Drivers](#-custom-drivers)
* [Integration Recipes](#-integration-recipes)
* [Contributing](#-contributing)

---

## ✨ Features

* **Strategy Pattern:** Switch between `StaleWhileRevalidate`, `CacheFirst`, `NetworkOnly`, or `CacheOnly` with a single enum.
* **Driver Agnostic:** Comes with an `InMemoryDriver` for testing. Easily plug in your own driver for Hive, generic files, or any other storage.
* **Type Safe:** Fully generic `<T>`. No `dynamic` casting required.
* **Fail-Safe:** Automatically handles network errors by falling back to cache (if available) or emitting typed error events.
* **Zero Dependencies:** (Almost). Extremely lightweight.

## 📦 Installation

```bash
dart pub add lean_repo
```

## 🚀 Usage

### 1. Initialize the Repository

Create a single instance of `LeanRepository`. You must provide a `CacheDriver`.

```dart
// For testing/prototyping, use the built-in InMemoryDriver
final repo = LeanRepository(
  cacheDriver: InMemoryDriver(),
);

// For production, see "Custom Drivers" below to use Hive/SharedPrefs
```

### 2. Stream Data

The core method is `stream()`. It returns a `Stream<Resource<T>>` that emits updates based on your strategy.

```dart
Stream<Resource<User>> getUser(String userId) {
  return repo.stream<User>(
    // 1. Unique Cache Key
    key: 'user_$userId',

    // 2. Network Fetcher (Return a Future<T>)
    fetch: () async {
      final response = await myApiClient.get('/users/$userId');
      return User.fromJson(response.data);
    },

    // 3. Serializers (How to store/retrieve from cache)
    fromJson: (json) => User.fromJson(json),
    toJson: (user) => user.toJson(),

    // 4. Strategy (Optional, defaults to staleWhileRevalidate)
    strategy: CacheStrategy.staleWhileRevalidate,
  );
}
```

### 3. Consume in UI (Flutter Example)

Use a `StreamBuilder` to listen to the resource.

```dart
StreamBuilder<Resource<User>>(
  stream: getUser('123'),
  builder: (context, snapshot) {
    final resource = snapshot.data;

    if (resource == null) return CircularProgressIndicator();

    // Show old data while fetching new data?
    if (resource.source == SourceType.cache) {
      showToast('Refreshing data...');
    }

    if (resource.isError) {
      return Text('Error: ${resource.error}');
    }

    final user = resource.data!;
    return Text('Hello ${user.name}');
  },
);
```

## 🏗️ Recommended Architecture

While you can use `LeanRepository` directly in your UI, the best practice is to wrap it in a specific repository class (e.g., `ProductsRepository`).

This keeps your UI clean and reusable.

```dart
class ProductsRepository {
  final LeanRepository _leanRepo;
  final MyApiClient _api;

  ProductsRepository({
    required LeanRepository leanRepo, 
    required MyApiClient api
  }) : _leanRepo = leanRepo, _api = api;

  /// The UI calls this simple method.
  /// No serializers, no strategies, just arguments.
  Stream<Resource<List<Product>>> getProducts(String category, int page) {
    return _leanRepo.stream<List<Product>>(
      // 1. Centralize Key Logic
      key: 'products_${category}_$page',
      
      // 2. Centralize Fetch Logic
      fetch: () => _api.fetchProducts(category, page),
      
      // 3. Centralize Serialization
      fromJson: (json) => (json['items'] as List)
          .map((item) => Product.fromJson(item))
          .toList(),
      
      toJson: (products) => {
        'items': products.map((p) => p.toJson()).toList()
      },
      
      // 4. Define Strategy (or pass it in)
      strategy: CacheStrategy.staleWhileRevalidate,
    );
  }
}
```

## 🧠 Strategies

Control how `LeanRepo` synchronizes data using the `strategy` parameter.

| Strategy | Behavior | Best For |
| :--- | :--- | :--- |
| `staleWhileRevalidate` | **(Default)** Returns Cache immediately, then fetches Network in background and updates UI. | User Profiles, Feeds, Lists |
| `cacheFirst` | Checks Cache. If data exists, returns it and **stops**. Only uses Network if Cache is empty. | Immutable data, Historical records |
| `networkOnly` | Ignores Cache. Fetches Network -> Saves to Cache -> Returns data. | Critical data (Wallet Balance, Payment Status) |
| `cacheOnly` | Returns Cache. Never hits Network. | Offline mode |

## 🔌 Custom Drivers

`LeanRepo` doesn't force a database choice on you. To use **Hive**, for example, just implement `CacheDriver`.

```dart
class HiveDriver implements CacheDriver {
  final Box box;
  HiveDriver(this.box);

  @override
  Future<String?> read(String key) async {
    return box.get(key);
  }

  @override
  Future<void> write(String key, String data, {Duration? ttl}) async {
    await box.put(key, data);
  }

  @override
  Future<void> delete(String key) async => await box.delete(key);

  @override
  Future<void> clear({String? prefix}) async => await box.clear();
}
```

Then use it:

```dart
final repo = LeanRepository(cacheDriver: HiveDriver(myBox));
```

## 🤝 Contributing

Contributions are welcome! Please check the issues tab for help wanted.

## 🍳 Integration Recipes

Here are copy-paste implementations for popular databases.

### SQLite (using `sqflite`)

**1. The Setup**
Ensure your table is created with a text primary key.

```sql
CREATE TABLE cache (
  key TEXT PRIMARY KEY, 
  value TEXT
);
```

**2. The Driver**

```dart
class SqliteDriver implements CacheDriver {
  final Database db;
  final String tableName;

  SqliteDriver(this.db, {this.tableName = 'cache'});

  @override
  Future<String?> read(String key) async {
    final maps = await db.query(
      tableName,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  @override
  Future<void> write(String key, String data, {Duration? ttl}) async {
    await db.insert(
      tableName,
      {'key': key, 'value': data},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String key) async {
    await db.delete(tableName, where: 'key = ?', whereArgs: [key]);
  }

  @override
  Future<void> clear({String? prefix}) async {
    if (prefix != null) {
      await db.delete(tableName, where: 'key LIKE ?', whereArgs: ['$prefix%']);
    } else {
      await db.delete(tableName);
    }
  }
}
```

---

### ObjectBox

**1. The Entity**
ObjectBox uses integer IDs by default, so we treat the `key` as a unique index.

```dart
@Entity()
class CacheEntity {
  @Id()
  int id = 0;

  @Unique()
  String key;

  String value;

  CacheEntity({required this.key, required this.value});
}
```

**2. The Driver**

```dart
class ObjectBoxDriver implements CacheDriver {
  final Box<CacheEntity> box;

  ObjectBoxDriver(this.box);

  @override
  Future<String?> read(String key) async {
    // Note: In real apps, keep the Query object reused for performance
    final query = box.query(CacheEntity_.key.equals(key)).build();
    final result = query.findFirst();
    query.close();
    return result?.value;
  }

  @override
  Future<void> write(String key, String data, {Duration? ttl}) async {
    final query = box.query(CacheEntity_.key.equals(key)).build();
    final existing = query.findFirst();
    query.close();

    if (existing != null) {
      existing.value = data;
      box.put(existing);
    } else {
      box.put(CacheEntity(key: key, value: data));
    }
  }

  @override
  Future<void> delete(String key) async {
    final query = box.query(CacheEntity_.key.equals(key)).build();
    query.remove();
    query.close();
  }

  @override
  Future<void> clear({String? prefix}) async {
    if (prefix != null) {
      final query = box.query(CacheEntity_.key.startsWith(prefix)).build();
      query.remove();
      query.close();
    } else {
      box.removeAll();
    }
  }
}
```

## 🔮 Roadmap

* [x] v0.0.1: Core Logic (Stale-While-Revalidate, CacheFirst, NetworkOnly).
* [x] v0.0.1: InMemoryDriver and Custom Driver support.
* [ ] v0.1.0: Reactive Streams (Listen to DB changes in real-time).
* [ ] v0.2.0: Retry policies (Exponential backoff).
