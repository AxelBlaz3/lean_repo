import 'dart:async';
import 'package:lean_repo/lean_repo.dart';

// 1. The Data Model
class User {
  final String id;
  final String name;
  final String status;

  User({required this.id, required this.name, required this.status});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'status': status};

  @override
  String toString() => '$name ($status)';
}

// 2. A Mock API Client
class MockApiClient {
  int _callCount = 0;

  Future<User> getUser(String id) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    _callCount++;

    // Return different data to prove the update happened
    return User(
      id: id,
      name: 'User $id',
      status: 'Online (Update #$_callCount)',
    );
  }
}

void main() async {
  // 3. Initialize the Repository
  // We use InMemoryDriver for this example, but you could use Hive/SQLite.
  final cacheDriver = InMemoryDriver();
  final repo = LeanRepository(cacheDriver: cacheDriver);
  final api = MockApiClient();

  const userId = 'user_123';

  print('--- 🚀 SCENARIO 1: First Load (Cold Start) ---');
  print('Expectation: Loading -> Network Data');
  await fetchAndPrint(repo, api, userId);

  print('\n${'-' * 50}\n');

  print('--- 🔄 SCENARIO 2: Second Load (Stale-While-Revalidate) ---');
  print('Expectation: Cached Data (Immediate) -> Network Data (Delayed)');
  await fetchAndPrint(repo, api, userId);
}

Future<void> fetchAndPrint(
  LeanRepository repo,
  MockApiClient api,
  String key,
) async {
  final completer = Completer<void>();

  // Subscribe to the stream
  final subscription = repo
      .stream<User>(
        key: key,
        fetch: () => api.getUser('123'),
        fromJson: User.fromJson,
        toJson: (user) => user.toJson(),
        strategy: CacheStrategy.staleWhileRevalidate,
      )
      .listen(
        (resource) {
          if (resource.isLoading) {
            print('Status: ⏳ Loading...');
          } else if (resource.isError) {
            print('Status: ❌ Error: ${resource.error}');
          } else {
            print(
              'Status: ✅ [${resource.source.name.toUpperCase()}] received: ${resource.data}',
            );
          }
        },
        onDone: () {
          completer.complete();
        },
      );

  await completer.future;
  await subscription.cancel();
}
