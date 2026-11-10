import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/visit.dart';

abstract interface class VisitRemoteDataSource {
  Future<List<Visit>> fetchVisits({String? userId, String? restaurantId});

  Stream<List<Visit>> watchVisits({String? userId, String? restaurantId});

  Future<void> upsertVisit(Visit visit);
}

class FirestoreVisitRemoteDataSource implements VisitRemoteDataSource {
  FirestoreVisitRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  Query<Map<String, dynamic>> _query({String? userId, String? restaurantId}) {
    var query = _firestore.collection('visits') as Query<Map<String, dynamic>>;
    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    } else if (restaurantId != null) {
      query = query.where('restaurantId', isEqualTo: restaurantId);
    }
    return query;
  }

  @override
  Future<List<Visit>> fetchVisits({
    String? userId,
    String? restaurantId,
  }) async {
    final snapshot = await _query(
      userId: userId,
      restaurantId: restaurantId,
    ).get();
    return snapshot.docs.map(Visit.fromFirestore).toList();
  }

  @override
  Stream<List<Visit>> watchVisits({String? userId, String? restaurantId}) =>
      _query(userId: userId, restaurantId: restaurantId).snapshots().map(
        (snapshot) => snapshot.docs.map(Visit.fromFirestore).toList(),
      );

  @override
  Future<void> upsertVisit(Visit visit) => _firestore
      .collection('visits')
      .doc(visit.id)
      .set(visit.toMap(), SetOptions(merge: true));
}
