import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:loyalo/core/data/repository_read_state.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/core/network/network_monitor.dart';
import 'package:loyalo/models/restaurant.dart';
import 'package:loyalo/models/restaurant_profile_section.dart';
import 'package:loyalo/services/loyalty_repository.dart';
import 'package:loyalo/services/merchant_image_service.dart';

class _Offline implements NetworkMonitor {
  @override
  Future<bool> get isNetworkAvailable async => false;
  @override
  Stream<bool> get onAvailabilityChanged => const Stream.empty();
}

class EstablishmentImages extends MerchantImageService {
  EstablishmentImages()
    : super(
        storage: FirebaseStorage.instanceFor(
          bucket: 'gs://local-establishment-test',
        ),
      );
  final requests = <({String owner, MerchantImageSlot slot, bool isolated})>[];
  final deleted = <String>[];
  Object? error;
  bool cancel = false;
  int serial = 0;
  @override
  Future<MerchantImageUpload?> pickAndUpload({
    required String merchantId,
    required MerchantImageSlot slot,
    bool preserveCurrentImage = false,
  }) async {
    requests.add((
      owner: merchantId,
      slot: slot,
      isolated: preserveCurrentImage,
    ));
    if (error != null) throw error!;
    if (cancel) return null;
    return MerchantImageUpload(
      downloadUrl: 'https://images.example/new-${slot.name}-${++serial}.jpg',
      storagePath: 'merchants/$merchantId/${slot.name}/isolated-$serial.jpg',
    );
  }

  @override
  Future<void> deleteByUrl(String? url) async {
    if (url != null) deleted.add(url);
  }
}

class EstablishmentTestRepository extends LoyaltyRepository {
  EstablishmentTestRepository(this.db, this.database)
    : super(firestore: db, database: database, networkMonitor: _Offline());
  final FakeFirebaseFirestore db;
  final AppDatabase database;
  final writes =
      <
        ({
          RestaurantProfileSection section,
          Map<String, dynamic> changes,
          Map<String, dynamic> previous,
        })
      >[];
  Object? writeError;
  Completer<void>? heldWrite;
  bool failAfterCommit = false;
  int completedWrites = 0;

  @override
  Future<Restaurant> updateRestaurantSection({
    required String restaurantId,
    required String ownerId,
    required RestaurantProfileSection section,
    required Map<String, dynamic> changes,
    Map<String, dynamic> previousValues = const {},
  }) async {
    writes.add((
      section: section,
      changes: Map.of(changes),
      previous: Map.of(previousValues),
    ));
    try {
      await heldWrite?.future;
      if (writeError != null) throw writeError!;
      final result = await super.updateRestaurantSection(
        restaurantId: restaurantId,
        ownerId: ownerId,
        section: section,
        changes: changes,
        previousValues: previousValues,
      );
      if (failAfterCommit) throw StateError('Réponse réseau perdue');
      return result;
    } finally {
      completedWrites++;
    }
  }
}

class EstablishmentFixture {
  EstablishmentFixture._(this.firestore, this.database, this.repo, this.images);
  static const id = 'establishment-shop';
  static const owner = 'merchant-one';
  final FakeFirebaseFirestore firestore;
  final AppDatabase database;
  final EstablishmentTestRepository repo;
  final EstablishmentImages images;
  Restaurant get restaurant => repo.restaurantById(id);
  DocumentReference<Map<String, dynamic>> get doc =>
      firestore.collection('restaurants').doc(id);

  static Future<EstablishmentFixture> create({
    RestaurantStatus status = RestaurantStatus.active,
    bool? active,
    bool draft = false,
    bool omitHours = false,
    bool emptyOptional = false,
    int gallery = 1,
  }) async {
    final db = FakeFirebaseFirestore();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final restaurant = Restaurant(
      id: id,
      ownerId: owner,
      name: 'Maison du coin',
      cuisine: 'Café',
      category: 'Café',
      description: emptyOptional ? '' : 'Un café de quartier.',
      phone: emptyOptional ? '' : '0200000000',
      email: 'contact@example.org',
      website: emptyOptional ? '' : 'https://example.org',
      address: emptyOptional ? '' : '1 rue du Marché',
      postalCode: emptyOptional ? '' : '35000',
      city: emptyOptional ? '' : 'Rennes',
      country: 'France',
      distanceKm: 2,
      rewardThreshold: 10,
      rewardLabel: draft ? '' : 'Un café offert',
      pointsPerVisit: 35,
      loyaltyProgramEnabled: !draft,
      active: draft ? false : active ?? status == RestaurantStatus.active,
      status: draft ? RestaurantStatus.draft : status,
      icon: Icons.local_cafe,
      latitude: 48.11,
      longitude: -1.68,
      logoUrl: emptyOptional ? null : 'https://images.example/logo.jpg',
      coverImageUrl: emptyOptional ? null : 'https://images.example/cover.jpg',
      galleryUrls: emptyOptional
          ? []
          : List.generate(
              gallery,
              (i) => 'https://images.example/gallery-$i.jpg',
            ),
    );
    final data = restaurant.toMap();
    if (omitHours) data.remove('openingHours');
    data['backendOnly'] = {'preserve': true};
    await db.collection('restaurants').doc(id).set(data);
    await db.collection('merchants').doc(owner).set({'restaurantId': id});
    final repo = EstablishmentTestRepository(db, database)
      ..startListeningForMerchant(id, ownerUid: owner);
    final fixture = EstablishmentFixture._(
      db,
      database,
      repo,
      EstablishmentImages(),
    );
    await fixture.waitFor(
      () =>
          !repo.restaurantsLoading &&
          repo.restaurantByIdOrNull(id) != null &&
          [
            StatisticsDataSource.visits,
            StatisticsDataSource.checkIns,
            StatisticsDataSource.rewards,
            StatisticsDataSource.offers,
          ].every(
            (s) =>
                repo.statisticsReadState(s).status ==
                RepositoryReadStatus.ready,
          ),
    );
    return fixture;
  }

  Future<void> waitFor(bool Function() done) async {
    for (var i = 0; i < 400; i++) {
      if (done()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('Fixture non prête');
  }

  Future<Map<String, dynamic>> data() async => (await doc.get()).data()!;
  Future<void> close({bool disposeRepository = true}) async {
    await repo.stopListening();
    if (disposeRepository) repo.dispose();
    await database.close();
  }
}
