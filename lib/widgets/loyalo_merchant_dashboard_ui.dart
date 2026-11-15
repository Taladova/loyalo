import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/restaurant.dart';
import 'loyalo_auth_ui.dart';
import 'loyalo_logo.dart';
import 'loyalo_ui.dart';
import 'main_bottom_nav.dart';

class LoyaloMerchantHeader extends StatelessWidget {
  const LoyaloMerchantHeader({
    super.key,
    this.restaurant,
    required this.notificationCount,
    required this.onNotifications,
    required this.onProfile,
    required this.onEstablishment,
    required this.onStatistics,
  });
  final Restaurant? restaurant;
  final int notificationCount;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final VoidCallback? onEstablishment;
  final VoidCallback? onStatistics;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        final actionExtent = constraints.maxWidth < 320
            ? 32.0
            : constraints.maxWidth < 350
            ? 40.0
            : 48.0;
        final actionSpacing = compact ? 2.0 : 4.0;
        final markSize = compact ? 24.0 : 28.0;
        final brand = Row(
          children: [
            ClipRect(
              child: Align(
                widthFactor: 0.5,
                heightFactor: 0.6,
                child: LoyaloDashboardMark(size: markSize * 2),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                key: const Key('dashboard-merchant-title-fit'),
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Espace commerçant',
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: Colors.white,
                    fontSize: constraints.maxWidth >= 390 ? 20 : 18,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MerchantHeaderAction(
              extent: actionExtent,
              icon: Icons.notifications_none_rounded,
              label: 'Notifications',
              count: notificationCount,
              onPressed: onNotifications,
            ),
            SizedBox(width: actionSpacing),
            _MerchantHeaderAction(
              extent: actionExtent,
              icon: Icons.bar_chart_rounded,
              label: 'Statistiques',
              onPressed: onStatistics,
            ),
            SizedBox(width: actionSpacing),
            _MerchantHeaderAction(
              extent: actionExtent,
              icon: Icons.settings_outlined,
              label: 'Paramètres',
              onPressed: onProfile,
            ),
          ],
        );
        final store = restaurant;
        final avatarSize = compact ? 36.0 : 40.0;
        final identitySpacing = compact ? 8.0 : 10.0;
        final buttonPadding = compact ? 8.0 : 10.0;
        final buttonIcon = compact ? 16.0 : 18.0;
        final buttonChevron = compact ? 14.0 : 16.0;
        final buttonSpacing = compact ? 4.0 : 6.0;
        final establishmentStyle = Theme.of(context).textTheme.labelLarge!
            .copyWith(
              fontSize: compact ? 12 : 13,
              height: 1.2,
              fontWeight: FontWeight.w600,
            );
        final label = TextPainter(
          text: TextSpan(
            text: 'Mon établissement',
            style: DefaultTextStyle.of(context).style.merge(establishmentStyle),
          ),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
        )..layout();
        final establishmentWidth = math.min(
          constraints.maxWidth -
              avatarSize -
              identitySpacing * 2 -
              (compact ? 64 : 88),
          label.width +
              buttonPadding * 2 +
              buttonIcon +
              buttonChevron +
              buttonSpacing * 2 +
              2,
        );
        label.dispose();
        final establishment = SizedBox(
          width: establishmentWidth,
          child: OutlinedButton(
            key: const Key('dashboard-establishment'),
            onPressed: onEstablishment,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: LoyaloAuthColors.navy.withValues(alpha: 0.55),
              side: BorderSide(
                color: LoyaloAuthColors.turquoise.withValues(alpha: 0.38),
              ),
              minimumSize: const Size(48, 48),
              padding: EdgeInsets.symmetric(
                horizontal: buttonPadding,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: establishmentStyle,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.storefront_outlined, size: buttonIcon),
                ),
                SizedBox(width: buttonSpacing),
                const Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Mon établissement',
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                SizedBox(width: buttonSpacing),
                ExcludeSemantics(
                  child: Icon(Icons.chevron_right, size: buttonChevron),
                ),
              ],
            ),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: brand),
                const SizedBox(width: 8),
                actions,
              ],
            ),
            if (store != null) ...[
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  LoyaloMerchantAvatar(
                    imageUrl: store.logoUrl ?? store.coverImageUrl,
                    icon: store.icon,
                    size: avatarSize,
                  ),
                  SizedBox(width: identitySpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name,
                          key: const Key('dashboard-restaurant-name'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 18 : 20,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (store.cuisine.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            store.cuisine,
                            key: const Key('dashboard-restaurant-category'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: identitySpacing),
                  establishment,
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
    this.extent = 48,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final int count;
  final double extent;

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
          icon: Container(
            width: math.min(36, extent),
            height: math.min(36, extent),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: onPressed == null ? 0.06 : 0.10,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: extent < 40 ? 20 : 22),
          ),
          style: IconButton.styleFrom(
            fixedSize: Size(extent, 48),
            minimumSize: Size(extent, 48),
            maximumSize: Size(extent, 48),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.standard,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.45),
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
    this.compact = false,
  });
  final T value;
  final String label;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    initialValue: value,
    tooltip: 'Choisir la période',
    onSelected: onSelected,
    itemBuilder: (_) => items,
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE3F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            color: LoyaloAuthColors.textSecondary,
            size: 18,
          ),
          SizedBox(width: compact ? 6 : 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: LoyaloAuthColors.textPrimary,
                fontSize: compact ? 12 : 14,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: LoyaloAuthColors.textSecondary,
            size: compact ? 20 : 24,
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
      if (constraints.maxWidth < 280 ||
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
  }) : assert(items.length == 5),
       assert(selectedIndex >= 0 && selectedIndex < 5);

  final List<NavItemData> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: LoyaloAuthColors.navy,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = MediaQuery.paddingOf(context);
          final sideInset = math.max(
            constraints.maxWidth < 360 ? 0.0 : 8.0,
            math.max(padding.left, padding.right),
          );
          final contentWidth = constraints.maxWidth - sideInset * 2;
          // La surface Android peut être provisoirement vide au démarrage.
          // Attendre la place des cinq cibles préserve la géométrie du bouton.
          if (contentWidth < 4 * 48 + 64) {
            return const SizedBox.shrink();
          }
          final centerSize = contentWidth < 400 ? 56.0 : 60.0;
          const rise = 12.0;
          final style = DefaultTextStyle.of(context).style.merge(
            const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.15,
              letterSpacing: 0,
            ),
          );
          final centerSlot = centerSize + 8;
          final sideWidth = (contentWidth - centerSlot) / 2;
          final rewardLabel = TextPainter(
            text: TextSpan(text: items[3].label, style: style),
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
          )..layout();
          final rewardsWidth = math
              .max(sideWidth / 2, rewardLabel.width)
              .clamp(48.0, sideWidth - 48)
              .toDouble();
          rewardLabel.dispose();
          final widths = [
            sideWidth / 2,
            sideWidth / 2,
            centerSlot,
            rewardsWidth,
            sideWidth - rewardsWidth,
          ];
          return SafeArea(
            top: false,
            minimum: EdgeInsets.fromLTRB(sideInset, 0, sideInset, 8),
            child: Stack(
              key: const Key('merchant-nav-hit-area'),
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: rise,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: PhysicalShape(
                    key: const Key('merchant-nav-surface'),
                    clipper: _MerchantNavBarClipper(
                      centerSize: centerSize,
                      rise: rise,
                    ),
                    color: Colors.white,
                    shadowColor: const Color(0x26000B27),
                    elevation: 3,
                    clipBehavior: Clip.antiAlias,
                    child: const SizedBox.expand(),
                  ),
                ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(
                      items.length,
                      (index) => SizedBox(
                        width: widths[index],
                        child: _MerchantNavDestination(
                          key: ValueKey('merchant-nav-item-$index'),
                          item: items[index],
                          central: index == 2,
                          selected: selectedIndex == index,
                          enabled: enabled,
                          centerSize: centerSize,
                          rise: rise,
                          labelStyle: style,
                          onTap: () => onTap(index),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MerchantNavBarClipper extends CustomClipper<Path> {
  const _MerchantNavBarClipper({required this.centerSize, required this.rise});

  final double centerSize;
  final double rise;

  @override
  Path getClip(Size size) {
    final bar = Offset.zero & size;
    // La découpe laisse six points d'air autour du cercle, ombre comprise.
    final button = Rect.fromCircle(
      center: Offset(size.width / 2, centerSize / 2 - rise),
      radius: centerSize / 2 + 6,
    );
    final roundedBar = Path()..addRRect(BorderRadius.circular(26).toRRect(bar));
    final notchedBar = const CircularNotchedRectangle().getOuterPath(
      bar,
      button,
    );
    return Path.combine(PathOperation.intersect, roundedBar, notchedBar);
  }

  @override
  bool shouldReclip(_MerchantNavBarClipper oldClipper) =>
      centerSize != oldClipper.centerSize || rise != oldClipper.rise;
}

class _MerchantNavDestination extends StatefulWidget {
  const _MerchantNavDestination({
    super.key,
    required this.item,
    required this.central,
    required this.selected,
    required this.enabled,
    required this.centerSize,
    required this.rise,
    required this.labelStyle,
    required this.onTap,
  });
  final NavItemData item;
  final bool central;
  final bool selected;
  final bool enabled;
  final double centerSize;
  final double rise;
  final TextStyle labelStyle;
  final VoidCallback onTap;

  @override
  State<_MerchantNavDestination> createState() =>
      _MerchantNavDestinationState();
}

class _MerchantNavDestinationState extends State<_MerchantNavDestination> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? LoyaloAuthColors.purple
        : LoyaloAuthColors.textSecondary;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final enlargedLabels =
        MediaQuery.textScalerOf(
          context,
        ).scale(widget.labelStyle.fontSize ?? 11) >
        14;
    final labelPadding = widget.central || enlargedLabels ? 4.0 : 0.0;
    final icon = widget.central
        ? AnimatedScale(
            key: const Key('merchant-nav-validate-press'),
            scale: _pressed && widget.enabled ? 0.95 : 1,
            duration: duration,
            curve: Curves.easeOut,
            child: AnimatedContainer(
              key: const Key('merchant-nav-validate-icon'),
              duration: duration,
              curve: Curves.easeOut,
              width: widget.centerSize,
              height: widget.centerSize,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    LoyaloAuthColors.turquoise,
                    Color(0xFF0868FF),
                    LoyaloAuthColors.purple,
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.selected
                      ? LoyaloAuthColors.purple.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.9),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000B27),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 29,
                color: Colors.white,
              ),
            ),
          )
        : SizedBox(
            height: widget.centerSize - widget.rise,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(begin: color, end: color),
                    duration: duration,
                    curve: Curves.easeOut,
                    builder: (context, value, _) =>
                        Icon(widget.item.icon, size: 23, color: value ?? color),
                  ),
                ),
                Positioned(
                  bottom: 1,
                  child: AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOut,
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: widget.selected ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          );
    return Semantics(
      button: true,
      selected: widget.selected,
      enabled: widget.enabled,
      label: widget.item.label,
      onTap: widget.enabled ? widget.onTap : null,
      excludeSemantics: true,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.45,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: widget.central ? const Key('merchant-nav-validate-tap') : null,
            borderRadius: BorderRadius.circular(20),
            onTap: widget.enabled ? widget.onTap : null,
            onHighlightChanged: (value) {
              if (widget.central && mounted && _pressed != value) {
                setState(() => _pressed = value);
              }
            },
            child: SizedBox(
              child: Padding(
                padding: EdgeInsets.only(
                  top: widget.central ? 0 : widget.rise,
                  left: labelPadding,
                  right: labelPadding,
                  bottom: 4,
                ),
                child: Column(
                  children: [
                    icon,
                    if (!widget.central) ...[
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        key: ValueKey(
                          'merchant-nav-label-${widget.item.label}',
                        ),
                        style: widget.labelStyle.copyWith(color: color),
                        duration: duration,
                        curve: Curves.easeOut,
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                            widget.item.label,
                            textAlign: TextAlign.center,
                            softWrap: true,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
