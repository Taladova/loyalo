import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/check_in_request.dart';
import '../../models/restaurant.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/loyalty_repository.dart';
import '../../widgets/loyalo_auth_ui.dart';
import '../../widgets/loyalo_merchant_dashboard_ui.dart';
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
    await ref.read(loyaltyRepositoryProvider).stopListening();
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
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider);
    final restaurant = restaurantId == null
        ? null
        : repo.restaurantByIdOrNull(restaurantId);
    if (restaurantId == null || restaurant == null) {
      final hasError =
          restaurantId != null && repo.restaurantsLoadError != null;
      return _frame(
        repo: repo,
        restaurantId: restaurantId,
        body: LoyaloDashboardStatus(
          key: const Key('dashboard-state'),
          loading: restaurantId != null && !hasError && repo.restaurantsLoading,
          message: restaurantId == null
              ? 'Votre session commerçant est indisponible. Reconnectez-vous.'
              : hasError
              ? 'Impossible de charger votre commerce. Réessayez.'
              : repo.restaurantsLoading
              ? 'Chargement de votre commerce…'
              : 'Votre commerce est indisponible pour le moment.',
          onRetry: hasError ? () => repo.retryRestaurants() : null,
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

    return _frame(
      repo: repo,
      restaurantId: restaurantId,
      restaurant: restaurant,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (repo.restaurantsLoading) ...[
            Semantics(
              label: 'Actualisation du commerce en cours',
              child: const LinearProgressIndicator(
                color: LoyaloAuthColors.purple,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (repo.restaurantsLoadError != null) ...[
            const LoyaloAuthError(
              message:
                  'Actualisation du commerce impossible. Les données disponibles restent affichées.',
            ),
            const SizedBox(height: 12),
          ],
          Column(
            key: const Key('dashboard-stats'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LoyaloClientSummaryCard(
                key: const Key('dashboard-clients'),
                totalClients: totalClients,
                activeClients: activeClients,
                newClientsThisMonth: newClientsThisMonth,
              ),
              const SizedBox(height: 12),
              LoyaloDashboardPair(
                first: LoyaloMetricCard(
                  key: const Key('dashboard-visits'),
                  value: '${activity.length}',
                  label: 'Visites',
                  icon: Icons.event_available_outlined,
                  trend: _trendLabel(activity.length, previousActivity.length),
                ),
                second: LoyaloMetricCard(
                  key: const Key('dashboard-new-clients'),
                  value: '$newClients',
                  label: 'Nouveaux clients',
                  icon: Icons.person_add_alt_1_outlined,
                  trend: _trendLabel(newClients, previousNewClients),
                ),
              ),
              const SizedBox(height: 12),
              LoyaloMetricCard(
                key: const Key('dashboard-points'),
                value: '$pointsGranted',
                label: 'Points accordés',
                icon: Icons.toll_outlined,
                trend: _trendLabel(pointsGranted, previousPoints),
                wide: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PendingCheckInsSection(restaurantId: restaurantId),
          const SizedBox(height: 20),
          _QuickActions(restaurantId: restaurantId),
          const SizedBox(height: 20),
          LoyaloDashboardSectionHeader(
            'Activité récente',
            key: const Key('dashboard-section-activity'),
            onViewAll: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ActivityHistoryScreen()),
            ),
          ),
          const SizedBox(height: 10),
          if (previewActivity.isEmpty)
            LoyaloCard(
              key: const Key('dashboard-empty-activity'),
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: const Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.calendar_today_outlined,
                      color: LoyaloAuthColors.textSecondary,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aucune activité pour le moment.',
                      style: TextStyle(
                        color: LoyaloAuthColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...previewActivity.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LoyaloRecentActivityTile(
                  key: ValueKey('dashboard-activity-${v.id}'),
                  name: repo.nameForClient(v.userId),
                  detail: repo.isFirstVisitForRestaurant(v)
                      ? 'Première visite · ${_relativeTime(v.timestamp)}'
                      : 'Visite validée · ${_relativeTime(v.timestamp)}',
                  points: '+${restaurant.pointsPerVisit} pts',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _frame({
    required LoyaltyRepository repo,
    required String? restaurantId,
    Restaurant? restaurant,
    required Widget body,
  }) => LoyaloAuthScaffold(
    onBack: null,
    showBackButton: false,
    headerBuilder: (context, compact, veryCompact) => Column(
      children: [
        LoyaloMerchantHeader(
          restaurant: restaurant,
          merchantName: AuthService().currentUser?.displayName,
          notificationCount: restaurantId == null
              ? 0
              : repo.unreadNotificationsForMerchant(restaurantId),
          onNotifications: restaurant == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(
                      merchant: true,
                      restaurantId: restaurantId!,
                    ),
                  ),
                ),
          onProfile: restaurant == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MerchantSettingsScreen(),
                  ),
                ),
          onLogout: () => _logout(context, ref),
        ),
        if (restaurant != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: LoyaloPeriodSelector<_DashboardPeriod>(
              key: const Key('dashboard-period'),
              value: _period,
              label: _period.label,
              onSelected: (period) => setState(() => _period = period),
              items: _DashboardPeriod.values
                  .map(
                    (period) =>
                        PopupMenuItem(value: period, child: Text(period.label)),
                  )
                  .toList(),
            ),
          ),
      ],
    ),
    contentBuilder: (context, compact) =>
        LoyaloAuthSurface(compact: true, child: body),
  );
}

String _relativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  return DateFormat('dd/MM à HH:mm').format(date);
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
    CheckInValidationResult? result;
    String? errorMessage;
    try {
      final merchantId = AuthService().currentUser?.uid;
      if (merchantId == null) {
        errorMessage = 'Session expirée. Reconnectez-vous pour continuer.';
      } else {
        result = await ref
            .read(loyaltyRepositoryProvider)
            .approveCheckIn(checkInId: checkInId, merchantId: merchantId);
      }
    } catch (error) {
      debugPrint('Validation du check-in impossible: $error');
      errorMessage = 'Validation impossible. Réessayez dans un instant.';
    } finally {
      if (mounted) setState(() => _processing.remove(checkInId));
    }
    if (!mounted) return;

    final message =
        errorMessage ??
        switch (result!.outcome) {
          CheckInValidationOutcome.validated =>
            result.synced
                ? 'Visite validée · +${result.pointsAwarded} pts'
                : 'Validation enregistrée. Synchronisation en attente.',
          CheckInValidationOutcome.rewardUnlocked =>
            'Visite validée · récompense débloquée',
          CheckInValidationOutcome.rejected => 'Demande refusée.',
          CheckInValidationOutcome.alreadyValidated =>
            'Ce client a déjà une visite récente.',
          CheckInValidationOutcome.expired => 'Cette arrivée a expiré.',
          CheckInValidationOutcome.notPending =>
            'Cette arrivée est déjà traitée.',
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
    CheckInValidationResult? result;
    String? errorMessage;
    try {
      final merchantId = AuthService().currentUser?.uid;
      if (merchantId == null) {
        errorMessage = 'Session expirée. Reconnectez-vous pour continuer.';
      } else {
        result = await ref
            .read(loyaltyRepositoryProvider)
            .rejectCheckIn(checkInId: checkInId, merchantId: merchantId);
      }
    } catch (error) {
      debugPrint('Refus du check-in impossible: $error');
      errorMessage = 'Refus impossible. Réessayez dans un instant.';
    } finally {
      if (mounted) setState(() => _processing.remove(checkInId));
    }
    if (!mounted) return;

    final message =
        errorMessage ??
        switch (result!.outcome) {
          CheckInValidationOutcome.rejected =>
            result.synced
                ? 'Demande refusée.'
                : 'Refus enregistré. Synchronisation en attente.',
          CheckInValidationOutcome.expired => 'Cette arrivée a expiré.',
          CheckInValidationOutcome.notPending =>
            'Cette arrivée est déjà traitée.',
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

    return StreamBuilder<List<CheckInRequest>>(
      stream: repo.watchMerchantValidationQueue(
        widget.restaurantId,
        ownerUid: AuthService().currentUser?.uid,
      ),
      builder: (context, snapshot) {
        final pending = snapshot.data ?? const <CheckInRequest>[];
        return _PendingCheckInsCard(
          restaurantId: widget.restaurantId,
          pending: pending,
          loading:
              snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData &&
              !snapshot.hasError &&
              repo.checkInsLoadError == null,
          unavailable:
              snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasData,
          hasError: snapshot.hasError || repo.checkInsLoadError != null,
          processing: _processing,
          onApprove: _approve,
          onReject: _reject,
          repo: repo,
        );
      },
    );
  }
}

class _PendingCheckInsCard extends StatelessWidget {
  const _PendingCheckInsCard({
    required this.restaurantId,
    required this.pending,
    required this.hasError,
    required this.loading,
    required this.unavailable,
    required this.processing,
    required this.onApprove,
    required this.onReject,
    required this.repo,
  });
  final String restaurantId;
  final List<CheckInRequest> pending;
  final bool hasError;
  final bool loading;
  final bool unavailable;
  final Set<String> processing;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;
  final LoyaltyRepository repo;

  @override
  Widget build(BuildContext context) {
    final awaitingValidation = pending
        .where((request) => request.status == CheckInStatus.pending)
        .length;
    return LoyaloExpressCard(
      key: const Key('dashboard-express'),
      loading: loading,
      message: hasError
          ? 'Lecture impossible, réessayez plus tard.'
          : loading
          ? 'Chargement des arrivées en cours…'
          : unavailable
          ? 'Loyalo Express est indisponible pour le moment.'
          : pending.isEmpty
          ? 'Aucun client en attente'
          : awaitingValidation > 0
          ? '$awaitingValidation client${awaitingValidation > 1 ? 's' : ''} attend${awaitingValidation > 1 ? 'ent' : ''} votre validation'
          : 'Validation hors ligne à finaliser',
      onViewAll: awaitingValidation > 0
          ? () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ValidateVisitScreen()),
            )
          : null,
      child: pending.isEmpty
          ? null
          : Column(
              children: pending.take(4).map((request) {
                final canAct = request.status == CheckInStatus.pending;
                final isExpired = request.status == CheckInStatus.expired;
                final clientName = repo.nameForClient(request.customerId);
                final count = repo.passageCount(
                  request.customerId,
                  restaurantId,
                );
                final restaurant = repo.restaurantById(restaurantId);
                final remaining =
                    restaurant.rewardThreshold -
                    (count % restaurant.rewardThreshold);
                final arrivedAgo = DateTime.now()
                    .difference(request.requestedAt)
                    .inMinutes;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LoyaloExpressRequestTile(
                    key: ValueKey('dashboard-request-${request.id}'),
                    name: clientName,
                    canAct: canAct,
                    detail: !canAct
                        ? isExpired
                              ? 'Arrivée expirée · points non attribués'
                              : request.status == CheckInStatus.rejected
                              ? 'Refus en attente de synchronisation'
                              : 'Validation en attente de synchronisation'
                        : remaining == 1
                        ? '$count/${restaurant.rewardThreshold} · proche d\'une récompense'
                        : '$count/${restaurant.rewardThreshold} visites · arrivé il y a ${arrivedAgo.clamp(0, 10)} min',
                    badge: canAct ? _loyaltyBadgeFor(count) : null,
                    processing: processing.contains(request.id),
                    onApprove: () => onApprove(request.id),
                    onReject: () => onReject(request.id),
                  ),
                );
              }).toList(),
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
  const _QuickActions({required this.restaurantId});
  final String restaurantId;
  @override
  Widget build(BuildContext context) => Column(
    key: const Key('dashboard-section-actions'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const LoyaloDashboardSectionHeader('Actions rapides'),
      const SizedBox(height: 10),
      LoyaloDashboardPair(
        first: LoyaloQuickAction(
          label: 'Valider une visite',
          icon: Icons.check_circle_outline_rounded,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ValidateVisitScreen()),
          ),
        ),
        second: LoyaloQuickAction(
          label: 'Mes clients',
          icon: Icons.people_outline_rounded,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ClientSearchScreen())),
        ),
      ),
      const SizedBox(height: 10),
      LoyaloDashboardPair(
        first: LoyaloQuickAction(
          label: 'Créer une offre',
          icon: Icons.local_fire_department_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OffersManagementScreen()),
          ),
        ),
        second: LoyaloQuickAction(
          label: 'Mes récompenses',
          icon: Icons.card_giftcard_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RewardsManagementScreen()),
          ),
        ),
      ),
    ],
  );
}
