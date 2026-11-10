import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../models/check_in_request.dart';
import '../../../models/visit.dart';

class CheckInConflictException implements Exception {
  final String message;
  const CheckInConflictException(this.message);
  @override
  String toString() => 'CheckInConflictException: $message';
}

const approveCheckInFunctionName = 'approveCheckInSecure';
const rejectCheckInFunctionName = 'rejectCheckInSecure';
const approveCheckInFunctionRegion = 'us-central1';
const secureApproveCheckInEnabled = bool.fromEnvironment(
  'LOYALO_SECURE_APPROVE_CHECKIN',
  defaultValue: false,
);
const secureRejectCheckInEnabled = bool.fromEnvironment(
  'LOYALO_SECURE_REJECT_CHECKIN',
  defaultValue: false,
);

class CheckInRemoteException implements Exception {
  final String code;
  final String? reason;
  final String message;

  const CheckInRemoteException({
    required this.code,
    required this.message,
    this.reason,
  });

  bool get isTemporary => const {
    'unavailable',
    'deadline-exceeded',
    'internal',
    'unauthenticated',
  }.contains(code);

  @override
  String toString() =>
      'CheckInRemoteException($code${reason == null ? '' : '/$reason'}): '
      '$message';
}

class SecureApprovalResult {
  final bool success;
  final String status;
  final String checkInId;
  final String operationId;
  final String visitId;
  final bool alreadyProcessed;

  const SecureApprovalResult({
    required this.success,
    required this.status,
    required this.checkInId,
    required this.operationId,
    required this.visitId,
    required this.alreadyProcessed,
  });

  factory SecureApprovalResult.fromData(Object? raw) {
    if (raw is! Map) {
      throw const CheckInConflictException('callable-response-not-a-map');
    }
    final data = Map<String, Object?>.from(raw);
    final success = data['success'];
    final status = data['status'];
    final checkInId = data['checkInId'];
    final operationId = data['operationId'];
    final visitId = data['visitId'];
    final alreadyProcessed = data['alreadyProcessed'];
    if (success is! bool ||
        status is! String ||
        checkInId is! String ||
        operationId is! String ||
        visitId is! String ||
        alreadyProcessed is! bool) {
      throw const CheckInConflictException('callable-response-invalid');
    }
    return SecureApprovalResult(
      success: success,
      status: status,
      checkInId: checkInId,
      operationId: operationId,
      visitId: visitId,
      alreadyProcessed: alreadyProcessed,
    );
  }
}

class SecureRejectionResult {
  final bool success;
  final String status;
  final String checkInId;
  final String operationId;
  final bool alreadyProcessed;

  const SecureRejectionResult({
    required this.success,
    required this.status,
    required this.checkInId,
    required this.operationId,
    required this.alreadyProcessed,
  });

  factory SecureRejectionResult.fromData(Object? raw) {
    if (raw is! Map) {
      throw const CheckInConflictException('callable-response-not-a-map');
    }
    final data = Map<String, Object?>.from(raw);
    if (data['success'] is! bool ||
        data['status'] is! String ||
        data['checkInId'] is! String ||
        data['operationId'] is! String ||
        data['alreadyProcessed'] is! bool) {
      throw const CheckInConflictException('callable-response-invalid');
    }
    return SecureRejectionResult(
      success: data['success']! as bool,
      status: data['status']! as String,
      checkInId: data['checkInId']! as String,
      operationId: data['operationId']! as String,
      alreadyProcessed: data['alreadyProcessed']! as bool,
    );
  }
}

abstract interface class SecureCheckInApprovalGateway {
  Future<SecureApprovalResult> approve({
    required String checkInId,
    required String operationId,
  });
}

abstract interface class SecureCheckInRejectionGateway {
  Future<SecureRejectionResult> reject({
    required String checkInId,
    required String operationId,
  });
}

class FirebaseSecureCheckInApprovalGateway
    implements SecureCheckInApprovalGateway {
  FirebaseSecureCheckInApprovalGateway(this._functions);

  factory FirebaseSecureCheckInApprovalGateway.forProduction() =>
      FirebaseSecureCheckInApprovalGateway(
        FirebaseFunctions.instanceFor(region: approveCheckInFunctionRegion),
      );

  final FirebaseFunctions _functions;

  @override
  Future<SecureApprovalResult> approve({
    required String checkInId,
    required String operationId,
  }) async {
    try {
      final result = await _functions
          .httpsCallable(approveCheckInFunctionName)
          .call(<String, Object?>{
            'checkInId': checkInId,
            'operationId': operationId,
          });
      return SecureApprovalResult.fromData(result.data);
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final rawReason = details is Map ? details['reason'] : null;
      final reason = rawReason is String ? rawReason : null;
      throw CheckInRemoteException(
        code: error.code,
        reason: reason,
        message: error.message ?? 'Secure check-in approval failed.',
      );
    }
  }
}

class FirebaseSecureCheckInRejectionGateway
    implements SecureCheckInRejectionGateway {
  FirebaseSecureCheckInRejectionGateway(this._functions);

  factory FirebaseSecureCheckInRejectionGateway.forProduction() =>
      FirebaseSecureCheckInRejectionGateway(
        FirebaseFunctions.instanceFor(region: approveCheckInFunctionRegion),
      );

  final FirebaseFunctions _functions;

  @override
  Future<SecureRejectionResult> reject({
    required String checkInId,
    required String operationId,
  }) async {
    try {
      final result = await _functions
          .httpsCallable(rejectCheckInFunctionName)
          .call(<String, Object?>{
            'checkInId': checkInId,
            'operationId': operationId,
          });
      return SecureRejectionResult.fromData(result.data);
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final rawReason = details is Map ? details['reason'] : null;
      throw CheckInRemoteException(
        code: error.code,
        reason: rawReason is String ? rawReason : null,
        message: error.message ?? 'Secure check-in rejection failed.',
      );
    }
  }
}

abstract interface class CheckInRemoteDataSource {
  Stream<List<CheckInRequest>> watchForMerchant(String merchantId);
  Future<String> approve(Map<String, Object?> payload);
  Future<void> reject(Map<String, Object?> payload);
}

CheckInRemoteDataSource selectCheckInRemoteDataSource({
  required bool secureApprovalEnabled,
  bool secureRejectionEnabled = secureRejectCheckInEnabled,
  required CheckInRemoteDataSource compatibilityDataSource,
  SecureCheckInApprovalGateway? secureGateway,
  SecureCheckInRejectionGateway? secureRejectionGateway,
}) {
  if (!secureApprovalEnabled && !secureRejectionEnabled) {
    return compatibilityDataSource;
  }
  return CallableApproveCheckInRemoteDataSource(
    compatibilityDataSource: compatibilityDataSource,
    secureGateway: secureApprovalEnabled
        ? secureGateway ?? FirebaseSecureCheckInApprovalGateway.forProduction()
        : null,
    secureRejectionGateway: secureRejectionEnabled
        ? secureRejectionGateway ??
              FirebaseSecureCheckInRejectionGateway.forProduction()
        : null,
  );
}

class CallableApproveCheckInRemoteDataSource
    implements CheckInRemoteDataSource {
  CallableApproveCheckInRemoteDataSource({
    required CheckInRemoteDataSource compatibilityDataSource,
    SecureCheckInApprovalGateway? secureGateway,
    SecureCheckInRejectionGateway? secureRejectionGateway,
  }) : _compatibilityDataSource = compatibilityDataSource,
       _secureGateway = secureGateway,
       _secureRejectionGateway = secureRejectionGateway;

  final CheckInRemoteDataSource _compatibilityDataSource;
  final SecureCheckInApprovalGateway? _secureGateway;
  final SecureCheckInRejectionGateway? _secureRejectionGateway;

  @override
  Stream<List<CheckInRequest>> watchForMerchant(String merchantId) =>
      _compatibilityDataSource.watchForMerchant(merchantId);

  @override
  Future<String> approve(Map<String, Object?> payload) async {
    final gateway = _secureGateway;
    if (gateway == null) return _compatibilityDataSource.approve(payload);
    final checkInId = payload['checkInId'];
    final operationId = payload['operationId'];
    final expectedVisitId = payload['visitId'];
    if (checkInId is! String ||
        operationId is! String ||
        expectedVisitId is! String ||
        operationId != 'approveCheckIn:$checkInId') {
      throw const CheckInConflictException('local-payload-invalid');
    }
    final result = await gateway.approve(
      checkInId: checkInId,
      operationId: operationId,
    );
    if (!result.success ||
        result.status != 'approved' ||
        result.checkInId != checkInId ||
        result.operationId != operationId ||
        result.visitId.isEmpty) {
      throw const CheckInConflictException('callable-response-inconsistent');
    }
    return result.visitId;
  }

  @override
  Future<void> reject(Map<String, Object?> payload) async {
    final gateway = _secureRejectionGateway;
    if (gateway == null) return _compatibilityDataSource.reject(payload);
    final checkInId = payload['checkInId'];
    final operationId = payload['operationId'];
    if (checkInId is! String ||
        operationId is! String ||
        operationId != 'rejectCheckIn:$checkInId') {
      throw const CheckInConflictException('local-payload-invalid');
    }
    final result = await gateway.reject(
      checkInId: checkInId,
      operationId: operationId,
    );
    if (!result.success ||
        result.status != 'rejected' ||
        result.checkInId != checkInId ||
        result.operationId != operationId) {
      throw const CheckInConflictException('callable-response-inconsistent');
    }
  }
}

class FirestoreCheckInRemoteDataSource implements CheckInRemoteDataSource {
  FirestoreCheckInRemoteDataSource(
    this._firestore, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final FirebaseFirestore _firestore;
  final DateTime Function() _clock;

  @override
  Stream<List<CheckInRequest>> watchForMerchant(String merchantId) => _firestore
      .collection('checkIns')
      .where('restaurantId', isEqualTo: merchantId)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map(CheckInRequest.fromFirestore).toList(),
      );

  @override
  Future<String> approve(Map<String, Object?> payload) async {
    final operationId = payload['operationId']! as String;
    final checkInId = payload['checkInId']! as String;
    final visitId = payload['visitId']! as String;
    final ownerUid = payload['ownerUid']! as String;
    final merchantId = payload['merchantId']! as String;
    final customerId = payload['customerId']! as String;
    final visitedAt = DateTime.parse(payload['visitedAt']! as String);
    final points = payload['pointsAwarded']! as int;
    if (operationId != 'approveCheckIn:$checkInId') {
      throw const CheckInConflictException('operation-id-mismatch');
    }
    final checkInRef = _firestore.collection('checkIns').doc(checkInId);
    final visitRef = _firestore.collection('visits').doc(visitId);
    final restaurantRef = _firestore.collection('restaurants').doc(merchantId);
    final previousVisits = await _firestore
        .collection('visits')
        .where('restaurantId', isEqualTo: merchantId)
        .where('userId', isEqualTo: customerId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    final previousVisitRef = previousVisits.docs.isEmpty
        ? null
        : previousVisits.docs.single.reference;
    final reward = payload['reward'];
    final rewardMap = reward is Map ? Map<String, dynamic>.from(reward) : null;
    final rewardRef = rewardMap == null
        ? null
        : _firestore
              .collection('rewards')
              .doc(rewardMap.remove('id') as String);
    final notificationRef = _firestore
        .collection('notifications')
        .doc('checkin-sync-$checkInId');

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(checkInRef);
      final visitSnapshot = await transaction.get(visitRef);
      final restaurantSnapshot = await transaction.get(restaurantRef);
      final previousVisitSnapshot = previousVisitRef == null
          ? null
          : await transaction.get(previousVisitRef);
      final rewardSnapshot = rewardRef == null
          ? null
          : await transaction.get(rewardRef);
      final notificationSnapshot = await transaction.get(notificationRef);
      if (!snapshot.exists) {
        throw const CheckInConflictException('remote-missing');
      }
      if (!restaurantSnapshot.exists) {
        throw const CheckInConflictException('restaurant-missing');
      }
      final remote = CheckInRequest.fromFirestore(snapshot);
      if (remote.restaurantId != merchantId ||
          remote.customerId != customerId) {
        throw const CheckInConflictException('identity-mismatch');
      }
      if (remote.status == CheckInStatus.approved) {
        final visitData = visitSnapshot.data();
        final sameOperation =
            snapshot.data()?['syncOperationId'] == operationId;
        final coherentVisit =
            visitSnapshot.exists &&
            visitData?['checkInId'] == checkInId &&
            visitData?['operationId'] == operationId &&
            remote.visitId == visitId;
        if (!sameOperation || !coherentVisit) {
          throw const CheckInConflictException('approved-visit-inconsistent');
        }
        return;
      }
      if (remote.status != CheckInStatus.pending) {
        throw CheckInConflictException(
          'remote-${remote.status.firestoreValue}',
        );
      }
      final now = _clock().toUtc();
      if (visitedAt.toUtc().isAfter(remote.expiresAt.toUtc()) ||
          !remote.expiresAt.toUtc().isAfter(now)) {
        throw const CheckInConflictException('approval-time-unverifiable');
      }
      if (visitSnapshot.exists) {
        throw const CheckInConflictException('visit-already-exists');
      }
      final restaurantData = restaurantSnapshot.data()!;
      if (restaurantData['ownerId'] != ownerUid) {
        throw const CheckInConflictException('merchant-owner-mismatch');
      }
      final policy =
          restaurantData['validationPolicy'] as String? ?? 'oncePerDay';
      final minimumHours =
          (restaurantData['minimumHoursBetweenVisits'] as num?)?.toInt() ?? 4;
      final previousData = previousVisitSnapshot?.data();
      final previousTimestamp = previousData?['timestamp'];
      if (previousTimestamp is Timestamp) {
        final previousAt = previousTimestamp.toDate();
        final blocked = switch (policy) {
          'perTransaction' => false,
          'onceEveryXHours' =>
            previousAt.add(Duration(hours: minimumHours)).isAfter(visitedAt),
          _ => _isSameLocalDay(previousAt, visitedAt),
        };
        if (blocked) {
          throw const CheckInConflictException('frequency-rule-conflict');
        }
      }
      final visit = Visit(
        id: visitId,
        userId: customerId,
        restaurantId: merchantId,
        timestamp: visitedAt,
      );
      transaction.set(visitRef, {
        ...visit.toMap(),
        'checkInId': checkInId,
        'operationId': operationId,
      });
      if (rewardMap != null && rewardRef != null) {
        final rewardWrite = <String, dynamic>{
          ...rewardMap,
          'expiresAt': Timestamp.fromDate(
            DateTime.parse(rewardMap['expiresAt'] as String),
          ),
        };
        if (rewardSnapshot?.exists != true) {
          transaction.set(rewardRef, rewardWrite);
        }
      }
      if (!notificationSnapshot.exists) {
        final rewardUnlocked = rewardMap != null;
        transaction.set(notificationRef, {
          'recipientType': 'client',
          'userId': customerId,
          'restaurantId': merchantId,
          'title': rewardUnlocked ? 'Récompense débloquée' : 'Visite validée',
          'body': rewardUnlocked
              ? '${rewardMap['label'] ?? 'Une récompense'} vous attend.'
              : 'Votre visite a été confirmée. +$points points.',
          'type': rewardUnlocked ? 'reward_unlocked' : 'visit_validated',
          'relatedId': checkInId,
          'createdAt': Timestamp.fromDate(visitedAt),
          'read': false,
          'isRead': false,
        });
      }
      transaction.update(checkInRef, {
        'status': 'approved',
        'validatedAt': Timestamp.fromDate(visitedAt),
        'validatedBy': ownerUid,
        'pointsAwarded': points,
        'visitId': visitId,
        'syncOperationId': operationId,
      });
    });
    return visitId;
  }

  @override
  Future<void> reject(Map<String, Object?> payload) async {
    final operationId = payload['operationId']! as String;
    final checkInId = payload['checkInId']! as String;
    final ownerUid = payload['ownerUid']! as String;
    final merchantId = payload['merchantId']! as String;
    if (operationId != 'rejectCheckIn:$checkInId') {
      throw const CheckInConflictException('operation-id-mismatch');
    }
    final checkInRef = _firestore.collection('checkIns').doc(checkInId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(checkInRef);
      if (!snapshot.exists) {
        throw const CheckInConflictException('remote-missing');
      }
      final remote = CheckInRequest.fromFirestore(snapshot);
      if (remote.restaurantId != merchantId) {
        throw const CheckInConflictException('identity-mismatch');
      }
      if (remote.status == CheckInStatus.rejected) {
        if (snapshot.data()?['syncOperationId'] != operationId ||
            remote.rejectedBy != ownerUid) {
          throw const CheckInConflictException('rejection-conflict');
        }
        return;
      }
      if (remote.status != CheckInStatus.pending) {
        throw CheckInConflictException(
          'remote-${remote.status.firestoreValue}',
        );
      }
      transaction.update(checkInRef, {
        'status': 'rejected',
        'rejectedAt': Timestamp.fromDate(
          DateTime.parse(payload['actedAt']! as String),
        ),
        'rejectedBy': ownerUid,
        'syncOperationId': operationId,
      });
    });
  }
}

bool _isSameLocalDay(DateTime first, DateTime second) {
  final a = first.toLocal();
  final b = second.toLocal();
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
