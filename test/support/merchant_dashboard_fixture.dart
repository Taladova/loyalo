// Données exclusivement locales pour les tests et l'aperçu du simulateur.
// Aucun listener Firebase, aucune authentification ni écriture distante.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/core/network/network_monitor.dart';
import 'package:loyalo/models/check_in_request.dart';
import 'package:loyalo/models/restaurant.dart';
import 'package:loyalo/models/visit.dart';
import 'package:loyalo/services/loyalty_repository.dart';

class DashboardTestCore extends FirebasePlatform {
  final value = FirebaseAppPlatform(
    defaultFirebaseAppName,
    const FirebaseOptions(
      apiKey: 'local-dashboard-test',
      appId: 'local-dashboard-test',
      messagingSenderId: 'local-dashboard-test',
      projectId: 'local-dashboard-test',
    ),
  );
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) => value;
}

class DashboardTestAuth extends FirebaseAuthPlatform {
  String? name = 'Camille';
  bool signedIn = true;
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) => this;
  @override
  UserPlatform? get currentUser => signedIn ? _DashboardUser(this, name) : null;
}

class _MultiFactor extends MultiFactorPlatform {
  _MultiFactor(super.auth);
}

class _DashboardUser extends UserPlatform {
  _DashboardUser(FirebaseAuthPlatform auth, String? name)
    : super(
        auth,
        _MultiFactor(auth),
        PigeonUserDetails(
          userInfo: PigeonUserInfo(
            uid: 'merchant-one',
            displayName: name,
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: [],
        ),
      );
}

class _OfflineNetwork implements NetworkMonitor {
  @override
  Future<bool> get isNetworkAvailable async => false;
  @override
  Stream<bool> get onAvailabilityChanged => const Stream.empty();
}

typedef DashboardQuery = ({String id, DateTime start, DateTime end});

class DashboardTestRepository extends LoyaltyRepository {
  DashboardTestRepository._(this.database)
    : super(
        firestore: FakeFirebaseFirestore(),
        database: database,
        networkMonitor: _OfflineNetwork(),
      );

  factory DashboardTestRepository() => DashboardTestRepository._(
    AppDatabase.forTesting(NativeDatabase.memory()),
  );

  final AppDatabase database;
  final now = DateTime.now();
  Restaurant commerce = const Restaurant(
    id: 'shop-one',
    ownerId: 'merchant-one',
    name: 'Maison du coin',
    cuisine: 'Boulangerie',
    distanceKm: 0,
    rewardThreshold: 10,
    rewardLabel: 'Une douceur offerte',
    pointsPerVisit: 35,
    icon: Icons.storefront_outlined,
  );
  bool hasRestaurant = true;
  bool loading = false;
  Object? loadError;
  Object? queueError;
  bool empty = false;
  int totalClients = 12;
  int activeClients = 7;
  int notificationCount = 2;
  int retries = 0;
  final queries = <DashboardQuery>[];
  final restaurantIds = <String>[];
  final queueOwners = <String?>[];
  DateTime? activeSince;
  Stream<List<CheckInRequest>> queue = Stream.value([]);
  Completer<CheckInValidationResult>? validation;
  final approvals = <({String id, String owner})>[];
  final rejections = <({String id, String owner})>[];

  @override
  bool get restaurantsLoading => loading;
  @override
  Object? get restaurantsLoadError => loadError;
  @override
  Object? get checkInsLoadError => queueError;
  @override
  List<Restaurant> get restaurants => hasRestaurant ? [commerce] : [];
  @override
  Restaurant? restaurantByIdOrNull(String id) =>
      hasRestaurant && id == commerce.id ? commerce : null;
  @override
  Restaurant restaurantById(String id) => restaurantByIdOrNull(id)!;

  @override
  int uniqueClientsForRestaurant(String restaurantId) {
    restaurantIds.add(restaurantId);
    return empty ? 0 : totalClients;
  }

  @override
  int activeClientsSince(String restaurantId, DateTime since) {
    restaurantIds.add(restaurantId);
    activeSince = since;
    return empty ? 0 : activeClients;
  }

  // Réponses du repository pilotées par la période demandée. Les calculs de
  // statistiques restent dans les services réels, couverts par leurs tests.
  int _period(DateTime start) {
    for (final days in [1, 7, 30]) {
      if (start == DateTime(now.year, now.month, now.day - days + 1)) {
        return days;
      }
    }
    return 0;
  }

  @override
  List<Visit> visitsForRestaurantBetween(
    String restaurantId,
    DateTime start,
    DateTime end,
  ) {
    restaurantIds.add(restaurantId);
    queries.add((id: restaurantId, start: start, end: end));
    final days = _period(start);
    if (empty || days == 0 || restaurantId != commerce.id) return [];
    return [
      Visit(
        id: 'visit-a',
        userId: 'a',
        restaurantId: restaurantId,
        timestamp: now.subtract(const Duration(minutes: 5)),
      ),
      Visit(
        id: 'visit-b',
        userId: 'b',
        restaurantId: restaurantId,
        timestamp: now.subtract(const Duration(hours: 1)),
      ),
      if (days >= 7) ...[
        Visit(
          id: 'visit-c',
          userId: 'c',
          restaurantId: restaurantId,
          timestamp: now.subtract(const Duration(days: 2)),
        ),
        Visit(
          id: 'visit-d',
          userId: 'a',
          restaurantId: restaurantId,
          timestamp: now.subtract(const Duration(days: 4)),
        ),
      ],
      if (days == 30)
        Visit(
          id: 'visit-e',
          userId: 'd',
          restaurantId: restaurantId,
          timestamp: now.subtract(const Duration(days: 20)),
        ),
    ];
  }

  @override
  int newClientsBetween(String restaurantId, DateTime start, DateTime end) {
    restaurantIds.add(restaurantId);
    if (empty) return 0;
    return switch (_period(start)) {
      1 => 1,
      7 => 3,
      30 => 4,
      _ => start == DateTime(now.year, now.month) ? 3 : 0,
    };
  }

  @override
  String nameForClient(String userId) => switch (userId) {
    'a' => 'Alex Martin',
    'b' => 'Noa Dupont',
    'c' => 'Lou Bernard',
    'd' => 'Charlie Petit',
    _ => 'Client local',
  };
  @override
  bool isFirstVisitForRestaurant(Visit visit) => visit.userId != 'a';
  @override
  int passageCount(String userId, String restaurantId) => userId == 'a' ? 9 : 0;
  @override
  int unreadNotificationsForMerchant(String restaurantId) => notificationCount;
  @override
  Stream<List<CheckInRequest>> watchMerchantValidationQueue(
    String restaurantId, {
    String? ownerUid,
  }) {
    restaurantIds.add(restaurantId);
    queueOwners.add(ownerUid);
    return queue;
  }

  CheckInRequest arrival(
    String id, {
    CheckInStatus status = CheckInStatus.pending,
    String customer = 'a',
  }) => CheckInRequest(
    id: id,
    customerId: customer,
    restaurantId: commerce.id,
    requestedAt: now.subtract(const Duration(minutes: 2)),
    expiresAt: now.add(const Duration(minutes: 8)),
    status: status,
  );

  void showQueue(List<CheckInRequest> arrivals) {
    queueError = null;
    queue = Stream.value(arrivals);
    notifyListeners();
  }

  @override
  Future<CheckInValidationResult> approveCheckIn({
    required String checkInId,
    required String merchantId,
  }) async {
    approvals.add((id: checkInId, owner: merchantId));
    return validation?.future ??
        const CheckInValidationResult(
          outcome: CheckInValidationOutcome.validated,
          pointsAwarded: 35,
          synced: true,
        );
  }

  @override
  Future<CheckInValidationResult> rejectCheckIn({
    required String checkInId,
    required String merchantId,
  }) async {
    rejections.add((id: checkInId, owner: merchantId));
    return validation?.future ??
        const CheckInValidationResult(
          outcome: CheckInValidationOutcome.rejected,
          synced: false,
        );
  }

  @override
  Future<void> retryRestaurants() async {
    retries++;
    hasRestaurant = true;
    loading = false;
    loadError = null;
    notifyListeners();
  }
}
