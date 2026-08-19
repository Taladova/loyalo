import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Petite pluie de confettis dessinée à la main (pas de dépendance externe) :
/// quelques dizaines de rectangles colorés qui tombent et tournent sur eux-
/// mêmes derrière la carte de célébration.
class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiPiece> pieces;

  _ConfettiPainter({required this.progress, required this.pieces});

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final dy = size.height * ((piece.startY + progress * piece.speed) % 1.1);
      final dx = size.width * piece.startX + sin((progress * 6 + piece.phase) * pi) * 14;
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(progress * piece.rotationSpeed * pi * 2);
      final paint = Paint()..color = piece.color.withValues(alpha: (1 - progress * 0.3).clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: piece.size, height: piece.size * 0.5), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}

class _ConfettiPiece {
  final double startX;
  final double startY;
  final double speed;
  final double phase;
  final double rotationSpeed;
  final double size;
  final Color color;

  _ConfettiPiece({
    required this.startX,
    required this.startY,
    required this.speed,
    required this.phase,
    required this.rotationSpeed,
    required this.size,
    required this.color,
  });

  factory _ConfettiPiece.random(Random rnd) {
    const colors = [AppColors.teal, AppColors.blue, AppColors.purple, AppColors.orange];
    return _ConfettiPiece(
      startX: rnd.nextDouble(),
      startY: -0.2 - rnd.nextDouble() * 0.6,
      speed: 0.6 + rnd.nextDouble() * 0.8,
      phase: rnd.nextDouble() * 2,
      rotationSpeed: 1 + rnd.nextDouble() * 3,
      size: 6 + rnd.nextDouble() * 6,
      color: colors[rnd.nextInt(colors.length)],
    );
  }
}

class _RewardUnlockedContent extends StatefulWidget {
  final String rewardLabel;
  final String restaurantName;

  const _RewardUnlockedContent({required this.rewardLabel, required this.restaurantName});

  @override
  State<_RewardUnlockedContent> createState() => _RewardUnlockedContentState();
}

class _RewardUnlockedContentState extends State<_RewardUnlockedContent> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _pieces = List.generate(28, (_) => _ConfettiPiece.random(rnd));
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CustomPaint(painter: _ConfettiPainter(progress: _controller.value, pieces: _pieces)),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) => Transform.scale(scale: value, child: child),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
                    child: const Icon(Icons.card_giftcard, color: Colors.white, size: 38),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Récompense débloquée !',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 8),
                Text(
                  '${widget.rewardLabel}\nchez ${widget.restaurantName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textGray, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Super !'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showRewardUnlockedDialog(
  BuildContext context, {
  required String rewardLabel,
  required String restaurantName,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Récompense débloquée',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, _, _) =>
        _RewardUnlockedContent(rewardLabel: rewardLabel, restaurantName: restaurantName),
    transitionBuilder: (context, animation, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: animation, child: child),
    ),
  );
}
