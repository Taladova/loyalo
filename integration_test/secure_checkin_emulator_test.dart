import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/core/database/pending_action_payload.dart';
import 'package:loyalo/core/database/tables/local_check_ins.dart';
import 'package:loyalo/core/database/tables/local_visits.dart';
import 'package:loyalo/core/database/tables/pending_actions.dart';
import 'package:loyalo/core/firebase/firebase_emulator_config.dart';
import 'package:loyalo/features/checkins/data/check_in_remote_data_source.dart';
import 'package:loyalo/features/checkins/data/check_in_sync_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const merchantEmail = 'merchant.integration@loyalo.test';
  const clientEmail = 'client.integration@loyalo.test';
  const referrerEmail = 'referrer.integration@loyalo.test';
  const password = 'Test123!';
  const restaurantId = 'integration-restaurant';
  const checkInId = 'integration-approve';
  const rejectedCheckInId = 'integration-reject';

  testWidgets('Flutter SDK -> Auth -> Firestore -> secure Functions', (
    _,
  ) async {
    expect(FirebaseEmulatorConfig.enabled, isTrue);
    expect(secureApproveCheckInEnabled, isTrue);
    expect(secureRejectCheckInEnabled, isTrue);
    final testApp = await Firebase.initializeApp();
    final auth = FirebaseAuth.instanceFor(app: testApp);
    final firestore = FirebaseFirestore.instanceFor(app: testApp);
    await auth.useAuthEmulator(FirebaseEmulatorConfig.host, 9099);
    firestore.useFirestoreEmulator(FirebaseEmulatorConfig.host, 8080);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await auth.signOut();
      await database.close();
    });

    final merchant = await _createAccount(auth, merchantEmail, password);
    await firestore.collection('restaurants').doc(restaurantId).set({
      'ownerId': merchant.uid,
      'active': true,
      'name': 'Restaurant intégration Rennes',
      'cuisine': 'Café',
      'rewardThreshold': 1,
      'rewardLabel': 'Café offert',
      'pointsPerVisit': 120,
      'loyaltyProgramEnabled': true,
      'loyaltyProgramType': 'visits',
      'validationPolicy': 'perTransaction',
      'minimumHoursBetweenVisits': 1,
    });
    await firestore.collection('merchants').doc(merchant.uid).set({
      'restaurantId': restaurantId,
    });

    final referrer = await _createAccount(auth, referrerEmail, password);
    await _createClientProfile(
      firestore,
      referrer.uid,
      referrerEmail,
      'REFCODE',
    );
    await firestore.collection('referralCodes').doc('REFCODE').set({
      'userId': referrer.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final client = await _createAccount(auth, clientEmail, password);
    await _createClientProfile(
      firestore,
      client.uid,
      clientEmail,
      'CLIENTCODE',
    );
    await firestore.collection('referrals').doc('initial_${client.uid}').set({
      'referrerId': referrer.uid,
      'referredUserId': client.uid,
      'referralCode': 'REFCODE',
      'name': 'Client intégration',
      'status': 'pending',
      'pointsEarned': 0,
      'invitedAt': FieldValue.serverTimestamp(),
    });

    final restaurants = await firestore
        .collection('restaurants')
        .where('active', isEqualTo: true)
        .get();
    expect(restaurants.docs.map((doc) => doc.id), contains(restaurantId));

    final now = DateTime.now().toUtc();
    await _createRemoteCheckIn(
      firestore,
      id: checkInId,
      customerId: client.uid,
      restaurantId: restaurantId,
      now: now,
    );
    await _createRemoteCheckIn(
      firestore,
      id: rejectedCheckInId,
      customerId: client.uid,
      restaurantId: restaurantId,
      now: now,
    );

    final remote = selectCheckInRemoteDataSource(
      secureApprovalEnabled: secureApproveCheckInEnabled,
      secureRejectionEnabled: secureRejectCheckInEnabled,
      compatibilityDataSource: FirestoreCheckInRemoteDataSource(firestore),
      secureGateway: FirebaseSecureCheckInApprovalGateway(
        FirebaseFunctions.instanceFor(
          app: testApp,
          region: approveCheckInFunctionRegion,
        )..useFunctionsEmulator(FirebaseEmulatorConfig.host, 5001),
      ),
      secureRejectionGateway: FirebaseSecureCheckInRejectionGateway(
        FirebaseFunctions.instanceFor(
          app: testApp,
          region: approveCheckInFunctionRegion,
        )..useFunctionsEmulator(FirebaseEmulatorConfig.host, 5001),
      ),
    );
    await expectLater(
      remote.approve({
        'operationId': 'approveCheckIn:$checkInId',
        'checkInId': checkInId,
        'visitId': 'forged-client-visit',
      }),
      throwsA(isA<CheckInRemoteException>()),
    );

    await auth.signOut();
    await auth.signInWithEmailAndPassword(
      email: merchantEmail,
      password: password,
    );
    final pending = await firestore
        .collection('checkIns')
        .where('restaurantId', isEqualTo: restaurantId)
        .where('status', isEqualTo: 'pending')
        .get();
    expect(pending.docs, hasLength(2));

    const provisionalVisitId = 'offline-provisional-visit';
    await _seedOfflineApproval(
      database,
      ownerUid: merchant.uid,
      restaurantId: restaurantId,
      customerId: client.uid,
      checkInId: checkInId,
      visitId: provisionalVisitId,
      now: now,
    );
    final syncService = CheckInSyncService(
      database: database,
      remoteDataSource: remote,
    );
    await syncService.retryPendingActions(ownerScopeId: restaurantId);
    final approved = await firestore
        .collection('checkIns')
        .doc(checkInId)
        .get();
    final canonicalVisitId = approved.data()!['visitId'] as String;
    expect(approved.data()!['status'], 'approved');
    expect(approved.data()!['pointsAwarded'], 120);
    expect(approved.data()!['visitId'], canonicalVisitId);
    expect(canonicalVisitId, isNot(provisionalVisitId));
    expect(await database.visitDao.getVisitById(provisionalVisitId), isNull);
    expect(await database.visitDao.getVisitById(canonicalVisitId), isNotNull);
    expect(
      (await database.pendingActionDao.getActionByOperationId(
        'approveCheckIn:$checkInId',
      ))?.status,
      PendingActionStatus.synced,
    );

    final visits = await firestore
        .collection('visits')
        .where('userId', isEqualTo: client.uid)
        .where('restaurantId', isEqualTo: restaurantId)
        .get();
    expect(visits.docs, hasLength(1));
    final rewards = await firestore
        .collection('rewards')
        .where('userId', isEqualTo: client.uid)
        .where('restaurantId', isEqualTo: restaurantId)
        .get();
    expect(rewards.docs, hasLength(1));

    final replayVisitId = await remote.approve({
      'operationId': 'approveCheckIn:$checkInId',
      'checkInId': checkInId,
      'visitId': 'another-provisional-id',
    });
    expect(replayVisitId, canonicalVisitId);
    expect(
      (await firestore
              .collection('visits')
              .where('userId', isEqualTo: client.uid)
              .where('restaurantId', isEqualTo: restaurantId)
              .get())
          .docs,
      hasLength(1),
    );

    await auth.signOut();
    await auth.signInWithEmailAndPassword(
      email: referrerEmail,
      password: password,
    );
    final referral = await firestore
        .collection('referrals')
        .doc('initial_${client.uid}')
        .get();
    expect(referral.data()!['status'], 'rewarded');
    expect(referral.data()!['pointsEarned'], 500);

    await auth.signOut();
    await auth.signInWithEmailAndPassword(
      email: merchantEmail,
      password: password,
    );
    await remote.reject({
      'operationId': 'rejectCheckIn:$rejectedCheckInId',
      'checkInId': rejectedCheckInId,
    });
    final rejected = await firestore
        .collection('checkIns')
        .doc(rejectedCheckInId)
        .get();
    expect(rejected.data()!['status'], 'rejected');
    expect(
      (await firestore
              .collection('visits')
              .where('checkInId', isEqualTo: rejectedCheckInId)
              .where('restaurantId', isEqualTo: restaurantId)
              .get())
          .docs,
      isEmpty,
    );
  });
}

Future<User> _createAccount(
  FirebaseAuth auth,
  String email,
  String password,
) async {
  await auth.signOut();
  return (await auth.createUserWithEmailAndPassword(
    email: email,
    password: password,
  )).user!;
}

Future<void> _createClientProfile(
  FirebaseFirestore firestore,
  String uid,
  String email,
  String referralCode,
) => firestore.collection('users').doc(uid).set({
  'name': email.split('@').first,
  'email': email,
  'phone': '—',
  'referralCode': referralCode,
  'createdAt': FieldValue.serverTimestamp(),
});

Future<void> _createRemoteCheckIn(
  FirebaseFirestore firestore, {
  required String id,
  required String customerId,
  required String restaurantId,
  required DateTime now,
}) => firestore.collection('checkIns').doc(id).set({
  'customerId': customerId,
  'restaurantId': restaurantId,
  'requestedAt': Timestamp.fromDate(now),
  'expiresAt': Timestamp.fromDate(now.add(const Duration(minutes: 10))),
  'status': 'pending',
});

Future<void> _seedOfflineApproval(
  AppDatabase database, {
  required String ownerUid,
  required String restaurantId,
  required String customerId,
  required String checkInId,
  required String visitId,
  required DateTime now,
}) async {
  await database.checkInDao.upsertCheckIn(
    LocalCheckInsCompanion.insert(
      checkInId: checkInId,
      ownerUid: ownerUid,
      merchantId: restaurantId,
      customerId: customerId,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
      businessStatus: LocalCheckInBusinessStatus.approved,
      syncStatus: const Value(LocalCheckInSyncStatus.pending),
      updatedAt: now,
      visitId: Value(visitId),
    ),
  );
  await database.visitDao.insertVisit(
    LocalVisitsCompanion.insert(
      visitId: visitId,
      merchantId: restaurantId,
      customerId: customerId,
      visitedAt: now,
      syncStatus: const Value(LocalVisitSyncStatus.pending),
      createdAt: now,
      updatedAt: now,
    ),
  );
  final operationId = 'approveCheckIn:$checkInId';
  await database.pendingActionDao.insertPendingAction(
    PendingActionsCompanion.insert(
      operationId: operationId,
      ownerScopeId: Value(restaurantId),
      actionType: PendingActionType.approveCheckIn,
      entityType: 'checkIn',
      entityId: checkInId,
      payload: PendingActionPayload.encode({
        'operationId': operationId,
        'checkInId': checkInId,
        'visitId': visitId,
        'ownerUid': ownerUid,
        'merchantId': restaurantId,
        'customerId': customerId,
        'pointsAwarded': 999999,
      }),
      createdAt: now,
      updatedAt: now,
    ),
  );
}
