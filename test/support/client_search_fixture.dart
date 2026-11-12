// Données locales de test, également utilisables dans un aperçu natif isolé.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/core/network/network_monitor.dart';
import 'package:loyalo/models/restaurant.dart';
import 'package:loyalo/services/loyalty_repository.dart';

class SearchReadFirestore extends FakeFirebaseFirestore {
  final reads = <String>[];
  final denied = <String>{};
  Completer<void>? pendingRead;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    final value = super.collection(path);
    return path == 'users' ? _Users(value, this) : value;
  }
}

// Doubles de test du SDK : seule la lecture des documents est interceptée.
// ignore: subtype_of_sealed_class
class _Users implements CollectionReference<Map<String, dynamic>> {
  _Users(this.delegate, this.owner);
  final CollectionReference<Map<String, dynamic>> delegate;
  final SearchReadFirestore owner;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _User(delegate.doc(path), owner);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _User implements DocumentReference<Map<String, dynamic>> {
  _User(this.delegate, this.owner);
  final DocumentReference<Map<String, dynamic>> delegate;
  final SearchReadFirestore owner;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    owner.reads.add(delegate.id);
    await owner.pendingRead?.future;
    if (owner.denied.contains(delegate.id)) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Test read failure, never display technical details',
      );
    }
    return delegate.get(options);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) =>
      delegate.set(data, options);
  @override
  Future<void> update(Map<Object, Object?> data) => delegate.update(data);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Offline implements NetworkMonitor {
  @override
  Future<bool> get isNetworkAvailable async => false;
  @override
  Stream<bool> get onAvailabilityChanged => const Stream.empty();
}

class ClientSearchTestRepository extends LoyaltyRepository {
  ClientSearchTestRepository(this.firestore, this.database)
    : super(
        firestore: firestore,
        database: database,
        networkMonitor: _Offline(),
      );
  final SearchReadFirestore firestore;
  final AppDatabase database;
  bool? forceLoading;
  Object? forceError;
  bool searchThrows = false;
  bool? forceRestaurantPresent;
  bool? forceRestaurantLoading;
  int retryCount = 0;
  Future<void>? retryCompletion;
  final searches = <String>[];

  @override
  bool get merchantClientsLoading =>
      forceLoading ?? super.merchantClientsLoading;
  @override
  Object? get merchantClientsLoadError =>
      forceError ?? super.merchantClientsLoadError;
  @override
  bool get restaurantsLoading =>
      forceRestaurantLoading ?? super.restaurantsLoading;
  @override
  Restaurant? restaurantByIdOrNull(String id) =>
      forceRestaurantPresent == false ? null : super.restaurantByIdOrNull(id);
  @override
  List<DirectoryClient> searchClients(String query) {
    searches.add(query);
    if (searchThrows) throw StateError('private backend detail');
    return super.searchClients(query);
  }

  @override
  Future<void> retryRestaurants() {
    retryCount++;
    forceError = null;
    forceLoading = null;
    return retryCompletion = super.retryRestaurants();
  }
}

class ClientSearchFixture {
  ClientSearchFixture._(this.firestore, this.database, this.repo);
  final SearchReadFirestore firestore;
  final AppDatabase database;
  final ClientSearchTestRepository repo;
  static const shopId = 'search-shop';
  static const ownerId = 'search-owner';

  static Future<ClientSearchFixture> create({
    int clients = 3,
    bool start = true,
  }) async {
    final firestore = SearchReadFirestore();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = ClientSearchTestRepository(firestore, database);
    const shop = Restaurant(
      id: shopId,
      ownerId: ownerId,
      name: 'Atelier du quartier',
      cuisine: 'Café',
      distanceKm: 0,
      rewardThreshold: 10,
      rewardLabel: 'Un café offert',
      icon: Icons.storefront,
    );
    await firestore.collection('restaurants').doc(shopId).set(shop.toMap());
    await firestore.collection('merchants').doc(ownerId).set({
      'restaurantId': shopId,
    });
    final now = DateTime.now();
    for (var i = 0; i < clients; i++) {
      final names = ['Amélie Rivière', 'Noé Laurent', 'Zoé Petit'];
      await firestore.collection('users').doc('client-$i').set({
        'name': i < 3 ? names[i] : 'Client local $i',
        'email': 'client-$i@local.example',
        'phone': i == 0 ? '+33 6 11 22 33 44' : '+33 7 00 00 00 $i',
      });
      await firestore.collection('visits').doc('visit-$i').set({
        'restaurantId': shopId,
        'userId': 'client-$i',
        'timestamp': Timestamp.fromDate(now.subtract(Duration(minutes: i))),
      });
    }
    await firestore.collection('users').doc('foreign-client').set({
      'name': 'Amélie autre commerce',
      'email': 'foreign@local.example',
      'phone': '+33 6 11 22 33 44',
    });
    await firestore.collection('visits').doc('foreign-visit').set({
      'restaurantId': 'foreign-shop',
      'userId': 'foreign-client',
      'timestamp': Timestamp.fromDate(now),
    });
    final value = ClientSearchFixture._(firestore, database, repo);
    if (start) {
      repo.startListeningForMerchant(shopId, ownerUid: ownerId);
      await value.waitFor(
        () => repo.directory.length == clients && !repo.merchantClientsLoading,
      );
    }
    return value;
  }

  Future<void> waitFor(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Local search fixture did not settle');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<void> close() async {
    await repo.stopListening();
    await database.close();
  }
}
