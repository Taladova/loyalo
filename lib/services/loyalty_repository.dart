import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/check_in_request.dart';
import '../models/exclusive_offer.dart';
import '../models/loyalo_notification.dart';
import '../models/referral.dart';
import '../models/reward.dart';
import '../models/reward_definition.dart';
import '../models/restaurant.dart';
import '../models/visit.dart';

enum VisitOutcome { validated, alreadyValidatedToday, rewardUnlocked }

enum RestaurantPrimaryFilter { all, nearby, favorites }

class RestaurantSearchResult {
  final Restaurant restaurant;
  final double? distanceMeters;
  final bool favorite;

  const RestaurantSearchResult({
    required this.restaurant,
    required this.distanceMeters,
    required this.favorite,
  });
}

class LoyaltyProgress {
  final Restaurant restaurant;
  final int visits;
  final int points;
  final int current;
  final int threshold;
  final int remaining;
  final int cycle;
  final double ratio;
  final String unitLabel;
  final String rewardLabel;
  final bool enabled;

  const LoyaltyProgress({
    required this.restaurant,
    required this.visits,
    required this.points,
    required this.current,
    required this.threshold,
    required this.remaining,
    required this.cycle,
    required this.ratio,
    required this.unitLabel,
    required this.rewardLabel,
    required this.enabled,
  });
}

enum CheckInCreateOutcome {
  created,
  alreadyActive,
  restaurantInactive,
  tooFrequent,
  tooFar,
}

enum CheckInValidationOutcome {
  validated,
  rewardUnlocked,
  rejected,
  alreadyValidated,
  expired,
  notPending,
  notFound,
  unauthorized,
}

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

class CheckInCreateResult {
  final CheckInCreateOutcome outcome;
  final CheckInRequest? request;
  final String message;

  const CheckInCreateResult({
    required this.outcome,
    this.request,
    required this.message,
  });
}

class CheckInValidationResult {
  final CheckInValidationOutcome outcome;
  final Restaurant? restaurant;
  final int passageCount;
  final int pointsAwarded;

  const CheckInValidationResult({
    required this.outcome,
    this.restaurant,
    this.passageCount = 0,
    this.pointsAwarded = 0,
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
  bool _restaurantsLoading = false;
  Object? _restaurantsLoadError;
  final List<StreamSubscription> _subscriptions = [];

  List<Restaurant> _restaurants = [];
  List<_UserDoc> _users = [];
  List<Visit> _visits = [];
  List<RewardItem> _rewardItems = [];
  List<RewardDefinition> _rewardDefinitions = [];
  List<ExclusiveOffer> _exclusiveOffers = [];
  List<ReferredFriend> _referrals = [];
  List<CheckInRequest> _checkIns = [];
  List<LoyaloNotification> _notifications = [];

  /// Démarre la synchronisation avec Firestore. À appeler une fois
  /// qu'un utilisateur (client ou commerçant) est authentifié, puisque
  /// les règles de sécurité exigent une session active.
  void startListening() {
    _startListening();
  }

  void startListeningForClient(String userId) {
    _startListening(clientId: userId);
  }

  void startListeningForMerchant(String restaurantId) {
    _startListening(merchantRestaurantId: restaurantId);
  }

  void _startListening({String? clientId, String? merchantRestaurantId}) {
    if (_listening) return;
    _listening = true;
    _restaurantsLoading = true;
    _restaurantsLoadError = null;

    if (merchantRestaurantId != null) {
      _subscriptions.add(
        _db
            .collection('restaurants')
            .doc(merchantRestaurantId)
            .snapshots()
            .listen((snap) {
              _restaurantsLoading = false;
              _restaurantsLoadError = null;
              _restaurants = snap.exists
                  ? [Restaurant.fromFirestore(snap)]
                  : <Restaurant>[];
              notifyListeners();
            }, onError: _handleRestaurantsError),
      );
    } else {
      _subscriptions.add(
        (clientId != null
                ? _db.collection('restaurants').where('active', isEqualTo: true)
                : _db.collection('restaurants'))
            .snapshots()
            .listen((snap) async {
              _restaurantsLoading = false;
              _restaurantsLoadError = null;
              if (snap.docs.isEmpty && clientId == null) {
                await _seedDefaultRestaurants();
                return;
              }
              _restaurants = snap.docs.isEmpty && clientId != null
                  ? _rennesDemoRestaurants
                  : snap.docs.map(Restaurant.fromFirestore).toList();
              notifyListeners();
            }, onError: _handleRestaurantsError),
      );
    }

    _subscriptions.add(
      clientId == null && merchantRestaurantId == null
          ? _db.collection('users').snapshots().listen((snap) {
              _users = snap.docs.map(_UserDoc.fromFirestore).toList();
              notifyListeners();
            }, onError: (_) {})
          : clientId != null
          ? _db.collection('users').doc(clientId).snapshots().listen((snap) {
              _users = snap.exists
                  ? [_UserDoc.fromFirestore(snap)]
                  : <_UserDoc>[];
              notifyListeners();
            }, onError: (_) {})
          : const Stream<QuerySnapshot<Map<String, dynamic>>>.empty().listen(
              (_) {},
            ),
    );

    _subscriptions.add(
      (clientId != null
              ? _db.collection('visits').where('userId', isEqualTo: clientId)
              : merchantRestaurantId != null
              ? _db
                    .collection('visits')
                    .where('restaurantId', isEqualTo: merchantRestaurantId)
              : _db.collection('visits'))
          .snapshots()
          .listen((snap) async {
            _visits = snap.docs.map(Visit.fromFirestore).toList();
            if (merchantRestaurantId != null) {
              await _refreshMerchantUsers(merchantRestaurantId);
            }
            notifyListeners();
          }, onError: (_) {}),
    );

    _subscriptions.add(
      (clientId != null
              ? _db.collection('rewards').where('userId', isEqualTo: clientId)
              : merchantRestaurantId != null
              ? _db
                    .collection('rewards')
                    .where('restaurantId', isEqualTo: merchantRestaurantId)
              : _db.collection('rewards'))
          .snapshots()
          .listen((snap) {
            _rewardItems = snap.docs.map(RewardItem.fromFirestore).toList();
            notifyListeners();
          }, onError: (_) {}),
    );

    _subscriptions.add(
      _db.collection('rewardDefinitions').snapshots().listen((snap) {
        _rewardDefinitions = snap.docs
            .map(RewardDefinition.fromFirestore)
            .toList();
        notifyListeners();
      }, onError: (_) {}),
    );

    _subscriptions.add(
      (clientId != null
              ? _db
                    .collection('exclusiveOffers')
                    .where('active', isEqualTo: true)
              : merchantRestaurantId != null
              ? _db
                    .collection('exclusiveOffers')
                    .where('restaurantId', isEqualTo: merchantRestaurantId)
              : _db.collection('exclusiveOffers'))
          .snapshots()
          .listen((snap) {
            _exclusiveOffers = snap.docs
                .map(ExclusiveOffer.fromFirestore)
                .toList();
            notifyListeners();
          }, onError: (_) {}),
    );

    _subscriptions.add(
      (clientId != null
              ? _db
                    .collection('checkIns')
                    .where('customerId', isEqualTo: clientId)
              : merchantRestaurantId != null
              ? _db
                    .collection('checkIns')
                    .where('restaurantId', isEqualTo: merchantRestaurantId)
              : _db.collection('checkIns'))
          .snapshots()
          .listen((snap) async {
            _checkIns = snap.docs.map(CheckInRequest.fromFirestore).toList();
            if (merchantRestaurantId != null) {
              await _refreshMerchantUsers(merchantRestaurantId);
            }
            notifyListeners();
          }, onError: (_) {}),
    );

    if (clientId == null && merchantRestaurantId == null) {
      _listenAllReferrals();
    } else if (clientId != null) {
      _listenReferralsForClient(clientId);
    }

    if (clientId != null) {
      _listenNotificationsForUser(clientId);
    } else if (merchantRestaurantId != null) {
      _listenNotificationsForMerchant(merchantRestaurantId);
    }
  }

  void _handleRestaurantsError(Object error) {
    debugPrint(
      'LoyaltyRepository: chargement des restaurants impossible: $error',
    );
    _restaurantsLoading = false;
    _restaurantsLoadError = error;
    notifyListeners();
  }

  Future<void> _ensureReferralCode(String uid, String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return;
    await _db.collection('referralCodes').doc(trimmed).set({
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> _referrerIdForCode(String code) async {
    final doc = await _db.collection('referralCodes').doc(code).get();
    final referrerId = doc.data()?['userId'] as String?;
    if (referrerId != null && referrerId.isNotEmpty) {
      return referrerId;
    }

    try {
      final matches = await _db
          .collection('users')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();
      if (matches.docs.isEmpty) return null;
      final legacyReferrerId = matches.docs.first.id;
      await _ensureReferralCode(legacyReferrerId, code);
      return legacyReferrerId;
    } on FirebaseException {
      return null;
    }
  }

  Future<String?> resolveUserIdFromCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.length != 6) return null;
    final doc = await _db.collection('validationCodes').doc(trimmed).get();
    if (!doc.exists) return null;
    final data = doc.data();
    final userId = data?['userId'] as String?;
    final expiresAt = data?['expiresAt'];
    if (userId == null || userId.isEmpty) return null;
    if (expiresAt is Timestamp && !expiresAt.toDate().isAfter(_clock())) {
      return null;
    }
    return userId;
  }

  Future<void> _refreshMerchantUsers(String restaurantId) async {
    final userIds = <String>{
      for (final visit in _visits.where((v) => v.restaurantId == restaurantId))
        visit.userId,
      for (final checkIn in _checkIns.where(
        (c) => c.restaurantId == restaurantId,
      ))
        checkIn.customerId,
    };
    if (userIds.isEmpty) {
      _users = [];
      return;
    }
    final docs = await Future.wait(
      userIds.map((id) async {
        try {
          return await _db.collection('users').doc(id).get();
        } on FirebaseException {
          return null;
        }
      }),
    );
    _users = docs
        .whereType<DocumentSnapshot<Map<String, dynamic>>>()
        .where((doc) => doc.exists)
        .map(_UserDoc.fromFirestore)
        .toList();
  }

  Future<void> _rememberRestaurantCustomer({
    required String restaurantId,
    required String userId,
  }) async {
    await _db
        .collection('restaurantCustomers')
        .doc('${restaurantId}_$userId')
        .set({
          'restaurantId': restaurantId,
          'userId': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> ensureDailyValidationCode(String userId) async {
    final now = _clock();
    final code = dailyCodeFor(userId);
    await _db.collection('validationCodes').doc(code).set({
      'userId': userId,
      'dateKey': '${now.year}-${now.month}-${now.day}',
      'expiresAt': Timestamp.fromDate(
        DateTime(now.year, now.month, now.day + 1),
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _mergeReferrals(QuerySnapshot<Map<String, dynamic>> snap) {
    final byId = {for (final r in _referrals) r.id: r};
    for (final referral in snap.docs.map(ReferredFriend.fromFirestore)) {
      byId[referral.id] = referral;
    }
    _referrals = byId.values.toList();
  }

  void _listenReferralsForClient(String clientId) {
    _subscriptions.add(
      _db
          .collection('referrals')
          .where('referrerId', isEqualTo: clientId)
          .snapshots()
          .listen((snap) {
            _mergeReferrals(snap);
            notifyListeners();
          }, onError: (_) {}),
    );
    _subscriptions.add(
      _db
          .collection('referrals')
          .where('referredUserId', isEqualTo: clientId)
          .snapshots()
          .listen((snap) {
            _mergeReferrals(snap);
            notifyListeners();
          }, onError: (_) {}),
    );
  }

  void _listenAllReferrals() {
    _subscriptions.add(
      _db.collection('referrals').snapshots().listen((snap) {
        _referrals = snap.docs.map(ReferredFriend.fromFirestore).toList();
        notifyListeners();
      }, onError: (_) {}),
    );
  }

  void _listenNotificationsForUser(String userId) {
    _subscriptions.add(
      _db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .listen((snap) {
            _notifications =
                snap.docs.map(LoyaloNotification.fromFirestore).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            notifyListeners();
          }, onError: (_) {}),
    );
  }

  void _listenNotificationsForMerchant(String restaurantId) {
    _subscriptions.add(
      _db
          .collection('notifications')
          .where('recipientType', isEqualTo: 'merchant')
          .where('restaurantId', isEqualTo: restaurantId)
          .snapshots()
          .listen((snap) {
            _notifications =
                snap.docs.map(LoyaloNotification.fromFirestore).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            notifyListeners();
          }, onError: (_) {}),
    );
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
    _notifications = [];
    _restaurantsLoading = false;
    _restaurantsLoadError = null;
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
        coverImageUrl:
            'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=900&q=80',
        logoUrl:
            'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=240&q=80',
        address: '12 Rue de la Paix, 75002 Paris',
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
        coverImageUrl:
            'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=900&q=80',
        logoUrl:
            'https://images.unsplash.com/photo-1617196034796-73dfa7b1fd56?auto=format&fit=crop&w=240&q=80',
        address: '18 Rue Saint-Honoré, 75001 Paris',
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
        coverImageUrl:
            'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=900&q=80',
        logoUrl:
            'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=240&q=80',
        address: '5 Place de l\'Opéra, 75009 Paris',
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
        coverImageUrl:
            'https://images.unsplash.com/photo-1552566626-52f8b828add9?auto=format&fit=crop&w=900&q=80',
        logoUrl:
            'https://images.unsplash.com/photo-1594007654729-407eedc4be65?auto=format&fit=crop&w=240&q=80',
        address: '44 Avenue de Suffren, 75015 Paris',
      ),
    ];
    final batch = _db.batch();
    for (final r in seed) {
      batch.set(_db.collection('restaurants').doc(), r.toMap());
    }
    await batch.commit();
  }

  static const List<Restaurant> _rennesDemoRestaurants = [
    Restaurant(
      id: 'demo-rennes-bistro',
      name: 'Le Bistrot des Lices',
      cuisine: 'Cuisine française',
      category: 'Restaurant',
      description:
          'Une table rennaise conviviale inspirée des produits du marché des Lices.',
      distanceKm: 0.4,
      rewardThreshold: 1,
      rewardLabel: 'Dessert maison offert',
      rewardDescription:
          'Un dessert offert après chaque visite validée pendant la démonstration.',
      pointsPerVisit: 120,
      icon: Icons.restaurant,
      latitude: 48.1127,
      longitude: -1.6833,
      address: '8 place des Lices, 35000 Rennes',
      postalCode: '35000',
      city: 'Rennes',
      rating: 4.7,
      reviewCount: 186,
      coverImageUrl:
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=85',
      logoUrl:
          'https://images.unsplash.com/photo-1552566626-52f8b828add9?auto=format&fit=crop&w=300&q=85',
      galleryUrls: [
        'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=700&q=80',
        'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=700&q=80',
      ],
    ),
    Restaurant(
      id: 'demo-rennes-creperie',
      name: 'La Galette du Parlement',
      cuisine: 'Crêperie bretonne',
      category: 'Restaurant',
      description:
          'Galettes de sarrasin, crêpes gourmandes et recettes bretonnes au cœur de Rennes.',
      distanceKm: 0.7,
      rewardThreshold: 6,
      rewardLabel: 'Crêpe dessert offerte',
      rewardDescription: 'Une crêpe dessert offerte après 6 visites.',
      pointsPerVisit: 100,
      icon: Icons.restaurant,
      latitude: 48.1118,
      longitude: -1.6780,
      address: '12 rue Saint-Georges, 35000 Rennes',
      postalCode: '35000',
      city: 'Rennes',
      rating: 4.8,
      reviewCount: 241,
      coverImageUrl:
          'https://images.unsplash.com/photo-1519676867240-f03562e64548?auto=format&fit=crop&w=1200&q=85',
      logoUrl:
          'https://images.unsplash.com/photo-1528207776546-365bb710ee93?auto=format&fit=crop&w=300&q=85',
      galleryUrls: [
        'https://images.unsplash.com/photo-1528207776546-365bb710ee93?auto=format&fit=crop&w=700&q=80',
        'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?auto=format&fit=crop&w=700&q=80',
      ],
    ),
    Restaurant(
      id: 'demo-rennes-cafe',
      name: 'Café Vilaine',
      cuisine: 'Café & brunch',
      category: 'Café',
      description:
          'Café de spécialité, pâtisseries et brunch dans une ambiance lumineuse près des quais.',
      distanceKm: 1.1,
      rewardThreshold: 5,
      rewardLabel: 'Boisson chaude offerte',
      rewardDescription: 'Votre boisson préférée offerte après 5 passages.',
      pointsPerVisit: 80,
      icon: Icons.local_cafe,
      latitude: 48.1089,
      longitude: -1.6794,
      address: '21 quai Émile Zola, 35000 Rennes',
      postalCode: '35000',
      city: 'Rennes',
      rating: 4.6,
      reviewCount: 128,
      coverImageUrl:
          'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=1200&q=85',
      logoUrl:
          'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=300&q=85',
      galleryUrls: [
        'https://images.unsplash.com/photo-1445116572660-236099ec97a0?auto=format&fit=crop&w=700&q=80',
        'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=700&q=80',
      ],
    ),
    Restaurant(
      id: 'demo-rennes-italien',
      name: 'Casa République',
      cuisine: 'Cuisine italienne',
      category: 'Restaurant',
      description:
          'Pizzas artisanales et cuisine italienne généreuse à deux pas de République.',
      distanceKm: 1.4,
      rewardThreshold: 10,
      rewardLabel: '-15 % sur l’addition',
      rewardDescription: '15 % de remise après 10 visites validées.',
      pointsPerVisit: 150,
      icon: Icons.local_pizza,
      latitude: 48.1096,
      longitude: -1.6810,
      address: '5 rue de Nemours, 35000 Rennes',
      postalCode: '35000',
      city: 'Rennes',
      rating: 4.7,
      reviewCount: 204,
      coverImageUrl:
          'https://images.unsplash.com/photo-1579751626657-72bc17010498?auto=format&fit=crop&w=1200&q=85',
      logoUrl:
          'https://images.unsplash.com/photo-1594007654729-407eedc4be65?auto=format&fit=crop&w=300&q=85',
      galleryUrls: [
        'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=700&q=80',
        'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?auto=format&fit=crop&w=700&q=80',
      ],
    ),
  ];

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
    String? referredByCode,
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
      await _ensureReferralCode(uid, referralCode);
      await ensureDailyValidationCode(uid);
      if (referredByCode != null && referredByCode.trim().isNotEmpty) {
        await redeemReferralCode(
          code: referredByCode,
          newUserId: uid,
          newUserName: name,
        );
      }
      return AppUser(
        id: uid,
        name: name,
        email: email,
        referralCode: referralCode,
      );
    }
    final data = snap.data()!;
    final referralCode =
        data['referralCode'] as String? ?? referralCodeFor(uid);
    await _ensureReferralCode(uid, referralCode);
    await ensureDailyValidationCode(uid);
    return AppUser(
      id: uid,
      name: data['name'] as String? ?? name,
      email: data['email'] as String? ?? email,
      referralCode: referralCode,
    );
  }

  Future<void> linkMerchantToRestaurant(String uid, String restaurantId) async {
    await _db.collection('merchants').doc(uid).set({
      'restaurantId': restaurantId,
    });
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

  bool get restaurantsLoading => _restaurantsLoading;

  Object? get restaurantsLoadError => _restaurantsLoadError;

  List<Restaurant> get visibleClientRestaurants => _restaurants
      .where((r) => r.active && r.status == RestaurantStatus.active)
      .toList();

  List<RestaurantSearchResult> searchRestaurants({
    String query = '',
    String? category,
    RestaurantPrimaryFilter filter = RestaurantPrimaryFilter.all,
    Set<String> favoriteRestaurantIds = const {},
    double? userLatitude,
    double? userLongitude,
    double nearbyRadiusMeters = 5000,
  }) {
    final normalizedQuery = _normalizeSearch(query);
    final normalizedCategory = _normalizeSearch(category ?? '');
    final hasLocation = userLatitude != null && userLongitude != null;

    final results = <RestaurantSearchResult>[];
    for (final restaurant in visibleClientRestaurants) {
      final favorite = favoriteRestaurantIds.contains(restaurant.id);
      if (filter == RestaurantPrimaryFilter.favorites && !favorite) continue;

      final distanceMeters = hasLocation
          ? distanceBetweenMeters(
              userLatitude,
              userLongitude,
              restaurant.latitude,
              restaurant.longitude,
            )
          : null;
      if (filter == RestaurantPrimaryFilter.nearby) {
        final distance = distanceMeters ?? restaurant.distanceKm * 1000;
        if (distance > nearbyRadiusMeters) continue;
      }

      if (normalizedCategory.isNotEmpty &&
          _normalizeSearch(restaurant.category) != normalizedCategory) {
        continue;
      }

      if (normalizedQuery.isNotEmpty &&
          !_restaurantMatchesQuery(restaurant, normalizedQuery)) {
        continue;
      }

      results.add(
        RestaurantSearchResult(
          restaurant: restaurant,
          distanceMeters: distanceMeters,
          favorite: favorite,
        ),
      );
    }

    results.sort((a, b) {
      if (hasLocation) {
        return (a.distanceMeters ?? double.infinity).compareTo(
          b.distanceMeters ?? double.infinity,
        );
      }
      return a.restaurant.name.toLowerCase().compareTo(
        b.restaurant.name.toLowerCase(),
      );
    });
    return results;
  }

  static String formatDistance(double? distanceMeters, double fallbackKm) {
    final meters = distanceMeters ?? fallbackKm * 1000;
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  static double distanceBetweenMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = _degreesToRadians(startLatitude);
    final lat2 = _degreesToRadians(endLatitude);
    final deltaLat = _degreesToRadians(endLatitude - startLatitude);
    final deltaLng = _degreesToRadians(endLongitude - startLongitude);
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  bool _restaurantMatchesQuery(Restaurant restaurant, String normalizedQuery) {
    final searchable = _normalizeSearch(
      [
        restaurant.name,
        restaurant.category,
        restaurant.cuisine,
        restaurant.city,
        restaurant.postalCode,
        restaurant.address ?? '',
      ].join(' '),
    );
    return normalizedQuery
        .split(' ')
        .where((part) => part.isNotEmpty)
        .every(searchable.contains);
  }

  String _normalizeSearch(String value) =>
      value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  Restaurant restaurantById(String id) =>
      _restaurants.firstWhere((r) => r.id == id);

  Restaurant? restaurantByIdOrNull(String id) {
    for (final r in _restaurants) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Crée un nouveau restaurant (utilisé par l'inscription commerçant).
  Future<String> createRestaurant({
    required String ownerId,
    required String name,
    required String cuisine,
    required int rewardThreshold,
    required String rewardLabel,
    String email = '',
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
      ownerId: ownerId,
      category: cuisine,
      email: email,
    );
    await docRef.set(restaurant.toMap());
    return docRef.id;
  }

  Future<void> updateRestaurantProfile({
    required Restaurant restaurant,
    required String ownerId,
  }) async {
    if (restaurant.ownerId != null && restaurant.ownerId != ownerId) {
      throw StateError('Ce commerce appartient à un autre compte.');
    }
    final next = restaurant.copyWith(ownerId: restaurant.ownerId ?? ownerId);
    await _db.collection('restaurants').doc(restaurant.id).update({
      ...next.toMap(),
    });
    _restaurants = [
      for (final current in _restaurants)
        if (current.id == restaurant.id) next else current,
    ];
    notifyListeners();
  }

  Future<void> updateRestaurantImages({
    required String restaurantId,
    required String ownerId,
    String? logoUrl,
    bool clearLogo = false,
    String? coverImageUrl,
    bool clearCover = false,
    List<String>? galleryUrls,
  }) async {
    final restaurant = restaurantByIdOrNull(restaurantId);
    if (restaurant?.ownerId != null && restaurant!.ownerId != ownerId) {
      throw StateError('Ce commerce appartient à un autre compte.');
    }

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (logoUrl != null) updates['logoUrl'] = logoUrl;
    if (clearLogo) updates['logoUrl'] = FieldValue.delete();
    if (coverImageUrl != null) updates['coverImageUrl'] = coverImageUrl;
    if (clearCover) updates['coverImageUrl'] = FieldValue.delete();
    if (galleryUrls != null) updates['galleryUrls'] = galleryUrls;

    await _db.collection('restaurants').doc(restaurantId).update(updates);

    if (restaurant != null) {
      _restaurants = [
        for (final current in _restaurants)
          if (current.id == restaurantId)
            current.copyWith(
              logoUrl: clearLogo ? '' : logoUrl,
              coverImageUrl: clearCover ? '' : coverImageUrl,
              galleryUrls: galleryUrls,
            )
          else
            current,
      ];
      notifyListeners();
    }
  }

  Future<void> updateLoyaltyProgram({
    required String restaurantId,
    required String ownerId,
    required bool enabled,
    required LoyaltyProgramType type,
    required int rewardThreshold,
    required int pointsPerVisit,
    required String rewardLabel,
    String rewardDescription = '',
    required VisitValidationPolicy validationPolicy,
    required int minimumHoursBetweenVisits,
  }) async {
    final restaurant = restaurantById(restaurantId);
    if (restaurant.ownerId != null && restaurant.ownerId != ownerId) {
      throw StateError('Ce commerce appartient à un autre compte.');
    }
    final safeThreshold = rewardThreshold < 1 ? 1 : rewardThreshold;
    final safePoints = pointsPerVisit < 1 ? 1 : pointsPerVisit;
    await _db.collection('restaurants').doc(restaurantId).update({
      'loyaltyProgramEnabled': enabled,
      'loyaltyProgramType': type.firestoreValue,
      'rewardThreshold': safeThreshold,
      'pointsPerVisit': safePoints,
      'rewardLabel': rewardLabel,
      'rewardDescription': rewardDescription,
      'validationPolicy': validationPolicy.firestoreValue,
      'minimumHoursBetweenVisits': minimumHoursBetweenVisits < 1
          ? 1
          : minimumHoursBetweenVisits,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _restaurants = [
      for (final current in _restaurants)
        if (current.id == restaurantId)
          current.copyWith(
            loyaltyProgramEnabled: enabled,
            loyaltyProgramType: type,
            rewardThreshold: safeThreshold,
            pointsPerVisit: safePoints,
            rewardLabel: rewardLabel,
            rewardDescription: rewardDescription,
            validationPolicy: validationPolicy,
            minimumHoursBetweenVisits: minimumHoursBetweenVisits < 1
                ? 1
                : minimumHoursBetweenVisits,
          )
        else
          current,
    ];
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Annuaire clients (vu côté commerçant)
  // ---------------------------------------------------------------------

  List<DirectoryClient> get directory =>
      _users.map((u) => u.toDirectoryClient()).toList();

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
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.email.toLowerCase().contains(q) ||
              c.phone.replaceAll(' ', '').contains(q.replaceAll(' ', '')),
        )
        .map((u) => u.toDirectoryClient())
        .toList();
  }

  String nameForClient(String userId) => clientById(userId)?.name ?? 'Client';

  // ---------------------------------------------------------------------
  // Passages, points, récompenses
  // ---------------------------------------------------------------------

  int passageCount(String userId, String restaurantId) {
    return _visits
        .where((v) => v.userId == userId && v.restaurantId == restaurantId)
        .length;
  }

  int totalPoints(String userId) {
    var total = 0;
    for (final v in _visits.where((v) => v.userId == userId)) {
      final restaurant = _restaurants
          .where((r) => r.id == v.restaurantId)
          .firstOrNull;
      total += restaurant?.pointsPerVisit ?? 0;
    }
    for (final r in _referrals.where(
      (r) => r.referrerId == userId && r.status == ReferralStatus.rewarded,
    )) {
      total += r.pointsEarned;
    }
    return total;
  }

  LoyaltyProgress loyaltyProgressFor({
    required String userId,
    required Restaurant restaurant,
  }) {
    final visits = passageCount(userId, restaurant.id);
    final points = visits * restaurant.pointsPerVisit;
    final threshold = restaurant.rewardThreshold <= 0
        ? 1
        : restaurant.rewardThreshold;
    final rawTotal = restaurant.loyaltyProgramType == LoyaltyProgramType.points
        ? points
        : visits;
    final current = rawTotal % threshold;
    final remaining = threshold - current;
    return LoyaltyProgress(
      restaurant: restaurant,
      visits: visits,
      points: points,
      current: current,
      threshold: threshold,
      remaining: remaining,
      cycle: rawTotal ~/ threshold,
      ratio: current / threshold,
      unitLabel: restaurant.loyaltyProgramType == LoyaltyProgramType.points
          ? 'points'
          : 'visites',
      rewardLabel: restaurant.rewardLabel,
      enabled: restaurant.loyaltyProgramEnabled,
    );
  }

  List<Visit> visitsForUser(String userId) =>
      _visits.where((v) => v.userId == userId).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  List<RewardItem> rewardsForUser(String userId) =>
      _rewardItems.where((r) => r.userId == userId).toList();

  List<LoyaloNotification> notificationsForUser(String userId) {
    return _notifications.where((n) => n.userId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<LoyaloNotification> notificationsForMerchant(String restaurantId) {
    return _notifications
        .where(
          (n) =>
              n.recipientType == 'merchant' && n.restaurantId == restaurantId,
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int unreadNotificationsForUser(String userId) {
    return notificationsForUser(userId).where((n) => !n.isRead).length;
  }

  int unreadNotificationsForMerchant(String restaurantId) {
    return notificationsForMerchant(
      restaurantId,
    ).where((n) => !n.isRead).length;
  }

  Future<void> markNotificationRead({
    required String notificationId,
    required String userId,
  }) async {
    final notification = _notifications
        .where((n) => n.id == notificationId)
        .firstOrNull;
    if (notification == null || notification.userId != userId) return;
    await _db.collection('notifications').doc(notificationId).update({
      'isRead': true,
      'read': true,
      'readAt': Timestamp.fromDate(_clock()),
    });
  }

  /// Code de validation à 6 chiffres, stable pour la journée en cours et
  /// propre à chaque client (voir document de présentation : le code
  /// change chaque jour pour limiter le risque de partage).
  String dailyCodeFor(String userId) {
    final day = _clock();
    final seed = '$userId-${day.year}-${day.month}-${day.day}';
    final hash = seed.codeUnits.fold<int>(
      0,
      (acc, c) => (acc * 31 + c) & 0x7fffffff,
    );
    final code = 100000 + (hash % 900000);
    return code.toString();
  }

  String referralCodeFor(String userId) {
    final safe = userId.replaceAll('-', '').toUpperCase();
    final suffix = safe.length >= 4
        ? safe.substring(0, 4)
        : safe.padRight(4, '0');
    return 'LOYA$suffix';
  }

  static const _referralBonusPoints = 500;

  /// Filleuls d'un client : chaque code saisi crée une relation en attente,
  /// puis la première vraie visite validée déclenche le bonus.
  List<ReferredFriend> referralsFor(String userId) {
    final mine = _referrals.where((r) => r.referrerId == userId).toList()
      ..sort((a, b) => b.invitedAt.compareTo(a.invitedAt));
    return mine;
  }

  /// Appelé juste après la création d'un tout nouveau profil client, si un code
  /// parrain a été renseigné à l'inscription. Crée uniquement une relation en
  /// attente : aucune récompense n'est distribuée avant une vraie visite.
  Future<bool> redeemReferralCode({
    required String code,
    required String newUserId,
    required String newUserName,
    String? restaurantId,
  }) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return false;

    final referrerId = await _referrerIdForCode(trimmed);
    if (referrerId == null) return false;
    if (referrerId == newUserId) return false;

    final docId = restaurantId == null
        ? 'initial_$newUserId'
        : '${restaurantId}_$newUserId';
    final docRef = _db.collection('referrals').doc(docId);
    final existing = await docRef.get();
    if (existing.exists) return false;

    final referral = ReferredFriend(
      id: docRef.id,
      referrerId: referrerId,
      referredUserId: newUserId,
      restaurantId: restaurantId,
      name: newUserName,
      status: ReferralStatus.pending,
      pointsEarned: 0,
      invitedAt: _clock(),
    );
    await docRef.set(referral.toMap());
    return true;
  }

  bool _hasVisitedToday(String userId, String restaurantId) {
    final now = _clock();
    return _visits.any(
      (v) =>
          v.userId == userId &&
          v.restaurantId == restaurantId &&
          v.isSameDay(now),
    );
  }

  Visit? _lastVisitFor(String userId, String restaurantId) {
    final visits =
        _visits
            .where((v) => v.userId == userId && v.restaurantId == restaurantId)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return visits.firstOrNull;
  }

  bool _canRegisterVisit(String userId, Restaurant restaurant, DateTime now) {
    switch (restaurant.validationPolicy) {
      case VisitValidationPolicy.oncePerDay:
        return !_hasVisitedToday(userId, restaurant.id);
      case VisitValidationPolicy.onceEveryXHours:
        final last = _lastVisitFor(userId, restaurant.id);
        if (last == null) return true;
        final minimumGap = Duration(
          hours: restaurant.minimumHoursBetweenVisits,
        );
        return !last.timestamp.add(minimumGap).isAfter(now);
      case VisitValidationPolicy.perTransaction:
        return true;
    }
  }

  CheckInRequest? activeCheckInForUserAndRestaurant({
    required String userId,
    required String restaurantId,
  }) {
    final now = _clock();
    final active =
        _checkIns
            .where(
              (request) =>
                  request.customerId == userId &&
                  request.restaurantId == restaurantId &&
                  request.status == CheckInStatus.pending &&
                  request.expiresAt.isAfter(now),
            )
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return active.firstOrNull;
  }

  List<CheckInRequest> pendingCheckInsForRestaurant(String restaurantId) {
    final now = _clock();
    final pending =
        _checkIns
            .where(
              (request) =>
                  request.restaurantId == restaurantId &&
                  request.status == CheckInStatus.pending &&
                  request.expiresAt.isAfter(now),
            )
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return pending;
  }

  Stream<List<CheckInRequest>> watchPendingCheckInsForRestaurant(
    String restaurantId,
  ) {
    return _db
        .collection('checkIns')
        .where('restaurantId', isEqualTo: restaurantId)
        .where('status', isEqualTo: CheckInStatus.pending.firestoreValue)
        .snapshots()
        .map((snap) {
          final now = _clock();
          final requests =
              snap.docs
                  .map(CheckInRequest.fromFirestore)
                  .where((request) => request.expiresAt.isAfter(now))
                  .toList()
                ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
          return requests;
        });
  }

  Future<void> cancelCheckIn({
    required String checkInId,
    required String userId,
  }) async {
    final ref = _db.collection('checkIns').doc(checkInId);
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) return;
      final request = CheckInRequest.fromFirestore(snap);
      if (request.customerId != userId ||
          request.status != CheckInStatus.pending) {
        return;
      }
      transaction.update(ref, {
        'status': CheckInStatus.cancelled.firestoreValue,
        'cancelledAt': Timestamp.fromDate(_clock()),
      });
    });
  }

  Future<CheckInValidationResult> rejectCheckIn({
    required String checkInId,
    required String merchantId,
  }) async {
    await expirePendingCheckIns();
    final checkInRef = _db.collection('checkIns').doc(checkInId);
    final snap = await checkInRef.get();
    if (!snap.exists) {
      return const CheckInValidationResult(
        outcome: CheckInValidationOutcome.notFound,
      );
    }
    final request = CheckInRequest.fromFirestore(snap);
    final restaurant = restaurantByIdOrNull(request.restaurantId);
    if (restaurant == null ||
        !await _merchantCanValidateRestaurant(
          merchantId: merchantId,
          restaurant: restaurant,
        )) {
      return CheckInValidationResult(
        outcome: CheckInValidationOutcome.unauthorized,
        restaurant: restaurant,
      );
    }

    final now = _clock();
    if (request.status != CheckInStatus.pending) {
      return CheckInValidationResult(
        outcome: request.status == CheckInStatus.expired
            ? CheckInValidationOutcome.expired
            : CheckInValidationOutcome.notPending,
        restaurant: restaurant,
      );
    }
    if (!request.expiresAt.isAfter(now)) {
      await checkInRef.update({'status': CheckInStatus.expired.firestoreValue});
      return CheckInValidationResult(
        outcome: CheckInValidationOutcome.expired,
        restaurant: restaurant,
      );
    }

    await _db.runTransaction((transaction) async {
      final liveSnap = await transaction.get(checkInRef);
      if (!liveSnap.exists) return;
      final live = CheckInRequest.fromFirestore(liveSnap);
      if (live.status != CheckInStatus.pending ||
          !live.expiresAt.isAfter(_clock())) {
        return;
      }
      transaction.update(checkInRef, {
        'status': CheckInStatus.rejected.firestoreValue,
        'rejectedAt': Timestamp.fromDate(_clock()),
        'rejectedBy': merchantId,
      });
    });

    await _createNotification(
      recipientType: 'client',
      userId: request.customerId,
      restaurantId: request.restaurantId,
      title: 'Demande refusée',
      body: 'Votre arrivée chez ${restaurant.name} n’a pas été validée.',
      type: 'check_in_rejected',
      relatedId: checkInId,
    );
    return CheckInValidationResult(
      outcome: CheckInValidationOutcome.rejected,
      restaurant: restaurant,
      passageCount: passageCount(request.customerId, request.restaurantId),
    );
  }

  Future<void> expirePendingCheckIns() async {
    final now = _clock();
    final expired = _checkIns.where(
      (request) =>
          request.status == CheckInStatus.pending &&
          !request.expiresAt.isAfter(now),
    );
    for (final request in expired) {
      await _db.collection('checkIns').doc(request.id).update({
        'status': CheckInStatus.expired.firestoreValue,
      });
    }
  }

  Future<CheckInCreateResult> createCheckIn({
    required String userId,
    required String restaurantId,
    double? customerLatitude,
    double? customerLongitude,
    double? distanceMeters,
  }) async {
    await expirePendingCheckIns();

    final restaurant = restaurantByIdOrNull(restaurantId);
    if (restaurant == null || !restaurant.active) {
      return const CheckInCreateResult(
        outcome: CheckInCreateOutcome.restaurantInactive,
        message: 'Ce commerce n\'est pas disponible pour le moment.',
      );
    }

    final existing =
        activeCheckInForUserAndRestaurant(
          userId: userId,
          restaurantId: restaurantId,
        ) ??
        await _activeCheckInFromFirestore(userId, restaurantId);
    if (existing != null) {
      return CheckInCreateResult(
        outcome: CheckInCreateOutcome.alreadyActive,
        request: existing,
        message: 'Votre arrivée est déjà en attente de validation.',
      );
    }

    if (!_canRegisterVisit(userId, restaurant, _clock())) {
      return const CheckInCreateResult(
        outcome: CheckInCreateOutcome.tooFrequent,
        message: 'Vous avez déjà une visite récente dans ce commerce.',
      );
    }

    final tooFar =
        distanceMeters != null &&
        distanceMeters > restaurant.validationRadiusMeters;
    if (tooFar && restaurant.requireLocationForCheckIn) {
      return CheckInCreateResult(
        outcome: CheckInCreateOutcome.tooFar,
        message:
            'Vous semblez trop loin de ce commerce pour signaler votre arrivée.',
      );
    }

    final now = _clock();
    final docRef = _db.collection('checkIns').doc();
    await _rememberRestaurantCustomer(
      restaurantId: restaurantId,
      userId: userId,
    );
    final request = CheckInRequest(
      id: docRef.id,
      customerId: userId,
      restaurantId: restaurantId,
      requestedAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
      status: CheckInStatus.pending,
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
      distanceMeters: distanceMeters,
    );
    await docRef.set(request.toMap());
    _checkIns = [
      ..._checkIns.where((existing) => existing.id != request.id),
      request,
    ];
    notifyListeners();
    await _createNotification(
      recipientType: 'merchant',
      userId: await _merchantUserIdForRestaurant(restaurantId),
      restaurantId: restaurantId,
      title: _pendingCheckInsForRestaurantCount(restaurantId) > 1
          ? '${_pendingCheckInsForRestaurantCount(restaurantId)} clients attendent'
          : '${nameForClient(userId)} est arrivé',
      body: _pendingCheckInsForRestaurantCount(restaurantId) > 1
          ? 'Plusieurs clients Loyalo attendent votre validation.'
          : 'Un client Loyalo attend votre validation.',
      type: 'check_in_requested',
      relatedId: docRef.id,
    );
    return CheckInCreateResult(
      outcome: CheckInCreateOutcome.created,
      request: request,
      message: tooFar
          ? 'Arrivée signalée. Distance GPS à confirmer par le commerçant.'
          : 'Arrivée signalée. Le commerçant a été informé.',
    );
  }

  Future<CheckInRequest?> _activeCheckInFromFirestore(
    String userId,
    String restaurantId,
  ) async {
    final now = _clock();
    final snap = await _db
        .collection('checkIns')
        .where('customerId', isEqualTo: userId)
        .where('restaurantId', isEqualTo: restaurantId)
        .where('status', isEqualTo: CheckInStatus.pending.firestoreValue)
        .get();
    final active =
        snap.docs
            .map(CheckInRequest.fromFirestore)
            .where((request) => request.expiresAt.isAfter(now))
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return active.firstOrNull;
  }

  /// Enregistre le passage d'un client validé par le commerçant (via son
  /// code personnel ou sa fiche client). Applique la règle anti-triche :
  /// un seul passage validé par jour et par restaurant. Réservé aux
  /// comptes commerçant côté règles de sécurité Firestore.
  ///
  /// Pour la politique par défaut (une visite/jour), l'écriture utilise un
  /// identifiant de document déterministe et une transaction : deux appels
  /// concomitants (double appui, requête réseau rejouée, deux appareils
  /// commerçant) ne peuvent donc pas créer deux visites le même jour — la
  /// même protection que celle déjà utilisée par [approveCheckIn]. Pour les
  /// autres politiques (plusieurs visites/jour autorisées), une clé par jour
  /// ne conviendrait pas : on garde la vérification en mémoire, moins
  /// critique sur ces politiques plus rares.
  Future<VisitResult> registerVisit({
    required String userId,
    required String restaurantId,
  }) async {
    final restaurant = restaurantById(restaurantId);

    if (!_canRegisterVisit(userId, restaurant, _clock())) {
      return VisitResult(
        outcome: VisitOutcome.alreadyValidatedToday,
        restaurant: restaurant,
        passageCount: passageCount(userId, restaurantId),
      );
    }

    // Calculé avant l'écriture : le cache local sera mis à jour par
    // l'écouteur Firestore une fois la visite persistée.
    final newCount = passageCount(userId, restaurantId) + 1;
    final justUnlocked =
        _rewardCycleFor(visitCount: newCount, restaurant: restaurant) >
        _rewardCycleFor(visitCount: newCount - 1, restaurant: restaurant);

    await _rememberRestaurantCustomer(
      restaurantId: restaurantId,
      userId: userId,
    );

    if (restaurant.validationPolicy == VisitValidationPolicy.oncePerDay) {
      final now = _clock();
      final dateKey = '${now.year}-${now.month}-${now.day}';
      final docRef = _db
          .collection('visits')
          .doc('${restaurantId}_${userId}_$dateKey');
      var alreadyExists = false;
      await _db.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (snap.exists) {
          alreadyExists = true;
          return;
        }
        transaction.set(
          docRef,
          Visit(
            id: docRef.id,
            userId: userId,
            restaurantId: restaurantId,
            timestamp: now,
          ).toMap(),
        );
      });
      if (alreadyExists) {
        return VisitResult(
          outcome: VisitOutcome.alreadyValidatedToday,
          restaurant: restaurant,
          passageCount: passageCount(userId, restaurantId),
        );
      }
    } else {
      final docRef = _db.collection('visits').doc();
      final visit = Visit(
        id: docRef.id,
        userId: userId,
        restaurantId: restaurantId,
        timestamp: _clock(),
      );
      await docRef.set(visit.toMap());
    }

    await _createRewardForCurrentCycleIfNeeded(
      userId: userId,
      restaurant: restaurant,
      visitCount: newCount,
    );
    await _completeEligibleReferralsAfterVisit(
      referredUserId: userId,
      restaurantId: restaurantId,
      isFirstVisitForThisRestaurant: newCount == 1,
    );
    await _createNotification(
      recipientType: 'client',
      userId: userId,
      restaurantId: restaurantId,
      title: justUnlocked ? 'Récompense débloquée' : 'Visite validée',
      body: justUnlocked
          ? '${restaurant.rewardLabel} vous attend chez ${restaurant.name}.'
          : '${restaurant.name} a validé votre visite. +${restaurant.pointsPerVisit} points.',
      type: justUnlocked ? 'reward_unlocked' : 'visit_validated',
    );

    return VisitResult(
      outcome: justUnlocked
          ? VisitOutcome.rewardUnlocked
          : VisitOutcome.validated,
      restaurant: restaurant,
      passageCount: newCount,
    );
  }

  Future<CheckInValidationResult> approveCheckIn({
    required String checkInId,
    required String merchantId,
  }) async {
    await expirePendingCheckIns();

    final checkInRef = _db.collection('checkIns').doc(checkInId);
    final snap = await checkInRef.get();
    if (!snap.exists) {
      return const CheckInValidationResult(
        outcome: CheckInValidationOutcome.notFound,
      );
    }

    final request = CheckInRequest.fromFirestore(snap);
    if (request.status != CheckInStatus.pending) {
      return CheckInValidationResult(
        outcome: request.status == CheckInStatus.expired
            ? CheckInValidationOutcome.expired
            : CheckInValidationOutcome.notPending,
      );
    }
    final now = _clock();
    if (!request.expiresAt.isAfter(now)) {
      await checkInRef.update({'status': CheckInStatus.expired.firestoreValue});
      return const CheckInValidationResult(
        outcome: CheckInValidationOutcome.expired,
      );
    }

    final restaurant = restaurantById(request.restaurantId);
    if (!await _merchantCanValidateRestaurant(
      merchantId: merchantId,
      restaurant: restaurant,
    )) {
      return CheckInValidationResult(
        outcome: CheckInValidationOutcome.unauthorized,
        restaurant: restaurant,
      );
    }

    if (!_canRegisterVisit(request.customerId, restaurant, now)) {
      await checkInRef.update({
        'status': CheckInStatus.rejected.firestoreValue,
        'rejectedAt': Timestamp.fromDate(now),
        'rejectedBy': merchantId,
      });
      return CheckInValidationResult(
        outcome: CheckInValidationOutcome.alreadyValidated,
        restaurant: restaurant,
        passageCount: passageCount(request.customerId, request.restaurantId),
      );
    }

    final newCount = passageCount(request.customerId, request.restaurantId) + 1;
    final previousCycle = _rewardCycleFor(
      visitCount: newCount - 1,
      restaurant: restaurant,
    );
    final nextCycle = _rewardCycleFor(
      visitCount: newCount,
      restaurant: restaurant,
    );
    final justUnlocked = nextCycle > previousCycle;
    final dateKey = '${now.year}-${now.month}-${now.day}';
    final visitId =
        restaurant.validationPolicy == VisitValidationPolicy.oncePerDay
        ? '${restaurant.id}_${request.customerId}_$dateKey'
        : 'checkin_$checkInId';
    final visitRef = _db.collection('visits').doc(visitId);
    final rewardRef = justUnlocked
        ? _db
              .collection('rewards')
              .doc(
                _rewardDocumentId(
                  userId: request.customerId,
                  restaurantId: restaurant.id,
                  cycle: nextCycle,
                ),
              )
        : null;
    var committed = false;
    var alreadyValidated = false;

    await _db.runTransaction((transaction) async {
      final liveSnap = await transaction.get(checkInRef);
      final existingVisitSnap = await transaction.get(visitRef);
      final rewardSnap = rewardRef == null
          ? null
          : await transaction.get(rewardRef);
      if (!liveSnap.exists) return;
      final live = CheckInRequest.fromFirestore(liveSnap);
      if (live.status != CheckInStatus.pending ||
          !live.expiresAt.isAfter(_clock())) {
        return;
      }
      if (existingVisitSnap.exists) {
        transaction.update(checkInRef, {
          'status': CheckInStatus.rejected.firestoreValue,
          'rejectedAt': Timestamp.fromDate(_clock()),
          'rejectedBy': merchantId,
        });
        alreadyValidated = true;
        return;
      }

      final visit = Visit(
        id: visitRef.id,
        userId: request.customerId,
        restaurantId: request.restaurantId,
        timestamp: _clock(),
      );
      transaction.set(visitRef, visit.toMap());
      if (rewardRef != null) {
        if (rewardSnap?.exists == true) {
          transaction.update(checkInRef, {
            'status': CheckInStatus.approved.firestoreValue,
            'validatedAt': Timestamp.fromDate(_clock()),
            'validatedBy': merchantId,
            'pointsAwarded': restaurant.pointsPerVisit,
            'visitId': visitRef.id,
          });
          committed = true;
          return;
        }
        final reward = RewardItem(
          id: rewardRef.id,
          userId: request.customerId,
          restaurantName: restaurant.name,
          restaurantId: restaurant.id,
          label: restaurant.rewardLabel,
          expiresAt: _clock().add(const Duration(days: 30)),
          status: RewardStatus.available,
          cycle: nextCycle,
        );
        transaction.set(rewardRef, reward.toMap());
      }
      transaction.update(checkInRef, {
        'status': CheckInStatus.approved.firestoreValue,
        'validatedAt': Timestamp.fromDate(_clock()),
        'validatedBy': merchantId,
        'pointsAwarded': restaurant.pointsPerVisit,
        'visitId': visitRef.id,
      });
      committed = true;
    });

    if (alreadyValidated) {
      return CheckInValidationResult(
        outcome: CheckInValidationOutcome.alreadyValidated,
        restaurant: restaurant,
        passageCount: passageCount(request.customerId, request.restaurantId),
      );
    }

    if (!committed) {
      final liveSnap = await checkInRef.get();
      if (!liveSnap.exists) {
        return CheckInValidationResult(
          outcome: CheckInValidationOutcome.notFound,
          restaurant: restaurant,
        );
      }
      final live = CheckInRequest.fromFirestore(liveSnap);
      return CheckInValidationResult(
        outcome: live.status == CheckInStatus.expired
            ? CheckInValidationOutcome.expired
            : CheckInValidationOutcome.notPending,
        restaurant: restaurant,
        passageCount: passageCount(request.customerId, request.restaurantId),
      );
    }

    await _rememberRestaurantCustomer(
      restaurantId: request.restaurantId,
      userId: request.customerId,
    );
    await _completeEligibleReferralsAfterVisit(
      referredUserId: request.customerId,
      restaurantId: request.restaurantId,
      isFirstVisitForThisRestaurant: newCount == 1,
    );

    await _createNotification(
      recipientType: 'client',
      userId: request.customerId,
      restaurantId: request.restaurantId,
      title: justUnlocked ? 'Récompense débloquée' : 'Visite validée',
      body: justUnlocked
          ? '${restaurant.rewardLabel} vous attend chez ${restaurant.name}.'
          : 'Votre passage chez ${restaurant.name} a été validé.',
      type: justUnlocked ? 'reward_unlocked' : 'visit_validated',
      relatedId: checkInId,
    );

    return CheckInValidationResult(
      outcome: justUnlocked
          ? CheckInValidationOutcome.rewardUnlocked
          : CheckInValidationOutcome.validated,
      restaurant: restaurant,
      passageCount: newCount,
      pointsAwarded: restaurant.pointsPerVisit,
    );
  }

  Future<bool> _merchantCanValidateRestaurant({
    required String merchantId,
    required Restaurant restaurant,
  }) async {
    if (restaurant.ownerId == merchantId) return true;
    final snap = await _db.collection('merchants').doc(merchantId).get();
    if (snap.exists && snap.data()?['restaurantId'] == restaurant.id) {
      return true;
    }
    return restaurant.ownerId == null && !snap.exists;
  }

  /// Passages les plus récents pour un restaurant, utilisés pour le fil
  /// d'activité de l'espace commerçant.
  List<Visit> recentActivityForRestaurant(
    String restaurantId, {
    int limit = 5,
  }) {
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

  Future<bool> redeemReward({
    required String rewardId,
    required String merchantId,
  }) async {
    final ref = _db.collection('rewards').doc(rewardId);
    final initialSnap = await ref.get();
    if (!initialSnap.exists) return false;
    final initialReward = RewardItem.fromFirestore(initialSnap);
    final restaurantId = initialReward.restaurantId;
    if (restaurantId == null) return false;
    final restaurant = restaurantByIdOrNull(restaurantId);
    if (restaurant == null ||
        !await _merchantCanValidateRestaurant(
          merchantId: merchantId,
          restaurant: restaurant,
        )) {
      return false;
    }

    var redeemed = false;
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) return;
      final reward = RewardItem.fromFirestore(snap);
      if (reward.restaurantId != restaurantId ||
          reward.status == RewardStatus.used) {
        return;
      }
      transaction.update(ref, {
        'status': 'used',
        'redeemedAt': Timestamp.fromDate(_clock()),
        'redeemedBy': merchantId,
      });
      redeemed = true;
    });
    return redeemed;
  }

  Future<void> _completeEligibleReferralsAfterVisit({
    required String referredUserId,
    required String restaurantId,
    required bool isFirstVisitForThisRestaurant,
  }) async {
    if (!isFirstVisitForThisRestaurant) return;

    final pending = _referrals.where((referral) {
      if (referral.referredUserId != referredUserId) return false;
      if (referral.status != ReferralStatus.pending) return false;
      return referral.restaurantId == null ||
          referral.restaurantId == restaurantId;
    }).toList();

    for (final referral in pending) {
      final ref = _db.collection('referrals').doc(referral.id);
      var rewarded = false;
      await _db.runTransaction((transaction) async {
        final snap = await transaction.get(ref);
        if (!snap.exists) return;
        final live = ReferredFriend.fromFirestore(snap);
        if (live.status != ReferralStatus.pending) return;
        if (live.referredUserId != referredUserId) return;
        if (live.restaurantId != null && live.restaurantId != restaurantId) {
          return;
        }
        transaction.update(ref, {
          'restaurantId': live.restaurantId ?? restaurantId,
          'status': ReferralStatus.rewarded.firestoreValue,
          'pointsEarned': _referralBonusPoints,
          'completedAt': Timestamp.fromDate(_clock()),
          'rewardedAt': Timestamp.fromDate(_clock()),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        rewarded = true;
      });
      if (!rewarded) continue;
      await _createNotification(
        recipientType: 'client',
        userId: referral.referrerId,
        restaurantId: restaurantId,
        title: 'Parrainage réussi',
        body: '${referral.name} a effectué sa première visite validée.',
        type: 'referral_rewarded',
        relatedId: referral.id,
      );
    }
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
    return _visits
        .where((v) => v.restaurantId == restaurantId && v.isSameDay(now))
        .length;
  }

  List<Visit> visitsForRestaurantSince(String restaurantId, DateTime since) {
    final visits =
        _visits
            .where(
              (v) =>
                  v.restaurantId == restaurantId &&
                  !v.timestamp.isBefore(since),
            )
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return visits;
  }

  List<Visit> visitsForRestaurantBetween(
    String restaurantId,
    DateTime start,
    DateTime end,
  ) {
    final visits =
        _visits
            .where(
              (v) =>
                  v.restaurantId == restaurantId &&
                  !v.timestamp.isBefore(start) &&
                  v.timestamp.isBefore(end),
            )
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return visits;
  }

  int uniqueClientsForRestaurant(String restaurantId) {
    return _visits
        .where((v) => v.restaurantId == restaurantId)
        .map((v) => v.userId)
        .toSet()
        .length;
  }

  int activeClientsSince(String restaurantId, DateTime since) {
    return _visits
        .where(
          (v) => v.restaurantId == restaurantId && !v.timestamp.isBefore(since),
        )
        .map((v) => v.userId)
        .toSet()
        .length;
  }

  bool isFirstVisitForRestaurant(Visit visit) {
    return !_visits.any(
      (candidate) =>
          candidate.restaurantId == visit.restaurantId &&
          candidate.userId == visit.userId &&
          candidate.timestamp.isBefore(visit.timestamp),
    );
  }

  int newClientsBetween(String restaurantId, DateTime start, DateTime end) {
    final firstVisitByUser = <String, DateTime>{};
    for (final visit in _visits.where((v) => v.restaurantId == restaurantId)) {
      final current = firstVisitByUser[visit.userId];
      if (current == null || visit.timestamp.isBefore(current)) {
        firstVisitByUser[visit.userId] = visit.timestamp;
      }
    }
    return firstVisitByUser.values
        .where(
          (firstVisit) =>
              !firstVisit.isBefore(start) && firstVisit.isBefore(end),
        )
        .length;
  }

  int pointsGrantedBetween(String restaurantId, DateTime start, DateTime end) {
    final restaurant = restaurantByIdOrNull(restaurantId);
    final pointsPerVisit = restaurant?.pointsPerVisit ?? 0;
    return visitsForRestaurantBetween(restaurantId, start, end).length *
        pointsPerVisit;
  }

  int rewardsUnlockedBetween(
    String restaurantId,
    DateTime start,
    DateTime end,
  ) {
    return _rewardItems.where((reward) {
      if (reward.restaurantId != restaurantId) return false;
      // Les récompenses existantes ne stockent pas encore `createdAt`.
      // Dans ce repository, elles expirent 30 jours après leur création.
      final unlockedAt = reward.expiresAt.subtract(const Duration(days: 30));
      return !unlockedAt.isBefore(start) && unlockedAt.isBefore(end);
    }).length;
  }

  int usedRewardsForRestaurant(String restaurantId) {
    return _rewardItems
        .where(
          (reward) =>
              reward.restaurantId == restaurantId &&
              reward.status == RewardStatus.used,
        )
        .length;
  }

  int pendingReferralsForRestaurant(String restaurantId) {
    return _referrals
        .where(
          (referral) =>
              referral.restaurantId == restaurantId &&
              referral.status == ReferralStatus.pending,
        )
        .length;
  }

  int rewardedReferralsForRestaurant(String restaurantId) {
    return _referrals
        .where(
          (referral) =>
              referral.restaurantId == restaurantId &&
              referral.status == ReferralStatus.rewarded,
        )
        .length;
  }

  int activeOffersForRestaurant(String restaurantId) {
    final now = _clock();
    return _exclusiveOffers.where((offer) {
      return offer.restaurantId == restaurantId &&
          offer.active &&
          !now.isBefore(offer.startsAt) &&
          !now.isAfter(offer.endsAt);
    }).length;
  }

  int pendingCheckInsCount(String restaurantId) {
    final now = _clock();
    return _checkIns.where((request) {
      return request.restaurantId == restaurantId &&
          request.status == CheckInStatus.pending &&
          request.expiresAt.isAfter(now);
    }).length;
  }

  int approvedCheckInsBetween(
    String restaurantId,
    DateTime start,
    DateTime end,
  ) {
    return _checkIns.where((request) {
      final validatedAt = request.validatedAt;
      return request.restaurantId == restaurantId &&
          request.status == CheckInStatus.approved &&
          validatedAt != null &&
          !validatedAt.isBefore(start) &&
          validatedAt.isBefore(end);
    }).length;
  }

  int newClientsSince(String restaurantId, DateTime since) {
    final seenBeforePeriod = <String>{};
    final newInPeriod = <String>{};
    final visits = _visits.where((v) => v.restaurantId == restaurantId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (final v in visits) {
      if (v.timestamp.isBefore(since)) {
        seenBeforePeriod.add(v.userId);
      } else if (!seenBeforePeriod.contains(v.userId)) {
        newInPeriod.add(v.userId);
      }
    }
    return newInPeriod.length;
  }

  // ---------------------------------------------------------------------
  // Catalogue de récompenses par restaurant (espace commerçant)
  // ---------------------------------------------------------------------

  List<RewardDefinition> rewardDefinitionsFor(String restaurantId) =>
      _rewardDefinitions.where((r) => r.restaurantId == restaurantId).toList();

  Future<void> toggleRewardDefinition(String id) async {
    final current = _rewardDefinitions.where((r) => r.id == id).firstOrNull;
    if (current == null) return;
    await _db.collection('rewardDefinitions').doc(id).update({
      'active': !current.active,
    });
  }

  Future<void> createRewardDefinition(
    String restaurantId,
    String label,
    int thresholdVisits,
  ) async {
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

  int _rewardCycleFor({
    required int visitCount,
    required Restaurant restaurant,
  }) {
    if (!restaurant.loyaltyProgramEnabled) return 0;
    final threshold = restaurant.rewardThreshold <= 0
        ? 1
        : restaurant.rewardThreshold;
    final value = restaurant.loyaltyProgramType == LoyaltyProgramType.points
        ? visitCount * restaurant.pointsPerVisit
        : visitCount;
    return value ~/ threshold;
  }

  String _rewardDocumentId({
    required String userId,
    required String restaurantId,
    required int cycle,
  }) {
    return '${restaurantId}_${userId}_cycle_$cycle';
  }

  Future<void> _createRewardForCurrentCycleIfNeeded({
    required String userId,
    required Restaurant restaurant,
    required int visitCount,
  }) async {
    final cycle = _rewardCycleFor(
      visitCount: visitCount,
      restaurant: restaurant,
    );
    final previousCycle = _rewardCycleFor(
      visitCount: visitCount - 1,
      restaurant: restaurant,
    );
    if (cycle <= previousCycle || cycle <= 0) return;
    final rewardRef = _db
        .collection('rewards')
        .doc(
          _rewardDocumentId(
            userId: userId,
            restaurantId: restaurant.id,
            cycle: cycle,
          ),
        );
    final exists = await rewardRef.get();
    if (exists.exists) return;
    final reward = RewardItem(
      id: rewardRef.id,
      userId: userId,
      restaurantName: restaurant.name,
      restaurantId: restaurant.id,
      label: restaurant.rewardLabel,
      expiresAt: _clock().add(const Duration(days: 30)),
      status: RewardStatus.available,
      cycle: cycle,
    );
    await rewardRef.set(reward.toMap());
  }

  // ---------------------------------------------------------------------
  // Offres exclusives temporaires (espace commerçant -> client)
  // ---------------------------------------------------------------------

  List<ExclusiveOffer> exclusiveOffersForRestaurant(String restaurantId) {
    final offers =
        _exclusiveOffers.where((o) => o.restaurantId == restaurantId).toList()
          ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return offers;
  }

  List<ExclusiveOffer> activeExclusiveOffersForUser(String userId) {
    final offers =
        _exclusiveOffers
            .where((o) => _isOfferAccessibleToUser(o, userId))
            .toList()
          ..sort((a, b) => a.endsAt.compareTo(b.endsAt));
    return offers;
  }

  List<ExclusiveOffer> currentExclusiveOffersForUser(String userId) {
    final offers =
        _exclusiveOffers.where((o) {
          return _isOfferCurrent(o) && _matchesNewCustomerCondition(o, userId);
        }).toList()..sort((a, b) {
          final aUnlocked = _isOfferAccessibleToUser(a, userId);
          final bUnlocked = _isOfferAccessibleToUser(b, userId);
          if (aUnlocked != bUnlocked) return aUnlocked ? -1 : 1;
          return a.endsAt.compareTo(b.endsAt);
        });
    return offers;
  }

  List<ExclusiveOffer> activeExclusiveOffersForRestaurant({
    required String restaurantId,
    required String userId,
  }) {
    final visits = passageCount(userId, restaurantId);
    final offers = _exclusiveOffers.where((o) {
      return o.restaurantId == restaurantId &&
          _isOfferCurrent(o) &&
          _matchesNewCustomerCondition(o, userId) &&
          visits >= o.minVisitsRequired;
    }).toList()..sort((a, b) => a.endsAt.compareTo(b.endsAt));
    return offers;
  }

  List<ExclusiveOffer> currentExclusiveOffersForRestaurant({
    required String restaurantId,
    required String userId,
  }) {
    final offers =
        _exclusiveOffers.where((o) {
          return o.restaurantId == restaurantId &&
              _isOfferCurrent(o) &&
              _matchesNewCustomerCondition(o, userId);
        }).toList()..sort((a, b) {
          final visits = passageCount(userId, restaurantId);
          final aUnlocked = visits >= a.minVisitsRequired;
          final bUnlocked = visits >= b.minVisitsRequired;
          if (aUnlocked != bUnlocked) return aUnlocked ? -1 : 1;
          return a.endsAt.compareTo(b.endsAt);
        });
    return offers;
  }

  Future<void> createExclusiveOffer({
    required String restaurantId,
    required String title,
    required String description,
    required DateTime startsAt,
    required DateTime endsAt,
    int minVisitsRequired = 0,
    bool active = true,
    bool newCustomersOnly = false,
    String? imageUrl,
  }) async {
    if (title.trim().isEmpty) {
      throw ArgumentError('Le titre de l’offre est obligatoire.');
    }
    if (endsAt.isBefore(startsAt)) {
      throw ArgumentError('La date de fin doit être après la date de début.');
    }
    final docRef = _db.collection('exclusiveOffers').doc();
    final offer = ExclusiveOffer(
      id: docRef.id,
      restaurantId: restaurantId,
      title: title,
      description: description,
      startsAt: startsAt,
      endsAt: endsAt,
      active: active,
      minVisitsRequired: minVisitsRequired,
      newCustomersOnly: newCustomersOnly,
      imageUrl: imageUrl ?? _offerImageFor(title),
      distanceKm: restaurantByIdOrNull(restaurantId)?.distanceKm,
    );
    await docRef.set(offer.toMap());
    if (active && _isOfferCurrent(offer)) {
      await _notifyEligibleClientsOfNewOffer(offer);
    }
  }

  Future<void> updateExclusiveOffer({
    required String offerId,
    required String restaurantId,
    required String title,
    required String description,
    required DateTime startsAt,
    required DateTime endsAt,
    required bool active,
    required int minVisitsRequired,
    required bool newCustomersOnly,
  }) async {
    final current = _exclusiveOffers.where((o) => o.id == offerId).firstOrNull;
    if (current == null || current.restaurantId != restaurantId) {
      throw StateError('Offre introuvable pour ce commerce.');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError('Le titre de l’offre est obligatoire.');
    }
    if (endsAt.isBefore(startsAt)) {
      throw ArgumentError('La date de fin doit être après la date de début.');
    }
    await _db.collection('exclusiveOffers').doc(offerId).update({
      'title': title.trim(),
      'description': description.trim(),
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
      'active': active,
      'minVisitsRequired': minVisitsRequired < 0 ? 0 : minVisitsRequired,
      'newCustomersOnly': newCustomersOnly,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _offerImageFor(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('café') ||
        lower.contains('cafe') ||
        lower.contains('boisson')) {
      return 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=500&q=80';
    }
    if (lower.contains('sushi')) {
      return 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?auto=format&fit=crop&w=500&q=80';
    }
    if (lower.contains('dessert') || lower.contains('pâtisserie')) {
      return 'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=500&q=80';
    }
    if (lower.contains('pizza') || lower.contains('italia')) {
      return 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=500&q=80';
    }
    return 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=500&q=80';
  }

  Future<void> toggleExclusiveOffer(String id) async {
    final current = _exclusiveOffers.where((o) => o.id == id).firstOrNull;
    if (current == null) return;
    await _db.collection('exclusiveOffers').doc(id).update({
      'active': !current.active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExclusiveOffer({
    required String offerId,
    required String restaurantId,
  }) async {
    final current = _exclusiveOffers.where((o) => o.id == offerId).firstOrNull;
    if (current == null || current.restaurantId != restaurantId) {
      throw StateError('Offre introuvable pour ce commerce.');
    }
    await _db.collection('exclusiveOffers').doc(offerId).delete();
  }

  bool _isOfferCurrent(ExclusiveOffer offer) {
    final now = _clock();
    return offer.active &&
        !now.isBefore(offer.startsAt) &&
        !now.isAfter(offer.endsAt);
  }

  bool _matchesNewCustomerCondition(ExclusiveOffer offer, String userId) {
    return !offer.newCustomersOnly ||
        passageCount(userId, offer.restaurantId) == 0;
  }

  bool _isOfferAccessibleToUser(ExclusiveOffer offer, String userId) {
    return _isOfferCurrent(offer) &&
        _matchesNewCustomerCondition(offer, userId) &&
        passageCount(userId, offer.restaurantId) >= offer.minVisitsRequired;
  }

  int _pendingCheckInsForRestaurantCount(String restaurantId) {
    final now = _clock();
    return _checkIns
        .where(
          (request) =>
              request.restaurantId == restaurantId &&
              request.status == CheckInStatus.pending &&
              request.expiresAt.isAfter(now),
        )
        .length;
  }

  Future<String?> _merchantUserIdForRestaurant(String restaurantId) async {
    final ownerId = restaurantByIdOrNull(restaurantId)?.ownerId;
    if (ownerId != null && ownerId.isNotEmpty) return ownerId;
    final snap = await _db
        .collection('merchants')
        .where('restaurantId', isEqualTo: restaurantId)
        .limit(1)
        .get();
    return snap.docs.firstOrNull?.id;
  }

  Future<void> updateNotificationPreference({
    required String userId,
    required String key,
    required bool enabled,
  }) async {
    await _db.collection('users').doc(userId).set({
      'notificationPreferences': {key: enabled},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> _notificationPreferenceEnabled({
    required String userId,
    required String key,
  }) async {
    final snap = await _db.collection('users').doc(userId).get();
    final prefs = snap.data()?['notificationPreferences'];
    if (prefs is Map<String, dynamic>) {
      return prefs[key] as bool? ?? true;
    }
    return true;
  }

  String _preferenceKeyForNotification(String type) {
    switch (type) {
      case 'new_offer':
        return 'offers';
      case 'reward_unlocked':
        return 'rewards';
      case 'referral_rewarded':
        return 'referrals';
      case 'visit_validated':
      case 'check_in_rejected':
        return 'visits';
      case 'check_in_requested':
        return 'merchantCheckIns';
      default:
        return 'important';
    }
  }

  Future<void> _notifyEligibleClientsOfNewOffer(ExclusiveOffer offer) async {
    final userIds = _visits
        .where((visit) => visit.restaurantId == offer.restaurantId)
        .map((visit) => visit.userId)
        .toSet();
    if (offer.newCustomersOnly) return;
    for (final userId in userIds) {
      if (!_isOfferAccessibleToUser(offer, userId)) continue;
      await _createNotification(
        recipientType: 'client',
        userId: userId,
        restaurantId: offer.restaurantId,
        title:
            'Nouvelle offre chez ${restaurantByIdOrNull(offer.restaurantId)?.name ?? 'un commerce'}',
        body: offer.title,
        type: 'new_offer',
        relatedId: offer.id,
      );
    }
  }

  Future<void> _createNotification({
    required String recipientType,
    required String title,
    required String body,
    required String type,
    String? userId,
    String? restaurantId,
    String? relatedId,
  }) async {
    final resolvedUserId =
        userId ??
        (recipientType == 'merchant' && restaurantId != null
            ? await _merchantUserIdForRestaurant(restaurantId)
            : null);
    if (resolvedUserId == null || resolvedUserId.isEmpty) return;
    final preferenceKey = _preferenceKeyForNotification(type);
    final enabled = await _notificationPreferenceEnabled(
      userId: resolvedUserId,
      key: preferenceKey,
    );
    if (!enabled && preferenceKey != 'important') return;
    if (type == 'check_in_requested' &&
        _pendingCheckInsForRestaurantCount(restaurantId ?? '') > 1) {
      final recentGrouped = _notifications.any(
        (notification) =>
            notification.type == LoyaloNotificationType.checkInPending &&
            notification.restaurantId == restaurantId &&
            notification.createdAt.isAfter(
              _clock().subtract(const Duration(minutes: 5)),
            ),
      );
      if (recentGrouped) return;
    }
    final data = <String, dynamic>{
      'recipientType': recipientType,
      'userId': resolvedUserId,
      'title': title,
      'body': body,
      'type': type,
      'createdAt': Timestamp.fromDate(_clock()),
      'read': false,
      'isRead': false,
    };
    if (restaurantId != null) data['restaurantId'] = restaurantId;
    if (relatedId != null) data['relatedId'] = relatedId;
    try {
      await _db.collection('notifications').add(data);
    } on FirebaseException catch (e, st) {
      debugPrint('Notification Firestore non créée: $e\n$st');
    }
  }
}

class _UserDoc {
  final String id;
  final String name;
  final String email;
  final String phone;

  const _UserDoc({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory _UserDoc.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return _UserDoc(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '—',
    );
  }

  DirectoryClient toDirectoryClient() =>
      DirectoryClient(id: id, name: name, email: email, phone: phone);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
