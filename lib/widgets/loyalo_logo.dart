import 'package:flutter/material.dart';

/// Marque discrète des accueils, issue du monogramme officiel existant.
class LoyaloDashboardMark extends StatelessWidget {
  const LoyaloDashboardMark({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Loyalo',
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: 48,
        child: Image.asset(
          'assets/images/app_icon_foreground.png',
          fit: BoxFit.contain,
          cacheWidth: (48 * MediaQuery.devicePixelRatioOf(context)).ceil(),
        ),
      ),
    ),
  );
}

/// Logo officiel Loyalo (asset fourni), avec ou sans le slogan.
/// `markSize` calibre la taille globale du lockup (icône + texte).
class LoyaloWordmark extends StatelessWidget {
  final double markSize;
  final bool showTagline;

  const LoyaloWordmark({
    super.key,
    this.markSize = 96,
    this.showTagline = true,
  });

  @override
  Widget build(BuildContext context) {
    final asset = showTagline
        ? 'assets/images/loyalo_logo.png'
        : 'assets/images/loyalo_logo_compact.png';

    return Image.asset(asset, width: markSize * 2.75, fit: BoxFit.contain);
  }
}
