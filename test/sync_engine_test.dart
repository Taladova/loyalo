import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/core/database/pending_action_payload.dart';
import 'package:loyalo/core/database/tables/local_visits.dart';
import 'package:loyalo/core/database/tables/pending_actions.dart';
import 'package:loyalo/core/network/network_monitor.dart';
import 'package:loyalo/core/sync/sync_engine.dart';
import 'package:loyalo/features/visits/data/visit_mapper.dart';
import 'package:loyalo/features/visits/data/visit_remote_data_source.dart';
import 'package:loyalo/features/visits/data/visit_sync_service.dart';
import 'package:loyalo/models/visit.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late _FakeNetworkMonitor network;
  late _RecordingRemoteDataSource remote;
  late VisitSyncService service;
  late SyncEngine engine;
  var now = DateTime(2026, 10, 9, 12);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    network = _FakeNetworkMonitor();
    remote = _RecordingRemoteDataSource();
    service = VisitSyncService(
      database: database,
      remoteDataSource: remote,
      clock: () => now,
    );
    engine = SyncEngine(networkMonitor: network, visitSyncService: service);
  });

  tearDown(() async {
    await engine.dispose();
    await network.close();
    await database.close();
  });

  test(
    'network restored synchronise automatiquement une visite pending',
    () async {
      await _insertPending(database, now: now);
      network.available = false;
      await engine.start(ownerScopeId: 'merchant-a');

      network.emit(true);
      await _waitForStatus(database, PendingActionStatus.synced);

      expect(remote.visits, hasLength(1));
    },
  );

  test('le démarrage synchronise les actions persistantes', () async {
    await _insertPending(database, now: now);
    network.available = true;

    await engine.start(ownerScopeId: 'merchant-a');

    expect(await _actionStatus(database), PendingActionStatus.synced);
  });

  test(
    'connectivity disponible mais Firestore indisponible reste retryable',
    () async {
      await _insertPending(database, now: now);
      remote.failWrites = true;
      network.available = true;

      await engine.start(ownerScopeId: 'merchant-a');

      final action = await database.pendingActionDao.getActionByOperationId(
        'createVisit:visit-1',
      );
      expect(action?.status, PendingActionStatus.failed);
      expect(action?.retryCount, 1);
      expect(
        (await database.visitDao.getVisitById('visit-1'))?.syncStatus,
        LocalVisitSyncStatus.failed,
      );
    },
  );

  test(
    'plusieurs événements réseau ne produisent qu’une écriture distante',
    () async {
      await _insertPending(database, now: now);
      network.available = false;
      await engine.start(ownerScopeId: 'merchant-a');

      network.emit(true);
      network.emit(true);
      network.emit(true);
      await _waitForStatus(database, PendingActionStatus.synced);

      expect(remote.writeAttempts, 1);
    },
  );

  test(
    'startup réseau et retry manuel concurrents restent sérialisés',
    () async {
      await _insertPending(database, now: now);
      remote.writeDelay = const Duration(milliseconds: 40);
      network.available = false;
      await engine.start(ownerScopeId: 'merchant-a');

      network.emit(true);
      final manual = engine.synchronize();
      final resume = engine.onAppResumed();
      await Future.wait([manual, resume]);
      await _waitForStatus(database, PendingActionStatus.synced);

      expect(remote.writeAttempts, 1);
    },
  );

  test('une action syncing stale est récupérée au démarrage', () async {
    await _insertPending(
      database,
      now: now.subtract(const Duration(minutes: 10)),
      actionStatus: PendingActionStatus.syncing,
      visitStatus: LocalVisitSyncStatus.syncing,
    );
    network.available = true;

    await engine.start(ownerScopeId: 'merchant-a');

    expect(await _actionStatus(database), PendingActionStatus.synced);
    expect(remote.writeAttempts, 1);
  });

  test('une réponse perdue est rejouée avec le même visitId', () async {
    await _insertPending(database, now: now);
    remote.loseFirstResponse = true;
    network.available = true;
    await engine.start(ownerScopeId: 'merchant-a');
    expect(await _actionStatus(database), PendingActionStatus.failed);

    await engine.synchronize();

    expect(await _actionStatus(database), PendingActionStatus.synced);
    expect(remote.visits, hasLength(1));
    expect(remote.visits.single.id, 'visit-1');
    expect(remote.writeAttempts, 2);
  });

  test('une action du merchant A ne part jamais sous le merchant B', () async {
    await _insertPending(database, now: now, ownerScopeId: 'merchant-a');
    network.available = false;
    await engine.start(ownerScopeId: 'merchant-a');
    await engine.stop();

    network.available = true;
    await engine.start(ownerScopeId: 'merchant-b');

    expect(await _actionStatus(database), PendingActionStatus.pending);
    expect(remote.writeAttempts, 0);
  });

  test('le retour au premier plan déclenche la synchronisation', () async {
    await _insertPending(database, now: now);
    network.available = false;
    await engine.start(ownerScopeId: 'merchant-a');

    network.available = true;
    await engine.onAppResumed();

    expect(await _actionStatus(database), PendingActionStatus.synced);
  });

  test(
    'un événement réseau sans action pending ne fait aucune écriture',
    () async {
      network.available = false;
      await engine.start(ownerScopeId: 'merchant-a');

      network.emit(true);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(remote.writeAttempts, 0);
    },
  );

  test('la migration v1 vers v2 conserve les PendingActions', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('loyalo-v1-');
    final file = File('${directory.path}/migration.sqlite');
    final legacy = sqlite.sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE pending_actions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        operation_id TEXT NOT NULL UNIQUE,
        action_type TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT NULL
      );
    ''');
    legacy.execute(
      "INSERT INTO pending_actions "
      "(operation_id, action_type, entity_type, entity_id, payload, "
      "created_at, updated_at, status) VALUES "
      "('legacy-op', 'createVisit', 'visit', 'legacy-visit', '{}', 1, 1, 'pending')",
    );
    legacy.execute('PRAGMA user_version = 1;');
    legacy.close();

    final migrated = AppDatabase.forTesting(NativeDatabase(file));
    final action = await migrated.pendingActionDao.getActionByOperationId(
      'legacy-op',
    );

    expect(action, isNotNull);
    expect(action?.entityId, 'legacy-visit');
    expect(action?.ownerScopeId, isNull);
    await migrated.close();
    await directory.delete(recursive: true);
  });

  test(
    'la migration v2 vers v3 conserve LocalVisits et PendingActions',
    () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp('loyalo-v2-');
      final file = File('${directory.path}/migration.sqlite');
      final legacy = sqlite.sqlite3.open(file.path);
      legacy.execute('''
        CREATE TABLE local_visits (
          visit_id TEXT NOT NULL PRIMARY KEY,
          merchant_id TEXT NOT NULL,
          customer_id TEXT NOT NULL,
          visited_at INTEGER NOT NULL,
          sync_status TEXT NOT NULL DEFAULT 'pending',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      legacy.execute('''
        CREATE TABLE pending_actions (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          operation_id TEXT NOT NULL UNIQUE,
          owner_scope_id TEXT NULL,
          action_type TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT NULL
        );
      ''');
      legacy.execute(
        "INSERT INTO local_visits VALUES "
        "('legacy-visit', 'merchant-a', 'customer-a', 1, 'pending', 1, 1)",
      );
      legacy.execute(
        "INSERT INTO pending_actions "
        "(operation_id, owner_scope_id, action_type, entity_type, entity_id, "
        "payload, created_at, updated_at, status) VALUES "
        "('legacy-op', 'merchant-a', 'createVisit', 'visit', "
        "'legacy-visit', '{}', 1, 1, 'pending')",
      );
      legacy.execute('PRAGMA user_version = 2;');
      legacy.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(file));

      expect(await migrated.visitDao.getVisitById('legacy-visit'), isNotNull);
      expect(
        await migrated.pendingActionDao.getActionByOperationId('legacy-op'),
        isNotNull,
      );
      expect(
        await migrated.checkInDao.getCheckInsForMerchant('x', 'x'),
        isEmpty,
      );
      await migrated.close();
      await directory.delete(recursive: true);
    },
  );
}

Future<void> _insertPending(
  AppDatabase database, {
  required DateTime now,
  String ownerScopeId = 'merchant-a',
  PendingActionStatus actionStatus = PendingActionStatus.pending,
  LocalVisitSyncStatus visitStatus = LocalVisitSyncStatus.pending,
}) async {
  final visit = Visit(
    id: 'visit-1',
    userId: 'customer-a',
    restaurantId: 'merchant-a',
    timestamp: now,
  );
  await database.insertVisitWithPendingAction(
    visit: VisitMapper.toLocal(
      visit,
      syncStatus: visitStatus,
      createdAt: now,
      updatedAt: now,
    ),
    action: PendingActionsCompanion.insert(
      operationId: 'createVisit:visit-1',
      ownerScopeId: Value(ownerScopeId),
      actionType: PendingActionType.createVisit,
      entityType: 'visit',
      entityId: visit.id,
      payload: PendingActionPayload.encode(VisitMapper.toPendingPayload(visit)),
      createdAt: now,
      updatedAt: now,
      status: Value(actionStatus),
    ),
  );
}

Future<PendingActionStatus?> _actionStatus(AppDatabase database) async =>
    (await database.pendingActionDao.getActionByOperationId(
      'createVisit:visit-1',
    ))?.status;

Future<void> _waitForStatus(
  AppDatabase database,
  PendingActionStatus status,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (await _actionStatus(database) == status) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('PendingAction did not reach $status.');
}

class _FakeNetworkMonitor implements NetworkMonitor {
  final _controller = StreamController<bool>.broadcast();
  bool available = false;

  @override
  Future<bool> get isNetworkAvailable async => available;

  @override
  Stream<bool> get onAvailabilityChanged => _controller.stream;

  void emit(bool value) {
    available = value;
    _controller.add(value);
  }

  Future<void> close() => _controller.close();
}

class _RecordingRemoteDataSource implements VisitRemoteDataSource {
  final Map<String, Visit> _visits = {};
  bool failWrites = false;
  bool loseFirstResponse = false;
  Duration writeDelay = Duration.zero;
  int writeAttempts = 0;

  List<Visit> get visits => _visits.values.toList();

  @override
  Future<List<Visit>> fetchVisits({
    String? userId,
    String? restaurantId,
  }) async => visits;

  @override
  Stream<List<Visit>> watchVisits({String? userId, String? restaurantId}) =>
      Stream.value(visits);

  @override
  Future<void> upsertVisit(Visit visit) async {
    writeAttempts++;
    if (writeDelay > Duration.zero) await Future<void>.delayed(writeDelay);
    if (failWrites) throw StateError('Firestore unavailable');
    _visits[visit.id] = visit;
    if (loseFirstResponse) {
      loseFirstResponse = false;
      throw TimeoutException('Response lost after remote commit');
    }
  }
}
