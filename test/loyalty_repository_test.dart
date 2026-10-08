import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/models/check_in_request.dart';
import 'package:loyalo/models/referral.dart';
import 'package:loyalo/models/restaurant.dart';
import 'package:loyalo/services/loyalty_repository.dart';
import 'package:loyalo/services/notification_service.dart';

void main() {
  group('LoyaltyRepository', () {
    late FakeFirebaseFirestore firestore;
    late LoyaltyRepository repo;
    const userId = 'user-1';
    const restaurantId = 'r1'; // seuil = 10 passages

    Future<LoyaltyRepository> buildRepo({DateTime Function()? clock}) async {
      final r = LoyaltyRepository(firestore: firestore, clock: clock);
      r.startListening();
      await Future.delayed(Duration.zero);
      return r;
    }

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await firestore.collection('restaurants').doc('r1').set({
        'name': 'Le Bistrot Parisien',
        'cuisine': 'Cuisine française',
        'distanceKm': 0.5,
        'rewardThreshold': 10,
        'rewardLabel': 'Un repas offert',
        'pointsPerVisit': 350,
        'iconKey': 'restaurant',
        'latitude': 48.8656,
        'longitude': 2.3212,
        'validationRadiusMeters': 75,
        'ownerId': 'merchant-1',
      });
      await firestore.collection('restaurants').doc('r2').set({
        'name': 'Sushi House',
        'cuisine': 'Japonais',
        'distanceKm': 1.2,
        'rewardThreshold': 10,
        'rewardLabel': '-10% sur votre addition',
        'pointsPerVisit': 350,
        'iconKey': 'sushi',
        'ownerId': 'merchant-2',
      });
      await firestore.collection('merchants').doc('merchant-1').set({
        'restaurantId': 'r1',
      });
      await firestore.collection('merchants').doc('merchant-2').set({
        'restaurantId': 'r2',
      });
      await firestore.collection('users').doc(userId).set({
        'name': 'David T.',
        'email': 'david@example.com',
        'phone': '—',
      });
      repo = await buildRepo();
    });

    test('un premier passage est validé et compté', () async {
      final result = await repo.registerVisit(
        userId: userId,
        restaurantId: restaurantId,
      );

      expect(result.outcome, VisitOutcome.validated);
      expect(result.passageCount, 1);
      expect(repo.passageCount(userId, restaurantId), 1);
    });

    test('un second scan le même jour est bloqué (anti-doublon)', () async {
      await repo.registerVisit(userId: userId, restaurantId: restaurantId);
      final second = await repo.registerVisit(
        userId: userId,
        restaurantId: restaurantId,
      );

      expect(second.outcome, VisitOutcome.alreadyValidatedToday);
      expect(repo.passageCount(userId, restaurantId), 1);
    });

    // Pas de test ici pour deux appels registerVisit() réellement
    // concurrents : le doc de fake_cloud_firestore (_DummyTransaction)
    // exécute les transactions "sans rollback, séquentiellement", donc il
    // ne peut pas simuler le contrôle de concurrence optimiste (retry sur
    // conflit) que le vrai SDK Firestore applique. La protection contre
    // deux visites le même jour (ID de document déterministe + transaction
    // dans registerVisit) repose sur cette garantie réelle de Firestore,
    // vérifiable uniquement avec l'émulateur ou en production — pas avec ce
    // fake. Le test ci-dessus couvre au moins le cas séquentiel.

    test('atteindre le seuil débloque la récompense', () async {
      var day = DateTime(2026, 1, 1);
      final dailyRepo = await buildRepo(clock: () => day);
      final restaurant = dailyRepo.restaurantById(restaurantId);

      VisitResult? last;
      for (var i = 0; i < restaurant.rewardThreshold; i++) {
        last = await dailyRepo.registerVisit(
          userId: userId,
          restaurantId: restaurantId,
        );
        day = day.add(const Duration(days: 1)); // un passage validé par jour
      }

      expect(last!.outcome, VisitOutcome.rewardUnlocked);
      expect(last.passageCount, restaurant.rewardThreshold);
    });

    test('la progression fidélité indique le reste avant récompense', () async {
      var day = DateTime(2026, 1, 1);
      final dailyRepo = await buildRepo(clock: () => day);
      final restaurant = dailyRepo.restaurantById(restaurantId);

      var empty = dailyRepo.loyaltyProgressFor(
        userId: userId,
        restaurant: restaurant,
      );
      expect(empty.current, 0);
      expect(empty.remaining, 10);
      expect(empty.cycle, 0);

      for (var i = 0; i < 9; i++) {
        await dailyRepo.registerVisit(
          userId: userId,
          restaurantId: restaurantId,
        );
        day = day.add(const Duration(days: 1));
      }

      final almost = dailyRepo.loyaltyProgressFor(
        userId: userId,
        restaurant: restaurant,
      );
      expect(almost.current, 9);
      expect(almost.remaining, 1);
      expect(almost.ratio, 0.9);
    });

    test(
      'un commerce sans programme actif ne crée pas de récompense',
      () async {
        var day = DateTime(2026, 1, 1);
        final disabledRepo = await buildRepo(clock: () => day);
        await disabledRepo.updateLoyaltyProgram(
          restaurantId: restaurantId,
          ownerId: 'merchant-1',
          enabled: false,
          type: LoyaltyProgramType.visits,
          rewardThreshold: 2,
          pointsPerVisit: 350,
          rewardLabel: 'Café offert',
          validationPolicy: VisitValidationPolicy.oncePerDay,
          minimumHoursBetweenVisits: 4,
        );

        await disabledRepo.registerVisit(
          userId: userId,
          restaurantId: restaurantId,
        );
        day = day.add(const Duration(days: 1));
        final second = await disabledRepo.registerVisit(
          userId: userId,
          restaurantId: restaurantId,
        );
        await Future.delayed(Duration.zero);

        final progress = disabledRepo.loyaltyProgressFor(
          userId: userId,
          restaurant: disabledRepo.restaurantById(restaurantId),
        );
        expect(second.outcome, VisitOutcome.validated);
        expect(progress.enabled, isFalse);
        expect(disabledRepo.rewardsForUser(userId), isEmpty);
      },
    );

    test(
      'le programme fidélité peut être configuré par le commerçant',
      () async {
        await repo.updateLoyaltyProgram(
          restaurantId: restaurantId,
          ownerId: 'merchant-1',
          enabled: true,
          type: LoyaltyProgramType.points,
          rewardThreshold: 700,
          pointsPerVisit: 350,
          rewardLabel: 'Dessert offert',
          rewardDescription: 'Valable sur place.',
          validationPolicy: VisitValidationPolicy.onceEveryXHours,
          minimumHoursBetweenVisits: 6,
        );
        await Future.delayed(Duration.zero);

        final restaurant = repo.restaurantById(restaurantId);
        expect(restaurant.loyaltyProgramType, LoyaltyProgramType.points);
        expect(restaurant.rewardThreshold, 700);
        expect(restaurant.pointsPerVisit, 350);
        expect(restaurant.rewardLabel, 'Dessert offert');
        expect(restaurant.rewardDescription, 'Valable sur place.');
        expect(
          restaurant.validationPolicy,
          VisitValidationPolicy.onceEveryXHours,
        );
        expect(restaurant.minimumHoursBetweenVisits, 6);
      },
    );

    test(
      'le mode points débloque une récompense selon le seuil de points',
      () async {
        var day = DateTime(2026, 1, 1);
        final pointsRepo = await buildRepo(clock: () => day);
        await pointsRepo.updateLoyaltyProgram(
          restaurantId: restaurantId,
          ownerId: 'merchant-1',
          enabled: true,
          type: LoyaltyProgramType.points,
          rewardThreshold: 700,
          pointsPerVisit: 350,
          rewardLabel: 'Dessert offert',
          validationPolicy: VisitValidationPolicy.oncePerDay,
          minimumHoursBetweenVisits: 4,
        );

        final first = await pointsRepo.registerVisit(
          userId: userId,
          restaurantId: restaurantId,
        );
        day = day.add(const Duration(days: 1));
        final second = await pointsRepo.registerVisit(
          userId: userId,
          restaurantId: restaurantId,
        );
        await Future.delayed(Duration.zero);

        expect(first.outcome, VisitOutcome.validated);
        expect(second.outcome, VisitOutcome.rewardUnlocked);
        expect(pointsRepo.rewardsForUser(userId), hasLength(1));
        expect(pointsRepo.rewardsForUser(userId).single.cycle, 1);
      },
    );

    test('les cycles créent une seule récompense par palier atteint', () async {
      var day = DateTime(2026, 1, 1);
      final cycleRepo = await buildRepo(clock: () => day);

      for (var i = 0; i < 20; i++) {
        await cycleRepo.registerVisit(
          userId: userId,
          restaurantId: restaurantId,
        );
        day = day.add(const Duration(days: 1));
      }
      await Future.delayed(Duration.zero);

      final rewards = cycleRepo
          .rewardsForUser(userId)
          .where((reward) => reward.restaurantId == restaurantId)
          .toList();
      expect(rewards, hasLength(2));
      expect(rewards.map((reward) => reward.cycle).toSet(), {1, 2});
      expect(rewards.map((reward) => reward.id).toSet(), {
        '${restaurantId}_${userId}_cycle_1',
        '${restaurantId}_${userId}_cycle_2',
      });
    });

    test('les passages sont isolés par restaurant', () async {
      await repo.registerVisit(userId: userId, restaurantId: 'r1');
      await repo.registerVisit(userId: userId, restaurantId: 'r2');

      expect(repo.passageCount(userId, 'r1'), 1);
      expect(repo.passageCount(userId, 'r2'), 1);
      expect(
        repo
            .loyaltyProgressFor(
              userId: userId,
              restaurant: repo.restaurantById('r1'),
            )
            .current,
        1,
      );
      expect(
        repo
            .loyaltyProgressFor(
              userId: userId,
              restaurant: repo.restaurantById('r2'),
            )
            .current,
        1,
      );
    });

    test('un token FCM est enregistré par appareil', () async {
      final service = NotificationService(firestore: firestore);

      await service.saveDeviceToken(
        userId: userId,
        token: 'token-a',
        deviceId: 'device-a',
      );

      final doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc('device-a')
          .get();
      expect(doc.data()!['token'], 'token-a');
      expect(doc.data()!['platform'], isNotEmpty);
      expect(doc.data()!['active'], isTrue);
    });

    test('un refresh token met à jour le même appareil', () async {
      final service = NotificationService(firestore: firestore);

      await service.saveDeviceToken(
        userId: userId,
        token: 'token-a',
        deviceId: 'device-a',
      );
      await service.saveDeviceToken(
        userId: userId,
        token: 'token-b',
        deviceId: 'device-a',
      );

      final devices = await firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .get();
      expect(devices.docs, hasLength(1));
      expect(devices.docs.single.data()['token'], 'token-b');
    });

    test('clientsForRestaurant agrège les passages par client', () async {
      await repo.registerVisit(userId: 'user-1', restaurantId: restaurantId);
      await repo.registerVisit(userId: 'user-2', restaurantId: restaurantId);

      final clients = repo.clientsForRestaurant(restaurantId);
      expect(clients['user-1'], 1);
      expect(clients['user-2'], 1);
    });

    test(
      'un commerçant peut créer puis modifier sa fiche établissement',
      () async {
        final restaurantId = await repo.createRestaurant(
          ownerId: 'merchant-1',
          name: 'Maison Martin',
          cuisine: 'Café',
          rewardThreshold: 10,
          rewardLabel: 'Café offert',
          email: 'contact@maison-martin.fr',
        );
        await Future.delayed(Duration.zero);

        final created = repo.restaurantById(restaurantId);
        expect(created.ownerId, 'merchant-1');
        expect(created.email, 'contact@maison-martin.fr');

        await repo.updateRestaurantProfile(
          restaurant: created.copyWith(
            description: 'Cuisine locale et café de spécialité.',
            address: '1 Rue de Rennes',
            postalCode: '35000',
            city: 'Rennes',
            openingHours: {
              ...created.openingHours,
              'sunday': const OpeningHours(
                open: true,
                opensAt: '10:00',
                closesAt: '16:00',
              ),
            },
          ),
          ownerId: 'merchant-1',
        );
        await Future.delayed(Duration.zero);

        final updated = repo.restaurantById(restaurantId);
        expect(updated.description, 'Cuisine locale et café de spécialité.');
        expect(updated.address, '1 Rue de Rennes');
        expect(updated.city, 'Rennes');
        expect(updated.openingHours['sunday']!.open, isTrue);
      },
    );

    test(
      'un autre propriétaire ne peut pas modifier la fiche établissement',
      () async {
        final owned = Restaurant(
          id: 'owned-r',
          ownerId: 'merchant-1',
          name: 'Commerce protégé',
          cuisine: 'Restaurant',
          distanceKm: 0,
          rewardThreshold: 10,
          rewardLabel: 'Récompense',
          icon: Icons.storefront,
        );
        await firestore
            .collection('restaurants')
            .doc(owned.id)
            .set(owned.toMap());
        await Future.delayed(Duration.zero);

        expect(
          () => repo.updateRestaurantProfile(
            restaurant: owned.copyWith(name: 'Nom modifié'),
            ownerId: 'merchant-2',
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'un commerçant peut mettre à jour les images de son établissement',
      () async {
        final restaurantId = await repo.createRestaurant(
          ownerId: 'merchant-1',
          name: 'Atelier Café',
          cuisine: 'Café',
          rewardThreshold: 10,
          rewardLabel: 'Café offert',
        );
        await Future.delayed(Duration.zero);

        await repo.updateRestaurantImages(
          restaurantId: restaurantId,
          ownerId: 'merchant-1',
          logoUrl: 'https://storage.example/logo.jpg',
          coverImageUrl: 'https://storage.example/cover.jpg',
          galleryUrls: const [
            'https://storage.example/gallery-1.jpg',
            'https://storage.example/gallery-2.jpg',
          ],
        );
        await Future.delayed(Duration.zero);

        final updated = repo.restaurantById(restaurantId);
        expect(updated.logoUrl, 'https://storage.example/logo.jpg');
        expect(updated.coverImageUrl, 'https://storage.example/cover.jpg');
        expect(updated.galleryUrls, hasLength(2));
      },
    );

    test(
      'un commerçant peut retirer le logo et la cover sans effacer la galerie',
      () async {
        final restaurantId = await repo.createRestaurant(
          ownerId: 'merchant-1',
          name: 'Atelier Café',
          cuisine: 'Café',
          rewardThreshold: 10,
          rewardLabel: 'Café offert',
        );
        await repo.updateRestaurantImages(
          restaurantId: restaurantId,
          ownerId: 'merchant-1',
          logoUrl: 'https://storage.example/logo.jpg',
          coverImageUrl: 'https://storage.example/cover.jpg',
          galleryUrls: const ['https://storage.example/gallery.jpg'],
        );
        await Future.delayed(Duration.zero);

        await repo.updateRestaurantImages(
          restaurantId: restaurantId,
          ownerId: 'merchant-1',
          clearLogo: true,
          clearCover: true,
        );
        await Future.delayed(Duration.zero);

        final doc = await firestore
            .collection('restaurants')
            .doc(restaurantId)
            .get();
        final data = doc.data()!;
        expect(data.containsKey('logoUrl'), isFalse);
        expect(data.containsKey('coverImageUrl'), isFalse);
        expect(data['galleryUrls'], ['https://storage.example/gallery.jpg']);
      },
    );

    test(
      'un autre propriétaire ne peut pas mettre à jour les images',
      () async {
        final restaurantId = await repo.createRestaurant(
          ownerId: 'merchant-1',
          name: 'Atelier Café',
          cuisine: 'Café',
          rewardThreshold: 10,
          rewardLabel: 'Café offert',
        );
        await Future.delayed(Duration.zero);

        expect(
          () => repo.updateRestaurantImages(
            restaurantId: restaurantId,
            ownerId: 'merchant-2',
            logoUrl: 'https://storage.example/logo.jpg',
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'la recherche commerces trouve un nom exact, partiel et sans respecter la casse',
      () async {
        final restaurantId = await repo.createRestaurant(
          ownerId: 'merchant-1',
          name: 'Maison Martin',
          cuisine: 'Café',
          rewardThreshold: 10,
          rewardLabel: 'Café offert',
        );
        await repo.updateRestaurantProfile(
          restaurant: repo
              .restaurantById(restaurantId)
              .copyWith(city: 'Rennes', category: 'Café'),
          ownerId: 'merchant-1',
        );
        await Future.delayed(Duration.zero);

        expect(
          repo
              .searchRestaurants(query: 'Maison Martin')
              .map((r) => r.restaurant.id),
          contains(restaurantId),
        );
        expect(
          repo.searchRestaurants(query: 'maison').map((r) => r.restaurant.id),
          contains(restaurantId),
        );
        expect(
          repo.searchRestaurants(query: 'MARTIN').map((r) => r.restaurant.id),
          contains(restaurantId),
        );
      },
    );

    test('la recherche commerces filtre par catégorie et ville', () async {
      final restaurantId = await repo.createRestaurant(
        ownerId: 'merchant-1',
        name: 'Maison Martin',
        cuisine: 'Café',
        rewardThreshold: 10,
        rewardLabel: 'Café offert',
      );
      await repo.updateRestaurantProfile(
        restaurant: repo
            .restaurantById(restaurantId)
            .copyWith(
              city: 'Rennes',
              category: 'Café',
              address: '12 Rue Saint-Michel',
            ),
        ownerId: 'merchant-1',
      );
      await Future.delayed(Duration.zero);

      expect(
        repo.searchRestaurants(category: 'Café').map((r) => r.restaurant.id),
        contains(restaurantId),
      );
      expect(
        repo.searchRestaurants(query: 'rennes').map((r) => r.restaurant.id),
        contains(restaurantId),
      );
      expect(
        repo
            .searchRestaurants(query: 'rennes', category: 'Boulangerie')
            .map((r) => r.restaurant.id),
        isNot(contains(restaurantId)),
      );
    });

    test('la recherche commerces exclut les commerces non visibles', () async {
      final draftId = await repo.createRestaurant(
        ownerId: 'merchant-1',
        name: 'Commerce Brouillon',
        cuisine: 'Restaurant',
        rewardThreshold: 10,
        rewardLabel: 'Récompense',
      );
      await repo.updateRestaurantProfile(
        restaurant: repo
            .restaurantById(draftId)
            .copyWith(active: false, status: RestaurantStatus.draft),
        ownerId: 'merchant-1',
      );
      await Future.delayed(Duration.zero);

      expect(
        repo.searchRestaurants(query: 'brouillon').map((r) => r.restaurant.id),
        isNot(contains(draftId)),
      );
    });

    test('la recherche commerces filtre les favoris Loyalo', () async {
      final restaurantId = await repo.createRestaurant(
        ownerId: 'merchant-1',
        name: 'Maison Favorite',
        cuisine: 'Restaurant',
        rewardThreshold: 10,
        rewardLabel: 'Récompense',
      );
      await Future.delayed(Duration.zero);

      final results = repo.searchRestaurants(
        filter: RestaurantPrimaryFilter.favorites,
        favoriteRestaurantIds: {restaurantId},
      );

      expect(results.map((r) => r.restaurant.id), contains(restaurantId));
      expect(
        results.firstWhere((r) => r.restaurant.id == restaurantId).favorite,
        isTrue,
      );
    });

    test(
      'la recherche proximité calcule et trie par distance réelle',
      () async {
        final nearId = await repo.createRestaurant(
          ownerId: 'merchant-1',
          name: 'Commerce Proche',
          cuisine: 'Restaurant',
          rewardThreshold: 10,
          rewardLabel: 'Récompense',
        );
        await repo.updateRestaurantProfile(
          restaurant: repo
              .restaurantById(nearId)
              .copyWith(latitude: 48.112, longitude: -1.678, city: 'Rennes'),
          ownerId: 'merchant-1',
        );
        final farId = await repo.createRestaurant(
          ownerId: 'merchant-2',
          name: 'Commerce Lointain',
          cuisine: 'Restaurant',
          rewardThreshold: 10,
          rewardLabel: 'Récompense',
        );
        await repo.updateRestaurantProfile(
          restaurant: repo
              .restaurantById(farId)
              .copyWith(latitude: 48.8566, longitude: 2.3522, city: 'Paris'),
          ownerId: 'merchant-2',
        );
        await Future.delayed(Duration.zero);

        final results = repo.searchRestaurants(
          filter: RestaurantPrimaryFilter.nearby,
          userLatitude: 48.1113,
          userLongitude: -1.6800,
        );

        expect(results.map((r) => r.restaurant.id), contains(nearId));
        expect(results.map((r) => r.restaurant.id), isNot(contains(farId)));
        expect(results.first.restaurant.id, nearId);
        expect(results.first.distanceMeters, lessThan(500));
      },
    );

    test('la recherche commerces retourne un état vide sans résultat', () {
      final results = repo.searchRestaurants(query: 'commerce inexistant');

      expect(results, isEmpty);
    });

    test(
      'les statistiques restaurant filtrent par période et restaurant',
      () async {
        var now = DateTime(2026, 1, 10, 10);
        final statsRepo = await buildRepo(clock: () => now);

        await statsRepo.registerVisit(userId: 'user-1', restaurantId: 'r1');
        now = DateTime(2026, 1, 11, 10);
        await statsRepo.registerVisit(userId: 'user-2', restaurantId: 'r1');
        now = DateTime(2026, 1, 12, 10);
        await statsRepo.registerVisit(userId: 'user-1', restaurantId: 'r1');
        await statsRepo.registerVisit(userId: 'user-1', restaurantId: 'r2');
        await Future.delayed(Duration.zero);

        final start = DateTime(2026, 1, 10);
        final end = DateTime(2026, 1, 13);

        expect(
          statsRepo.visitsForRestaurantBetween('r1', start, end),
          hasLength(3),
        );
        expect(statsRepo.uniqueClientsForRestaurant('r1'), 2);
        expect(
          statsRepo.newClientsBetween(
            'r1',
            DateTime(2026, 1, 11),
            DateTime(2026, 1, 13),
          ),
          1,
        );
        expect(statsRepo.pointsGrantedBetween('r1', start, end), 1050);
      },
    );

    test(
      'les clients actifs et premières visites sont calculés depuis les visites',
      () async {
        var now = DateTime(2026, 1, 1, 10);
        final statsRepo = await buildRepo(clock: () => now);

        await statsRepo.registerVisit(userId: 'user-1', restaurantId: 'r1');
        now = DateTime(2026, 2, 5, 10);
        await statsRepo.registerVisit(userId: 'user-2', restaurantId: 'r1');
        now = DateTime(2026, 2, 6, 10);
        final second = await statsRepo.registerVisit(
          userId: 'user-1',
          restaurantId: 'r1',
        );
        await Future.delayed(Duration.zero);

        final visits = statsRepo.visitsForRestaurantBetween(
          'r1',
          DateTime(2026, 1, 1),
          DateTime(2026, 2, 7),
        );
        final user1FirstVisit = visits.firstWhere(
          (v) => v.userId == 'user-1' && v.timestamp.month == 1,
        );
        final user1SecondVisit = visits.firstWhere(
          (v) => v.userId == 'user-1' && v.timestamp.month == 2,
        );
        final user2FirstVisit = visits.firstWhere((v) => v.userId == 'user-2');

        expect(statsRepo.activeClientsSince('r1', DateTime(2026, 1, 7)), 2);
        expect(statsRepo.isFirstVisitForRestaurant(user1FirstVisit), isTrue);
        expect(statsRepo.isFirstVisitForRestaurant(user2FirstVisit), isTrue);
        expect(second.passageCount, 2);
        expect(statsRepo.isFirstVisitForRestaurant(user1SecondVisit), isFalse);
      },
    );

    test(
      'les offres exclusives actives respectent les dates et visites min',
      () async {
        var day = DateTime(2026, 1, 10, 12);
        final offerRepo = await buildRepo(clock: () => day);

        await offerRepo.createExclusiveOffer(
          restaurantId: restaurantId,
          title: 'Dessert offert',
          description: 'Offre réservée aux clients fidèles',
          startsAt: DateTime(2026, 1, 1),
          endsAt: DateTime(2026, 1, 31),
          minVisitsRequired: 2,
        );
        await Future.delayed(Duration.zero);

        expect(offerRepo.activeExclusiveOffersForUser(userId), isEmpty);

        await offerRepo.registerVisit(
          userId: userId,
          restaurantId: restaurantId,
        );
        day = day.add(const Duration(days: 1));
        await offerRepo.registerVisit(
          userId: userId,
          restaurantId: restaurantId,
        );

        final offers = offerRepo.activeExclusiveOffersForUser(userId);
        expect(offers, hasLength(1));
        expect(offers.first.title, 'Dessert offert');
      },
    );

    test('une offre inactive ou expirée n’apparaît pas comme active', () async {
      final offerRepo = await buildRepo(clock: () => DateTime(2026, 1, 10, 12));

      await offerRepo.createExclusiveOffer(
        restaurantId: restaurantId,
        title: 'Offre inactive',
        description: 'Non visible',
        startsAt: DateTime(2026, 1, 1),
        endsAt: DateTime(2026, 1, 31),
        active: false,
      );
      await offerRepo.createExclusiveOffer(
        restaurantId: restaurantId,
        title: 'Offre expirée',
        description: 'Trop tard',
        startsAt: DateTime(2025, 12, 1),
        endsAt: DateTime(2025, 12, 31),
      );
      await Future.delayed(Duration.zero);

      expect(offerRepo.activeExclusiveOffersForUser(userId), isEmpty);
      expect(offerRepo.currentExclusiveOffersForUser(userId), isEmpty);
    });

    test('un commerçant peut modifier puis supprimer une offre', () async {
      final offerRepo = await buildRepo(clock: () => DateTime(2026, 1, 10, 12));

      await offerRepo.createExclusiveOffer(
        restaurantId: restaurantId,
        title: 'Cafe offert',
        description: 'Ancienne description',
        startsAt: DateTime(2026, 1, 10),
        endsAt: DateTime(2026, 1, 20),
      );
      await Future.delayed(Duration.zero);
      final offer = offerRepo.exclusiveOffersForRestaurant(restaurantId).single;

      await offerRepo.updateExclusiveOffer(
        offerId: offer.id,
        restaurantId: restaurantId,
        title: 'Dessert offert',
        description: 'Nouvelle description',
        startsAt: DateTime(2026, 1, 11),
        endsAt: DateTime(2026, 1, 25),
        active: true,
        minVisitsRequired: 2,
        newCustomersOnly: false,
      );
      await Future.delayed(Duration.zero);

      final updated = offerRepo
          .exclusiveOffersForRestaurant(restaurantId)
          .single;
      expect(updated.title, 'Dessert offert');
      expect(updated.minVisitsRequired, 2);

      await offerRepo.deleteExclusiveOffer(
        offerId: offer.id,
        restaurantId: restaurantId,
      );
      await Future.delayed(Duration.zero);

      expect(offerRepo.exclusiveOffersForRestaurant(restaurantId), isEmpty);
    });

    test(
      'un commerce A ne peut pas modifier une offre du commerce B',
      () async {
        final offerRepo = await buildRepo(
          clock: () => DateTime(2026, 1, 10, 12),
        );

        await offerRepo.createExclusiveOffer(
          restaurantId: restaurantId,
          title: 'Offre A',
          description: 'Commerce A',
          startsAt: DateTime(2026, 1, 10),
          endsAt: DateTime(2026, 1, 20),
        );
        await Future.delayed(Duration.zero);
        final offer = offerRepo
            .exclusiveOffersForRestaurant(restaurantId)
            .single;

        expect(
          () => offerRepo.updateExclusiveOffer(
            offerId: offer.id,
            restaurantId: 'r2',
            title: 'Offre B',
            description: 'Commerce B',
            startsAt: DateTime(2026, 1, 10),
            endsAt: DateTime(2026, 1, 20),
            active: true,
            minVisitsRequired: 0,
            newCustomersOnly: false,
          ),
          throwsStateError,
        );
      },
    );

    test(
      'une offre nouveaux clients disparaît après une visite validée',
      () async {
        var day = DateTime(2026, 1, 10, 12);
        final offerRepo = await buildRepo(clock: () => day);

        await offerRepo.createExclusiveOffer(
          restaurantId: restaurantId,
          title: 'Bienvenue',
          description: 'Première visite',
          startsAt: DateTime(2026, 1, 1),
          endsAt: DateTime(2026, 1, 31),
          newCustomersOnly: true,
        );
        await Future.delayed(Duration.zero);

        expect(offerRepo.activeExclusiveOffersForUser(userId), hasLength(1));

        await offerRepo.registerVisit(
          userId: userId,
          restaurantId: restaurantId,
        );
        await Future.delayed(Duration.zero);

        expect(offerRepo.activeExclusiveOffersForUser(userId), isEmpty);
      },
    );

    test('une nouvelle offre notifie les clients éligibles', () async {
      var day = DateTime(2026, 1, 10, 12);
      final offerRepo = await buildRepo(clock: () => day);

      await offerRepo.registerVisit(userId: userId, restaurantId: restaurantId);
      day = DateTime(2026, 1, 11, 12);
      await offerRepo.createExclusiveOffer(
        restaurantId: restaurantId,
        title: '-20 % ce week-end',
        description: 'Offre spéciale',
        startsAt: DateTime(2026, 1, 11),
        endsAt: DateTime(2026, 1, 20),
      );
      await Future.delayed(Duration.zero);

      final notifications = await firestore.collection('notifications').get();
      expect(
        notifications.docs
            .where((doc) => doc.data()['type'] == 'new_offer')
            .length,
        1,
      );
    });

    test(
      'les offres désactivées dans les préférences ne notifient pas',
      () async {
        var day = DateTime(2026, 1, 10, 12);
        final offerRepo = await buildRepo(clock: () => day);
        await offerRepo.updateNotificationPreference(
          userId: userId,
          key: 'offers',
          enabled: false,
        );

        await offerRepo.registerVisit(
          userId: userId,
          restaurantId: restaurantId,
        );
        day = DateTime(2026, 1, 11, 12);
        await offerRepo.createExclusiveOffer(
          restaurantId: restaurantId,
          title: '-20 % ce week-end',
          description: 'Offre spéciale',
          startsAt: DateTime(2026, 1, 11),
          endsAt: DateTime(2026, 1, 20),
        );
        await Future.delayed(Duration.zero);

        final notifications = await firestore.collection('notifications').get();
        expect(
          notifications.docs.where((doc) => doc.data()['type'] == 'new_offer'),
          isEmpty,
        );
      },
    );

    test(
      'les offres exclusives en cours restent visibles avant le seuil',
      () async {
        final offerRepo = await buildRepo(
          clock: () => DateTime(2026, 1, 10, 12),
        );

        await offerRepo.createExclusiveOffer(
          restaurantId: restaurantId,
          title: 'Cafe offert',
          description: 'Visible même avant le seuil',
          startsAt: DateTime(2026, 1, 1),
          endsAt: DateTime(2026, 1, 31),
          minVisitsRequired: 10,
        );
        await Future.delayed(Duration.zero);

        expect(offerRepo.activeExclusiveOffersForUser(userId), isEmpty);
        expect(offerRepo.currentExclusiveOffersForUser(userId), hasLength(1));
      },
    );

    test(
      'un code parrain crée un referral pending sans bonus immédiat',
      () async {
        await firestore.collection('referralCodes').doc('DAVID123').set({
          'userId': 'referrer-1',
        });
        await firestore.collection('users').doc('referrer-1').set({
          'name': 'David',
          'email': 'referrer@example.com',
          'phone': '—',
        });
        await Future.delayed(Duration.zero);

        final created = await repo.redeemReferralCode(
          code: 'DAVID123',
          newUserId: 'sophie-1',
          newUserName: 'Sophie',
        );
        await Future.delayed(Duration.zero);

        final referrals = repo.referralsFor('referrer-1');
        expect(created, isTrue);
        expect(referrals, hasLength(1));
        expect(referrals.single.status, ReferralStatus.pending);
        expect(referrals.single.pointsEarned, 0);
        expect(repo.totalPoints('referrer-1'), 0);
      },
    );

    test('l’auto-parrainage est refusé', () async {
      await firestore.collection('referralCodes').doc('SELF123').set({
        'userId': userId,
      });

      final created = await repo.redeemReferralCode(
        code: 'SELF123',
        newUserId: userId,
        newUserName: 'David',
      );
      await Future.delayed(Duration.zero);

      expect(created, isFalse);
      expect(repo.referralsFor(userId), isEmpty);
    });

    test('un check-in pending ne valide pas un parrainage', () async {
      await firestore.collection('referralCodes').doc('DAVID123').set({
        'userId': 'referrer-1',
      });
      await repo.redeemReferralCode(
        code: 'DAVID123',
        newUserId: 'sophie-1',
        newUserName: 'Sophie',
      );
      await repo.createCheckIn(
        userId: 'sophie-1',
        restaurantId: restaurantId,
        distanceMeters: 20,
      );
      await Future.delayed(Duration.zero);

      final referral = repo.referralsFor('referrer-1').single;
      expect(referral.status, ReferralStatus.pending);
      expect(repo.totalPoints('referrer-1'), 0);
    });

    test(
      'la première visite validée récompense le parrain une seule fois',
      () async {
        var day = DateTime(2026, 1, 10, 10);
        final referralRepo = await buildRepo(clock: () => day);
        await firestore.collection('referralCodes').doc('DAVID123').set({
          'userId': 'referrer-1',
        });
        await referralRepo.redeemReferralCode(
          code: 'DAVID123',
          newUserId: 'sophie-1',
          newUserName: 'Sophie',
        );
        await Future.delayed(Duration.zero);

        await referralRepo.registerVisit(
          userId: 'sophie-1',
          restaurantId: restaurantId,
        );
        day = DateTime(2026, 1, 11, 10);
        await referralRepo.registerVisit(
          userId: 'sophie-1',
          restaurantId: restaurantId,
        );
        await Future.delayed(Duration.zero);

        final referral = referralRepo.referralsFor('referrer-1').single;
        expect(referral.status, ReferralStatus.rewarded);
        expect(referral.restaurantId, restaurantId);
        expect(referral.pointsEarned, 500);
        expect(referralRepo.totalPoints('referrer-1'), 500);

        final notifications = await firestore.collection('notifications').get();
        expect(
          notifications.docs
              .where((doc) => doc.data()['type'] == 'referral_rewarded')
              .length,
          1,
        );
      },
    );

    test('un filleul ne peut avoir qu’un parrain initial', () async {
      await firestore.collection('referralCodes').doc('DAVID123').set({
        'userId': 'referrer-1',
      });
      await firestore.collection('referralCodes').doc('EMMA123').set({
        'userId': 'referrer-2',
      });

      final first = await repo.redeemReferralCode(
        code: 'DAVID123',
        newUserId: 'sophie-1',
        newUserName: 'Sophie',
      );
      final second = await repo.redeemReferralCode(
        code: 'EMMA123',
        newUserId: 'sophie-1',
        newUserName: 'Sophie',
      );
      await Future.delayed(Duration.zero);

      expect(first, isTrue);
      expect(second, isFalse);
      expect(repo.referralsFor('referrer-1'), hasLength(1));
      expect(repo.referralsFor('referrer-2'), isEmpty);
    });

    test('deux referrals par commerce restent séparés', () async {
      var day = DateTime(2026, 1, 10, 10);
      final referralRepo = await buildRepo(clock: () => day);
      await firestore.collection('referralCodes').doc('DAVID123').set({
        'userId': 'referrer-1',
      });

      final first = await referralRepo.redeemReferralCode(
        code: 'DAVID123',
        newUserId: 'sophie-1',
        newUserName: 'Sophie',
        restaurantId: 'r1',
      );
      final second = await referralRepo.redeemReferralCode(
        code: 'DAVID123',
        newUserId: 'sophie-1',
        newUserName: 'Sophie',
        restaurantId: 'r2',
      );
      await Future.delayed(Duration.zero);

      await referralRepo.registerVisit(userId: 'sophie-1', restaurantId: 'r1');
      day = DateTime(2026, 1, 11, 10);
      await referralRepo.registerVisit(userId: 'sophie-1', restaurantId: 'r2');
      await Future.delayed(Duration.zero);

      final referrals = referralRepo.referralsFor('referrer-1');
      expect(first, isTrue);
      expect(second, isTrue);
      expect(referrals, hasLength(2));
      expect(referrals.map((referral) => referral.restaurantId).toSet(), {
        'r1',
        'r2',
      });
      expect(
        referrals.every((r) => r.status == ReferralStatus.rewarded),
        isTrue,
      );
      expect(referralRepo.totalPoints('referrer-1'), 1000);
    });

    test(
      'un client peut signaler son arrivée sans attribuer de points',
      () async {
        final result = await repo.createCheckIn(
          userId: userId,
          restaurantId: restaurantId,
          distanceMeters: 20,
        );
        await Future.delayed(Duration.zero);

        expect(result.outcome, CheckInCreateOutcome.created);
        expect(repo.passageCount(userId, restaurantId), 0);
        expect(repo.pendingCheckInsForRestaurant(restaurantId), hasLength(1));
      },
    );

    test('un check-in crée une notification commerçant', () async {
      await repo.createCheckIn(
        userId: userId,
        restaurantId: restaurantId,
        distanceMeters: 20,
      );
      await Future.delayed(Duration.zero);

      final notifications = await firestore.collection('notifications').get();
      expect(notifications.docs, hasLength(1));
      expect(notifications.docs.single.data()['type'], 'check_in_requested');
      expect(notifications.docs.single.data()['userId'], 'merchant-1');
      expect(notifications.docs.single.data()['restaurantId'], restaurantId);
    });

    test('un check-in actif bloque une deuxième demande', () async {
      await repo.createCheckIn(userId: userId, restaurantId: restaurantId);
      final second = await repo.createCheckIn(
        userId: userId,
        restaurantId: restaurantId,
      );

      expect(second.outcome, CheckInCreateOutcome.alreadyActive);
    });

    test('un check-in hors rayon reste possible sans mode strict', () async {
      final result = await repo.createCheckIn(
        userId: userId,
        restaurantId: restaurantId,
        distanceMeters: 250,
      );
      await Future.delayed(Duration.zero);

      expect(result.outcome, CheckInCreateOutcome.created);
      expect(repo.pendingCheckInsForRestaurant(restaurantId), hasLength(1));
    });

    test(
      'un check-in hors rayon est rejeté si le commerce est strict',
      () async {
        await firestore.collection('restaurants').doc(restaurantId).update({
          'requireLocationForCheckIn': true,
        });
        await Future.delayed(Duration.zero);

        final result = await repo.createCheckIn(
          userId: userId,
          restaurantId: restaurantId,
          distanceMeters: 250,
        );

        expect(result.outcome, CheckInCreateOutcome.tooFar);
      },
    );

    test('les demandes expirées ne restent pas en attente', () async {
      var now = DateTime(2026, 1, 10, 10);
      final checkInRepo = await buildRepo(clock: () => now);

      await checkInRepo.createCheckIn(
        userId: userId,
        restaurantId: restaurantId,
      );
      await Future.delayed(Duration.zero);
      expect(
        checkInRepo.pendingCheckInsForRestaurant(restaurantId),
        hasLength(1),
      );

      now = now.add(const Duration(minutes: 11));
      await checkInRepo.expirePendingCheckIns();
      await Future.delayed(Duration.zero);

      expect(checkInRepo.pendingCheckInsForRestaurant(restaurantId), isEmpty);
      final snap = await firestore.collection('checkIns').get();
      final request = CheckInRequest.fromFirestore(snap.docs.first);
      expect(request.status, CheckInStatus.expired);
    });

    test('la validation express transforme le check-in en visite', () async {
      final created = await repo.createCheckIn(
        userId: userId,
        restaurantId: restaurantId,
        distanceMeters: 20,
      );
      final result = await repo.approveCheckIn(
        checkInId: created.request!.id,
        merchantId: 'merchant-1',
      );
      await Future.delayed(Duration.zero);

      expect(result.outcome, CheckInValidationOutcome.validated);
      expect(result.pointsAwarded, 350);
      expect(repo.passageCount(userId, restaurantId), 1);
    });

    test('une visite validée crée une notification client', () async {
      await repo.registerVisit(userId: userId, restaurantId: restaurantId);
      await Future.delayed(Duration.zero);

      final notifications = await firestore.collection('notifications').get();
      expect(
        notifications.docs
            .where((doc) => doc.data()['type'] == 'visit_validated')
            .length,
        1,
      );
    });

    test('une récompense débloquée crée une notification client', () async {
      var day = DateTime(2026, 1, 1, 10);
      final notificationRepo = await buildRepo(clock: () => day);

      for (var i = 0; i < 10; i++) {
        await notificationRepo.registerVisit(
          userId: userId,
          restaurantId: restaurantId,
        );
        day = day.add(const Duration(days: 1));
      }
      await Future.delayed(Duration.zero);

      final notifications = await firestore.collection('notifications').get();
      expect(
        notifications.docs
            .where((doc) => doc.data()['type'] == 'reward_unlocked')
            .length,
        1,
      );
    });

    test('un utilisateur peut marquer sa notification comme lue', () async {
      await firestore.collection('notifications').doc('notif-1').set({
        'userId': userId,
        'recipientType': 'client',
        'title': 'Visite validée',
        'body': 'Votre visite est validée.',
        'type': 'visit_validated',
        'restaurantId': restaurantId,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 10, 10)),
        'isRead': false,
        'read': false,
      });
      final clientRepo = LoyaltyRepository(firestore: firestore);
      clientRepo.startListeningForClient(userId);
      await Future.delayed(Duration.zero);

      expect(clientRepo.unreadNotificationsForUser(userId), 1);

      await clientRepo.markNotificationRead(
        notificationId: 'notif-1',
        userId: userId,
      );
      await Future.delayed(Duration.zero);

      expect(clientRepo.unreadNotificationsForUser(userId), 0);
      final doc = await firestore
          .collection('notifications')
          .doc('notif-1')
          .get();
      expect(doc.data()!['isRead'], isTrue);
    });

    test(
      'le cache notifications client ignore les notifications des autres',
      () async {
        await firestore.collection('notifications').doc('mine').set({
          'userId': userId,
          'recipientType': 'client',
          'title': 'À moi',
          'body': 'Visible',
          'type': 'visit_validated',
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 10, 10)),
          'isRead': false,
        });
        await firestore.collection('notifications').doc('other').set({
          'userId': 'other-user',
          'recipientType': 'client',
          'title': 'Autre',
          'body': 'Invisible',
          'type': 'visit_validated',
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 10, 10)),
          'isRead': false,
        });
        final clientRepo = LoyaltyRepository(firestore: firestore);
        clientRepo.startListeningForClient(userId);
        await Future.delayed(Duration.zero);

        final notifications = clientRepo.notificationsForUser(userId);
        expect(notifications, hasLength(1));
        expect(notifications.single.id, 'mine');
      },
    );

    test('un mauvais commerçant ne peut pas valider un check-in', () async {
      final created = await repo.createCheckIn(
        userId: userId,
        restaurantId: restaurantId,
        distanceMeters: 20,
      );

      final result = await repo.approveCheckIn(
        checkInId: created.request!.id,
        merchantId: 'merchant-2',
      );
      await Future.delayed(Duration.zero);

      expect(result.outcome, CheckInValidationOutcome.unauthorized);
      expect(repo.passageCount(userId, restaurantId), 0);
    });

    test('un double clic validation ne crée pas deux visites', () async {
      final created = await repo.createCheckIn(
        userId: userId,
        restaurantId: restaurantId,
        distanceMeters: 20,
      );

      final first = await repo.approveCheckIn(
        checkInId: created.request!.id,
        merchantId: 'merchant-1',
      );
      final second = await repo.approveCheckIn(
        checkInId: created.request!.id,
        merchantId: 'merchant-1',
      );
      await Future.delayed(Duration.zero);

      expect(first.outcome, CheckInValidationOutcome.validated);
      expect(second.outcome, CheckInValidationOutcome.notPending);
      expect(repo.passageCount(userId, restaurantId), 1);
      final visits = await firestore.collection('visits').get();
      expect(
        visits.docs
            .where(
              (doc) =>
                  doc.data()['userId'] == userId &&
                  doc.data()['restaurantId'] == restaurantId,
            )
            .length,
        1,
      );
    });

    test('un commerçant peut refuser un check-in', () async {
      final created = await repo.createCheckIn(
        userId: userId,
        restaurantId: restaurantId,
        distanceMeters: 20,
      );

      final result = await repo.rejectCheckIn(
        checkInId: created.request!.id,
        merchantId: 'merchant-1',
      );
      await Future.delayed(Duration.zero);

      final doc = await firestore
          .collection('checkIns')
          .doc(created.request!.id)
          .get();
      expect(result.outcome, CheckInValidationOutcome.rejected);
      expect(doc.data()!['status'], CheckInStatus.rejected.firestoreValue);
      expect(repo.passageCount(userId, restaurantId), 0);
    });

    test('un client peut annuler son check-in pending', () async {
      final created = await repo.createCheckIn(
        userId: userId,
        restaurantId: restaurantId,
        distanceMeters: 20,
      );

      await repo.cancelCheckIn(checkInId: created.request!.id, userId: userId);
      await Future.delayed(Duration.zero);

      final doc = await firestore
          .collection('checkIns')
          .doc(created.request!.id)
          .get();
      expect(doc.data()!['status'], CheckInStatus.cancelled.firestoreValue);
      expect(
        repo.activeCheckInForUserAndRestaurant(
          userId: userId,
          restaurantId: restaurantId,
        ),
        isNull,
      );
    });

    test(
      'la politique onceEveryXHours bloque une visite trop proche',
      () async {
        var now = DateTime(2026, 1, 10, 10);
        final policyRepo = await buildRepo(clock: () => now);
        await firestore.collection('restaurants').doc(restaurantId).update({
          'validationPolicy':
              VisitValidationPolicy.onceEveryXHours.firestoreValue,
          'minimumHoursBetweenVisits': 4,
        });
        await Future.delayed(Duration.zero);

        await policyRepo.registerVisit(
          userId: userId,
          restaurantId: restaurantId,
        );
        now = DateTime(2026, 1, 10, 12);
        final created = await policyRepo.createCheckIn(
          userId: userId,
          restaurantId: restaurantId,
          distanceMeters: 20,
        );

        expect(created.outcome, CheckInCreateOutcome.tooFrequent);
      },
    );

    test(
      'la politique perTransaction accepte deux visites le même jour',
      () async {
        var now = DateTime(2026, 1, 10, 10);
        final transactionRepo = await buildRepo(clock: () => now);
        await transactionRepo.updateLoyaltyProgram(
          restaurantId: restaurantId,
          ownerId: 'merchant-1',
          enabled: true,
          type: LoyaltyProgramType.visits,
          rewardThreshold: 10,
          pointsPerVisit: 350,
          rewardLabel: 'Un repas offert',
          validationPolicy: VisitValidationPolicy.perTransaction,
          minimumHoursBetweenVisits: 4,
        );

        await transactionRepo.registerVisit(
          userId: userId,
          restaurantId: restaurantId,
        );
        now = DateTime(2026, 1, 10, 11);
        final second = await transactionRepo.registerVisit(
          userId: userId,
          restaurantId: restaurantId,
        );

        expect(second.outcome, VisitOutcome.validated);
        expect(transactionRepo.passageCount(userId, restaurantId), 2);
      },
    );

    test(
      'une récompense est débloquée une seule fois après validation check-in',
      () async {
        var now = DateTime(2026, 1, 1, 10);
        final rewardRepo = await buildRepo(clock: () => now);

        for (var i = 0; i < 9; i++) {
          await rewardRepo.registerVisit(
            userId: userId,
            restaurantId: restaurantId,
          );
          now = now.add(const Duration(days: 1));
        }
        final created = await rewardRepo.createCheckIn(
          userId: userId,
          restaurantId: restaurantId,
          distanceMeters: 20,
        );
        final first = await rewardRepo.approveCheckIn(
          checkInId: created.request!.id,
          merchantId: 'merchant-1',
        );
        final second = await rewardRepo.approveCheckIn(
          checkInId: created.request!.id,
          merchantId: 'merchant-1',
        );
        await Future.delayed(Duration.zero);

        expect(first.outcome, CheckInValidationOutcome.rewardUnlocked);
        expect(second.outcome, CheckInValidationOutcome.notPending);
        final rewards = await firestore.collection('rewards').get();
        expect(
          rewards.docs
              .where(
                (doc) =>
                    doc.data()['userId'] == userId &&
                    doc.data()['restaurantId'] == restaurantId,
              )
              .length,
          1,
        );
      },
    );

    test(
      'un commerçant peut utiliser une récompense de son restaurant',
      () async {
        var now = DateTime(2026, 1, 1, 10);
        final rewardRepo = await buildRepo(clock: () => now);

        for (var i = 0; i < 10; i++) {
          await rewardRepo.registerVisit(
            userId: userId,
            restaurantId: restaurantId,
          );
          now = now.add(const Duration(days: 1));
        }
        await Future.delayed(Duration.zero);

        final reward = rewardRepo.rewardsForUser(userId).single;
        final redeemed = await rewardRepo.redeemReward(
          rewardId: reward.id,
          merchantId: 'merchant-1',
        );
        final secondAttempt = await rewardRepo.redeemReward(
          rewardId: reward.id,
          merchantId: 'merchant-1',
        );
        await Future.delayed(Duration.zero);

        final doc = await firestore.collection('rewards').doc(reward.id).get();
        expect(redeemed, isTrue);
        expect(secondAttempt, isFalse);
        expect(doc.data()!['status'], 'used');
        expect(doc.data()!['redeemedBy'], 'merchant-1');
        expect(doc.data()!['redeemedAt'], isNotNull);
      },
    );

    test(
      'un commerçant ne peut pas utiliser une récompense concurrente',
      () async {
        var now = DateTime(2026, 1, 1, 10);
        final rewardRepo = await buildRepo(clock: () => now);

        for (var i = 0; i < 10; i++) {
          await rewardRepo.registerVisit(
            userId: userId,
            restaurantId: restaurantId,
          );
          now = now.add(const Duration(days: 1));
        }
        await Future.delayed(Duration.zero);

        final reward = rewardRepo.rewardsForUser(userId).single;
        final redeemed = await rewardRepo.redeemReward(
          rewardId: reward.id,
          merchantId: 'merchant-2',
        );

        final doc = await firestore.collection('rewards').doc(reward.id).get();
        expect(redeemed, isFalse);
        expect(doc.data()!['status'], 'available');
      },
    );

    test('un check-in expiré ne peut pas être validé', () async {
      var now = DateTime(2026, 1, 10, 10);
      final checkInRepo = await buildRepo(clock: () => now);
      final created = await checkInRepo.createCheckIn(
        userId: userId,
        restaurantId: restaurantId,
      );

      now = now.add(const Duration(minutes: 11));
      final result = await checkInRepo.approveCheckIn(
        checkInId: created.request!.id,
        merchantId: 'merchant-1',
      );

      expect(result.outcome, CheckInValidationOutcome.expired);
      expect(checkInRepo.passageCount(userId, restaurantId), 0);
    });
  });
}
