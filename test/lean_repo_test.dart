import 'dart:convert';
import 'package:test/test.dart';
import 'package:lean_repo/lean_repo.dart'; // Ensure this points to your lib

// 1. Define a simple model for testing
class User {
  final String id;
  final String name;

  User(this.id, this.name);

  // Boilerplate JSON logic
  factory User.fromJson(Map<String, dynamic> json) =>
      User(json['id'], json['name']);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  // Needed for equality checks in tests
  @override
  bool operator ==(Object other) =>
      other is User && other.id == id && other.name == name;
  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

void main() {
  late CacheDriver driver;
  late LeanRepository repo;

  setUp(() {
    driver = InMemoryDriver();
    repo = LeanRepository(cacheDriver: driver);
  });

  group('LeanRepository Flow', () {
    test('emits Cached data first, then Network data', () async {
      const key = 'user_1';
      final oldUser = User('1', 'Old Name');
      final freshUser = User('1', 'Fresh Name');

      // 1. SETUP: Pre-fill the cache with "Old" data
      await driver.write(key, jsonEncode(oldUser.toJson()));

      // 2. EXECUTE: Create the stream
      final resultStream = repo.stream<User>(
        key: key,
        fromJson: User.fromJson,
        toJson: (user) => user.toJson(),
        // 3. SIMULATION: A network call that takes time
        fetch: () async {
          await Future.delayed(const Duration(milliseconds: 50));
          return freshUser;
        },
      );

      // 4. VERIFY: Check the stream events in order
      // expectLater is designed for Streams
      await expectLater(
        resultStream,
        emitsInOrder([
          // Event 1: Should be the cached data
          predicate<Resource<User>>(
            (r) => r.data == oldUser && r.source == SourceType.cache,
          ),

          // Event 2: Should be the fresh network data
          predicate<Resource<User>>(
            (r) => r.data == freshUser && r.source == SourceType.network,
          ),

          // Stream should close after network finishes
          emitsDone,
        ]),
      );
    });

    test('handles network errors gracefully (keeps showing cache)', () async {
      const key = 'user_2';
      final cachedUser = User('2', 'Safe User');

      // Pre-fill cache
      await driver.write(key, jsonEncode(cachedUser.toJson()));

      final resultStream = repo.stream<User>(
        key: key,
        fromJson: User.fromJson,
        toJson: (user) => user.toJson(),
        fetch: () async {
          await Future.delayed(const Duration(milliseconds: 50));
          throw Exception('Server 500 Error');
        },
      );

      await expectLater(
        resultStream,
        emitsInOrder([
          // 1. Gets cache successfully
          predicate<Resource<User>>((r) => r.data == cachedUser),

          // 2. Emits error (but stream stays alive usually, here we check the error event)
          predicate<Resource<User>>((r) => r.isError == true),

          emitsDone,
        ]),
      );
    });
  });
}
