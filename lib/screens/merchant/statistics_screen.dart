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
              Expanded(child: StatPill(label: 'Visites', value: stats['visites']!, trend: stats['trendV']!)),
              const SizedBox(width: 10),
              Expanded(child: StatPill(label: 'Clients', value: stats['clients']!, trend: stats['trendC']!)),
              const SizedBox(width: 10),
              Expanded(child: StatPill(label: 'Récompenses', value: stats['recompenses']!, trend: stats['trendR']!)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Évolution des visites', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
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
        ],
      ),
    );
  }
}
