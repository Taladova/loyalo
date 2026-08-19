import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/referral.dart';
import '../models/reward.dart';
import '../models/reward_definition.dart';
import '../models/restaurant.dart';
import '../models/visit.dart';

enum VisitOutcome { validated, alreadyValidatedToday, rewardUnlocked }

class VisitResult {
  final VisitOutcome outcome;
  final Restaurant restaurant;
  final int passageCount;

  const VisitResult({
    required this.outcome,
    required this.restaurant,
    required this.passageCount,
  });
}

/// Un client "annuaire" simplifié, tel que vu côté espace commerçant
/// (recherche de client, profil, historique). Projection du même
/// document Firestore `users/{uid}` que [AppUser].
class DirectoryClient {
  final String id;
  final String name;
  final String email;
  final String phone;

  const DirectoryClient({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });
}

/// Dépôt de données adossé à Firestore, avec un cache local tenu à jour
/// par des écouteurs temps réel. Les écrans lisent des getters/méthodes
/// synchrones (comme avant, en mémoire) ; c'est ce cache qui absorbe
/// l'aspect asynchrone de Firestore. Les écritures (registerVisit,
/// createRestaurant, ...) sont asynchrones et mettent aussi à jour le
/// cache local de façon optimiste pour un retour instantané dans l'UI.
class LoyaltyRepository extends ChangeNotifier {
  LoyaltyRepository({FirebaseFirestore? firestore, DateTime Function()? clock})
      : _db = firestore ?? FirebaseFirestore.instance,
        _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  bool _listening = false;
  final List<StreamSubscription> _subscriptions = [];

  List<Restaurant> _restaurants = [];
  List<_UserDoc> _users = [];
  List<Visit> _visits = [];
  List<RewardItem> _rewardItems = [];
  List<RewardDefinition> _rewardDefinitions = [];

  /// Démarre la synchronisation avec Firestore. À appeler une fois
  /// qu'un utilisateur (client ou commerçant) est authentifié, puisque
  /// les règles de sécurité exigent une session active.
  void startListening() {
    if (_listening) return;
    _listening = true;

    _subscriptions.add(_db.collection('restaurants').snapshots().listen((snap) async {
      if (snap.docs.isEmpty) {
        await _seedDefaultRestaurants();
        return;
      }
      _restaurants = snap.docs.map(Restaurant.fromFirestore).toList();
      notifyListeners();
    }, onError: (_) {}));

    _subscriptions.add(_db.collection('users').snapshots().listen((snap) {
      _users = snap.docs.map(_UserDoc.fromFirestore).toList();
      notifyListeners();
    }, onError: (_) {}));

    _subscriptions.add(_db.collection('visits').snapshots().listen((snap) {
      _visits = snap.docs.map(Visit.fromFirestore).toList();
      notifyListeners();
    }, onError: (_) {}));

    _subscriptions.add(_db.collection('rewards').snapshots().listen((snap) {
      _rewardItems = snap.docs.map(RewardItem.fromFirestore).toList();
      notifyListeners();
    }, onError: (_) {}));

    _subscriptions.add(_db.collection('rewardDefinitions').snapshots().listen((snap) {
      _rewardDefinitions = snap.docs.map(RewardDefinition.fromFirestore).toList();
      notifyListeners();
    }, onError: (_) {}));
  }

  /// Coupe la synchronisation Firestore. À appeler à la déconnexion,
  /// avant que les règles de sécurité ne rejettent les écouteurs actifs
  /// (sinon ils remontent des erreurs "permission-denied" en boucle).
  /// Le cache local n'est volontairement pas vidé : l'écran en cours de
  /// transition de sortie peut encore le lire une dernière fois, et la
  /// prochaine connexion le remplace de toute façon dès que les nouveaux
  /// écouteurs reçoivent leur premier instantané.
  void stopListening() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    _listening = false;
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _seedDefaultRestaurants() async {
    const seed = [
      Restaurant(
        id: '',
        name: 'Le Bistrot Parisien',
        cuisine: 'Cuisine française',
        distanceKm: 0.5,
        rewardThreshold: 10,
        rewardLabel: 'Un repas offert',
        icon: Icons.restaurant,
        latitude: 48.8656,
        longitude: 2.3212,
      ),
      Restaurant(
        id: '',
        name: 'Sushi House',
        cuisine: 'Japonais',
        distanceKm: 1.2,
        rewardThreshold: 10,
        rewardLabel: '-10% sur votre addition',
        icon: Icons.set_meal,
        latitude: 48.8704,
        longitude: 2.3062,
      ),
      Restaurant(
        id: '',
        name: 'Café de la Paix',
        cuisine: 'Café',
        distanceKm: 1.5,
        rewardThreshold: 8,
        rewardLabel: 'Boisson offerte',
        icon: Icons.local_cafe,
        latitude: 48.8708,
        longitude: 2.3316,
      ),
      Restaurant(
        id: '',
        name: 'Bella Italia',
        cuisine: 'Italien',
        distanceKm: 2.1,
        rewardThreshold: 10,
        rewardLabel: '-15% sur votre addition',
        icon: Icons.local_pizza,
        latitude: 48.8584,
        longitude: 2.2945,
      ),
    ];
    final batch = _db.batch();
    for (final r in seed) {
      batch.set(_db.collection('restaurants').doc(), r.toMap());
    }
    await batch.commit();
  }

  // ---------------------------------------------------------------------
  // Comptes (client & commerçant)
  // ---------------------------------------------------------------------

  /// Récupère (ou crée s'il n'existe pas encore) le profil Firestore
  /// d'un client, juste après une connexion/inscription Firebase Auth
  /// réussie.
  Future<AppUser> loadOrCreateClientProfile({
    required String uid,
    required String name,
    required String email,
  }) async {
    final doc = _db.collection('users').doc(uid);
    final snap = await doc.get();
    if (!snap.exists) {
      final referralCode = referralCodeFor(uid);
      await doc.set({
        'name': name,
        'email': email,
        'phone': '—',
        'referralCode': referralCode,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return AppUser(id: uid, name: name, email: email, referralCode: referralCode);
    }
    final data = snap.data()!;
    return AppUser(
      id: uid,
      name: data['name'] as String? ?? name,
      email: data['email'] as String? ?? email,
      referralCode: data['referralCode'] as String? ?? referralCodeFor(uid),
    );
  }

  Future<void> linkMerchantToRestaurant(String uid, String restaurantId) async {
    await _db.collection('merchants').doc(uid).set({'restaurantId': restaurantId});
  }

  Future<String?> restaurantIdForMerchant(String uid) async {
    final doc = await _db.collection('merchants').doc(uid).get();
    return doc.data()?['restaurantId'] as String?;
  }

  /// Supprime le profil Firestore d'un client. L'historique de visites et
  /// de récompenses reste, lui, impossible à supprimer par le client
  /// lui-même (règles de sécurité anti-fraude) : il est simplement dissocié
  /// de tout profil lisible une fois le compte Firebase Auth supprimé.
  Future<void> deleteClientProfile(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  Future<void> unlinkMerchant(String uid) async {
    await _db.collection('merchants').doc(uid).delete();
  }

  // ---------------------------------------------------------------------
  // Restaurants
  // ---------------------------------------------------------------------

  List<Restaurant> get restaurants => List.unmodifiable(_restaurants);

  Restaurant restaurantById(String id) => _restaurants.firstWhere((r) => r.id == id);

  /// Crée un nouveau restaurant (utilisé par l'inscription commerçant).
  Future<String> createRestaurant({
    required String name,
    required String cuisine,
    required int rewardThreshold,
    required String rewardLabel,
  }) async {
    final docRef = _db.collection('restaurants').doc();
    final restaurant = Restaurant(
      id: docRef.id,
      name: name,
      cuisine: cuisine,
      distanceKm: 0,
      rewardThreshold: rewardThreshold,
      rewardLabel: rewardLabel,
      icon: Icons.storefront,
    );
    await docRef.set(restaurant.toMap());
    return docRef.id;
  }

  // ---------------------------------------------------------------------
  // Annuaire clients (vu côté commerçant)
  // ---------------------------------------------------------------------

  List<DirectoryClient> get directory => _users.map((u) => u.toDirectoryClient()).toList();

  DirectoryClient? clientById(String id) {
    for (final u in _users) {
      if (u.id == id) return u.toDirectoryClient();
    }
    return null;
  }

  List<DirectoryClient> searchClients(String query) {
    if (query.trim().isEmpty) return directory;
    final q = query.toLowerCase();
    return _users
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q) ||
            c.phone.replaceAll(' ', '').contains(q.replaceAll(' ', '')))
        .map((u) => u.toDirectoryClient())
        .toList();
  }

  String nameForClient(String userId) => clientById(userId)?.name ?? 'Client';

  // ---------------------------------------------------------------------
  // Passages, points, récompenses
  // ---------------------------------------------------------------------

  int passageCount(String userId, String restaurantId) {
    return _visits.where((v) => v.userId == userId && v.restaurantId == restaurantId).length;
  }

  int totalPoints(String userId) {
    var total = 0;
    for (final v in _visits.where((v) => v.userId == userId)) {
      final restaurant = _restaurants.where((r) => r.id == v.restaurantId).firstOrNull;
      total += restaurant?.pointsPerVisit ?? 0;
    }
    return total;
  }

  List<Visit> visitsForUser(String userId) =>
      _visits.where((v) => v.userId == userId).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  List<RewardItem> rewardsForUser(String userId) => _rewardItems.where((r) => r.userId == userId).toList();

  /// Code de validation à 6 chiffres, stable pour la journée en cours et
  /// propre à chaque client (voir document de présentation : le code
  /// change chaque jour pour limiter le risque de partage).
  String dailyCodeFor(String userId) {
    final day = _clock();
    final seed = '$userId-${day.year}-${day.month}-${day.day}';
    final hash = seed.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
    final code = 100000 + (hash % 900000);
    return code.toString();
  }

  String referralCodeFor(String userId) {
    final safe = userId.replaceAll('-', '').toUpperCase();
    final suffix = safe.length >= 4 ? safe.substring(0, 4) : safe.padRight(4, '0');
    return 'LOYA$suffix';
  }

  final Map<String, List<ReferredFriend>> _referrals = {};

  /// Filleuls d'un client. Simulation locale (non persistée) pour la
  /// phase de test — le parrainage n'est pas encore branché à Firestore.
  List<ReferredFriend> referralsFor(String userId) {
    final now = _clock();
    return _referrals.putIfAbsent(
      userId,
      () => [
        ReferredFriend(name: 'Camille R.', status: ReferralStatus.joined, pointsEarned: 500, invitedAt: now.subtract(const Duration(days: 12))),
        ReferredFriend(name: 'Thomas L.', status: ReferralStatus.pending, pointsEarned: 0, invitedAt: now.subtract(const Duration(days: 3))),
      ],
    );
  }

  void inviteFriend(String userId, String name) {
    referralsFor(userId).insert(
      0,
      ReferredFriend(name: name, status: ReferralStatus.pending, pointsEarned: 0, invitedAt: _clock()),
    );
    notifyListeners();
  }

  bool _hasVisitedToday(String userId, String restaurantId) {
    final now = _clock();
    return _visits.any((v) => v.userId == userId && v.restaurantId == restaurantId && v.isSameDay(now));
  }

  /// Enregistre le passage d'un client validé par le commerçant (via son
  /// code personnel ou sa fiche client). Applique la règle anti-triche :
  /// un seul passage validé par jour et par restaurant. Réservé aux
  /// comptes commerçant côté règles de sécurité Firestore.
  Future<VisitResult> registerVisit({
    required String userId,
    required String restaurantId,
  }) async {
    final restaurant = restaurantById(restaurantId);

    if (_hasVisitedToday(userId, restaurantId)) {
      return VisitResult(
        outcome: VisitOutcome.alreadyValidatedToday,
        restaurant: restaurant,
        passageCount: passageCount(userId, restaurantId),
      );
    }

    // Calculé avant l'écriture : le cache local sera mis à jour par
    // l'écouteur Firestore une fois la visite persistée.
    final newCount = passageCount(userId, restaurantId) + 1;
    final justUnlocked = newCount % restaurant.rewardThreshold == 0;

    final docRef = _db.collection('visits').doc();
    final visit = Visit(id: docRef.id, userId: userId, restaurantId: restaurantId, timestamp: _clock());
    await docRef.set(visit.toMap());

    if (justUnlocked) {
      final rewardRef = _db.collection('rewards').doc();
      final reward = RewardItem(
        id: rewardRef.id,
        userId: userId,
        restaurantName: restaurant.name,
        label: restaurant.rewardLabel,
        expiresAt: _clock().add(const Duration(days: 30)),
        status: RewardStatus.available,
      );
      await rewardRef.set(reward.toMap());
    }

    return VisitResult(
      outcome: justUnlocked ? VisitOutcome.rewardUnlocked : VisitOutcome.validated,
      restaurant: restaurant,
      passageCount: newCount,
    );
  }

  /// Trouve le client correspondant à un code à 6 chiffres saisi par le
  /// commerçant, parmi les clients connus (annuaire Firestore).
  String? resolveUserIdFromCode(String code) {
    for (final u in _users) {
      if (dailyCodeFor(u.id) == code) return u.id;
    }
    return null;
  }

  /// Passages les plus récents pour un restaurant, utilisés pour le fil
  /// d'activité de l'espace commerçant.
  List<Visit> recentActivityForRestaurant(String restaurantId, {int limit = 5}) {
    final visits = _visits.where((v) => v.restaurantId == restaurantId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return visits.take(limit).toList();
  }

  int newClientsToday(String restaurantId) {
    final now = _clock();
    final Set<String> seenBeforeToday = {};
    final Set<String> newToday = {};
    final visits = _visits.where((v) => v.restaurantId == restaurantId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (final v in visits) {
      if (v.isSameDay(now)) {
        if (!seenBeforeToday.contains(v.userId)) newToday.add(v.userId);
      } else {
        seenBeforeToday.add(v.userId);
      }
    }
    return newToday.length;
  }

  Future<void> markRewardUsed(String rewardId) async {
    await _db.collection('rewards').doc(rewardId).update({'status': 'used'});
  }

  /// Liste des clients ayant visité un restaurant donné, avec leur nombre
  /// de passages — utilisé par l'espace professionnel restaurant.
  Map<String, int> clientsForRestaurant(String restaurantId) {
    final Map<String, int> counts = {};
    for (final v in _visits.where((v) => v.restaurantId == restaurantId)) {
      counts[v.userId] = (counts[v.userId] ?? 0) + 1;
    }
    return counts;
  }

  int visitsToday(String restaurantId) {
    final now = _clock();
    return _visits.where((v) => v.restaurantId == restaurantId && v.isSameDay(now)).length;
  }

  // ---------------------------------------------------------------------
  // Catalogue de récompenses par restaurant (espace commerçant)
  // ---------------------------------------------------------------------

  List<RewardDefinition> rewardDefinitionsFor(String restaurantId) =>
      _rewardDefinitions.where((r) => r.restaurantId == restaurantId).toList();

  Future<void> toggleRewardDefinition(String id) async {
    final current = _rewardDefinitions.where((r) => r.id == id).firstOrNull;
    if (current == null) return;
    await _db.collection('rewardDefinitions').doc(id).update({'active': !current.active});
  }

  Future<void> createRewardDefinition(String restaurantId, String label, int thresholdVisits) async {
    final docRef = _db.collection('rewardDefinitions').doc();
    final def = RewardDefinition(
      id: docRef.id,
      restaurantId: restaurantId,
      label: label,
      thresholdVisits: thresholdVisits,
      activeCount: 0,
      active: true,
    );
    await docRef.set(def.toMap());
  }
}

class _UserDoc {
  final String id;
  final String name;
  final String email;
  final String phone;

  const _UserDoc({required this.id, required this.name, required this.email, required this.phone});

  factory _UserDoc.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return _UserDoc(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '—',
    );
  }

  DirectoryClient toDirectoryClient() => DirectoryClient(id: id, name: name, email: email, phone: phone);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
