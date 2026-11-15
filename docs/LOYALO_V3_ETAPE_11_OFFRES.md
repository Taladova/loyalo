# Loyalo V3 — Étape 11 — Offres exclusives

12 novembre 2026 — branche `feature/offline-first`.

La liste, l’état vide et le formulaire de création / modification utilisent les composants V3 : en-tête bleu nuit sans logo, cartes blanches arrondies, champs partagés et boutons dégradés. L’icône fournie est copiée à l’identique et affichée à 80 dp.

Les offres proviennent exclusivement du repository du commerce courant. Les cartes présentent titre, description, période complète, statut et conditions disponibles. Aucun filtre, statistique ni contenu de démonstration n’a été ajouté à l’application.

Le dialogue existant conserve ses champs, ses sélecteurs de dates, ses options et ses appels de création / modification / suppression. Le titre obligatoire, le contrôle des dates, les bornes de dates 2024–2035, l’ajustement de la fin lors d’un changement du début et le seuil de visites borné à 0–999 sont conservés. Le message existant de publication échouée est affiché dans le dialogue avec conservation de la saisie et nouvel essai possible. Les échecs d’activation et de suppression sont également affichés. Les six onglets commerçant sont conservés.

## Fichiers du lot

| Fichier | Changement |
| --- | --- |
| [offers_management_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/offers_management_screen.dart) | Présentation V3, formulaire responsive, erreurs visibles, gestion de la fermeture et des contrôleurs. |
| [pubspec.yaml](/Users/david/dev/flutter_projects/Loyalo/pubspec.yaml) | Une déclaration d’asset ; aucune dépendance modifiée. |
| [exclusive_offers_icon.png](/Users/david/dev/flutter_projects/Loyalo/assets/images/merchant/exclusive_offers_icon.png) | Copie conforme de `/Users/david/Desktop/icon100.png`, sans transformation ni génération. |
| [offers_management_screen_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/offers_management_screen_test.dart) | 24 nouveaux tests UI et parcours d’offres. |
| [offers_fixture.dart](/Users/david/dev/flutter_projects/Loyalo/test/support/offers_fixture.dart) | Données et erreurs de test locales, repository métier réel. |
| [LOYALO_V3_ETAPE_11_OFFRES.md](/Users/david/dev/flutter_projects/Loyalo/docs/LOYALO_V3_ETAPE_11_OFFRES.md) | Ce rapport. |

## Vérifications

| Contrôle | Résultat |
| --- | --- |
| `dart format` | Trois fichiers Dart conformes ; contrôle final sans changement. |
| `flutter analyze --no-pub` | Aucun diagnostic. |
| `flutter test --no-pub` | **490 tests réussis**, dont les 24 nouveaux tests d’offres. |
| Parcours | État vide, données du commerce, statuts, création, valeurs transmises, dates invalides, modification, activation, suppression / confirmation, erreurs / nouvel essai, double appui et fermeture pendant une requête. |
| Responsive | 320 × 568, 390 × 844, 430 × 932, 360 × 640 et 412 × 915 ; texte ×1 / ×2 et clavier simulé de 280 dp. |
| Compilation iOS | Réussie sur `lib/main.dart` ; configuration normale rétablie après l’aperçu. |
| Intégrité | 374 fichiers préexistants identiques au début du lot ; seuls l’écran d’offres et `pubspec.yaml` ont changé parmi les 376 fichiers initiaux. Aucun fichier initial supprimé. |

Les créations, mises à jour et suppressions des tests exécutent les méthodes existantes sur **FakeFirebaseFirestore** et une base Drift en mémoire. Les captures utilisent ces mêmes fixtures dans une application d’aperçu distincte. Aucun test d’écriture n’a été exécuté sur Firebase distant.

Backend, règles, services, providers, modèles, thème, navigation et assets antérieurs sont identiques à l’instantané initial. Aucun déploiement. Les applications installées Emulator (**498 fichiers**) et Pilot (**268 fichiers**) sont identiques avant / après ; l’aperçu distinct a été désinstallé et son port local fermé.

## Captures relues

iPhone 16e / iOS 26.2, 390 × 844 dp ; PNG 1170 × 2532. Aucun débordement observé dans ces scénarios. À texte agrandi, les dates et les actions du formulaire passent en colonne ; la navigation inférieure conserve son défilement existant. Android et le clavier ouvert sont couverts par les widget tests, sans revendication de test sur un appareil Android ni de capture du clavier logiciel iOS.

| Vue | Capture |
| --- | --- |
| État vide | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-11/01-offres-vide.png) |
| Liste alimentée par les fixtures locales | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-11/02-offres-liste.png) |
| Formulaire — début | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-11/03-formulaire.png) |
| Formulaire — conditions et actions | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-11/04-formulaire-conditions.png) |
| Erreur de publication avec saisie conservée | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-11/05-erreur-publication.png) |
| État vide — texte ×2 | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-11/06-offres-vide-texte-200.png) |
| Actions du formulaire — texte ×2 | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-11/07-formulaire-texte-200.png) |

Le commit `147cd88` (« update maquette »), apparu pendant l’intervention, inclut déjà une partie du lot ainsi que le travail antérieur. Il est conservé ; aucun commit n’a été créé par cette intervention. La liste ci-dessus décrit le lot complet, indépendamment de son état d’enregistrement Git.

Preuves : [suite Flutter](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-11/tests-flutter.log), [compilation iOS](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-11/compilation-ios.log), [sources](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-11/verification-sources.json), [applications](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-11/verification-applications.json).

La compilation conserve l’avertissement préexistant concernant le support futur de Swift Package Manager par `flutter_local_notifications` ; aucune dépendance n’a été changée.
