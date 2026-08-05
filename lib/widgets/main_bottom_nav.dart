import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class NavItemData {
  final IconData icon;
  final String label;

  const NavItemData({required this.icon, this.label = ''});
}

/// Barre de navigation avec un item central mis en avant (bouton rond),
/// reprenant la maquette (icône de code/validation surélevée au centre).
class MainBottomNav extends StatelessWidget {
  final List<NavItemData> items;
  final int centerIndex;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const MainBottomNav({
    super.key,
    required this.items,
    required this.centerIndex,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final item = items[i];
            final selected = i == selectedIndex;
            if (i == centerIndex) {
              return GestureDetector(
                onTap: () => onTap(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, color: Colors.white, size: 22),
                    ),
                  ],
                ),
              );
            }
            return InkWell(
              onTap: () => onTap(i),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, color: selected ? AppColors.purple : AppColors.textGray, size: 22),
                    const SizedBox(height: 3),
                    Text(item.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: selected ? AppColors.purple : AppColors.textGray,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        )),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
