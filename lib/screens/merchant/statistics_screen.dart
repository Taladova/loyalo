import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/repository_read_state.dart';
import '../../providers/app_providers.dart';
import '../../services/loyalty_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_auth_ui.dart';
import '../../widgets/loyalo_page_header.dart';
import '../../widgets/loyalo_statistics_ui.dart';
import '../../widgets/loyalo_ui.dart';

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
  bool _retrying = false;
  bool _retryFailed = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retryFailed = false;
    });
    try {
      await ref.read(loyaltyRepositoryProvider).retryRestaurants();
    } catch (_) {
      if (mounted) setState(() => _retryFailed = true);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Widget _periodMenu(double width) => SizedBox(
    width: width,
    child: PopupMenuButton<_Period>(
      key: const Key('statistics-period'),
      tooltip: 'Choisir la période',
      initialValue: _period,
      onSelected: (period) => setState(() => _period = period),
      itemBuilder: (context) => _Period.values
          .map(
            (period) => PopupMenuItem(value: period, child: Text(period.label)),
          )
          .toList(),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                _period.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _frame(BuildContext context, Widget content) => LoyaloAuthScaffold(
    onBack: () => Navigator.of(context).maybePop(),
    showBackButton: false,
    headerBuilder: (context, compact, veryCompact) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double measure(String text, double size, FontWeight weight) {
            final painter = TextPainter(
              text: TextSpan(
                text: text,
                style: DefaultTextStyle.of(
                  context,
                ).style.merge(TextStyle(fontSize: size, fontWeight: weight)),
              ),
              textScaler: MediaQuery.textScalerOf(context),
              textDirection: Directionality.of(context),
            )..layout();
            final width = painter.width;
            painter.dispose();
            return width;
          }

          final back = Navigator.of(context).canPop();
          final selectorWidth =
              (measure(_period.label, 12, FontWeight.w600) + 79).clamp(
                0.0,
                constraints.maxWidth,
              );
          final combined =
              measure('Statistiques', 22, FontWeight.w800) +
              selectorWidth +
              16 +
              (back ? 56 : 0);
          final menu = _periodMenu(selectorWidth);
          final inline =
              combined <= constraints.maxWidth &&
              MediaQuery.textScalerOf(context).scale(16) <= 23;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LoyaloPageHeader(
                title: 'Statistiques',
                centerTitle: false,
                showBackButton: back,
                onBack: () => Navigator.of(context).maybePop(),
                actions: inline ? [menu] : [],
              ),
              if (!inline) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: menu),
              ],
            ],
          );
        },
      ),
    ),
    contentBuilder: (context, compact) => content,
  );

  Widget _status(String message, {bool loading = false, bool retry = false}) =>
      LoyaloCard(
        color: Colors.white,
        child: Semantics(
          liveRegion: true,
          child: Column(
            children: [
              if (loading)
                const CircularProgressIndicator(color: LoyaloAuthColors.purple)
              else
                const LoyaloIconBadge(icon: Icons.info_outline, size: 42),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: LoyaloAuthColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (retry) ...[
                const SizedBox(height: 16),
                LoyaloAuthPrimaryButton(
                  label: 'Réessayer',
                  onPressed: _retrying ? null : _retry,
                  loading: _retrying,
                ),
              ],
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider);
    if (restaurantId == null) {
      return _frame(
        context,
        _status('Votre session commerçant est indisponible. Reconnectez-vous.'),
      );
    }
    if (repo.restaurantsLoadError != null || _retryFailed) {
      return _frame(
        context,
        _status(
          'Impossible de charger les statistiques de votre commerce.',
          retry: true,
        ),
      );
    }
    if (repo.restaurantsLoading) {
      return _frame(
        context,
        _status('Chargement des statistiques…', loading: true),
      );
    }
    if (repo.restaurantByIdOrNull(restaurantId) == null) {
      return _frame(
        context,
        _status('Votre commerce est indisponible pour le moment.', retry: true),
      );
    }

    LoyaloStatisticStatus statusFor(StatisticsDataSource source) =>
        switch (repo.statisticsReadState(source).status) {
          RepositoryReadStatus.ready => LoyaloStatisticStatus.ready,
          RepositoryReadStatus.loading => LoyaloStatisticStatus.loading,
          RepositoryReadStatus.error => LoyaloStatisticStatus.error,
          RepositoryReadStatus.unavailable => LoyaloStatisticStatus.unavailable,
        };
    final visitStatus = statusFor(StatisticsDataSource.visits);
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
    final errors = StatisticsDataSource.values
        .where((source) => statusFor(source) == LoyaloStatisticStatus.error)
        .isNotEmpty;
    final cards = [
      LoyaloStatisticCard(
        key: const Key('stats-visits'),
        id: 'visits',
        label: 'Visites',
        value: '${visits.length}',
        icon: Icons.trending_up,
        color: AppColors.teal,
        status: visitStatus,
        trend: visitTrend.label,
        trendUp: visitTrend.trendUp,
      ),
      LoyaloStatisticCard(
        key: const Key('stats-clients'),
        id: 'clients',
        label: 'Clients',
        value: '$currentClientCount',
        icon: Icons.people_alt_outlined,
        color: AppColors.blue,
        status: visitStatus,
        trend: clientTrend.label,
        trendUp: clientTrend.trendUp,
      ),
      LoyaloStatisticCard(
        key: const Key('stats-rewards'),
        id: 'rewards',
        label: 'Récompenses',
        value: '$rewards',
        icon: Icons.card_giftcard,
        color: AppColors.purple,
        status: statusFor(StatisticsDataSource.rewards),
        trend: rewardTrend.label,
        trendUp: rewardTrend.trendUp,
      ),
      LoyaloStatisticCard(
        key: const Key('stats-points'),
        id: 'points',
        label: 'Points',
        value: '$points',
        icon: Icons.star_border,
        color: AppColors.orange,
        status: visitStatus,
      ),
      LoyaloStatisticCard(
        key: const Key('stats-offers'),
        id: 'offers',
        label: 'Offres actives',
        value: '${repo.activeOffersForRestaurant(restaurantId)}',
        icon: Icons.local_fire_department_outlined,
        color: AppColors.purple,
        status: statusFor(StatisticsDataSource.offers),
      ),
      LoyaloStatisticCard(
        key: const Key('stats-checkins'),
        id: 'checkins',
        label: 'Check-ins',
        value: '${repo.pendingCheckInsCount(restaurantId)}',
        icon: Icons.task_alt,
        color: AppColors.teal,
        status: statusFor(StatisticsDataSource.checkIns),
      ),
      LoyaloStatisticCard(
        key: const Key('stats-referrals'),
        id: 'referrals',
        label: 'Parrainages',
        value: '${repo.rewardedReferralsForRestaurant(restaurantId)}',
        icon: Icons.group_add_outlined,
        color: AppColors.success,
        status: statusFor(StatisticsDataSource.referrals),
      ),
      LoyaloStatisticCard(
        key: const Key('stats-pending'),
        id: 'pending',
        label: 'En attente',
        value: '${repo.pendingReferralsForRestaurant(restaurantId)}',
        icon: Icons.hourglass_empty,
        color: AppColors.orange,
        status: statusFor(StatisticsDataSource.referrals),
      ),
    ];

    return _frame(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (errors) ...[
            const LoyaloAuthError(
              message:
                  'Certaines statistiques ne peuvent pas être chargées. Les valeurs indisponibles sont indiquées par « — ».',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _retrying ? null : _retry,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Réessayer',
                  style: TextStyle(color: Colors.white),
                ),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ),
          ],
          Semantics(
            header: true,
            child: const Text(
              'Aperçu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          LoyaloStatisticsGrid(cards: cards),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                header: true,
                child: const Text(
                  'Évolution des visites',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                visitStatus == LoyaloStatisticStatus.ready
                    ? '${visits.length} visites · ${_period.label.toLowerCase()}'
                    : visitStatus == LoyaloStatisticStatus.loading
                    ? 'Chargement…'
                    : 'Indisponible',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LoyaloVisitsChart(
            series: series,
            start: range.currentStart,
            total: visits.length,
            periodLabel: _period.label,
            status: visitStatus,
          ),
        ],
      ),
    );
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
