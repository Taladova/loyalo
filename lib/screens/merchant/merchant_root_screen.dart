import 'package:flutter/material.dart';

import '../../widgets/main_bottom_nav.dart';
import 'client_search_screen.dart';
import 'merchant_dashboard_screen.dart';
import 'offers_management_screen.dart';
import 'rewards_management_screen.dart';
import 'statistics_screen.dart';
import 'validate_visit_screen.dart';

class MerchantRootScreen extends StatefulWidget {
  const MerchantRootScreen({super.key});

  @override
  State<MerchantRootScreen> createState() => _MerchantRootScreenState();
}

class _MerchantRootScreenState extends State<MerchantRootScreen> {
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
    NavItemData(icon: Icons.check_circle_outline),
    NavItemData(icon: Icons.card_giftcard_outlined, label: 'Récompenses'),
    NavItemData(icon: Icons.local_fire_department_outlined, label: 'Offres'),
    NavItemData(icon: Icons.bar_chart, label: 'Stats'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: MainBottomNav(
        items: _items,
        centerIndex: 2,
        selectedIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
