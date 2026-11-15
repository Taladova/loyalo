# Loyalo V3 — Étape 19 : en-tête et menu commerçant

Réalisé le 13 novembre 2026, sur `feature/offline-first`. Travail des étapes précédentes conservé.

**Résultat**

- Logo officiel V3 réutilisé en format compact, avec « Espace commerçant » dessous. Aucun fichier graphique créé ou modifié.
- Accès Notifications, Statistiques et Paramètres dans l’en-tête. Déconnexion disponible dans Paramètres.
- Identité du commerce conservée, nom sur une ligne avec ellipse, catégorie et accès Mon établissement. « Vue d’ensemble » et sélecteur de période réunis sur la même ligne.
- Barre flottante partagée : Accueil, Clients, Valider, Récompenses, Offres. Les cinq pages gardent leur état dans l’IndexedStack.
- Valider : bouton dégradé de 60 dp, adapté à 54 dp à 320 dp de largeur, surélévation de 14 dp, pression animée en 180 ms. Toute sa surface reste dans les limites tactiles du composant ; aucune animation permanente. Réduction des animations respectée.
- Statistiques utilise l’écran existant comme page secondaire, avec retour vers l’accueil et conservation de la période de l’accueil.

**Fichiers modifiés**

- [merchant_dashboard_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_dashboard_screen.dart) : en-tête, ligne Vue d’ensemble et accès Statistiques.
- [merchant_root_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_root_screen.dart) : intégration des cinq destinations.
- [loyalo_merchant_dashboard_ui.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_merchant_dashboard_ui.dart) : composants d’en-tête, filtre compact et navigation partagée.
- [loyalo_logo.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_logo.dart) : affichage compact du logo officiel existant.
- [merchant_bottom_nav_test.dart — nouveau](/Users/david/dev/flutter_projects/Loyalo/test/merchant_bottom_nav_test.dart), [tests accueil](/Users/david/dev/flutter_projects/Loyalo/test/merchant_dashboard_screen_test.dart), [statistiques](/Users/david/dev/flutter_projects/Loyalo/test/statistics_screen_test.dart), [validation](/Users/david/dev/flutter_projects/Loyalo/test/visit_validation_screen_test.dart), [offres](/Users/david/dev/flutter_projects/Loyalo/test/offers_management_screen_test.dart).

**Vérifications**

- `dart format --output=none --set-exit-if-changed` : conforme.
- `flutter analyze --no-pub` : aucun problème.
- `flutter test --no-pub` : **664 tests réussis**, dont 22 tests dédiés au menu.
- Responsive de 320 à 430 dp, iPhone et Android, texte jusqu’à ×2,5 : libellés complets, SafeArea, états sélectionnés, absence de débordement, zones tactiles d’au moins 48 dp et retour des pages secondaires.
- Tests natifs sur iPhone 16e et Android API 36.1 en 320×568 dp, dans des aperçus isolés avec données locales de test.
- Appuis Android réels : les cinq onglets, huit positions sur le bouton central et les quatre accès Notifications / Statistiques / Paramètres / Mon établissement, avec retour vers l’accueil. [Résultats](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-19/verification-android.json).
- Calculs des cartes d’accueil et code Loyalo Express vérifiés inchangés. Repositories, providers métier, modèles, écrans Clients / Valider / Récompenses / Offres / Statistiques et configuration Firebase préservés.
- Aucune dépendance ajoutée, aucune génération graphique, aucun déploiement Firebase.
- Aperçus temporaires retirés ; émulateur Android de test fermé sans sauvegarder ses changements. APK Android normal recompilé et Loyalo Pilot normal relancé sur l’iPhone avec sa session existante.

**Limite de mise en page**

À 320 dp ou avec un texte agrandi, certains libellés peuvent occuper plusieurs lignes pour rester lisibles sans ellipse. Aucun blocage identifié pour cette étape.

**Captures**

[Accueil iPhone](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-19/accueil-iphone.png) · [Valider sélectionné](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-19/valider-iphone.png) · [Statistiques en page secondaire](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-19/statistiques-iphone.png) · [Android 320 dp](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-19/accueil-android-320.png) · [Accueil Pilot réel](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-19/accueil-pilot.png)
