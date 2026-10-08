import 'package:flutter/material.dart';

import '../../widgets/main_bottom_nav.dart';
import 'client_dashboard_screen.dart';
import 'client_profile_screen.dart';
import 'my_code_screen.dart';
import 'restaurant_list_screen.dart';
import 'rewards_screen.dart';

class ClientRootScreen extends StatefulWidget {
  const ClientRootScreen({super.key});

  @override
  State<ClientRootScreen> createState() => _ClientRootScreenState();
}

class _ClientRootScreenState extends State<ClientRootScreen> {
  int _index = 0;

  List<Widget> get _screens => [
    const ClientDashboardScreen(),
    const RestaurantListScreen(),
    MyCodeScreen(onBack: () => setState(() => _index = 0)),
    const RewardsScreen(),
    const ClientProfileScreen(),
  ];

  static const _items = [
    NavItemData(icon: Icons.home_outlined, label: 'Accueil'),
    NavItemData(icon: Icons.explore_outlined, label: 'Découvrir'),
    NavItemData(icon: Icons.qr_code_scanner),
    NavItemData(icon: Icons.card_giftcard_outlined, label: 'Avantages'),
    NavItemData(icon: Icons.person_outline, label: 'Profil'),
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
