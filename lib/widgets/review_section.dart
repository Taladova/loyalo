import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/review.dart';
import '../theme/app_theme.dart';
import 'loyalo_ui.dart';

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
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
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
    await FirebaseFirestore.instance
        .collection('reviews')
        .doc(_docId)
        .set(review.toMap());
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Merci pour votre avis !')));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('restaurantId', isEqualTo: widget.restaurantId)
          .snapshots(),
      builder: (context, snapshot) {
        final reviews = (snapshot.data?.docs ?? [])
            .map(Review.fromFirestore)
            .toList();
        final average = reviews.isEmpty
            ? 0.0
            : reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                  reviews.length;
        final text = AppTheme.textOf(context);
        final muted = AppTheme.mutedOf(context);

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
            Text(
              'Avis',
              style: TextStyle(
                color: text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            LoyaloCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.star,
                      color: AppColors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              reviews.isEmpty
                                  ? 'Aucun avis'
                                  : average.toStringAsFixed(1),
                              style: TextStyle(
                                color: text,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (reviews.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              ...List.generate(
                                5,
                                (i) => Icon(
                                  i < average.round()
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: AppColors.orange,
                                  size: 15,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          reviews.isEmpty
                              ? 'Soyez le premier à partager votre expérience.'
                              : '${reviews.length} avis client${reviews.length > 1 ? 's' : ''} sur Loyalo',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LoyaloCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasReviewed
                              ? 'Modifier mon avis'
                              : 'Noter mon passage',
                          style: TextStyle(
                            color: text,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        '$_rating/5',
                        style: const TextStyle(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: List.generate(5, (i) {
                      final filled = i < _rating;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = i + 1),
                        child: Container(
                          width: 42,
                          height: 42,
                          margin: const EdgeInsets.only(right: 7),
                          decoration: BoxDecoration(
                            color: filled
                                ? AppColors.orange.withValues(alpha: 0.14)
                                : AppTheme.backgroundOf(context),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            filled ? Icons.star : Icons.star_border,
                            color: AppColors.orange,
                            size: 25,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _commentController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Un mot sur votre visite (optionnel)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  LoyaloGradientButton(
                    label: hasReviewed
                        ? 'Mettre à jour mon avis'
                        : 'Publier mon avis',
                    onPressed: _saving ? null : _submit,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _openGoogleReview,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Aussi sur Google'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.purple,
                      minimumSize: const Size.fromHeight(46),
                      side: BorderSide(
                        color: AppColors.purple.withValues(alpha: 0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
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
