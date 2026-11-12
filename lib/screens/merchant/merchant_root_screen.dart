import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/loyalo_merchant_dashboard_ui.dart';
import 'client_search_screen.dart';
import 'merchant_dashboard_screen.dart';
import 'offers_management_screen.dart';
import 'rewards_management_screen.dart';
import 'statistics_screen.dart';
import 'validate_visit_screen.dart';

class MerchantRootScreen extends ConsumerStatefulWidget {
  const MerchantRootScreen({super.key});

  @override
  ConsumerState<MerchantRootScreen> createState() => _MerchantRootScreenState();
}

class _MerchantRootScreenState extends ConsumerState<MerchantRootScreen> {
  int _index = 0;

  static const _screens = [
    MerchantDashboardScreen(),
    ClientSearchScreen(),
    ValidateVisitScreen(),
    RewardsManagementScreen(),
    OffersManagementScreen(),
    StatisticsScreen(),
  ];

  static const _items = [
    NavItemData(icon: Icons.home_outlined, label: 'Accueil'),
    NavItemData(icon: Icons.people_outline, label: 'Clients'),
    NavItemData(icon: Icons.check_circle_outline, label: 'Valider'),
    NavItemData(icon: Icons.card_giftcard_outlined, label: 'Récompenses'),
    NavItemData(icon: Icons.local_fire_department_outlined, label: 'Offres'),
    NavItemData(icon: Icons.bar_chart, label: 'Stats'),
  ];

  @override
  Widget build(BuildContext context) {
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider);
    final repo = ref.watch(loyaltyRepositoryProvider);
    final available =
        restaurantId != null && repo.restaurantByIdOrNull(restaurantId) != null;
    return Scaffold(
      // Les autres pages exigent un commerce chargé. Pendant une erreur ou
      // une session absente, seul le dashboard peut présenter cet état.
      body: available
          ? IndexedStack(index: _index, children: _screens)
          : const MerchantDashboardScreen(),
      bottomNavigationBar: LoyaloMerchantBottomNav(
        items: _items,
        selectedIndex: available ? _index : 0,
        enabled: available,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
