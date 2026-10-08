import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/loyalty_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_pill.dart';

enum _Period { sevenDays, thirtyDays, ninetyDays }

extension on _Period {
  String get label {
    switch (this) {
      case _Period.sevenDays:
        return '7 derniers jours';
      case _Period.thirtyDays:
        return '30 derniers jours';
      case _Period.ninetyDays:
        return '90 derniers jours';
    }
  }

  int get days {
    switch (this) {
      case _Period.sevenDays:
        return 7;
      case _Period.thirtyDays:
        return 30;
      case _Period.ninetyDays:
        return 90;
    }
  }
}

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  _Period _period = _Period.thirtyDays;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider)!;
    final range = _rangeFor(_period, DateTime.now());
    final visits = repo.visitsForRestaurantBetween(
      restaurantId,
      range.currentStart,
      range.currentEnd,
    );
    final previousVisits = repo.visitsForRestaurantBetween(
      restaurantId,
      range.previousStart,
      range.previousEnd,
    );
    final currentClientCount = visits.map((v) => v.userId).toSet().length;
    final previousClientCount = previousVisits
        .map((v) => v.userId)
        .toSet()
        .length;
    final rewards = repo.rewardsUnlockedBetween(
      restaurantId,
      range.currentStart,
      range.currentEnd,
    );
    final previousRewards = repo.rewardsUnlockedBetween(
      restaurantId,
      range.previousStart,
      range.previousEnd,
    );
    final points = repo.pointsGrantedBetween(
      restaurantId,
      range.currentStart,
      range.currentEnd,
    );
    final series = _visitsSeries(
      repo,
      restaurantId,
      range.currentStart,
      _period.days,
    );
    final visitTrend = _trend(visits.length, previousVisits.length);
    final clientTrend = _trend(currentClientCount, previousClientCount);
    final rewardTrend = _trend(rewards, previousRewards);
    final maxY = series.isEmpty ? 1.0 : series.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: PopupMenuButton<_Period>(
                initialValue: _period,
                onSelected: (p) => setState(() => _period = p),
                itemBuilder: (context) => _Period.values
                    .map((p) => PopupMenuItem(value: p, child: Text(p.label)))
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_period.label, style: const TextStyle(fontSize: 12)),
                      const Icon(Icons.keyboard_arrow_down, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Aperçu',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatPill(
                  label: 'Visites',
                  value: '${visits.length}',
                  trend: visitTrend.label,
                  trendUp: visitTrend.trendUp,
                  icon: Icons.trending_up,
                  iconColor: AppColors.teal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatPill(
                  label: 'Clients',
                  value: '$currentClientCount',
                  trend: clientTrend.label,
                  trendUp: clientTrend.trendUp,
                  icon: Icons.people_alt_outlined,
                  iconColor: AppColors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatPill(
                  label: 'Récompenses',
                  value: '$rewards',
                  trend: rewardTrend.label,
                  trendUp: rewardTrend.trendUp,
                  icon: Icons.card_giftcard,
                  iconColor: AppColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatPill(
                  label: 'Points',
                  value: '$points',
                  icon: Icons.star_border,
                  iconColor: AppColors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatPill(
                  label: 'Offres actives',
                  value: '${repo.activeOffersForRestaurant(restaurantId)}',
                  icon: Icons.local_fire_department_outlined,
                  iconColor: AppColors.purple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatPill(
                  label: 'Check-ins',
                  value: '${repo.pendingCheckInsCount(restaurantId)}',
                  icon: Icons.task_alt,
                  iconColor: AppColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatPill(
                  label: 'Parrainages',
                  value: '${repo.rewardedReferralsForRestaurant(restaurantId)}',
                  icon: Icons.group_add_outlined,
                  iconColor: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatPill(
                  label: 'En attente',
                  value: '${repo.pendingReferralsForRestaurant(restaurantId)}',
                  icon: Icons.hourglass_empty,
                  iconColor: AppColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'Évolution des visites',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${visits.length}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  'visites · ${_period.label.toLowerCase()}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textGray,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY <= 0 ? 1 : maxY + 1,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _gridInterval(series),
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.border,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: _gridInterval(series),
                        getTitlesWidget: (v, meta) => Text(
                          v >= 1000
                              ? '${(v / 1000).toStringAsFixed(1)}k'
                              : v.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textGray,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: (series.length / 4)
                            .clamp(1, series.length)
                            .roundToDouble(),
                        getTitlesWidget: (v, meta) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'J${v.toInt() + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textGray,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppColors.navy,
                      tooltipBorderRadius: BorderRadius.circular(8),
                      getTooltipItems: (spots) => spots
                          .map(
                            (s) => LineTooltipItem(
                              s.y.toInt().toString(),
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < series.length; i++)
                          FlSpot(i.toDouble(), series[i]),
                      ],
                      isCurved: true,
                      color: AppColors.purple,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.purple.withValues(alpha: 0.22),
                            AppColors.purple.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _gridInterval(List<double> series) {
    if (series.isEmpty) return 1;
    final maxY = series.reduce((a, b) => a > b ? a : b);
    final raw = maxY / 4;
    if (raw <= 0) return 1;
    final magnitude = raw < 10 ? 1 : (raw < 100 ? 10 : 100);
    return (raw / magnitude).ceil() * magnitude.toDouble();
  }
}

class _StatsRange {
  final DateTime currentStart;
  final DateTime currentEnd;
  final DateTime previousStart;
  final DateTime previousEnd;

  const _StatsRange({
    required this.currentStart,
    required this.currentEnd,
    required this.previousStart,
    required this.previousEnd,
  });
}

class _Trend {
  final String? label;
  final bool trendUp;

  const _Trend(this.label, this.trendUp);
}

_StatsRange _rangeFor(_Period period, DateTime now) {
  final todayStart = DateTime(now.year, now.month, now.day);
  final currentStart = DateTime(
    todayStart.year,
    todayStart.month,
    todayStart.day - period.days + 1,
  );
  final duration = now.difference(currentStart);
  return _StatsRange(
    currentStart: currentStart,
    currentEnd: now,
    previousStart: currentStart.subtract(duration),
    previousEnd: currentStart,
  );
}

List<double> _visitsSeries(
  LoyaltyRepository repo,
  String restaurantId,
  DateTime start,
  int days,
) {
  return List.generate(days, (index) {
    final dayStart = DateTime(start.year, start.month, start.day + index);
    final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);
    return repo
        .visitsForRestaurantBetween(restaurantId, dayStart, dayEnd)
        .length
        .toDouble();
  });
}

_Trend _trend(int current, int previous) {
  if (previous == 0) {
    return _Trend(current == 0 ? null : 'Nouveau', true);
  }
  final percent = ((current - previous) / previous * 100).round();
  if (percent == 0) return const _Trend('stable', true);
  return _Trend(percent > 0 ? '+$percent%' : '$percent%', percent > 0);
}
