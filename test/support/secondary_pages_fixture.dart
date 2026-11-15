// Données de contrôle uniquement : Firestore et base locale en mémoire.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/core/network/network_monitor.dart';
import 'package:loyalo/services/loyalty_repository.dart';

import 'merchant_dashboard_fixture.dart';

void configureSecondaryPageMocks() {
  FirebasePlatform.instance = DashboardTestCore();
  FirebaseAuthPlatform.instance = DashboardTestAuth();
}

Map<String, dynamic> notificationDocument({
  required String title,
  required DateTime createdAt,
  String body = 'Message reçu depuis le dépôt de notifications de test.',
  String userId = 'merchant-one',
  String type = 'unknown',
  String recipientType = 'client',
  String restaurantId = 'shop-one',
  bool isRead = false,
}) => {
  'userId': userId,
  'recipientType': recipientType,
  'restaurantId': restaurantId,
  'title': title,
  'body': body,
  'type': type,
  'createdAt': Timestamp.fromDate(createdAt),
  'isRead': isRead,
  'read': isRead,
};

class SecondaryPagesFixture {
  SecondaryPagesFixture._(this.firestore, this.database, this.repository);

  final FakeFirebaseFirestore firestore;
  final AppDatabase database;
  final LoyaltyRepository repository;

  static Future<SecondaryPagesFixture> create({
    bool merchant = false,
    Map<String, Map<String, dynamic>> notifications = const {},
  }) async {
    final firestore = FakeFirebaseFirestore();
    for (final entry in notifications.entries) {
      await firestore
          .collection('notifications')
          .doc(entry.key)
          .set(entry.value);
    }
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = LoyaltyRepository(
      firestore: firestore,
      database: database,
      networkMonitor: const _OfflineNetwork(),
    );
    if (merchant) {
      repository.startListeningForMerchant(
        'shop-one',
        ownerUid: 'merchant-one',
      );
    } else {
      repository.startListeningForClient('merchant-one');
    }
    await Future<void>.delayed(Duration.zero);
    return SecondaryPagesFixture._(firestore, database, repository);
  }

  Future<void> close() async {
    await repository.stopListening();
    await database.close();
  }
}

class _OfflineNetwork implements NetworkMonitor {
  const _OfflineNetwork();

  @override
  Future<bool> get isNetworkAvailable async => false;

  @override
  Stream<bool> get onAvailabilityChanged => const Stream.empty();
}
