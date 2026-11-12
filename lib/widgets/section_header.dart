import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const SectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.textOf(context),
      ),
    );
    final action = onSeeAll == null
        ? null
        : TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text(
              'Voir tout',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.purple,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (action != null &&
            (constraints.maxWidth < 330 ||
                MediaQuery.textScalerOf(context).scale(16) > 23)) {
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
            if (action != null) ...[const SizedBox(width: 12), action],
          ],
        );
      },
    );
  }
}
