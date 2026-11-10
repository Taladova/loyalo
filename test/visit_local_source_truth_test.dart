import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/core/database/tables/local_visits.dart';
import 'package:loyalo/features/visits/data/visit_remote_data_source.dart';
import 'package:loyalo/features/visits/data/visit_repository.dart';
import 'package:loyalo/models/visit.dart';
import 'package:loyalo/services/loyalty_repository.dart';

void main() {
  late AppDatabase database;
  late _FakeVisitRemoteDataSource remote;
  late VisitRepository repository;
  final now = DateTime(2026, 10, 9, 12);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    remote = _FakeVisitRemoteDataSource();
    repository = VisitRepository(
      FakeFirebaseFirestore(),
      database: database,
      remoteDataSource: remote,
      clock: () => now,
    );
  });

  tearDown(() => database.close());

  test('refresh de 3 visites distantes hydrate SQLite', () async {
    remote.visits = [
      _visit('v1'),
      _visit('v2', timestamp: now.subtract(const Duration(days: 1))),
      _visit('v3', timestamp: now.subtract(const Duration(days: 2))),
    ];

    await repository.refreshVisitsFromRemote(userId: 'customer-a');

    expect(
      await database.visitDao.getVisitsByCustomer('customer-a'),
      hasLength(3),
    );
  });

  test(
    'les lectures locales fonctionnent quand le réseau est indisponible',
    () async {
      await database.visitDao.insertVisit(_localVisit('local-1'));
      remote.failReads = true;

      final visits = await repository.watchVisits(userId: 'customer-a').first;

      expect(visits.map((visit) => visit.id), ['local-1']);
    },
  );

  test('une visite pending absente du remote est conservée', () async {
    await database.visitDao.insertVisit(_localVisit('pending-1'));

    await repository.refreshVisitsFromRemote(userId: 'customer-a');

    final local = await database.visitDao.getVisitById('pending-1');
    expect(local?.syncStatus, LocalVisitSyncStatus.pending);
  });

  test('une visite pending ne crédite pas les points confirmés', () async {
    await database.visitDao.insertVisit(_localVisit('pending-points'));
    final subscription = repository
        .watchVisits(userId: 'customer-a')
        .listen((_) {});
    await _waitFor(() => repository.visits.isNotEmpty);

    expect(repository.visitsForUser('customer-a'), hasLength(1));
    expect(repository.passageCount('customer-a', 'merchant-a'), 0);

    await database.visitDao.markSyncStatus(
      'pending-points',
      LocalVisitSyncStatus.synced,
      now,
    );
    await _waitFor(
      () => repository.passageCount('customer-a', 'merchant-a') == 1,
    );
    expect(repository.passageCount('customer-a', 'merchant-a'), 1);
    await subscription.cancel();
  });

  test(
    'une visite pending présente au remote devient synced sans doublon',
    () async {
      await database.visitDao.insertVisit(_localVisit('same-id'));
      remote.visits = [_visit('same-id')];

      await repository.refreshVisitsFromRemote(userId: 'customer-a');

      final visits = await database.visitDao.getVisitsByCustomer('customer-a');
      expect(visits, hasLength(1));
      expect(visits.single.syncStatus, LocalVisitSyncStatus.synced);
    },
  );

  test(
    'une nouvelle visite offline apparaît immédiatement dans watch',
    () async {
      remote.failWrites = true;
      final emissions = <List<Visit>>[];
      final subscription = repository
          .watchVisits(userId: 'customer-a')
          .listen(emissions.add);
      await _waitFor(() => emissions.isNotEmpty);

      final result = await repository.createVisit(
        userId: 'customer-a',
        restaurantId: 'merchant-a',
        ownerScopeId: 'merchant-a',
        timestamp: now,
        preventSameDayDuplicate: true,
      );
      await _waitFor(
        () => emissions.any(
          (visits) => visits.any((visit) => visit.id == result.visit?.id),
        ),
      );

      expect(result.visit, isNotNull);
      expect(result.synced, isFalse);
      await subscription.cancel();
    },
  );

  test(
    'une synchronisation réussie passe pending à synced sans doublon',
    () async {
      remote.failWrites = true;
      final result = await repository.createVisit(
        userId: 'customer-a',
        restaurantId: 'merchant-a',
        ownerScopeId: 'merchant-a',
        timestamp: now,
        preventSameDayDuplicate: true,
      );
      expect(
        (await database.visitDao.getVisitById(result.visit!.id))?.syncStatus,
        LocalVisitSyncStatus.failed,
      );

      remote.failWrites = false;
      await repository.retryPendingVisits(ownerScopeId: 'merchant-a');

      final visits = await database.visitDao.getVisitsByCustomer('customer-a');
      expect(visits, hasLength(1));
      expect(visits.single.syncStatus, LocalVisitSyncStatus.synced);
    },
  );

  test(
    'registerVisit crée SQLite avant les écritures secondaires distantes',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('restaurants').doc('merchant-a').set({
        'name': 'Commerce A',
        'cuisine': 'Test',
        'rewardThreshold': 10,
        'rewardLabel': 'Récompense',
        'pointsPerVisit': 10,
        'ownerId': 'merchant-a',
      });
      remote.failWrites = true;
      final visitRepository = VisitRepository(
        firestore,
        database: database,
        remoteDataSource: remote,
        clock: () => now,
      );
      final loyaltyRepository = LoyaltyRepository(
        firestore: firestore,
        database: database,
        visitRepository: visitRepository,
        clock: () => now,
      );
      loyaltyRepository.startListening();
      await Future<void>.delayed(Duration.zero);

      final result = await loyaltyRepository.registerVisit(
        userId: 'customer-a',
        restaurantId: 'merchant-a',
      );

      expect(result.outcome, VisitOutcome.validated);
      expect(
        await database.visitDao.getVisitsByCustomer('customer-a'),
        hasLength(1),
      );
      expect(
        (await database.pendingActionDao.getSyncableActions('merchant-a')),
        hasLength(1),
      );
      await loyaltyRepository.stopListening();
    },
  );

  test('les données des customers A et B restent isolées', () async {
    remote.visits = [
      _visit('a', customerId: 'customer-a'),
      _visit('b', customerId: 'customer-b'),
    ];
    await repository.refreshVisitsFromRemote(userId: 'customer-a');

    expect(remote.lastUserId, 'customer-a');
    expect(
      await database.visitDao.getVisitsByCustomer('customer-a'),
      hasLength(1),
    );
    expect(await database.visitDao.getVisitsByCustomer('customer-b'), isEmpty);
  });

  test('les données des merchants A et B restent isolées', () async {
    remote.visits = [
      _visit('a', merchantId: 'merchant-a'),
      _visit('b', merchantId: 'merchant-b'),
    ];
    await repository.refreshVisitsFromRemote(restaurantId: 'merchant-a');

    expect(remote.lastRestaurantId, 'merchant-a');
    expect(
      await database.visitDao.getVisitsByMerchant('merchant-a'),
      hasLength(1),
    );
    expect(await database.visitDao.getVisitsByMerchant('merchant-b'), isEmpty);
  });

  test('un refresh en erreur ne vide pas SQLite', () async {
    await database.visitDao.insertVisit(_localVisit('kept'));
    remote.failReads = true;

    await expectLater(
      repository.refreshVisitsFromRemote(userId: 'customer-a'),
      throwsA(isA<StateError>()),
    );

    expect(await database.visitDao.getVisitById('kept'), isNotNull);
  });

  test('un redémarrage conserve l’historique local', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('loyalo-visits-');
    final file = File('${directory.path}/visits.sqlite');
    final firstDatabase = AppDatabase.forTesting(NativeDatabase(file));
    await firstDatabase.visitDao.insertVisit(_localVisit('persisted'));
    await firstDatabase.close();

    final reopenedDatabase = AppDatabase.forTesting(NativeDatabase(file));
    final reopenedRepository = VisitRepository(
      FakeFirebaseFirestore(),
      database: reopenedDatabase,
      remoteDataSource: _FakeVisitRemoteDataSource()..failReads = true,
    );

    final visits = await reopenedRepository
        .watchVisits(userId: 'customer-a')
        .first;
    expect(visits.map((visit) => visit.id), ['persisted']);

    await reopenedDatabase.close();
    await directory.delete(recursive: true);
  });

  test('une base vide hors ligne retourne une liste vide sans crash', () async {
    remote.failReads = true;

    final visits = await repository.watchVisits(userId: 'customer-a').first;

    expect(visits, isEmpty);
  });

  test(
    'les visites locales sont ordonnées de la plus récente à la plus ancienne',
    () async {
      await database.visitDao.insertVisit(
        _localVisit('old', timestamp: now.subtract(const Duration(days: 1))),
      );
      await database.visitDao.insertVisit(_localVisit('new', timestamp: now));

      final visits = await repository.watchVisits(userId: 'customer-a').first;

      expect(visits.map((visit) => visit.id), ['new', 'old']);
    },
  );
}

Visit _visit(
  String id, {
  String customerId = 'customer-a',
  String merchantId = 'merchant-a',
  DateTime? timestamp,
}) => Visit(
  id: id,
  userId: customerId,
  restaurantId: merchantId,
  timestamp: timestamp ?? DateTime(2026, 10, 9, 12),
);

LocalVisitsCompanion _localVisit(
  String id, {
  String customerId = 'customer-a',
  String merchantId = 'merchant-a',
  DateTime? timestamp,
}) {
  final date = timestamp ?? DateTime(2026, 10, 9, 12);
  return LocalVisitsCompanion.insert(
    visitId: id,
    merchantId: merchantId,
    customerId: customerId,
    visitedAt: date,
    syncStatus: const Value(LocalVisitSyncStatus.pending),
    createdAt: date,
    updatedAt: date,
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition not reached before timeout.');
}

class _FakeVisitRemoteDataSource implements VisitRemoteDataSource {
  List<Visit> visits = [];
  bool failReads = false;
  bool failWrites = false;
  String? lastUserId;
  String? lastRestaurantId;

  @override
  Future<List<Visit>> fetchVisits({
    String? userId,
    String? restaurantId,
  }) async {
    lastUserId = userId;
    lastRestaurantId = restaurantId;
    if (failReads) throw StateError('offline');
    return _filter(userId: userId, restaurantId: restaurantId);
  }

  @override
  Stream<List<Visit>> watchVisits({String? userId, String? restaurantId}) {
    if (failReads) return Stream.error(StateError('offline'));
    return Stream.value(_filter(userId: userId, restaurantId: restaurantId));
  }

  @override
  Future<void> upsertVisit(Visit visit) async {
    if (failWrites) throw StateError('offline');
    visits = [visit, ...visits.where((item) => item.id != visit.id)];
  }

  List<Visit> _filter({String? userId, String? restaurantId}) {
    if (userId != null) {
      return visits.where((visit) => visit.userId == userId).toList();
    }
    if (restaurantId != null) {
      return visits
          .where((visit) => visit.restaurantId == restaurantId)
          .toList();
    }
    return List.of(visits);
  }
}
