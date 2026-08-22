import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/review.dart';
import '../theme/app_theme.dart';

/// Notes et avis laissés par les clients sur un restaurant, plus un
/// raccourci vers Google Maps pour aussi y laisser un avis public — Google
/// ne permettant à aucune app tierce de publier un avis à sa place, ce
/// raccourci ouvre directement la recherche du bon établissement.
class ReviewSection extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final String userId;
  final String userName;

  const ReviewSection({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.userId,
    required this.userName,
  });

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _initializedFromExisting = false;
  bool _saving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String get _docId => '${widget.restaurantId}_${widget.userId}';

  Future<void> _openGoogleReview() async {
    final query = Uri.encodeComponent(widget.restaurantName);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final review = Review(
      id: _docId,
      userId: widget.userId,
      restaurantId: widget.restaurantId,
      userName: widget.userName,
      rating: _rating,
      comment: _commentController.text.trim(),
      createdAt: DateTime.now(),
    );
    await FirebaseFirestore.instance.collection('reviews').doc(_docId).set(review.toMap());
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Merci pour votre avis !')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('restaurantId', isEqualTo: widget.restaurantId)
          .snapshots(),
      builder: (context, snapshot) {
        final reviews = (snapshot.data?.docs ?? []).map(Review.fromFirestore).toList();
        final average = reviews.isEmpty ? 0.0 : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

        if (!_initializedFromExisting) {
          final mine = reviews.where((r) => r.userId == widget.userId).toList();
          if (mine.isNotEmpty) {
            _rating = mine.first.rating;
            _commentController.text = mine.first.comment;
          }
          _initializedFromExisting = true;
        }
        final hasReviewed = reviews.any((r) => r.userId == widget.userId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Avis', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (reviews.isNotEmpty)
              Row(
                children: [
                  ...List.generate(5, (i) => Icon(
                        i < average.round() ? Icons.star : Icons.star_border,
                        color: AppColors.orange,
                        size: 18,
                      )),
                  const SizedBox(width: 8),
                  Text(average.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 4),
                  Text('(${reviews.length} avis)',
                      style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
                ],
              ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hasReviewed ? 'Modifier mon avis' : 'Noter mon passage',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      final filled = i < _rating;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(filled ? Icons.star : Icons.star_border, color: AppColors.orange, size: 30),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    maxLines: 2,
                    decoration: const InputDecoration(hintText: 'Un mot sur votre visite (optionnel)'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    child: _saving
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(hasReviewed ? 'Mettre à jour mon avis' : 'Publier mon avis'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openGoogleReview,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Aussi sur Google'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
