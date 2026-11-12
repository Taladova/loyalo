import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/models/restaurant.dart';
import 'package:loyalo/services/loyalty_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AppDatabase database;
  late LoyaltyRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LoyaltyRepository(firestore: firestore, database: database);
  });
  tearDown(() async {
    await repo.stopListening();
    repo.dispose();
    await database.close();
  });

  Future<Restaurant> draft({String name = 'Atelier local'}) =>
      repo.loadOrCreateMerchantDraft(
        ownerId: 'merchant-uid',
        name: name,
        cuisine: 'Caviste',
        email: 'merchant@example.org',
      );
  Future<Restaurant> publish(
    String id, {
    String ownerId = 'merchant-uid',
    int threshold = 5,
    int points = 100,
    String label = 'Une dégustation',
    int hours = 4,
  }) => repo.completeMerchantOnboarding(
    restaurantId: id,
    ownerId: ownerId,
    type: LoyaltyProgramType.visits,
    rewardThreshold: threshold,
    pointsPerVisit: points,
    rewardLabel: label,
    validationPolicy: VisitValidationPolicy.oncePerDay,
    minimumHoursBetweenVisits: hours,
  );

  test(
    'La création écrit directement un brouillon invisible, sans programme ni récompense active',
    () async {
      final restaurant = await draft();
      final data =
          (await firestore.collection('restaurants').doc(restaurant.id).get())
              .data()!;
      expect(restaurant.needsLoyaltySetup, isTrue);
      expect(data['active'], isFalse);
      expect(data['status'], 'draft');
      expect(data['loyaltyProgramEnabled'], isFalse);
      expect(data['rewardThreshold'], 10);
      expect(data['rewardLabel'], '');
      expect(data['cuisine'], 'Caviste');
      expect(data['ownerId'], 'merchant-uid');
      expect(repo.restaurantById(restaurant.id).needsLoyaltySetup, isTrue);
      expect(
        (await firestore
                .collection('restaurants')
                .where('active', isEqualTo: true)
                .get())
            .docs,
        isEmpty,
      );
      expect(
        (await firestore.collection('merchants').doc('merchant-uid').get())
            .data()!['restaurantId'],
        restaurant.id,
      );
      expect((await firestore.collection('visits').get()).docs, isEmpty);
      expect((await firestore.collection('rewards').get()).docs, isEmpty);
    },
  );

  test(
    'Une nouvelle tentative réutilise le commerce lié sans écraser ses données',
    () async {
      final first = await draft();
      final resumed = await draft(name: 'Nom envoyé à la reprise');
      expect(resumed.id, first.id);
      expect(resumed.name, 'Atelier local');
      expect(
        (await firestore.collection('restaurants').get()).docs,
        hasLength(1),
      );
    },
  );

  test('Deux créations concurrentes aboutissent au même brouillon', () async {
    final results = await Future.wait([draft(), draft()]);
    expect(results.map((r) => r.id).toSet(), hasLength(1));
    expect(
      (await firestore.collection('restaurants').get()).docs,
      hasLength(1),
    );
    expect((await firestore.collection('merchants').get()).docs, hasLength(1));
  });

  test(
    'Une interruption avant la liaison reprend le document déjà enregistré',
    () async {
      final first = await draft();
      await firestore.collection('merchants').doc('merchant-uid').delete();
      final resumed = await draft(name: 'Autre nom');
      expect(resumed.id, first.id);
      expect(resumed.name, first.name);
      expect(
        (await firestore.collection('restaurants').get()).docs,
        hasLength(1),
      );
      expect(
        (await firestore.collection('merchants').doc('merchant-uid').get())
            .data()!['restaurantId'],
        first.id,
      );
    },
  );

  for (final linked in [false, true]) {
    test(
      'Un commerce existant est conservé, liaison existante=$linked',
      () async {
        const existing = Restaurant(
          id: 'legacy-commerce',
          ownerId: 'merchant-uid',
          name: 'Commerce existant',
          cuisine: 'Café',
          distanceKm: 0,
          rewardThreshold: 7,
          rewardLabel: 'Café offert',
          icon: Icons.storefront,
        );
        await firestore
            .collection('restaurants')
            .doc(existing.id)
            .set(existing.toMap());
        if (linked) {
          await firestore.collection('merchants').doc('merchant-uid').set({
            'restaurantId': existing.id,
          });
        }
        final resumed = await draft();
        expect(resumed.id, existing.id);
        expect(resumed.active, isTrue);
        expect(resumed.loyaltyProgramEnabled, isTrue);
        expect(resumed.rewardThreshold, 7);
        expect(resumed.rewardLabel, 'Café offert');
        expect(resumed.name, existing.name);
        expect(
          (await firestore.collection('restaurants').get()).docs,
          hasLength(1),
        );
      },
    );
  }

  test(
    'Une liaison vers le commerce d’un autre propriétaire est refusée',
    () async {
      const other = Restaurant(
        id: 'other-commerce',
        ownerId: 'other-owner',
        name: 'Autre commerce',
        cuisine: 'Café',
        distanceKm: 0,
        rewardThreshold: 7,
        rewardLabel: 'Café offert',
        icon: Icons.storefront,
      );
      await firestore
          .collection('restaurants')
          .doc(other.id)
          .set(other.toMap());
      await firestore.collection('merchants').doc('merchant-uid').set({
        'restaurantId': other.id,
      });
      await expectLater(draft(), throwsStateError);
      expect(
        (await firestore.collection('restaurants').get()).docs,
        hasLength(1),
      );
    },
  );

  test(
    'Publication et configuration arrivent ensemble après validation',
    () async {
      final first = await draft();
      final snapshots = <Map<String, dynamic>>[];
      final subscription = firestore
          .collection('restaurants')
          .doc(first.id)
          .snapshots()
          .listen((doc) => snapshots.add(doc.data()!));
      final configured = await publish(first.id);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(configured.needsLoyaltySetup, isFalse);
      expect(configured.active, isTrue);
      expect(configured.status, RestaurantStatus.active);
      expect(configured.loyaltyProgramEnabled, isTrue);
      expect(configured.rewardThreshold, 5);
      expect(configured.rewardLabel, 'Une dégustation');
      expect(repo.restaurantById(first.id).active, isTrue);
      final data =
          (await firestore.collection('restaurants').doc(first.id).get())
              .data()!;
      expect(data['status'], 'active');
      expect(data['rewardLabel'], 'Une dégustation');
      for (final snapshot in snapshots.where((s) => s['active'] == true)) {
        expect(snapshot['loyaltyProgramEnabled'], isTrue);
        expect(snapshot['rewardThreshold'], 5);
        expect(snapshot['rewardLabel'], 'Une dégustation');
      }
      expect((await firestore.collection('rewards').get()).docs, isEmpty);
      expect((await firestore.collection('referrals').get()).docs, isEmpty);
    },
  );

  for (final invalid in [
    (threshold: 0, points: 100, label: 'Récompense', hours: 4),
    (threshold: 5, points: 0, label: 'Récompense', hours: 4),
    (threshold: 5, points: 100, label: '  ', hours: 4),
    (threshold: 5, points: 100, label: 'Récompense', hours: 0),
  ]) {
    test(
      'Une configuration invalide conserve le brouillon : $invalid',
      () async {
        final first = await draft();
        await expectLater(
          publish(
            first.id,
            threshold: invalid.threshold,
            points: invalid.points,
            label: invalid.label,
            hours: invalid.hours,
          ),
          throwsArgumentError,
        );
        final current = Restaurant.fromFirestore(
          await firestore.collection('restaurants').doc(first.id).get(),
        );
        expect(current.needsLoyaltySetup, isTrue);
        expect(current.active, isFalse);
      },
    );
  }

  test('Un autre propriétaire ne peut pas publier le brouillon', () async {
    final first = await draft();
    await expectLater(
      publish(first.id, ownerId: 'other-owner'),
      throwsStateError,
    );
    expect(
      (await firestore.collection('restaurants').doc(first.id).get())
          .data()!['active'],
      isFalse,
    );
  });

  test(
    'Une reprise après publication ne remplace pas le programme validé',
    () async {
      final first = await draft();
      await publish(first.id);
      await publish(first.id, threshold: 20, label: 'Autre récompense');
      final resumed = await draft();
      expect(resumed.rewardThreshold, 5);
      expect(resumed.rewardLabel, 'Une dégustation');
      expect(
        (await firestore.collection('restaurants').get()).docs,
        hasLength(1),
      );
    },
  );
}
