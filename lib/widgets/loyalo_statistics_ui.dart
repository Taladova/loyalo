import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'loyalo_auth_ui.dart';
import 'loyalo_ui.dart';

enum LoyaloStatisticStatus { ready, loading, error, unavailable }

class LoyaloStatisticsGrid extends StatelessWidget {
  const LoyaloStatisticsGrid({super.key, required this.cards});
  final List<LoyaloStatisticCard> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      double widthOf(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      }

      var minWidth = 108.0;
      for (final card in cards) {
        for (final word in card.label.split(' ')) {
          minWidth = math.max(minWidth, widthOf(word, _labelStyle) + 24);
        }
        if (card.status == LoyaloStatisticStatus.ready) {
          minWidth = math.max(minWidth, widthOf(card.value, _valueStyle) + 24);
        }
      }
      const gap = 10.0;
      final columns = constraints.maxWidth >= minWidth * 3 + gap * 2
          ? 3
          : constraints.maxWidth >= minWidth * 2 + gap
          ? 2
          : 1;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < cards.length; i++)
            SizedBox(
              width:
                  (constraints.maxWidth -
                      gap *
                          ((columns == 3 &&
                                  cards.length % 3 == 2 &&
                                  i >= cards.length - 2)
                              ? 1
                              : columns - 1)) /
                  ((columns == 3 &&
                          cards.length % 3 == 2 &&
                          i >= cards.length - 2)
                      ? 2
                      : columns),
              child: cards[i],
            ),
        ],
      );
    },
  );
}

const _labelStyle = TextStyle(
  color: LoyaloAuthColors.textPrimary,
  fontSize: 12.5,
  height: 1.25,
  fontWeight: FontWeight.w600,
);
const _valueStyle = TextStyle(
  color: LoyaloAuthColors.textPrimary,
  fontSize: 26,
  height: 1.15,
  fontWeight: FontWeight.w800,
);

class LoyaloStatisticCard extends StatelessWidget {
  const LoyaloStatisticCard({
    super.key,
    required this.id,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.status = LoyaloStatisticStatus.ready,
    this.trend,
    this.trendUp = true,
  });
  final String id;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final LoyaloStatisticStatus status;
  final String? trend;
  final bool trendUp;

  @override
  Widget build(BuildContext context) {
    final message = switch (status) {
      LoyaloStatisticStatus.ready => null,
      LoyaloStatisticStatus.loading => 'Chargement',
      LoyaloStatisticStatus.error => 'Erreur de lecture',
      LoyaloStatisticStatus.unavailable => 'Non disponible',
    };
    return Semantics(
      container: true,
      label:
          '$label : ${message ?? value}${status == LoyaloStatisticStatus.ready && trend != null ? ', $trend' : ''}',
      child: ExcludeSemantics(
        child: LoyaloCard(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoyaloIconBadge(icon: icon, color: color, size: 30),
                const SizedBox(height: 8),
                Text(label, style: _labelStyle),
                const SizedBox(height: 4),
                if (status == LoyaloStatisticStatus.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: LoyaloAuthColors.purple,
                      ),
                    ),
                  )
                else
                  Text(
                    status == LoyaloStatisticStatus.ready ? value : '—',
                    key: ValueKey('stats-value-$id'),
                    style: _valueStyle,
                  ),
                if (message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: status == LoyaloStatisticStatus.error
                          ? AppColors.danger
                          : LoyaloAuthColors.textSecondary,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ] else if (trend != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    trend!,
                    style: TextStyle(
                      color: trendUp
                          ? const Color(0xFF007C73)
                          : AppColors.danger,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Présente la série journalière calculée par l'écran, sans l'agréger.
class LoyaloVisitsChart extends StatelessWidget {
  const LoyaloVisitsChart({
    super.key,
    required this.series,
    required this.start,
    required this.total,
    required this.periodLabel,
    this.status = LoyaloStatisticStatus.ready,
  });
  final List<double> series;
  final DateTime start;
  final int total;
  final String periodLabel;
  final LoyaloStatisticStatus status;

  double _gridInterval() {
    if (series.isEmpty) return 1;
    final maxY = series.reduce(math.max);
    final raw = maxY / 4;
    if (raw <= 0) return 1;
    final magnitude = raw < 10 ? 1 : (raw < 100 ? 10 : 100);
    return (raw / magnitude).ceil() * magnitude.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final empty = series.every((value) => value == 0);
    if (status != LoyaloStatisticStatus.ready) {
      return LoyaloCard(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          child: Column(
            children: [
              if (status == LoyaloStatisticStatus.loading)
                const CircularProgressIndicator(color: LoyaloAuthColors.purple)
              else
                const LoyaloIconBadge(icon: Icons.bar_chart_rounded, size: 40),
              const SizedBox(height: 12),
              Text(
                switch (status) {
                  LoyaloStatisticStatus.loading => 'Chargement des visites…',
                  LoyaloStatisticStatus.error =>
                    'Impossible de charger les visites sur cette période.',
                  _ => 'Les données de visites ne sont pas disponibles.',
                },
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: LoyaloAuthColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final maximum = series.isEmpty ? 1.0 : series.reduce(math.max);
    final dates = DateFormat('dd/MM');
    final scaler = MediaQuery.textScalerOf(context);
    return LoyaloCard(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.fromLTRB(10, 20, 14, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeText = scaler.scale(12) > 18;
          final tickCount = largeText || constraints.maxWidth < 270 ? 2 : 4;
          final interval = ((series.length - 1) / (tickCount - 1))
              .ceilToDouble()
              .clamp(1.0, double.infinity);
          final leftWidth =
              scaler.scale(10) *
                  (maximum >= 1000
                      ? 3.5
                      : maximum.toInt().toString().length + 1) +
              8;
          final chart = SizedBox(
            height: 195 + math.max(0, scaler.scale(12) - 12) * 3,
            child: Stack(
              children: [
                LineChart(
                  key: ValueKey('stats-chart-${series.length}'),
                  duration: Duration.zero,
                  LineChartData(
                    minX: 0,
                    maxX: math.max(1.0, series.length - 1.0),
                    minY: 0,
                    maxY: maximum <= 0 ? 1 : maximum + 1,
                    clipData: const FlClipData.all(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _gridInterval(),
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: Color(0xFFDCE3EF),
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
                          reservedSize: leftWidth,
                          interval: _gridInterval(),
                          getTitlesWidget: (value, meta) => Text(
                            value >= 1000
                                ? '${(value / 1000).toStringAsFixed(1)}k'
                                : value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: LoyaloAuthColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: scaler.scale(10) * 1.3 + 12,
                          interval: interval,
                          getTitlesWidget: (value, meta) {
                            final date = DateTime(
                              start.year,
                              start.month,
                              start.day + value.round(),
                            );
                            return SideTitleWidget(
                              meta: meta,
                              space: 8,
                              fitInside: SideTitleFitInsideData(
                                enabled: true,
                                axisPosition: meta.axisPosition,
                                parentAxisSize: meta.parentAxisSize,
                                distanceFromEdge: 0,
                              ),
                              child: Text(
                                dates.format(date),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: LoyaloAuthColors.textSecondary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      enabled: !empty,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => AppColors.navy,
                        tooltipBorderRadius: BorderRadius.circular(10),
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (spots) => spots.map((spot) {
                          final date = DateTime(
                            start.year,
                            start.month,
                            start.day + spot.x.round(),
                          );
                          return LineTooltipItem(
                            '${dates.format(date)} · ${spot.y.toInt()} visite${spot.y == 1 ? '' : 's'}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    lineBarsData: empty
                        ? []
                        : [
                            LineChartBarData(
                              spots: [
                                for (var i = 0; i < series.length; i++)
                                  FlSpot(i.toDouble(), series[i]),
                              ],
                              isCurved: false,
                              color: LoyaloAuthColors.purple,
                              barWidth: 3,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    LoyaloAuthColors.purple.withValues(
                                      alpha: 0.18,
                                    ),
                                    LoyaloAuthColors.purple.withValues(
                                      alpha: 0,
                                    ),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                  ),
                ),
                if (empty)
                  Positioned.fill(
                    bottom: 26,
                    left: leftWidth,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const LoyaloIconBadge(
                              icon: Icons.bar_chart_rounded,
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Aucune visite sur cette période',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: LoyaloAuthColors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
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
          return Semantics(
            container: true,
            label: empty
                ? 'Aucune visite sur cette période, $periodLabel'
                : '$total visites, $periodLabel. Graphique des visites par jour.',
            child: ExcludeSemantics(child: chart),
          );
        },
      ),
    );
  }
}
