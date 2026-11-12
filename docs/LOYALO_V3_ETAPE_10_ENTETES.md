# Loyalo V3 — Étape 10 — Audit et harmonisation des en-têtes

Audit initial du 11 novembre 2026, branche `feature/offline-first`. Les modifications antérieures sont conservées.

## Phase A — Audit avant modification

| Groupe | État observé | Intervention prévue |
| --- | --- | --- |
| Bienvenue | Logo officiel V3 avec slogan intégré, illustration et sélection client/commerçant | Conserver cet écran et ses proportions. |
| Connexions client / commerçant | Même `LoyaloAuthHeader`, mais hauteur d’illustration commerçant surchargée | Compacter le composant partagé et aligner les proportions. |
| Inscriptions client / commerçant | Même composant de base, surcharges différentes de logo, illustration et espacement | Utiliser les mêmes réglages compacts. |
| Accueil commerçant | Logo complet 152 × 51 avec slogan, identité personnelle plus visible que le commerce | Remplacer par le monogramme officiel discret et valoriser le commerce. |
| Accueil client | En-tête « Accueil », notifications et déconnexion ; aucun grand logo | Ajouter une marque discrète sans remplacer un retour existant. |
| Mon code / carte personnelle | Logo décoratif dans le haut de la carte | Retirer ce logo et son espacement, conserver nom, points, QR et code. |
| Recherche client | Pas de logo ; illustration compacte et titre spécifique | En-tête fonctionnel commun ; retirer l’illustration de cet écran d’action. |
| Programme de fidélité | Pas de logo ; illustration 3D au-dessus des réglages | En-tête fonctionnel commun ; retirer l’illustration, garder l’explication du brouillon. |
| Autres pages fonctionnelles | 18 AppBar sans logo (profils, paramètres, offres, statistiques, historique, notifications, commerces, parrainage, validation, légal) | Conserver leurs titres, actions et retours, partager l’adaptation aux titres longs et au texte système. |
| AuthGate | Logos de transition / déverrouillage à la frontière d’authentification | Conserver, sans déplacer la logique d’authentification. |
| Visuels d’établissements | Logos, couvertures et avatars liés aux commerces | Conserver intégralement. |

Aucune page autonome de scanner QR ou de Réseau Local n’a été trouvée dans ce dépôt. Aucun nouvel écran ou parcours n’est créé pour compléter ces intitulés.

## Organisation retenue

- **AuthHeader** : adaptation de `LoyaloAuthHeader`, déjà partagé par les quatre formulaires. Logo V3 officiel, slogan présent une seule fois dans l’asset, proportions conservées.
- **PageHeader** : un composant commun sans logo pour les en-têtes personnalisés et un adaptateur AppBar respectant le thème existant, les actions et les retours natifs.
- **DashboardHeader** : monogramme officiel existant réutilisé sur les deux accueils. Aucun nouveau visuel ni reconstruction du logo en texte.

L’asset `assets/images/app_icon_foreground.png` est déjà utilisé par l’icône et le splash de l’application et contient le monogramme officiel. Seule sa déclaration comme asset Flutter sera ajoutée si nécessaire. Aucun fichier graphique ne sera créé, modifié ou supprimé.

## Plan de modification contrôlé

1. Phase B : composants communs, tests des titres longs, actions et retours.
2. Phase C : pages fonctionnelles, sans logo et sans espace décoratif de remplacement ; vérifier progressivement les groupes commerçant puis client.
3. Phase D : réglages partagés des quatre écrans d’authentification ; bienvenue conservée.
4. Phase E : marques discrètes des deux accueils et priorité aux informations du commerce.
5. Vérifications finales : format, analyse, suite Flutter, intégrité des services / modèles / providers / configurations / routes et captures natives des neuf écrans demandés.

Aucun changement de repository, de modèle, de provider métier, de Firebase, de calcul, de validation ou de navigation n’est autorisé ni prévu pour cette étape.

## Résultat livré

Les phases B à E sont terminées. Les modifications de cette étape portent sur **31 fichiers Flutter**, six fichiers de tests, la déclaration d’un asset déjà présent et ce rapport. Les changements antérieurs des étapes 01 à 08 restent présents, sur la même branche et sans commit, reset, stash ou suppression.

### Politique de marque appliquée

| Emplacement | Résultat |
| --- | --- |
| Bienvenue | Logo officiel V3, slogan intégré, illustrations et boutons conservés. Le fichier de l’écran est inchangé. |
| Quatre formulaires d’authentification | Même `LoyaloAuthHeader` : logo dans une boîte de ratio 3:1, au plus 192 × 64 dp sur écran standard ; `BoxFit.contain` ; slogan uniquement dans l’asset. Illustration standard de 88 dp, réduite sur petit écran, masquée avec clavier ouvert ou texte très agrandi. |
| Accueil commerçant | Grand logo avec slogan retiré de l’affichage. Monogramme officiel discret, actions notifications / profil / déconnexion conservées. Nom du commerce principal, « Bonjour [prénom] » secondaire, catégorie et avatar d’établissement conservés. Illustration secondaire réduite à 108 × 80 dp. |
| Accueil client | Même monogramme officiel discret sur la racine. Le retour natif reste prioritaire lorsque la page est ouverte dans une pile. Solde, progression, récompenses et callbacks inchangés. |
| Ma carte Loyalo | Logo décoratif et son espacement de 26 dp retirés. Nom, points, QR, code quotidien, historique et fermeture / retour conservés. |
| Recherche client | En-tête sans logo ni illustration, champ de recherche plus haut dans l’écran. États et critères de recherche inchangés. |
| Programme | En-tête sans logo ni illustration. Texte expliquant le brouillon conservé. Le bouton de retour existant et son parcours de secours sont conservés. |
| Autres pages fonctionnelles | 18 AppBar fonctionnelles utilisent le même adaptateur, sans ajout de logo. Les titres peuvent revenir à la ligne ; les actions disposent d’une ligne séparée lorsque nécessaire. |
| AuthGate | Présentation de transition d’authentification conservée. |
| Logos / images des commerces | Aucun changement ni retrait. |

Aucun fichier graphique n’a été créé, modifié ou supprimé. Les illustrations de recherche et de programme restent dans le projet et dans les assets déclarés. Le monogramme est `assets/images/app_icon_foreground.png`, déjà présent ; seule sa déclaration Flutter a été ajoutée.

### Composants

- `LoyaloAuthHeader` et `LoyaloAuthScaffold` existants : dimensions compactes partagées, sans nouveau composant concurrent.
- `LoyaloPageHeader` : titre, retour et actions des en-têtes personnalisés ; aucune décoration de marque.
- `loyaloPageAppBar` : adaptation des Scaffold existants, avec mesure du titre et respect du texte système, du thème et du retour natif. Les actions textuelles sont prises en compte à leur taille agrandie.
- `LoyaloDashboardMark` : même asset officiel pour les deux accueils.
- `LoyaloMerchantHeader` existant : hiérarchie commerce / personne et actions conservées.
- `SectionHeader` existant : titres de sections de l’accueil client adaptables, action « Voir tout » avec une zone tactile d’au moins 48 dp.

La page de validation conserve ses traitements ; seule sa disposition devient défilable si nécessaire, avec des cases de code adaptées à la largeur et des sélecteurs d’au moins 48 dp. Le filtre d’en-tête des statistiques a aussi une zone minimale de 48 × 48 dp.

### Fichiers Flutter modifiés pour cette étape

Cette liste est établie par comparaison SHA-256 avec l’état initial de l’étape 10, et non par comparaison avec HEAD, qui contient également les étapes précédentes.

- [lib/screens/auth/client_signup_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/auth/client_signup_screen.dart)
- [lib/screens/client/client_dashboard_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/client/client_dashboard_screen.dart)
- [lib/screens/client/client_profile_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/client/client_profile_screen.dart)
- [lib/screens/client/client_statistics_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/client/client_statistics_screen.dart)
- [lib/screens/client/client_visit_history_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/client/client_visit_history_screen.dart)
- [lib/screens/client/discover_restaurant_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/client/discover_restaurant_screen.dart)
- [lib/screens/client/my_code_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/client/my_code_screen.dart)
- [lib/screens/client/referral_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/client/referral_screen.dart)
- [lib/screens/client/referrals_list_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/client/referrals_list_screen.dart)
- [lib/screens/client/restaurant_list_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/client/restaurant_list_screen.dart)
- [lib/screens/client/rewards_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/client/rewards_screen.dart)
- [lib/screens/client/settings_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/client/settings_screen.dart)
- [lib/screens/legal_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/legal_screen.dart)
- [lib/screens/merchant/activity_history_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/activity_history_screen.dart)
- [lib/screens/merchant/client_search_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/client_search_screen.dart)
- [lib/screens/merchant/merchant_client_profile_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_client_profile_screen.dart)
- [lib/screens/merchant/merchant_establishment_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_establishment_screen.dart)
- [lib/screens/merchant/merchant_login_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_login_screen.dart)
- [lib/screens/merchant/merchant_settings_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_settings_screen.dart)
- [lib/screens/merchant/merchant_signup_view.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_signup_view.dart)
- [lib/screens/merchant/offers_management_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/offers_management_screen.dart)
- [lib/screens/merchant/statistics_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/statistics_screen.dart)
- [lib/screens/merchant/validate_visit_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/validate_visit_screen.dart)
- [lib/screens/notifications_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/notifications_screen.dart)
- [lib/widgets/loyalo_auth_ui.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_auth_ui.dart)
- [lib/widgets/loyalo_client_search_ui.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_client_search_ui.dart)
- [lib/widgets/loyalo_logo.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_logo.dart)
- [lib/widgets/loyalo_merchant_dashboard_ui.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_merchant_dashboard_ui.dart)
- [lib/widgets/loyalo_page_header.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_page_header.dart)
- [lib/widgets/loyalo_program_ui.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_program_ui.dart)
- [lib/widgets/section_header.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/section_header.dart)

La connexion client, le contrôleur d’inscription commerçant, la configuration du programme et le dashboard commerçant bénéficient de leurs composants partagés sans modification supplémentaire de leurs fichiers d’écran. `WelcomeScreen`, `ClientRootScreen`, `MerchantRootScreen`, `AuthGateScreen`, le thème et `lib/main.dart` restent identiques à l’état initial.

Autre fichier de configuration modifié : [pubspec.yaml](/Users/david/dev/flutter_projects/Loyalo/pubspec.yaml), uniquement pour déclarer le monogramme existant dans `flutter.assets`. Aucune dépendance ni version de paquet n’a été changée ; `pubspec.lock` est inchangé.

### Tests et vérifications

| Vérification | Résultat |
| --- | --- |
| `dart format` sur les 37 fichiers Dart concernés | Format conforme, aucune modification restante au dernier passage. |
| `flutter analyze --no-pub` | Aucun diagnostic. |
| `flutter test --no-pub --reporter expanded` | **432 tests réussis**, dont 32 nouveaux contrôles pour l’étape 10. |
| Compilation iOS de l’entrée normale `lib/main.dart` | Réussie, mode debug simulateur ; application normale non installée et non lancée. |
| `git diff --check` | Réussi. |
| Comparaison avec l’état initial | 363 fichiers relevés au départ ; 368 à la fin ; cinq nouveaux fichiers, aucun retrait. 39 fichiers ajoutés ou changés, tous dans le périmètre de présentation / tests / rapport / déclaration d’asset. |
| Domaines protégés | **185 fichiers contrôlés, aucun changement** : modèles, services, providers, core, thème, fonctions, configurations iOS / Android / Firebase, assets, racines de navigation et autres points protégés. |
| Applications installées | Les 498 fichiers d’Emulator et 265 fichiers de Pilot sont identiques avant / après, aux mêmes emplacements. L’aperçu distinct a été désinstallé et son port local fermé. |
| Cible locale de compilation | Rétablie sur `lib/main.dart`, sans cible d’aperçu temporaire. |

Les nouveaux contrôles couvrent les titres longs, actions, retours natifs, absence de retour ajouté à la racine, proportions identiques des quatre formulaires, suppression des logos décoratifs, conservation du QR / code / points et saisie / effacement des six chiffres. Les tests existants de connexion, inscription, brouillon, publication, recherche, statistiques, périodes et navigation continuent de passer.

Formats vérifiés en widget tests : iPhone compact 320 × 568, standard 390 × 844, grand 430 × 932 ; Android compact 360 × 640 et standard 412 × 915. Le composant d’en-tête est vérifié à ×1, ×1,3 et ×2 ; les suites existantes de recherche, programme et dashboard vont jusqu’à ×2,5. Les tests pertinents incluent SafeArea, clavier simulé, défilement, champs et commandes accessibles.

Fichiers de tests ajoutés ou adaptés :

- [test/client_search_screen_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/client_search_screen_test.dart)
- [test/functional_header_layout_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/functional_header_layout_test.dart)
- [test/header_brand_policy_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/header_brand_policy_test.dart)
- [test/loyalo_page_header_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/loyalo_page_header_test.dart)
- [test/merchant_dashboard_screen_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/merchant_dashboard_screen_test.dart)
- [test/rewards_management_screen_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/rewards_management_screen_test.dart)

Journaux : [suite Flutter](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/tests-flutter.log), [analyse](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/analyse-flutter.log), [compilation normale iOS](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/compilation-ios.log), [contrôle des sources](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/verification-sources.json), [intégrité des applications installées](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/verification-integrite-applications.json).

### Captures natives relues

Simulateur **iPhone 16e, iOS 26.2**, 390 × 844 points, PNG natifs 1170 × 2532. Les neuf écrans demandés et deux vues client complémentaires sont capturés à taille normale, plus quatre vues à texte ×2. Aucun débordement ni erreur Flutter observé dans ces scénarios. Les captures utilisent les vrais écrans / composants et des fixtures locales, sans opérations Firebase distantes.

Les cinq premières vues conservent les assets des maquettes. Les différences volontaires concernent la compacité de l’authentification, la marque discrète du dashboard et le retrait des illustrations des pages d’action. Les intitulés, couleurs et composants existants restent utilisés ; aucune nouvelle maquette graphique n’a été générée.

| Vue | Capture |
| --- | --- |
| Bienvenue | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/01-bienvenue.png) |
| Connexion client | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/02-connexion-client.png) |
| Connexion commerçant | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/03-connexion-commercant.png) |
| Inscription client | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/04-inscription-client.png) |
| Inscription commerçant | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/05-inscription-commercant.png) |
| Accueil commerçant, avec ses six onglets | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/06-accueil-commercant.png) |
| Validation d’une visite | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/07-validation-visite.png) |
| Recherche client | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/08-recherche-client.png) |
| Configuration du programme, commerce en brouillon | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/09-configuration-programme.png) |
| Accueil client, contenu de son Scaffold | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/10-accueil-client.png) |
| Carte client, QR et code | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/11-carte-client.png) |
| Connexion client, texte ×2 | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/12-connexion-texte-200.png) |
| Recherche client, texte ×2 | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/13-recherche-texte-200.png) |
| Programme, texte ×2 | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/14-programme-texte-200.png) |
| Accueil commerçant, texte ×2 | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-10/15-accueil-commercant-texte-200.png) |

### Limites et observations

- Validation native effectuée sur iPhone 16e. Les autres tailles et Android ont été vérifiés en widget tests, sans appareil Android natif pour cette étape.
- Les tests couvrent l’ouverture simulée du clavier et les champs ; aucune capture de clavier logiciel natif n’est livrée.
- La capture complémentaire de l’accueil client montre son Scaffold de contenu seul ; `ClientRootScreen` et ses onglets n’ont pas été modifiés. La validation commerçant est capturée dans sa navigation réelle à six onglets.
- À texte ×2, les pages restent défilables. La barre commerçant conserve son comportement existant permettant d’accéder horizontalement aux six onglets.
- La compilation réussit avec un avertissement de dépendance sur la compatibilité future de `flutter_local_notifications` avec Swift Package Manager. Ce paquet et les réglages du projet n’ont pas été changés.
- Aucune anomalie bloquante identifiée dans le périmètre vérifié. Aucun déploiement, changement Firebase, commit ou démarrage d’une autre étape.

