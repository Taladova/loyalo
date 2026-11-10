import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/features/checkins/data/check_in_remote_data_source.dart';

void main() {
  final now = DateTime.utc(2026, 10, 22, 12);
  late FakeFirebaseFirestore firestore;
  late FirestoreCheckInRemoteDataSource remote;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    remote = FirestoreCheckInRemoteDataSource(firestore, clock: () => now);
    await firestore.collection('restaurants').doc('restaurant-a').set({
      'ownerId': 'owner-a',
      'validationPolicy': 'oncePerDay',
      'minimumHoursBetweenVisits': 4,
      'pointsPerVisit': 120,
    });
    await _seedCheckIn(firestore, now);
  });

  test('approve est atomique et conserve les identifiants métier', () async {
    await remote.approve(_approvePayload(now));

    final checkIn = await firestore
        .collection('checkIns')
        .doc('checkin-1')
        .get();
    final visit = await firestore.collection('visits').doc('visit-1').get();
    expect(checkIn.data()?['status'], 'approved');
    expect(checkIn.data()?['visitId'], 'visit-1');
    expect(checkIn.data()?['syncOperationId'], 'approveCheckIn:checkin-1');
    expect(visit.data()?['checkInId'], 'checkin-1');
    expect(visit.data()?['operationId'], 'approveCheckIn:checkin-1');
  });

  test('retry approve ne crée pas une deuxième Visit', () async {
    final payload = _approvePayload(now);
    await remote.approve(payload);
    await remote.approve(payload);

    expect((await firestore.collection('visits').get()).docs, hasLength(1));
    expect(
      (await firestore.collection('notifications').get()).docs,
      hasLength(1),
    );
  });

  test('remote approved sans Visit est une incohérence', () async {
    await firestore.collection('checkIns').doc('checkin-1').update({
      'status': 'approved',
      'visitId': 'visit-1',
      'syncOperationId': 'approveCheckIn:checkin-1',
    });

    await expectLater(
      remote.approve(_approvePayload(now)),
      throwsA(
        isA<CheckInConflictException>().having(
          (error) => error.message,
          'message',
          'approved-visit-inconsistent',
        ),
      ),
    );
  });

  test('remote rejected bloque approve sans créer de Visit', () async {
    await firestore.collection('checkIns').doc('checkin-1').update({
      'status': 'rejected',
    });

    await expectLater(
      remote.approve(_approvePayload(now)),
      throwsA(isA<CheckInConflictException>()),
    );
    expect((await firestore.collection('visits').get()).docs, isEmpty);
  });

  test('reject est idempotent et ne crée aucune Visit', () async {
    final payload = _rejectPayload(now);
    await remote.reject(payload);
    await remote.reject(payload);

    final checkIn = await firestore
        .collection('checkIns')
        .doc('checkin-1')
        .get();
    expect(checkIn.data()?['status'], 'rejected');
    expect(checkIn.data()?['syncOperationId'], 'rejectCheckIn:checkin-1');
    expect((await firestore.collection('visits').get()).docs, isEmpty);
  });

  test('approbation synchronisée après expiration est refusée', () async {
    await firestore.collection('checkIns').doc('checkin-1').update({
      'expiresAt': Timestamp.fromDate(now.subtract(const Duration(seconds: 1))),
    });

    await expectLater(
      remote.approve(_approvePayload(now.subtract(const Duration(minutes: 2)))),
      throwsA(
        isA<CheckInConflictException>().having(
          (error) => error.message,
          'message',
          'approval-time-unverifiable',
        ),
      ),
    );
  });

  test('onceEveryXHours est revérifié depuis les Visits distantes', () async {
    await firestore.collection('restaurants').doc('restaurant-a').update({
      'validationPolicy': 'onceEveryXHours',
      'minimumHoursBetweenVisits': 4,
    });
    await firestore.collection('visits').doc('previous').set({
      'userId': 'customer-1',
      'restaurantId': 'restaurant-a',
      'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
    });

    await expectLater(
      remote.approve(_approvePayload(now)),
      throwsA(
        isA<CheckInConflictException>().having(
          (error) => error.message,
          'message',
          'frequency-rule-conflict',
        ),
      ),
    );
  });

  test('retry approve ne crée pas deux récompenses', () async {
    final payload = _approvePayload(now, withReward: true);
    await remote.approve(payload);
    await remote.approve(payload);

    expect((await firestore.collection('rewards').get()).docs, hasLength(1));
  });

  test('une récompense utilisée reste utilisée pendant un retry', () async {
    await firestore.collection('rewards').doc('reward-1').set({
      'userId': 'customer-1',
      'restaurantId': 'restaurant-a',
      'restaurantName': 'Restaurant A',
      'label': 'Récompense',
      'status': 'used',
      'cycle': 1,
      'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
      'redeemedAt': Timestamp.fromDate(now),
      'redeemedBy': 'owner-a',
    });

    await remote.approve(_approvePayload(now, withReward: true));
    final reward = await firestore.collection('rewards').doc('reward-1').get();

    expect(reward.data()?['status'], 'used');
    expect(reward.data()?['redeemedBy'], 'owner-a');
  });
}

Future<void> _seedCheckIn(FakeFirebaseFirestore firestore, DateTime now) =>
    firestore.collection('checkIns').doc('checkin-1').set({
      'customerId': 'customer-1',
      'restaurantId': 'restaurant-a',
      'requestedAt': Timestamp.fromDate(
        now.subtract(const Duration(minutes: 1)),
      ),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(minutes: 10))),
      'status': 'pending',
    });

Map<String, Object?> _approvePayload(
  DateTime visitedAt, {
  bool withReward = false,
}) => {
  'operationId': 'approveCheckIn:checkin-1',
  'checkInId': 'checkin-1',
  'visitId': 'visit-1',
  'ownerUid': 'owner-a',
  'merchantId': 'restaurant-a',
  'customerId': 'customer-1',
  'visitedAt': visitedAt.toIso8601String(),
  'pointsAwarded': 120,
  if (withReward)
    'reward': {
      'id': 'reward-1',
      'userId': 'customer-1',
      'restaurantId': 'restaurant-a',
      'restaurantName': 'Restaurant A',
      'label': 'Récompense',
      'status': 'available',
      'cycle': 1,
      'expiresAt': visitedAt.add(const Duration(days: 30)).toIso8601String(),
    },
};

Map<String, Object?> _rejectPayload(DateTime actedAt) => {
  'operationId': 'rejectCheckIn:checkin-1',
  'checkInId': 'checkin-1',
  'ownerUid': 'owner-a',
  'merchantId': 'restaurant-a',
  'actedAt': actedAt.toIso8601String(),
};
