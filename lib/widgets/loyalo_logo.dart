import 'package:flutter/material.dart';

/// Version compacte du logo officiel V3 : seule la zone du slogan est masquée.
/// Aucun asset n'est recréé et les proportions du logo restent inchangées.
class LoyaloMerchantBrand extends StatelessWidget {
  const LoyaloMerchantBrand({super.key, required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Loyalo',
    child: ExcludeSemantics(
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          widthFactor: 1,
          heightFactor: 0.74,
          child: Image.asset(
            'assets/images/logo_loyalo_v3_light.png',
            width: width,
            fit: BoxFit.contain,
            cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).ceil(),
          ),
        ),
      ),
    ),
  );
}

/// Marque discrète des accueils, issue du monogramme officiel existant.
class LoyaloDashboardMark extends StatelessWidget {
  const LoyaloDashboardMark({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Loyalo',
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Image.asset(
          'assets/images/app_icon_foreground.png',
          fit: BoxFit.contain,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
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
