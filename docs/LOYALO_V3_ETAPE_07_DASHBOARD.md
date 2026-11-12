# Loyalo V3 — Étape 07 — Tableau de bord commerçant

État au 11 novembre 2026, branche `feature/offline-first`.

La refonte de présentation du dashboard est intégrée et vérifiée localement. Les modifications des étapes précédentes restent présentes et non commitées. Aucun commit, reset Git, déploiement ou changement de configuration Firebase n’a été effectué pendant cette étape.

## Fichiers de cette étape

| Fichier | Intervention |
| --- | --- |
| [merchant_dashboard_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_dashboard_screen.dart) | Nouvelle composition, mêmes appels métier, états chargement/erreur/indisponibilité explicites. |
| [merchant_root_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_root_screen.dart) | Barre commerçant V3, six destinations conservées, garde d’affichage lorsque le commerce manque. |
| [loyalo_merchant_dashboard_ui.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_merchant_dashboard_ui.dart) | Nouveaux composants de présentation contrôlés par leurs paramètres. |
| [pubspec.yaml](/Users/david/dev/flutter_projects/Loyalo/pubspec.yaml) | Déclaration de l’illustration du dashboard ; aucune nouvelle dépendance à cette étape. |
| [merchant_dashboard_hero.png](/Users/david/dev/flutter_projects/Loyalo/assets/images/dashboard/merchant_dashboard_hero.png) | Copie exacte de l’illustration fournie. |
| [merchant_dashboard_screen_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/merchant_dashboard_screen_test.dart) | 38 tests du dashboard, des routes, du conteneur et du responsive. |
| [merchant_dashboard_fixture.dart](/Users/david/dev/flutter_projects/Loyalo/test/support/merchant_dashboard_fixture.dart) | Données et services simulés réservés aux tests et à l’aperçu natif isolé. |
| [merchant_dashboard.emulator.test.js](/Users/david/dev/flutter_projects/Loyalo/functions/test/emulator/merchant_dashboard.emulator.test.js) | Tests locaux d’isolation sous les règles Pilot existantes. |

Les autres différences visibles dans `git status`, notamment le modèle Restaurant, le repository, les écrans d’authentification et de configuration, ainsi que `pubspec.lock`, appartiennent au travail antérieur. Elles ont été préservées.

## Présentation et composants

Ordre : en-tête, période, clients, visites/nouveaux clients, points, Express, actions rapides, activité récente. Défilement vertical naturel et navigation inférieure indépendante.

Composants créés : `LoyaloMerchantHeader`, `LoyaloPeriodSelector`, `LoyaloClientSummaryCard`, `LoyaloMetricCard`, `LoyaloDashboardPair`, `LoyaloQuickAction`, `LoyaloDashboardSectionHeader`, `LoyaloRecentActivityTile`, `LoyaloExpressCard`, `LoyaloExpressRequestTile`, `LoyaloDashboardStatus`, `LoyaloMerchantBottomNav`.

Réutilisation des tokens `LoyaloAuthColors`, du fond `LoyaloAuthScaffold`, de `LoyaloAuthSurface`, de `LoyaloCard`, de l’avatar commerçant et des composants d’erreur/bouton existants. Les fichiers partagés des étapes précédentes restent inchangés.

Identité : nom Firebase Auth lorsqu’il existe, nom réel du commerce et activité. Sans prénom disponible, le commerce reste l’identité principale. Aucune valeur « Liam » ou « Pizza » introduite. Notifications, paramètres et déconnexion conservent leurs destinations et mécanismes.

## Calculs et parcours conservés

- Périodes : Aujourd’hui par défaut, 7 derniers jours, 30 derniers jours. Même début calendaire et même comparaison sur la durée écoulée immédiatement précédente.
- Clients : total distinct existant ; actifs sur les 30 derniers jours ; nouveaux du mois calendaire. Ces deux sous-indicateurs gardent leur propre périmètre quand la période change.
- Visites, nouveaux clients et points : mêmes méthodes du repository et mêmes bornes temporelles.
- Points : périmètre existant des visites confirmées multipliées par le taux actuel du commerce. Aucun agrégat Réseau Local ou parrainage, ni conversion vers un historique d’attributions différent.
- Activité récente : trois premières visites de la période, noms et qualification de première visite existants ; même affichage des points par visite et même route vers `ActivityHistoryScreen`.
- Express : même file locale filtrée par établissement et propriétaire, même traitement de validation/refus, mêmes messages métier et états de synchronisation. Chargement, vide, erreur et flux indisponible ont une présentation distincte. Le lien « Voir les arrivées » existe seulement avec des arrivées réellement en attente.
- « Nouveau » est conservé uniquement là où les calculs existants le produisent : tendance statistique ou statut de fidélité d’un client. Aucun badge de nouveauté produit n’est ajouté à Express.

Les quatre actions mènent toujours à `ValidateVisitScreen`, `ClientSearchScreen`, `OffersManagementScreen` et `RewardsManagementScreen`. « Créer une offre » ouvre donc le parcours de gestion/création existant.

La navigation conserve **Accueil, Clients, Valider, Récompenses, Offres, Stats**, dans cet ordre. Le bouton de validation reçoit un libellé visible. La barre partagée côté client est inchangée. Une éventuelle organisation à quatre destinations avec « Plus » nécessiterait une décision ultérieure sur les accès regroupés.

En l’absence de commerce chargé ou de session, le conteneur affiche l’état du dashboard et désactive les onglets. Il évite ainsi de construire les autres pages qui exigent un commerce non nul. Les six destinations redeviennent disponibles après récupération, sans nouvelle requête ni nouveau provider.

## Illustration et accessibilité

Source : [9.png](/Users/david/Desktop/9.png). PNG 1536 × 1024 avec transparence réelle. Le panneau arrondi et les halos intégrés à l’image fournie sont conservés. Aucun asset généré ou téléchargé.

SHA-256 identique entre source et copie : `1cc0f7ba6406090b39a6b41e744d918d5a28ce03481514feaeff4e8327517682`.

Boîte de 140 × 100 dp, `BoxFit.contain`, sujet visible d’environ **82 dp de hauteur** compte tenu des marges transparentes. Décodage adapté à la densité de l’écran. Illustration décorative exclue de la sémantique et masquée lorsque largeur ou texte agrandi exigent davantage de place.

Zones tactiles d’au moins 48 dp, libellés sémantiques et actions de lecteur d’écran, compteur de notifications accessible, messages Express annoncés. Les cartes passent en colonne sur écran étroit ou texte agrandi. Les six libellés de navigation restent complets ; la barre peut défiler horizontalement lorsque leur largeur cumulée dépasse l’écran.

## Vérifications exécutées

| Vérification | Résultat |
| --- | --- |
| `dart format` sur les cinq fichiers Dart de cette étape | Conforme |
| `flutter analyze --no-pub` | Aucune anomalie |
| Suite Flutter complète | **368 tests réussis** |
| Tests ciblés du dashboard, après le dernier ajustement visuel | **38 tests réussis** |
| `npm test` dans functions | **34 tests réussis** |
| Règles Pilot inchangées, émulateur Firestore local | **5 scénarios réussis**, 6 tests Node en comptant le conteneur |
| Compilation iOS simulateur | Réussie |
| `git diff --check` | Conforme |

Les scénarios d’émulateur vérifient les lectures de visites par période, l’interdiction des lectures/rejets d’arrivées d’un autre commerce, le périmètre des noms clients, les offres/récompenses et l’interdiction d’écrire directement des visites ou récompenses confirmées. Projet exclusivement local `demo-loyalo-dashboard-ui07`, serveur arrêté à la fin des tests.

Responsive testé avec noms longs, texte ×1 et ×2,5 : 320 × 568, 390 × 844, 430 × 932 sur configuration iOS ; 360 × 740 et 412 × 915 sur configuration Android. Absence d’overflow du dashboard et tailles tactiles vérifiées. Les six écrans et leur ordre sont aussi vérifiés dans le véritable conteneur.

Comparaison avec le code présent au début de l’étape : bloc des statistiques, calcul des périodes/tendances, dates relatives, badges de fidélité, déconnexion et callbacks de validation/refus inchangés. Empreintes SHA-256 identiques pour 30 fichiers protégés, dont services, repositories, providers, modèles, composants partagés, règles et configurations Firebase et code des fonctions sécurisées.

## Captures iPhone réelles

iPhone 16e, iOS 26.2, 390 × 844 dp ; captures natives 1170 × 2532 px. Véritables widgets de l’application, thème Poppins existant, données exclusivement locales de test : les noms et chiffres des captures ne représentent pas des données Pilot.

1. [En-tête et statistiques](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-07/01-entete-statistiques.png).
2. [Loyalo Express et arrivées](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-07/02-loyalo-express.png).
3. [Les quatre actions rapides](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-07/03-actions-rapides.png).
4. [Activité récente sur 30 jours](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-07/04-activite-recente.png).
5. [Navigation à six destinations et états vides](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-07/05-navigation-et-etats-vides.png).
6. [Erreur de lecture Express](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-07/06-express-erreur.png).
7. [Texte agrandi ×2,5](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-07/07-texte-agrandi.png).
8. [Commerce indisponible, nouvelle tentative](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-07/08-commerce-indisponible.png).

À l’ouverture standard, la carte clients commence à y = 333 dp, les statistiques secondaires à y = 450 dp ; la carte points se termine vers y = 672 dp. Les indicateurs sont visibles avant la navigation. La coupure du mot « récompenses » identifiée sur la première vérification native a été corrigée puis recapturée.

## Limites et suivi

Le parcours connecté au projet **Firebase Pilot distant**, notamment l’arrivée réelle d’un client et sa validation serveur depuis cette version, n’a pas été exécuté. Les tests d’intégration ci-dessus utilisent les règles Pilot sur l’émulateur local ; ils ne remplacent pas cette recette distante. Aucun test destructif sur Production n’a été réalisé.

Le débordement rencontré sur l’ancienne page de validation dans un test à police artificielle existe aussi avec l’ancienne barre. Il ne se reproduit pas sur l’iPhone standard avec Poppins : page et clavier numérique vérifiés nativement. La refonte des autres pages commerçant reste hors périmètre.

La compilation signale l’avertissement existant de compatibilité Swift Package Manager de `flutter_local_notifications` ; elle réussit.

Incident de manipulation du simulateur : une recopie asynchrone de l’aperçu a temporairement installé son binaire sous l’identifiant local Emulator. L’entrée normale `lib/main.dart` de cette app a été recompilée en mode émulateur et réinstallée sans désinstallation. L’app Pilot distincte n’a pas été remplacée. L’aperçu dédié est isolé sous `com.loyalo.loyalo.dashboardpreview07` et retiré après la validation ; ses contrôles temporaires et ses données simulées ne font pas partie du code de production.

