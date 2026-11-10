import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/features/visits/data/visit_repository.dart';

void main() {
  group('VisitRepository', () {
    late FakeFirebaseFirestore firestore;
    late AppDatabase database;
    late VisitRepository repository;
    final now = DateTime(2026, 8, 24, 12);

    setUp(() {
      firestore = FakeFirebaseFirestore();
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = VisitRepository(
        firestore,
        database: database,
        clock: () => now,
      );
    });

    tearDown(() => database.close());

    Future<void> createVisit({
      required String userId,
      required String restaurantId,
      required DateTime timestamp,
      bool preventSameDayDuplicate = false,
    }) async {
      await repository.createVisit(
        userId: userId,
        restaurantId: restaurantId,
        ownerScopeId: restaurantId,
        timestamp: timestamp,
        preventSameDayDuplicate: preventSameDayDuplicate,
      );
    }

    Future<void> refreshCache({String? userId, String? restaurantId}) async {
      await repository.refreshVisitsFromRemote(
        userId: userId,
        restaurantId: restaurantId,
      );
    }

    test('lit les visites d’un utilisateur', () async {
      await createVisit(
        userId: 'user-a',
        restaurantId: 'restaurant-a',
        timestamp: now,
      );
      await createVisit(
        userId: 'user-b',
        restaurantId: 'restaurant-a',
        timestamp: now,
      );

      await refreshCache(userId: 'user-a');

      expect(repository.visitsForUser('user-a'), hasLength(1));
      expect(repository.visitsForUser('user-a').single.userId, 'user-a');
    });

    test('lit les visites d’un commerce', () async {
      await createVisit(
        userId: 'user-a',
        restaurantId: 'restaurant-a',
        timestamp: now,
      );
      await createVisit(
        userId: 'user-a',
        restaurantId: 'restaurant-b',
        timestamp: now,
      );

      await refreshCache(restaurantId: 'restaurant-a');

      expect(repository.visits, hasLength(1));
      expect(repository.visits.single.restaurantId, 'restaurant-a');
    });

    test('crée une visite dans Firestore', () async {
      final result = await repository.createVisit(
        userId: 'user-a',
        restaurantId: 'restaurant-a',
        ownerScopeId: 'restaurant-a',
        timestamp: now,
        preventSameDayDuplicate: false,
      );

      final snapshot = await firestore.collection('visits').get();
      expect(result.alreadyExists, isFalse);
      expect(result.visit, isNotNull);
      expect(snapshot.docs, hasLength(1));
      expect(snapshot.docs.single.data()['userId'], 'user-a');
    });

    test('détecte une visite quotidienne existante', () async {
      final first = await repository.createVisit(
        userId: 'user-a',
        restaurantId: 'restaurant-a',
        ownerScopeId: 'restaurant-a',
        timestamp: now,
        preventSameDayDuplicate: true,
      );
      final second = await repository.createVisit(
        userId: 'user-a',
        restaurantId: 'restaurant-a',
        ownerScopeId: 'restaurant-a',
        timestamp: now.add(const Duration(hours: 1)),
        preventSameDayDuplicate: true,
      );

      expect(first.alreadyExists, isFalse);
      expect(second.alreadyExists, isTrue);
      expect((await firestore.collection('visits').get()).docs, hasLength(1));
    });

    test('retourne la dernière visite', () async {
      await createVisit(
        userId: 'user-a',
        restaurantId: 'restaurant-a',
        timestamp: now.subtract(const Duration(days: 2)),
      );
      await createVisit(
        userId: 'user-a',
        restaurantId: 'restaurant-a',
        timestamp: now.subtract(const Duration(days: 1)),
      );
      await refreshCache();

      expect(
        repository.lastVisitFor('user-a', 'restaurant-a')?.timestamp,
        now.subtract(const Duration(days: 1)),
      );
    });

    test('gère l’absence de visite', () async {
      await refreshCache();

      expect(repository.visitsForUser('user-a'), isEmpty);
      expect(repository.lastVisitFor('user-a', 'restaurant-a'), isNull);
      expect(repository.passageCount('user-a', 'restaurant-a'), 0);
    });

    test('conserve et trie plusieurs visites', () async {
      await createVisit(
        userId: 'user-a',
        restaurantId: 'restaurant-a',
        timestamp: now.subtract(const Duration(days: 2)),
      );
      await createVisit(
        userId: 'user-a',
        restaurantId: 'restaurant-a',
        timestamp: now,
      );
      await createVisit(
        userId: 'user-a',
        restaurantId: 'restaurant-a',
        timestamp: now.subtract(const Duration(days: 1)),
      );
      await refreshCache();

      final visits = repository.visitsForUser('user-a');
      expect(visits, hasLength(3));
      expect(visits.first.timestamp, now);
      expect(visits.last.timestamp, now.subtract(const Duration(days: 2)));
    });

    test('sépare les visites des commerces A et B', () async {
      await createVisit(
        userId: 'user-a',
        restaurantId: 'restaurant-a',
        timestamp: now,
      );
      await createVisit(
        userId: 'user-a',
        restaurantId: 'restaurant-a',
        timestamp: now.add(const Duration(hours: 1)),
      );
      await createVisit(
        userId: 'user-a',
        restaurantId: 'restaurant-b',
        timestamp: now,
      );
      await refreshCache();

      expect(repository.passageCount('user-a', 'restaurant-a'), 2);
      expect(repository.passageCount('user-a', 'restaurant-b'), 1);
      expect(repository.clientsForRestaurant('restaurant-a'), {'user-a': 2});
    });
  });
}
