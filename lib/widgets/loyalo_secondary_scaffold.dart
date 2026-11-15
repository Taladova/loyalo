import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'loyalo_auth_ui.dart';
import 'loyalo_page_header.dart';

/// Cadre V3 des pages de lecture, avec un retour toujours accessible.
class LoyaloSecondaryScaffold extends StatelessWidget {
  const LoyaloSecondaryScaffold({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: LoyaloAuthColors.navy,
      body: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.6,
                colors: [
                  LoyaloAuthColors.turquoise.withValues(alpha: 0.22),
                  LoyaloAuthColors.navy,
                ],
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomLeft,
                  radius: 1.5,
                  colors: [
                    LoyaloAuthColors.purple.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 20, 20),
                  child: LoyaloPageHeader(
                    title: title,
                    showBackButton: true,
                    centerTitle: false,
                    titleStyle: const TextStyle(fontSize: 20),
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: ColoredBox(
                color: const Color(0xFFF8FAFF),
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: body,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
