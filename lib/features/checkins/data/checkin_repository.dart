import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' hide Query;
import '../../../core/database/app_database.dart';
import '../../../core/database/pending_action_payload.dart';
import '../../../core/database/tables/local_check_ins.dart';
import '../../../core/database/tables/local_visits.dart';
import '../../../core/database/tables/pending_actions.dart';
import '../../../models/check_in_request.dart';
import '../../../models/restaurant.dart';
import '../../../models/visit.dart';
import '../../visits/data/visit_mapper.dart';
import 'check_in_mapper.dart';
import 'check_in_remote_data_source.dart';
import 'check_in_sync_service.dart';

enum LocalCheckInMutationOutcome {
  completed,
  notFound,
  notPending,
  expired,
  tooFrequent,
}

class LocalCheckInMutationResult {
  final LocalCheckInMutationOutcome outcome;
  final CheckInRequest? request;
  final Visit? visit;
  final bool synced;
  const LocalCheckInMutationResult(
    this.outcome, {
    this.request,
    this.visit,
    this.synced = false,
  });
}

class CheckInRepository {
  CheckInRepository(
    this._firestore, {
    required AppDatabase database,
    CheckInRemoteDataSource? remoteDataSource,
    SecureCheckInApprovalGateway? secureApprovalGateway,
    SecureCheckInRejectionGateway? secureRejectionGateway,
    bool secureApprovalEnabled = secureApproveCheckInEnabled,
    bool secureRejectionEnabled = secureRejectCheckInEnabled,
    CheckInSyncService? syncService,
    DateTime Function()? clock,
  }) : _database = database,
       _clock = clock ?? DateTime.now,
       _remote =
           remoteDataSource ??
           selectCheckInRemoteDataSource(
             secureApprovalEnabled: secureApprovalEnabled,
             secureRejectionEnabled: secureRejectionEnabled,
             compatibilityDataSource: FirestoreCheckInRemoteDataSource(
               _firestore,
               clock: clock ?? DateTime.now,
             ),
             secureGateway: secureApprovalGateway,
             secureRejectionGateway: secureRejectionGateway,
           ) {
    _syncService =
        syncService ??
        CheckInSyncService(
          database: database,
          remoteDataSource: _remote,
          clock: _clock,
        );
  }
  final FirebaseFirestore _firestore;
  final AppDatabase _database;
  final DateTime Function() _clock;
  final CheckInRemoteDataSource _remote;
  late final CheckInSyncService _syncService;
  Future<void> Function(String)? _synchronize;
  final Map<String, String> _ownerByMerchant = {};
  List<CheckInRequest> _checkIns = [];
  Object? _loadError;
  CheckInSyncService get syncService => _syncService;
  Object? get loadError => _loadError;
  List<CheckInRequest> get checkIns => List.unmodifiable(_checkIns);
  void attachSynchronizer(Future<void> Function(String) value) =>
      _synchronize = value;

  Stream<List<CheckInRequest>> watchCheckIns({
    String? customerId,
    String? restaurantId,
    String? ownerUid,
  }) {
    if (restaurantId == null) {
      Query<Map<String, dynamic>> query = _firestore.collection('checkIns');
      if (customerId != null) {
        query = query.where('customerId', isEqualTo: customerId);
      }
      return query.snapshots().map((snapshot) {
        _checkIns = snapshot.docs.map(CheckInRequest.fromFirestore).toList();
        return checkIns;
      });
    }
    final owner = ownerUid ?? restaurantId;
    _ownerByMerchant[restaurantId] = owner;
    late StreamController<List<CheckInRequest>> controller;
    StreamSubscription<List<LocalCheckIn>>? localSub;
    StreamSubscription<List<CheckInRequest>>? remoteSub;
    controller = StreamController<List<CheckInRequest>>(
      onListen: () {
        localSub = _database.checkInDao
            .watchPendingCheckInsForMerchant(restaurantId, owner)
            .listen(
              (rows) {
                final now = _clock().toUtc();
                _checkIns = rows
                    .where((row) => row.expiresAt.isAfter(now))
                    .map(CheckInMapper.fromLocal)
                    .toList();
                controller.add(checkIns);
              },
              onError: (Object error, StackTrace stackTrace) {
                _loadError = error;
                controller.addError(error, stackTrace);
              },
            );
        remoteSub = _remote
            .watchForMerchant(restaurantId)
            .listen(
              (items) async {
                try {
                  _loadError = null;
                  await _reconcile(items, owner);
                } catch (error, stackTrace) {
                  _loadError = error;
                  if (!controller.isClosed) {
                    controller.addError(error, stackTrace);
                  }
                }
              },
              onError: (Object error, StackTrace stackTrace) {
                _loadError = error;
                if (!controller.isClosed) {
                  controller.addError(error, stackTrace);
                }
              },
            );
      },
      onCancel: () async {
        await localSub?.cancel();
        await remoteSub?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> _reconcile(List<CheckInRequest> remote, String ownerUid) =>
      _database.transaction(() async {
        for (final item in remote) {
          final local = await _database.checkInDao.getCheckInById(item.id);
          final remoteStatus = LocalCheckInBusinessStatus.values.byName(
            item.status.firestoreValue,
          );
          if (local != null &&
              local.syncStatus != LocalCheckInSyncStatus.synced &&
              local.businessStatus != LocalCheckInBusinessStatus.pending) {
            await _database.checkInDao.updateSyncStatus(
              item.id,
              local.businessStatus == remoteStatus
                  ? LocalCheckInSyncStatus.synced
                  : remoteStatus == LocalCheckInBusinessStatus.pending
                  ? local.syncStatus
                  : LocalCheckInSyncStatus.failed,
              _clock().toUtc(),
            );
            continue;
          }
          await _database.checkInDao.upsertCheckIn(
            CheckInMapper.toLocal(
              item,
              ownerUid: ownerUid,
              syncStatus: LocalCheckInSyncStatus.synced,
              updatedAt: _clock(),
            ),
          );
        }
      });

  CheckInRequest? activeCheckInForUserAndRestaurant({
    required String userId,
    required String restaurantId,
  }) {
    final active =
        _checkIns
            .where(
              (r) =>
                  r.customerId == userId &&
                  r.restaurantId == restaurantId &&
                  r.status == CheckInStatus.pending &&
                  r.expiresAt.isAfter(_clock()),
            )
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return active.isEmpty ? null : active.first;
  }

  List<CheckInRequest> pendingCheckInsForRestaurant(String id) =>
      _checkIns
          .where(
            (r) =>
                r.restaurantId == id &&
                r.status == CheckInStatus.pending &&
                r.expiresAt.isAfter(_clock()),
          )
          .toList()
        ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  Stream<List<CheckInRequest>> watchPendingCheckInsForRestaurant(String id) {
    final owner = _ownerByMerchant[id] ?? id;
    return _database.checkInDao
        .watchPendingCheckInsForMerchant(id, owner)
        .map(
          (rows) => rows
              .where((r) => r.expiresAt.isAfter(_clock().toUtc()))
              .map(CheckInMapper.fromLocal)
              .toList(),
        );
  }

  Stream<List<CheckInRequest>> watchMerchantValidationQueue(
    String id, {
    String? ownerUid,
  }) {
    final owner = ownerUid ?? _ownerByMerchant[id] ?? id;
    return _database.checkInDao
        .watchMerchantValidationQueue(id, owner)
        .map((rows) => rows.map(CheckInMapper.fromLocal).toList());
  }

  Future<CheckInRequest?> activeCheckInFromFirestore({
    required String userId,
    required String restaurantId,
  }) async {
    final snap = await _firestore
        .collection('checkIns')
        .where('customerId', isEqualTo: userId)
        .get();
    final active =
        snap.docs
            .map(CheckInRequest.fromFirestore)
            .where(
              (r) =>
                  r.restaurantId == restaurantId &&
                  r.status == CheckInStatus.pending &&
                  r.expiresAt.isAfter(_clock()),
            )
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return active.isEmpty ? null : active.first;
  }

  Future<CheckInRequest?> getCheckIn(String id) async {
    final local = await _database.checkInDao.getCheckInById(id);
    if (local != null) return CheckInMapper.fromLocal(local);
    final snap = await checkInReference(id).get();
    return snap.exists ? CheckInRequest.fromFirestore(snap) : null;
  }

  Future<void> cacheForMerchant(CheckInRequest request, String ownerUid) =>
      _database.checkInDao.upsertCheckIn(
        CheckInMapper.toLocal(
          request,
          ownerUid: ownerUid,
          syncStatus: LocalCheckInSyncStatus.synced,
          updatedAt: _clock(),
        ),
      );
  DocumentReference<Map<String, dynamic>> checkInReference(String id) =>
      _firestore.collection('checkIns').doc(id);

  Future<CheckInRequest> createPendingCheckIn({
    required String userId,
    required String restaurantId,
    required DateTime requestedAt,
    required DateTime expiresAt,
    double? customerLatitude,
    double? customerLongitude,
    double? distanceMeters,
  }) async {
    final ref = _firestore.collection('checkIns').doc();
    final request = CheckInRequest(
      id: ref.id,
      customerId: userId,
      restaurantId: restaurantId,
      requestedAt: requestedAt,
      expiresAt: expiresAt,
      status: CheckInStatus.pending,
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
      distanceMeters: distanceMeters,
    );
    await ref.set(request.toMap());
    // The client action remains online-only. Keeping the acknowledged request
    // locally removes the short gap before the merchant Firestore listener
    // hydrates Drift when both roles are exercised on the same installation.
    await cacheForMerchant(request, restaurantId);
    _checkIns = [..._checkIns.where((e) => e.id != request.id), request];
    return request;
  }

  Future<void> cancelCheckIn({
    required String checkInId,
    required String userId,
  }) async {
    final ref = checkInReference(checkInId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final r = CheckInRequest.fromFirestore(snap);
      if (r.customerId == userId && r.status == CheckInStatus.pending) {
        tx.update(ref, {
          'status': 'cancelled',
          'cancelledAt': Timestamp.fromDate(_clock()),
        });
      }
    });
  }

  Future<void> rejectPendingCheckIn({
    required String checkInId,
    required String merchantId,
  }) async {
    final request = await getCheckIn(checkInId);
    if (request == null) return;
    await cacheForMerchant(request, merchantId);
    await rejectLocally(
      checkInId: checkInId,
      ownerUid: merchantId,
      merchantId: request.restaurantId,
    );
  }

  Future<LocalCheckInMutationResult> approveLocally({
    required String checkInId,
    required String ownerUid,
    required Restaurant restaurant,
    required int pointsAwarded,
    Map<String, Object?>? reward,
  }) async {
    final local = await _database.checkInDao.getCheckInById(checkInId);
    if (local == null ||
        local.ownerUid != ownerUid ||
        local.merchantId != restaurant.id) {
      return const LocalCheckInMutationResult(
        LocalCheckInMutationOutcome.notFound,
      );
    }
    if (local.businessStatus != LocalCheckInBusinessStatus.pending) {
      return LocalCheckInMutationResult(
        LocalCheckInMutationOutcome.notPending,
        request: CheckInMapper.fromLocal(local),
      );
    }
    final now = _clock();
    if (!local.expiresAt.isAfter(now.toUtc())) {
      await _database.checkInDao.updateBusinessStatus(
        checkInId,
        LocalCheckInBusinessStatus.expired,
        now.toUtc(),
      );
      return LocalCheckInMutationResult(
        LocalCheckInMutationOutcome.expired,
        request: CheckInMapper.fromLocal(local),
      );
    }
    final visits = (await _database.visitDao.getVisitsByCustomer(
      local.customerId,
    )).where((v) => v.merchantId == restaurant.id).toList();
    final blocked = switch (restaurant.validationPolicy) {
      VisitValidationPolicy.oncePerDay => visits.any((v) {
        final d = v.visitedAt.toLocal();
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }),
      VisitValidationPolicy.onceEveryXHours =>
        visits.isNotEmpty &&
            (visits..sort((a, b) => b.visitedAt.compareTo(a.visitedAt)))
                .first
                .visitedAt
                .add(Duration(hours: restaurant.minimumHoursBetweenVisits))
                .isAfter(now.toUtc()),
      VisitValidationPolicy.perTransaction => false,
    };
    if (blocked) {
      return LocalCheckInMutationResult(
        LocalCheckInMutationOutcome.tooFrequent,
        request: CheckInMapper.fromLocal(local),
      );
    }
    final key = '${now.year}-${now.month}-${now.day}';
    final visitId =
        restaurant.validationPolicy == VisitValidationPolicy.oncePerDay
        ? '${restaurant.id}_${local.customerId}_$key'
        : 'checkin_$checkInId';
    final visit = Visit(
      id: visitId,
      userId: local.customerId,
      restaurantId: restaurant.id,
      timestamp: now,
    );
    final op = 'approveCheckIn:$checkInId';
    final payload = <String, Object?>{
      'operationId': op,
      'checkInId': checkInId,
      'ownerUid': ownerUid,
      'merchantId': restaurant.id,
      'customerId': local.customerId,
      'visitId': visitId,
      'visitedAt': now.toUtc().toIso8601String(),
      'pointsAwarded': pointsAwarded,
      'reward': ?reward,
    };
    try {
      await _database.approveCheckInAtomically(
        checkInId: checkInId,
        ownerUid: ownerUid,
        merchantId: restaurant.id,
        now: now,
        visit: VisitMapper.toLocal(
          visit,
          syncStatus: LocalVisitSyncStatus.pending,
          createdAt: now.toUtc(),
          updatedAt: now.toUtc(),
        ),
        action: PendingActionsCompanion.insert(
          operationId: op,
          ownerScopeId: Value(restaurant.id),
          actionType: PendingActionType.approveCheckIn,
          entityType: 'checkIn',
          entityId: checkInId,
          payload: PendingActionPayload.encode(payload),
          createdAt: now.toUtc(),
          updatedAt: now.toUtc(),
        ),
      );
    } catch (_) {
      final current = await _database.checkInDao.getCheckInById(checkInId);
      if (current?.businessStatus == LocalCheckInBusinessStatus.approved) {
        return LocalCheckInMutationResult(
          LocalCheckInMutationOutcome.notPending,
          request: CheckInMapper.fromLocal(current!),
        );
      }
      rethrow;
    }
    return LocalCheckInMutationResult(
      LocalCheckInMutationOutcome.completed,
      request: CheckInMapper.fromLocal(local),
      visit: visit,
      synced: await _trySync(restaurant.id, op),
    );
  }

  Future<LocalCheckInMutationResult> rejectLocally({
    required String checkInId,
    required String ownerUid,
    required String merchantId,
  }) async {
    final local = await _database.checkInDao.getCheckInById(checkInId);
    if (local == null ||
        local.ownerUid != ownerUid ||
        local.merchantId != merchantId) {
      return const LocalCheckInMutationResult(
        LocalCheckInMutationOutcome.notFound,
      );
    }
    if (local.businessStatus != LocalCheckInBusinessStatus.pending) {
      return LocalCheckInMutationResult(
        LocalCheckInMutationOutcome.notPending,
        request: CheckInMapper.fromLocal(local),
      );
    }
    final now = _clock();
    if (!local.expiresAt.isAfter(now.toUtc())) {
      await _database.checkInDao.updateBusinessStatus(
        checkInId,
        LocalCheckInBusinessStatus.expired,
        now.toUtc(),
      );
      return LocalCheckInMutationResult(
        LocalCheckInMutationOutcome.expired,
        request: CheckInMapper.fromLocal(local),
      );
    }
    final op = 'rejectCheckIn:$checkInId';
    await _database.rejectCheckInAtomically(
      checkInId: checkInId,
      ownerUid: ownerUid,
      merchantId: merchantId,
      now: now,
      action: PendingActionsCompanion.insert(
        operationId: op,
        ownerScopeId: Value(merchantId),
        actionType: PendingActionType.rejectCheckIn,
        entityType: 'checkIn',
        entityId: checkInId,
        payload: PendingActionPayload.encode({
          'operationId': op,
          'checkInId': checkInId,
          'ownerUid': ownerUid,
          'merchantId': merchantId,
          'actedAt': now.toUtc().toIso8601String(),
        }),
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
    );
    return LocalCheckInMutationResult(
      LocalCheckInMutationOutcome.completed,
      request: CheckInMapper.fromLocal(local),
      synced: await _trySync(merchantId, op),
    );
  }

  Future<bool> _trySync(String owner, String op) async {
    try {
      final sync = _synchronize;
      if (sync != null) {
        await sync(owner);
      } else {
        await _syncService.syncAction(op, ownerScopeId: owner);
      }
    } catch (_) {}
    final action = await _database.pendingActionDao.getActionByOperationId(op);
    return action?.status == PendingActionStatus.synced;
  }

  Future<void> markExpired(String id) async {
    final local = await _database.checkInDao.getCheckInById(id);
    if (local != null) {
      await _database.checkInDao.updateBusinessStatus(
        id,
        LocalCheckInBusinessStatus.expired,
        _clock().toUtc(),
      );
    }
    try {
      await checkInReference(id).update({'status': 'expired'});
    } catch (_) {}
  }

  Future<void> expirePendingCheckIns() async {
    final now = _clock();
    for (final r in _checkIns.where(
      (e) => e.status == CheckInStatus.pending && !e.expiresAt.isAfter(now),
    )) {
      await markExpired(r.id);
    }
  }

  int pendingCheckInsCount(String id) =>
      pendingCheckInsForRestaurant(id).length;
  int approvedCheckInsBetween(String id, DateTime start, DateTime end) =>
      _checkIns
          .where(
            (r) =>
                r.restaurantId == id &&
                r.status == CheckInStatus.approved &&
                r.validatedAt != null &&
                !r.validatedAt!.isBefore(start) &&
                r.validatedAt!.isBefore(end),
          )
          .length;
}
