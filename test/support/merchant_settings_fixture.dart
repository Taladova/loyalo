import 'dart:async';

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/core/network/network_monitor.dart';
import 'package:loyalo/services/auth_service.dart';
import 'package:loyalo/services/loyalty_repository.dart';

class SettingsTestProvider implements UserInfo {
  SettingsTestProvider(this.providerId);
  @override
  final String providerId;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SettingsTestCredential implements UserCredential {
  SettingsTestCredential(this.user);
  @override
  final User? user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SettingsTestFirebaseAuth implements FirebaseAuth {
  SettingsTestFirebaseAuth() {
    user = SettingsTestUser(this);
  }
  SettingsTestUser? user;
  final events = <String>[];
  Object? reauthError;
  Object? updateError;
  Completer<void>? heldReauth;
  bool changeSessionDuringReauth = false;
  int updates = 0;
  @override
  User? get currentUser => user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SettingsTestUser implements User {
  SettingsTestUser(
    this.auth, {
    this.uid = 'settings-merchant',
    this.email = 'auth-merchant@example.org',
  });
  final SettingsTestFirebaseAuth auth;
  @override
  final String uid;
  @override
  String? email;
  @override
  bool isAnonymous = false;
  String provider = 'password';
  String expectedPassword = 'synthetic-current-17';
  @override
  List<UserInfo> get providerData => [SettingsTestProvider(provider)];
  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    auth.events.add('reauthenticate');
    await auth.heldReauth?.future;
    if (auth.reauthError != null) throw auth.reauthError!;
    if (credential is! EmailAuthCredential ||
        credential.email != email ||
        credential.password != expectedPassword) {
      throw FirebaseAuthException(code: 'wrong-password');
    }
    if (auth.changeSessionDuringReauth) {
      auth.user = SettingsTestUser(auth, uid: 'different-account');
    }
    return SettingsTestCredential(this);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    auth.events.add('update-password');
    if (auth.updateError != null) throw auth.updateError!;
    auth.updates++;
    expectedPassword = newPassword;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SettingsTestAuthService extends AuthService {
  SettingsTestAuthService(this.api) : super(auth: api);
  final SettingsTestFirebaseAuth api;
  Object? logoutError;
  Object? deleteError;
  int logouts = 0;
  int deletions = 0;
  @override
  Future<void> signOut() async {
    api.events.add('sign-out');
    logouts++;
    if (logoutError != null) throw logoutError!;
    api.user = null;
  }

  @override
  Future<void> deleteAccount() async {
    api.events.add('delete-auth');
    deletions++;
    if (deleteError != null) throw deleteError!;
    api.user = null;
  }
}

class _Offline implements NetworkMonitor {
  @override
  Future<bool> get isNetworkAvailable async => false;
  @override
  Stream<bool> get onAvailabilityChanged => const Stream.empty();
}

class SettingsTestRepository extends LoyaltyRepository {
  SettingsTestRepository(this.db, this.database, this.events)
    : super(firestore: db, database: database, networkMonitor: _Offline());
  final FakeFirebaseFirestore db;
  final AppDatabase database;
  final List<String> events;
  Object? readError;
  Object? writeError;
  Object? unlinkError;
  Completer<void>? heldRead;
  Completer<void>? heldWrite;
  bool enforceMissingProfileRule = false;
  final preferenceUsers = <String>[];
  final writes = <({String uid, String key, bool enabled})>[];
  int completedWrites = 0;
  int unlinks = 0;
  int stops = 0;
  @override
  Future<Map<String, bool>> loadMerchantNotificationPreferences(
    String userId,
  ) async {
    preferenceUsers.add(userId);
    await heldRead?.future;
    if (readError != null) throw readError!;
    return super.loadMerchantNotificationPreferences(userId);
  }

  @override
  Future<void> updateNotificationPreference({
    required String userId,
    required String key,
    required bool enabled,
  }) async {
    writes.add((uid: userId, key: key, enabled: enabled));
    try {
      await heldWrite?.future;
      if (writeError != null) throw writeError!;
      if (enforceMissingProfileRule &&
          !(await db.collection('users').doc(userId).get()).exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      }
      await super.updateNotificationPreference(
        userId: userId,
        key: key,
        enabled: enabled,
      );
    } finally {
      completedWrites++;
    }
  }

  @override
  Future<void> unlinkMerchant(String uid) async {
    events.add('unlink-merchant');
    unlinks++;
    if (unlinkError != null) throw unlinkError!;
    await super.unlinkMerchant(uid);
  }

  @override
  Future<void> stopListening() async {
    events.add('stop-listening');
    stops++;
    await super.stopListening();
  }
}

class MerchantSettingsFixture {
  MerchantSettingsFixture._(
    this.db,
    this.database,
    this.repo,
    this.api,
    this.auth,
  );
  static const uid = 'settings-merchant';
  static const shop = 'settings-shop';
  final FakeFirebaseFirestore db;
  final AppDatabase database;
  final SettingsTestRepository repo;
  final SettingsTestFirebaseAuth api;
  final SettingsTestAuthService auth;

  static Future<MerchantSettingsFixture> create({
    bool existingProfile = true,
  }) async {
    final db = FakeFirebaseFirestore();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final api = SettingsTestFirebaseAuth();
    final repo = SettingsTestRepository(db, database, api.events);
    if (existingProfile) {
      await db.collection('users').doc(uid).set({
        'name': 'Préférences existantes',
        'email': 'firestore-email@example.org',
        'referralCode': 'EXISTING',
        'notificationPreferences': {
          'merchantCheckIns': false,
          'important': true,
          'offers': false,
        },
        'unchanged': 'conserver',
      });
    }
    await db.collection('merchants').doc(uid).set({'restaurantId': shop});
    await db.collection('restaurants').doc(shop).set({
      'ownerId': uid,
      'name': 'Commerce conservé',
    });
    return MerchantSettingsFixture._(
      db,
      database,
      repo,
      api,
      SettingsTestAuthService(api),
    );
  }

  Future<void> waitFor(bool Function() ready) async {
    for (var i = 0; i < 400; i++) {
      if (ready()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('Fixture non prête');
  }

  Future<void> close({bool disposeRepository = true}) async {
    await repo.stopListening();
    if (disposeRepository) repo.dispose();
    await database.close();
  }
}
