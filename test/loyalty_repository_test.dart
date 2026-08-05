import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/services/loyalty_repository.dart';

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
      });
      await firestore.collection('restaurants').doc('r2').set({
        'name': 'Sushi House',
        'cuisine': 'Japonais',
        'distanceKm': 1.2,
        'rewardThreshold': 10,
        'rewardLabel': '-10% sur votre addition',
        'pointsPerVisit': 350,
        'iconKey': 'sushi',
      });
      repo = await buildRepo();
    });

    test('un premier passage est validé et compté', () async {
      final result = await repo.registerVisit(userId: userId, restaurantId: restaurantId);

      expect(result.outcome, VisitOutcome.validated);
      expect(result.passageCount, 1);
      expect(repo.passageCount(userId, restaurantId), 1);
    });

    test('un second scan le même jour est bloqué (anti-doublon)', () async {
      await repo.registerVisit(userId: userId, restaurantId: restaurantId);
      final second = await repo.registerVisit(userId: userId, restaurantId: restaurantId);

      expect(second.outcome, VisitOutcome.alreadyValidatedToday);
      expect(repo.passageCount(userId, restaurantId), 1);
    });

    test('atteindre le seuil débloque la récompense', () async {
      var day = DateTime(2026, 1, 1);
      final dailyRepo = await buildRepo(clock: () => day);
      final restaurant = dailyRepo.restaurantById(restaurantId);

      VisitResult? last;
      for (var i = 0; i < restaurant.rewardThreshold; i++) {
        last = await dailyRepo.registerVisit(userId: userId, restaurantId: restaurantId);
        day = day.add(const Duration(days: 1)); // un passage validé par jour
      }

      expect(last!.outcome, VisitOutcome.rewardUnlocked);
      expect(last.passageCount, restaurant.rewardThreshold);
    });

    test('les passages sont isolés par restaurant', () async {
      await repo.registerVisit(userId: userId, restaurantId: 'r1');
      await repo.registerVisit(userId: userId, restaurantId: 'r2');

      expect(repo.passageCount(userId, 'r1'), 1);
      expect(repo.passageCount(userId, 'r2'), 1);
    });

    test('clientsForRestaurant agrège les passages par client', () async {
      await repo.registerVisit(userId: 'user-1', restaurantId: restaurantId);
      await repo.registerVisit(userId: 'user-2', restaurantId: restaurantId);

      final clients = repo.clientsForRestaurant(restaurantId);
      expect(clients['user-1'], 1);
      expect(clients['user-2'], 1);
    });
  });
}
