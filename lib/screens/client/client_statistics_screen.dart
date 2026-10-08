import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/reward.dart';
import '../../providers/app_providers.dart';
import '../../services/loyalty_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_ui.dart';

class ClientStatisticsScreen extends ConsumerWidget {
  const ClientStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final user = ref.watch(currentUserProvider)!;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final previousMonthStart = DateTime(now.year, now.month - 1);
    final visits = repo.visitsForUser(user.id);
    final visitsThisMonth = visits.where((v) {
      return !v.timestamp.isBefore(monthStart);
    }).toList();
    final visitsPreviousMonth = visits.where((v) {
      return !v.timestamp.isBefore(previousMonthStart) &&
          v.timestamp.isBefore(monthStart);
    }).toList();
    final pointsThisMonth = visitsThisMonth.fold<int>(0, (total, visit) {
      return total +
          (repo.restaurantByIdOrNull(visit.restaurantId)?.pointsPerVisit ?? 0);
    });
    final pointsPreviousMonth = visitsPreviousMonth.fold<int>(0, (
      total,
      visit,
    ) {
      return total +
          (repo.restaurantByIdOrNull(visit.restaurantId)?.pointsPerVisit ?? 0);
    });
    final availableRewards = repo
        .rewardsForUser(user.id)
        .where((reward) => reward.status == RewardStatus.available)
        .length;
    final monthlyPoints = _monthlyPoints(repo, user.id, now);
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes statistiques'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.search, size: 22),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderOf(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ce mois-ci',
                    style: TextStyle(
                      color: text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 28),
                  Icon(Icons.keyboard_arrow_down, color: muted, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _MetricCard(
            label: 'Visites',
            value: '${visitsThisMonth.length}',
            trend: _deltaLabel(
              visitsThisMonth.length,
              visitsPreviousMonth.length,
            ),
            icon: Icons.tune,
            color: AppColors.blue,
          ),
          const SizedBox(height: 12),
          _MetricCard(
            label: 'Points gagnés',
            value: '$pointsThisMonth pts',
            trend: _deltaLabel(pointsThisMonth, pointsPreviousMonth),
            icon: Icons.card_giftcard,
            color: AppColors.purple,
          ),
          const SizedBox(height: 12),
          _MetricCard(
            label: 'Récompenses disponibles',
            value: '$availableRewards',
            trend: 'sur votre compte',
            icon: Icons.local_activity_outlined,
            color: AppColors.teal,
          ),
          const SizedBox(height: 18),
          LoyaloCard(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Évolution des points',
                  style: TextStyle(
                    color: text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 172,
                  child: CustomPaint(
                    painter: _PointsChartPainter(
                      values: monthlyPoints
                          .map((entry) => entry.points)
                          .toList(),
                      lineColor: AppColors.purple,
                      gridColor: AppTheme.borderOf(context),
                      textColor: muted,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: monthlyPoints.map((entry) {
                    return Text(
                      _shortMonthLabel(entry.month),
                      style: TextStyle(color: muted, fontSize: 11),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<_MonthPoints> _monthlyPoints(
    LoyaltyRepository repo,
    String userId,
    DateTime now,
  ) {
    final start = DateTime(now.year, now.month - 3);
    return List.generate(4, (index) {
      final month = DateTime(start.year, start.month + index);
      final nextMonth = DateTime(month.year, month.month + 1);
      final points = repo
          .visitsForUser(userId)
          .where((visit) {
            return !visit.timestamp.isBefore(month) &&
                visit.timestamp.isBefore(nextMonth);
          })
          .fold<int>(0, (total, visit) {
            return total +
                (repo
                        .restaurantByIdOrNull(visit.restaurantId)
                        ?.pointsPerVisit ??
                    0);
          });
      return _MonthPoints(month, points);
    });
  }

  static String _deltaLabel(int current, int previous) {
    final delta = current - previous;
    if (delta == 0) return 'stable';
    return delta > 0
        ? '+$delta par rapport au mois dernier'
        : '$delta par rapport au mois dernier';
  }

  static String _shortMonthLabel(DateTime month) {
    const labels = [
      'Jan.',
      'Fév.',
      'Mars',
      'Avr.',
      'Mai',
      'Juin',
      'Juil.',
      'Août',
      'Sept.',
      'Oct.',
      'Nov.',
      'Déc.',
    ];
    return labels[month.month - 1];
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String trend;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTheme.textOf(context);

    return LoyaloCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    color: text,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trend,
                  style: TextStyle(
                    color: trend.startsWith('-')
                        ? AppColors.danger
                        : AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ],
      ),
    );
  }
}

class _PointsChartPainter extends CustomPainter {
  final List<int> values;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  const _PointsChartPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(28, 6, size.width - 34, size.height - 26);
    final maxValue = math.max(100, values.fold<int>(0, math.max));
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: textColor, fontSize: 10);

    for (var i = 0; i <= 3; i++) {
      final y = chart.bottom - (chart.height / 3 * i);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final label = i == 0 ? '0' : '${(maxValue / 3 * i).round()}';
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(0, y - 7));
    }

    if (values.isEmpty) return;

    final points = List.generate(values.length, (index) {
      final x = values.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (values.length - 1);
      final y = chart.bottom - (values[index] / maxValue) * chart.height;
      return Offset(x, y);
    });

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, chart.bottom)
      ..lineTo(points.first.dx, chart.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.16),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(chart),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4,
    );
    canvas.drawCircle(points.last, 4, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(covariant _PointsChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor;
  }
}

class _MonthPoints {
  final DateTime month;
  final int points;

  const _MonthPoints(this.month, this.points);
}
