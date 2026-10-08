import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/check_in_request.dart';
import '../../models/restaurant.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/loyalty_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_ui.dart';
import '../notifications_screen.dart';
import '../welcome_screen.dart';
import 'activity_history_screen.dart';
import 'client_search_screen.dart';
import 'merchant_settings_screen.dart';
import 'offers_management_screen.dart';
import 'rewards_management_screen.dart';
import 'validate_visit_screen.dart';

enum _DashboardPeriod {
  today('Aujourd\'hui', 1),
  sevenDays('7 derniers jours', 7),
  thirtyDays('30 derniers jours', 30);

  final String label;
  final int days;

  const _DashboardPeriod(this.label, this.days);
}

class MerchantDashboardScreen extends ConsumerStatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  ConsumerState<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState
    extends ConsumerState<MerchantDashboardScreen> {
  _DashboardPeriod _period = _DashboardPeriod.today;

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    ref.read(loyaltyRepositoryProvider).stopListening();
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider)!;
    final restaurant = repo.restaurantByIdOrNull(restaurantId);
    if (restaurant == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundOf(context),
        body: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.purple),
          ),
        ),
      );
    }
    final range = _rangeFor(_period, DateTime.now());
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final activity = repo.visitsForRestaurantBetween(
      restaurantId,
      range.currentStart,
      range.currentEnd,
    );
    final previousActivity = repo.visitsForRestaurantBetween(
      restaurantId,
      range.previousStart,
      range.previousEnd,
    );
    final previewActivity = activity.take(3).toList();
    final pointsGranted = repo.pointsGrantedBetween(
      restaurantId,
      range.currentStart,
      range.currentEnd,
    );
    final previousPoints = repo.pointsGrantedBetween(
      restaurantId,
      range.previousStart,
      range.previousEnd,
    );
    final newClients = repo.newClientsBetween(
      restaurantId,
      range.currentStart,
      range.currentEnd,
    );
    final previousNewClients = repo.newClientsBetween(
      restaurantId,
      range.previousStart,
      range.previousEnd,
    );
    final totalClients = repo.uniqueClientsForRestaurant(restaurantId);
    final activeClients = repo.activeClientsSince(
      restaurantId,
      now.subtract(const Duration(days: 30)),
    );
    final newClientsThisMonth = repo.newClientsBetween(
      restaurantId,
      monthStart,
      now,
    );
    final background = AppTheme.backgroundOf(context);
    final surface = AppTheme.surfaceOf(context);
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);
    final border = AppTheme.borderOf(context);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: text,
        title: Text('Tableau de bord', style: TextStyle(color: text)),
        actions: [
          _NotificationAction(
            count: repo.unreadNotificationsForMerchant(restaurantId),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(
                  merchant: true,
                  restaurantId: restaurantId,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MerchantSettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
          ),
          IconButton(
            onPressed: () => _logout(context, ref),
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _MerchantHeader(restaurant: restaurant),
          const SizedBox(height: 16),
          PopupMenuButton<_DashboardPeriod>(
            initialValue: _period,
            onSelected: (period) => setState(() => _period = period),
            itemBuilder: (context) => _DashboardPeriod.values
                .map(
                  (period) =>
                      PopupMenuItem(value: period, child: Text(period.label)),
                )
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _period.label,
                      style: TextStyle(
                        color: text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, color: muted, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ClientSummaryCard(
            totalClients: totalClients,
            activeClients: activeClients,
            newClientsThisMonth: newClientsThisMonth,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TodayCard(
                  color: AppColors.teal,
                  value: '${activity.length}',
                  label: 'Visites',
                  trend: _trendLabel(activity.length, previousActivity.length),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TodayCard(
                  color: AppColors.purple,
                  value: '$newClients',
                  label: 'Nouveaux clients',
                  trend: _trendLabel(newClients, previousNewClients),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WideDarkStat(
            value: '$pointsGranted',
            label: 'Points accordés',
            trend: _trendLabel(pointsGranted, previousPoints),
            icon: Icons.star_border,
          ),
          const SizedBox(height: 12),
          _PendingCheckInsSection(restaurantId: restaurantId),
          const SizedBox(height: 18),
          _QuickActions(restaurantId: restaurantId),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activité récente',
                style: TextStyle(
                  color: text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ActivityHistoryScreen(),
                  ),
                ),
                child: const Text('Voir tout'),
              ),
            ],
          ),
          if (previewActivity.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aucune activité pour le moment.',
                style: TextStyle(color: muted),
              ),
            )
          else
            ...previewActivity.map(
              (v) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.teal.withValues(alpha: 0.16),
                      child: const Icon(
                        Icons.check,
                        color: AppColors.teal,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            repo.nameForClient(v.userId),
                            style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            repo.isFirstVisitForRestaurant(v)
                                ? 'Première visite · ${_relativeTime(v.timestamp)}'
                                : 'Visite validée · ${_relativeTime(v.timestamp)}',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+${restaurant.pointsPerVisit} pts',
                      style: const TextStyle(
                        color: AppColors.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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

class _NotificationAction extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;

  const _NotificationAction({required this.count, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: const Icon(Icons.notifications_none),
          tooltip: 'Notifications',
        ),
        if (count > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(999),
              ),
              constraints: const BoxConstraints(minWidth: 17),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _relativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  return DateFormat('dd/MM à HH:mm').format(date);
}

class _MerchantHeader extends StatelessWidget {
  final Restaurant restaurant;

  const _MerchantHeader({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);

    return Row(
      children: [
        LoyaloMerchantAvatar(
          imageUrl: restaurant.logoUrl ?? restaurant.coverImageUrl,
          icon: restaurant.icon,
          size: 56,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                restaurant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                restaurant.cuisine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClientSummaryCard extends StatelessWidget {
  final int totalClients;
  final int activeClients;
  final int newClientsThisMonth;

  const _ClientSummaryCard({
    required this.totalClients,
    required this.activeClients,
    required this.newClientsThisMonth,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);

    return LoyaloCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const LoyaloIconBadge(
            icon: Icons.people_alt_outlined,
            color: AppColors.purple,
            size: 48,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalClients',
                  style: TextStyle(
                    color: text,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Clients',
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$activeClients actifs · $newClientsThisMonth nouveaux ce mois-ci',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardRange {
  final DateTime currentStart;
  final DateTime currentEnd;
  final DateTime previousStart;
  final DateTime previousEnd;

  const _DashboardRange({
    required this.currentStart,
    required this.currentEnd,
    required this.previousStart,
    required this.previousEnd,
  });
}

_DashboardRange _rangeFor(_DashboardPeriod period, DateTime now) {
  final todayStart = DateTime(now.year, now.month, now.day);
  final currentStart = period == _DashboardPeriod.today
      ? todayStart
      : DateTime(
          todayStart.year,
          todayStart.month,
          todayStart.day - period.days + 1,
        );
  final duration = now.difference(currentStart);
  return _DashboardRange(
    currentStart: currentStart,
    currentEnd: now,
    previousStart: currentStart.subtract(duration),
    previousEnd: currentStart,
  );
}

String? _trendLabel(int current, int previous) {
  if (previous == 0) return current == 0 ? null : 'Nouveau';
  final percent = ((current - previous) / previous * 100).round();
  if (percent == 0) return 'stable';
  return percent > 0 ? '+$percent%' : '$percent%';
}

class _PendingCheckInsSection extends ConsumerStatefulWidget {
  final String restaurantId;

  const _PendingCheckInsSection({required this.restaurantId});

  @override
  ConsumerState<_PendingCheckInsSection> createState() =>
      _PendingCheckInsSectionState();
}

class _PendingCheckInsSectionState
    extends ConsumerState<_PendingCheckInsSection> {
  final Set<String> _processing = {};

  Future<void> _approve(String checkInId) async {
    setState(() => _processing.add(checkInId));
    final merchantId = AuthService().currentUser?.uid ?? 'merchant';
    final result = await ref
        .read(loyaltyRepositoryProvider)
        .approveCheckIn(checkInId: checkInId, merchantId: merchantId);
    if (!mounted) return;
    setState(() => _processing.remove(checkInId));

    final message = switch (result.outcome) {
      CheckInValidationOutcome.validated =>
        'Visite validée · +${result.pointsAwarded} pts',
      CheckInValidationOutcome.rewardUnlocked =>
        'Visite validée · récompense débloquée',
      CheckInValidationOutcome.rejected => 'Demande refusée.',
      CheckInValidationOutcome.alreadyValidated =>
        'Ce client a déjà une visite récente.',
      CheckInValidationOutcome.expired => 'Cette arrivée a expiré.',
      CheckInValidationOutcome.notPending => 'Cette arrivée est déjà traitée.',
      CheckInValidationOutcome.notFound => 'Arrivée introuvable.',
      CheckInValidationOutcome.unauthorized =>
        'Vous ne pouvez pas valider cette arrivée.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reject(String checkInId) async {
    setState(() => _processing.add(checkInId));
    final merchantId = AuthService().currentUser?.uid ?? 'merchant';
    final result = await ref
        .read(loyaltyRepositoryProvider)
        .rejectCheckIn(checkInId: checkInId, merchantId: merchantId);
    if (!mounted) return;
    setState(() => _processing.remove(checkInId));

    final message = switch (result.outcome) {
      CheckInValidationOutcome.rejected => 'Demande refusée.',
      CheckInValidationOutcome.expired => 'Cette arrivée a expiré.',
      CheckInValidationOutcome.notPending => 'Cette arrivée est déjà traitée.',
      CheckInValidationOutcome.notFound => 'Arrivée introuvable.',
      CheckInValidationOutcome.unauthorized =>
        'Vous ne pouvez pas refuser cette arrivée.',
      CheckInValidationOutcome.validated ||
      CheckInValidationOutcome.rewardUnlocked ||
      CheckInValidationOutcome.alreadyValidated => 'Demande déjà traitée.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);

    return StreamBuilder<List<CheckInRequest>>(
      stream: repo.watchPendingCheckInsForRestaurant(widget.restaurantId),
      builder: (context, snapshot) {
        final pending = snapshot.data ?? const <CheckInRequest>[];
        return _PendingCheckInsCard(
          restaurantId: widget.restaurantId,
          pending: pending,
          hasError: snapshot.hasError,
          processing: _processing,
          onApprove: _approve,
          onReject: _reject,
          text: text,
          muted: muted,
          repo: repo,
        );
      },
    );
  }
}

class _PendingCheckInsCard extends StatelessWidget {
  final String restaurantId;
  final List<CheckInRequest> pending;
  final bool hasError;
  final Set<String> processing;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;
  final Color text;
  final Color muted;
  final LoyaltyRepository repo;

  const _PendingCheckInsCard({
    required this.restaurantId,
    required this.pending,
    required this.hasError,
    required this.processing,
    required this.onApprove,
    required this.onReject,
    required this.text,
    required this.muted,
    required this.repo,
  });

  @override
  Widget build(BuildContext context) {
    return LoyaloCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LoyaloIconBadge(
                icon: Icons.flash_on,
                color: AppColors.teal,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loyalo Express',
                      style: TextStyle(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      hasError
                          ? 'Lecture impossible, réessayez plus tard'
                          : pending.isEmpty
                          ? 'Aucun client en attente'
                          : '${pending.length} client${pending.length > 1 ? 's' : ''} attend${pending.length > 1 ? 'ent' : ''} votre validation',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (pending.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ValidateVisitScreen(),
                    ),
                  ),
                  child: const Text('Voir'),
                ),
            ],
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...pending.take(4).map((request) {
              final clientName = repo.nameForClient(request.customerId);
              final count = repo.passageCount(request.customerId, restaurantId);
              final restaurant = repo.restaurantById(restaurantId);
              final remaining =
                  restaurant.rewardThreshold -
                  (count % restaurant.rewardThreshold);
              final arrivedAgo = DateTime.now()
                  .difference(request.requestedAt)
                  .inMinutes;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.purple.withValues(alpha: 0.14),
                      child: Text(
                        clientName.isNotEmpty
                            ? clientName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.purple,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clientName,
                            style: TextStyle(
                              color: text,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            remaining == 1
                                ? '$count/${restaurant.rewardThreshold} · proche d\'une récompense'
                                : '$count/${restaurant.rewardThreshold} visites · arrivé il y a ${arrivedAgo.clamp(0, 10)} min',
                            style: TextStyle(color: muted, fontSize: 11),
                          ),
                          Text(
                            _loyaltyBadgeFor(count),
                            style: const TextStyle(
                              color: AppColors.teal,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        SizedBox(
                          height: 38,
                          child: TextButton(
                            onPressed: processing.contains(request.id)
                                ? null
                                : () => onApprove(request.id),
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: processing.contains(request.id)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Valider',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                        TextButton(
                          onPressed: processing.contains(request.id)
                              ? null
                              : () => onReject(request.id),
                          child: const Text(
                            'Refuser',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

String _loyaltyBadgeFor(int passageCount) {
  if (passageCount == 0) return 'Nouveau';
  if (passageCount >= 10) return 'VIP';
  if (passageCount >= 3) return 'Fidèle';
  return 'Client récent';
}

class _QuickActions extends StatelessWidget {
  final String restaurantId;

  const _QuickActions({required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: TextStyle(
            color: AppTheme.textOf(context),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.9,
          children: [
            _QuickActionButton(
              icon: Icons.check_circle_outline,
              label: 'Valider',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ValidateVisitScreen()),
              ),
            ),
            _QuickActionButton(
              icon: Icons.people_outline,
              label: 'Clients',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ClientSearchScreen()),
              ),
            ),
            _QuickActionButton(
              icon: Icons.local_fire_department_outlined,
              label: 'Offre',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const OffersManagementScreen(),
                ),
              ),
            ),
            _QuickActionButton(
              icon: Icons.card_giftcard_outlined,
              label: 'Récompenses',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RewardsManagementScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTheme.textOf(context);
    final border = AppTheme.borderOf(context);

    return Material(
      color: AppTheme.surfaceOf(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.purple, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final Color color;
  final String value;
  final String label;
  final String? trend;

  const _TodayCard({
    required this.color,
    required this.value,
    required this.label,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final surface = AppTheme.surfaceOf(context);
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);
    final border = AppTheme.borderOf(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: text,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 8),
          if (trend != null)
            Text(
              trend!,
              style: TextStyle(
                color: trend!.startsWith('-')
                    ? AppColors.danger
                    : AppColors.teal,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _WideDarkStat extends StatelessWidget {
  final String value;
  final String label;
  final String? trend;
  final IconData icon;

  const _WideDarkStat({
    required this.value,
    required this.label,
    this.trend,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final surface = AppTheme.surfaceOf(context);
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);
    final border = AppTheme.borderOf(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: text,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label, style: TextStyle(color: muted, fontSize: 12)),
                if (trend != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    trend!,
                    style: TextStyle(
                      color: trend!.startsWith('-')
                          ? AppColors.danger
                          : AppColors.teal,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.teal),
          ),
        ],
      ),
    );
  }
}
