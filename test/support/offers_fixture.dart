// Fixtures strictement locales : FakeFirebaseFirestore et base Drift en mémoire.
// Les appels de publication, modification et suppression utilisent le repository réel.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/core/network/network_monitor.dart';
import 'package:loyalo/models/exclusive_offer.dart';
import 'package:loyalo/models/restaurant.dart';
import 'package:loyalo/services/loyalty_repository.dart';

class _Offline implements NetworkMonitor {
  @override
  Future<bool> get isNetworkAvailable async => false;
  @override
  Stream<bool> get onAvailabilityChanged => const Stream.empty();
}

class OffersUiRepository extends LoyaltyRepository {
  OffersUiRepository(this.firestore, this.database)
    : super(firestore: firestore, database: database, networkMonitor: _Offline());

  final FakeFirebaseFirestore firestore;
  final AppDatabase database;
  int publications = 0;
  Object? publishError;
  Object? toggleError;
  Object? deleteError;
  Completer<void>? publicationGate;

  @override
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
    publications++;
    await publicationGate?.future;
    if (publishError != null) throw publishError!;
    await super.createExclusiveOffer(
      restaurantId: restaurantId,
      title: title,
      description: description,
      startsAt: startsAt,
      endsAt: endsAt,
      minVisitsRequired: minVisitsRequired,
      active: active,
      newCustomersOnly: newCustomersOnly,
      imageUrl: imageUrl,
    );
  }

  @override
  Future<void> toggleExclusiveOffer(String id) async {
    if (toggleError != null) throw toggleError!;
    await super.toggleExclusiveOffer(id);
  }

  @override
  Future<void> deleteExclusiveOffer({
    required String offerId,
    required String restaurantId,
  }) async {
    if (deleteError != null) throw deleteError!;
    await super.deleteExclusiveOffer(offerId: offerId, restaurantId: restaurantId);
  }
}

class OffersUiFixture {
  OffersUiFixture._(this.firestore, this.database, this.repo);
  final FakeFirebaseFirestore firestore;
  final AppDatabase database;
  final OffersUiRepository repo;
  static const shopId = 'offers-shop';
  static const ownerId = 'merchant-one';

  static Future<OffersUiFixture> create() async {
    final firestore = FakeFirebaseFirestore();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = OffersUiRepository(firestore, database);
    const shop = Restaurant(
      id: shopId,
      ownerId: ownerId,
      name: 'Atelier du quartier',
      cuisine: 'Café',
      distanceKm: 0,
      rewardThreshold: 10,
      rewardLabel: 'Un café offert',
      pointsPerVisit: 35,
      icon: Icons.storefront_outlined,
    );
    await firestore.collection('restaurants').doc(shopId).set(shop.toMap());
    await firestore.collection('merchants').doc(ownerId).set({'restaurantId': shopId});
    repo.startListeningForMerchant(shopId, ownerUid: ownerId);
    for (var i = 0; i < 100 && repo.restaurantsLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    if (repo.restaurantsLoading) throw StateError('Fixture non chargée');
    return OffersUiFixture._(firestore, database, repo);
  }

  static ExclusiveOffer sample({
    String id = 'current',
    String title = 'Pause café',
    String description = 'Un café offert avec votre dessert.',
    int minVisits = 3,
    bool active = true,
    bool newCustomersOnly = false,
    int startDays = -1,
    int endDays = 7,
    String restaurantId = shopId,
  }) {
    final today = DateTime.now();
    return ExclusiveOffer(
      id: id,
      restaurantId: restaurantId,
      title: title,
      description: description,
      startsAt: DateTime(today.year, today.month, today.day + startDays),
      endsAt: DateTime(today.year, today.month, today.day + endDays),
      minVisitsRequired: minVisits,
      active: active,
      newCustomersOnly: newCustomersOnly,
    );
  }

  Future<void> seed(List<ExclusiveOffer> offers) async {
    final docs = (await firestore.collection('exclusiveOffers').get()).docs;
    for (final doc in docs) {
      await doc.reference.delete();
    }
    for (final offer in offers) {
      await firestore.collection('exclusiveOffers').doc(offer.id).set(offer.toMap());
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
