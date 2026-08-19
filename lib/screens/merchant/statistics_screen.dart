import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

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
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  _Period _period = _Period.thirtyDays;

  static const _seriesByPeriod = {
    _Period.sevenDays: [80.0, 95.0, 88.0, 110.0, 102.0, 130.0, 140.0],
    _Period.thirtyDays: [120.0, 150.0, 140.0, 180.0, 200.0, 190.0, 230.0, 260.0],
    _Period.ninetyDays: [90.0, 130.0, 160.0, 155.0, 210.0, 240.0, 260.0, 300.0, 340.0, 360.0],
  };

  static const _statsByPeriod = {
    _Period.sevenDays: {'visites': '104', 'clients': '62', 'recompenses': '19', 'trendV': '+6%', 'trendC': '+4%', 'trendR': '+9%'},
    _Period.thirtyDays: {'visites': '432', 'clients': '256', 'recompenses': '78', 'trendV': '+18%', 'trendC': '+15%', 'trendR': '+12%'},
    _Period.ninetyDays: {'visites': '1204', 'clients': '540', 'recompenses': '203', 'trendV': '+27%', 'trendC': '+22%', 'trendR': '+20%'},
  };

  @override
  Widget build(BuildContext context) {
    final series = _seriesByPeriod[_period]!;
    final stats = _statsByPeriod[_period]!;

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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          const Text('Aperçu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatPill(
                  label: 'Visites',
                  value: stats['visites']!,
                  trend: stats['trendV']!,
                  icon: Icons.trending_up,
                  iconColor: AppColors.teal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatPill(
                  label: 'Clients',
                  value: stats['clients']!,
                  trend: stats['trendC']!,
                  icon: Icons.people_alt_outlined,
                  iconColor: AppColors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatPill(
                  label: 'Récompenses',
                  value: stats['recompenses']!,
                  trend: stats['trendR']!,
                  icon: Icons.card_giftcard,
                  iconColor: AppColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text('Évolution des visites', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Text(
                stats['visites']!,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.purple),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text('visites · ${_period.label.toLowerCase()}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textGray)),
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
                BoxShadow(color: AppColors.navy.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _gridInterval(series),
                    getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: _gridInterval(series),
                        getTitlesWidget: (v, meta) => Text(
                          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: AppColors.textGray),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: (series.length / 4).clamp(1, series.length).roundToDouble(),
                        getTitlesWidget: (v, meta) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('J${v.toInt() + 1}',
                              style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
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
                          .map((s) => LineTooltipItem(
                                s.y.toInt().toString(),
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                              ))
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (var i = 0; i < series.length; i++) FlSpot(i.toDouble(), series[i])],
                      isCurved: true,
                      color: AppColors.purple,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [AppColors.purple.withValues(alpha: 0.22), AppColors.purple.withValues(alpha: 0.0)],
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
    final maxY = series.reduce((a, b) => a > b ? a : b);
    final raw = maxY / 4;
    if (raw <= 0) return 1;
    final magnitude = raw < 10 ? 1 : (raw < 100 ? 10 : 100);
    return (raw / magnitude).ceil() * magnitude.toDouble();
  }
}
