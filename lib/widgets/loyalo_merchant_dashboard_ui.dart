import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/restaurant.dart';
import 'loyalo_auth_ui.dart';
import 'loyalo_logo.dart';
import 'loyalo_ui.dart';
import 'main_bottom_nav.dart';

class LoyaloMerchantHeader extends StatelessWidget {
  const LoyaloMerchantHeader({
    super.key,
    this.restaurant,
    this.merchantName,
    required this.notificationCount,
    required this.onNotifications,
    required this.onProfile,
    required this.onLogout,
  });
  final Restaurant? restaurant;
  final String? merchantName;
  final int notificationCount;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(16) > 23;
        final brand = Row(
          children: [
            const LoyaloDashboardMark(),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Espace commerçant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MerchantHeaderAction(
              icon: Icons.notifications_none_rounded,
              label: 'Notifications',
              count: notificationCount,
              onPressed: onNotifications,
            ),
            const SizedBox(width: 4),
            _MerchantHeaderAction(
              icon: Icons.person_outline_rounded,
              label: 'Profil et paramètres',
              onPressed: onProfile,
            ),
            const SizedBox(width: 4),
            _MerchantHeaderAction(
              icon: Icons.logout_rounded,
              label: 'Déconnexion',
              onPressed: onLogout,
            ),
          ],
        );
        final store = restaurant;
        final name = merchantName?.trim() ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (largeText || constraints.maxWidth < 310) ...[
              brand,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: actions),
            ] else
              Row(
                children: [
                  Expanded(child: brand),
                  const SizedBox(width: 8),
                  actions,
                ],
              ),
            if (store != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  LoyaloMerchantAvatar(
                    imageUrl: store.logoUrl ?? store.coverImageUrl,
                    icon: store.icon,
                    size: 46,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Bonjour' : 'Bonjour $name',
                          style: TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          store.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (store.cuisine.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            store.cuisine,
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!largeText && constraints.maxWidth >= 330) ...[
                    const SizedBox(width: 6),
                    ExcludeSemantics(
                      child: SizedBox(
                        width: 108,
                        height: 80,
                        child: Image.asset(
                          'assets/images/dashboard/merchant_dashboard_hero.png',
                          fit: BoxFit.contain,
                          cacheHeight:
                              (80 * MediaQuery.devicePixelRatioOf(context))
                                  .ceil(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _MerchantHeaderAction extends StatelessWidget {
  const _MerchantHeaderAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.count = 0,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: count > 0 && onPressed != null ? '$label, $count non lues' : label,
    button: true,
    enabled: onPressed != null,
    onTap: onPressed,
    excludeSemantics: true,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: label,
          onPressed: onPressed,
          icon: Icon(icon, size: 23),
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.45),
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        if (count > 0 && onPressed != null)
          Positioned(
            top: 0,
            right: 0,
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D61),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class LoyaloPeriodSelector<T> extends StatelessWidget {
  const LoyaloPeriodSelector({
    super.key,
    required this.value,
    required this.label,
    required this.items,
    required this.onSelected,
  });
  final T value;
  final String label;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    initialValue: value,
    tooltip: 'Choisir la période',
    onSelected: onSelected,
    itemBuilder: (_) => items,
    child: Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE3F0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            color: LoyaloAuthColors.textSecondary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: LoyaloAuthColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: LoyaloAuthColors.textSecondary,
          ),
        ],
      ),
    ),
  );
}

class LoyaloClientSummaryCard extends StatelessWidget {
  const LoyaloClientSummaryCard({
    super.key,
    required this.totalClients,
    required this.activeClients,
    required this.newClientsThisMonth,
  });
  final int totalClients;
  final int activeClients;
  final int newClientsThisMonth;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '$totalClients clients, $activeClients actifs, $newClientsThisMonth nouveaux ce mois-ci',
    excludeSemantics: true,
    child: LoyaloCard(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(24),
      child: Row(
        children: [
          const _MetricIcon(Icons.people_alt_outlined, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalClients',
                  style: const TextStyle(
                    color: LoyaloAuthColors.textPrimary,
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Clients',
                  style: TextStyle(
                    color: LoyaloAuthColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$activeClients actifs · $newClientsThisMonth nouveaux ce mois-ci',
                  style: const TextStyle(
                    color: LoyaloAuthColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MetricIcon extends StatelessWidget {
  const _MetricIcon(this.icon, {this.size = 36, this.turquoise = false});
  final IconData icon;
  final double size;
  final bool turquoise;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color:
            (turquoise ? LoyaloAuthColors.turquoise : LoyaloAuthColors.purple)
                .withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        size: size * 0.58,
        color: turquoise ? const Color(0xFF00887F) : LoyaloAuthColors.purple,
      ),
    ),
  );
}

class LoyaloMetricCard extends StatelessWidget {
  const LoyaloMetricCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.trend,
    this.wide = false,
  });
  final String value;
  final String label;
  final IconData icon;
  final String? trend;
  final bool wide;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label : $value${trend == null ? '' : ', $trend'}',
    excludeSemantics: true,
    child: LoyaloCard(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(22),
      child: Row(
        children: [
          _MetricIcon(icon, turquoise: wide),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: LoyaloAuthColors.textPrimary,
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: LoyaloAuthColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                if (trend != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    trend!,
                    style: const TextStyle(
                      color: LoyaloAuthColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class LoyaloDashboardPair extends StatelessWidget {
  const LoyaloDashboardPair({
    super.key,
    required this.first,
    required this.second,
  });
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 310 ||
          MediaQuery.textScalerOf(context).scale(16) > 23) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 10), second],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: first),
            const SizedBox(width: 10),
            Expanded(child: second),
          ],
        ),
      );
    },
  );
}

class LoyaloQuickAction extends StatelessWidget {
  const LoyaloQuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 23;
    final glyph = ExcludeSemantics(
      child: Icon(icon, color: LoyaloAuthColors.purple, size: 22),
    );
    const chevron = ExcludeSemantics(
      child: Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: LoyaloAuthColors.textSecondary,
      ),
    );
    final text = Text(
      label,
      style: const TextStyle(
        color: LoyaloAuthColors.textPrimary,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFDCE3F0)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 62),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: largeText
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [glyph, const Spacer(), chevron]),
                      const SizedBox(height: 8),
                      text,
                    ],
                  )
                : Row(
                    children: [
                      glyph,
                      const SizedBox(width: 8),
                      Expanded(child: text),
                      const SizedBox(width: 4),
                      chevron,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class LoyaloDashboardSectionHeader extends StatelessWidget {
  const LoyaloDashboardSectionHeader(this.title, {super.key, this.onViewAll});
  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final heading = Semantics(
      header: true,
      child: Text(
        title,
        style: const TextStyle(
          color: LoyaloAuthColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final action = TextButton(
      onPressed: onViewAll,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: LoyaloAuthColors.purple,
      ),
      child: const Text(
        'Voir tout',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
    if (onViewAll == null) return heading;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (MediaQuery.textScalerOf(context).scale(16) > 23 ||
            constraints.maxWidth < 300) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              Align(alignment: Alignment.centerRight, child: action),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            action,
          ],
        );
      },
    );
  }
}

class LoyaloRecentActivityTile extends StatelessWidget {
  const LoyaloRecentActivityTile({
    super.key,
    required this.name,
    required this.detail,
    required this.points,
  });
  final String name;
  final String detail;
  final String points;

  @override
  Widget build(BuildContext context) => LoyaloCard(
    color: Colors.white,
    padding: const EdgeInsets.all(12),
    borderRadius: BorderRadius.circular(20),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final info = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _MetricIcon(Icons.check_rounded, turquoise: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: LoyaloAuthColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: LoyaloAuthColors.textSecondary,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final amount = Text(
          points,
          style: const TextStyle(
            color: Color(0xFF007A73),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        );
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(16) > 23) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              info,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: amount),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: info),
            const SizedBox(width: 10),
            amount,
          ],
        );
      },
    ),
  );
}

class LoyaloExpressCard extends StatelessWidget {
  const LoyaloExpressCard({
    super.key,
    required this.message,
    required this.loading,
    this.onViewAll,
    this.child,
  });
  final String message;
  final bool loading;
  final VoidCallback? onViewAll;
  final Widget? child;

  @override
  Widget build(BuildContext context) => LoyaloCard(
    color: const Color(0xFFEEFFFC),
    padding: const EdgeInsets.all(14),
    borderRadius: BorderRadius.circular(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _MetricIcon(
              Icons.flash_on_rounded,
              size: 36,
              turquoise: true,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Loyalo Express',
                    style: TextStyle(
                      color: LoyaloAuthColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: LoyaloAuthColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 6),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: LoyaloAuthColors.purple,
                  ),
                ),
              ),
          ],
        ),
        if (onViewAll != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: LoyaloAuthColors.purple,
              ),
              label: const Text('Voir les arrivées'),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        if (child != null) ...[const SizedBox(height: 12), child!],
      ],
    ),
  );
}

class LoyaloExpressRequestTile extends StatelessWidget {
  const LoyaloExpressRequestTile({
    super.key,
    required this.name,
    required this.detail,
    this.badge,
    required this.canAct,
    required this.processing,
    required this.onApprove,
    required this.onReject,
  });
  final String name;
  final String detail;
  final String? badge;
  final bool canAct;
  final bool processing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFDCE3F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: CircleAvatar(
                radius: 18,
                backgroundColor: LoyaloAuthColors.purple.withValues(
                  alpha: 0.10,
                ),
                child: Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: LoyaloAuthColors.purple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: LoyaloAuthColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: LoyaloAuthColors.textSecondary,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      badge!,
                      style: const TextStyle(
                        color: Color(0xFF007A73),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (canAct) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: processing ? null : onApprove,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: LoyaloAuthColors.purple,
                  foregroundColor: Colors.white,
                ),
                icon: processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: const Text(
                  'Valider',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: processing ? null : onReject,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: LoyaloAuthColors.textSecondary,
                ),
                child: const Text('Refuser', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class LoyaloDashboardStatus extends StatelessWidget {
  const LoyaloDashboardStatus({
    super.key,
    required this.message,
    this.loading = false,
    this.onRetry,
  });
  final String message;
  final bool loading;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      children: [
        if (loading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(color: LoyaloAuthColors.purple),
          )
        else
          const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(
              Icons.info_outline_rounded,
              size: 30,
              color: LoyaloAuthColors.purple,
            ),
          ),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: LoyaloAuthColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          LoyaloAuthPrimaryButton(label: 'Réessayer', onPressed: onRetry),
        ],
      ],
    ),
  );
}

class LoyaloMerchantBottomNav extends StatelessWidget {
  const LoyaloMerchantBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    this.enabled = true,
  });
  final List<NavItemData> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widths = <double>[];
            for (final item in items) {
              final painter = TextPainter(
                text: TextSpan(
                  text: item.label,
                  style: DefaultTextStyle.of(context).style.merge(
                    const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              widths.add(math.max(48, painter.width + 16));
              painter.dispose();
            }
            final total = widths.fold(0.0, (sum, width) => sum + width);
            final extra =
                math.max(0.0, constraints.maxWidth - total) / items.length;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final selected = selectedIndex == index;
                  return Semantics(
                    button: true,
                    enabled: enabled,
                    onTap: enabled ? () => onTap(index) : null,
                    excludeSemantics: true,
                    selected: selected,
                    label: item.label,
                    child: SizedBox(
                      width: widths[index] + extra,
                      child: Material(
                        color: selected
                            ? LoyaloAuthColors.purple.withValues(alpha: 0.09)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: enabled ? () => onTap(index) : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 4,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.icon,
                                  size: 22,
                                  color: selected
                                      ? LoyaloAuthColors.purple
                                      : LoyaloAuthColors.textSecondary,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: selected
                                        ? LoyaloAuthColors.purple
                                        : LoyaloAuthColors.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    ),
  );
}
