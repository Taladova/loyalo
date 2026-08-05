import 'package:cloud_firestore/cloud_firestore.dart';

class Visit {
  final String id;
  final String userId;
  final String restaurantId;
  final DateTime timestamp;

  const Visit({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.timestamp,
  });

  bool isSameDay(DateTime other) {
    return timestamp.year == other.year &&
        timestamp.month == other.month &&
        timestamp.day == other.day;
  }

  factory Visit.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final ts = data['timestamp'];
    return Visit(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      restaurantId: data['restaurantId'] as String? ?? '',
      timestamp: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'restaurantId': restaurantId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
