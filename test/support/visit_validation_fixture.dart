// Doubles locaux de présentation : aucune lecture ou écriture Firebase distante.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/core/network/network_monitor.dart';
import 'package:loyalo/models/check_in_request.dart';
import 'package:loyalo/models/restaurant.dart';
import 'package:loyalo/services/loyalty_repository.dart';

class _Offline implements NetworkMonitor {
  @override
  Future<bool> get isNetworkAvailable async => false;
  @override
  Stream<bool> get onAvailabilityChanged => const Stream.empty();
}

class VisitValidationUiRepository extends LoyaltyRepository {
  VisitValidationUiRepository._(this.database)
    : super(
        firestore: FakeFirebaseFirestore(),
        database: database,
        networkMonitor: _Offline(),
      );

  factory VisitValidationUiRepository() => VisitValidationUiRepository._(
    AppDatabase.forTesting(NativeDatabase.memory()),
  );

  final AppDatabase database;
  final codes = <String>[];
  final validations = <({String userId, String restaurantId})>[];
  String? resolvedUser = 'client-ui-09';
  Object? resolveError;
  Object? validationError;
  Completer<String?>? codeGate;
  Completer<VisitResult>? validationGate;
  VisitOutcome outcome = VisitOutcome.validated;

  static const shop = Restaurant(
    id: 'visit-shop',
    ownerId: 'merchant-one',
    name: 'Maison du coin',
    cuisine: 'Boulangerie',
    distanceKm: 0,
    rewardThreshold: 10,
    rewardLabel: 'Une douceur offerte',
    pointsPerVisit: 35,
    icon: Icons.storefront_outlined,
  );

  @override
  List<Restaurant> get restaurants => [shop];
  @override
  Restaurant? restaurantByIdOrNull(String id) => id == shop.id ? shop : null;
  @override
  Restaurant restaurantById(String id) => restaurantByIdOrNull(id)!;
  @override
  Stream<List<CheckInRequest>> watchMerchantValidationQueue(
    String restaurantId, {
    String? ownerUid,
  }) => Stream.value([]);

  @override
  Future<String?> resolveUserIdFromCode(String code) async {
    codes.add(code);
    if (resolveError != null) throw resolveError!;
    return codeGate == null ? resolvedUser : await codeGate!.future;
  }

  @override
  Future<VisitResult> registerVisit({
    required String userId,
    required String restaurantId,
  }) async {
    validations.add((userId: userId, restaurantId: restaurantId));
    if (validationError != null) throw validationError!;
    return validationGate == null ? result() : await validationGate!.future;
  }

  VisitResult result() =>
      VisitResult(outcome: outcome, restaurant: shop, passageCount: 1);
}
