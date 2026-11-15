# Loyalo V3 — Étape 12 — Statistiques commerçant

12 novembre 2026 — branche `feature/offline-first`.

L’écran utilise le Design System V3 : en-tête bleu nuit sans logo ni slogan, sélecteur compact, huit cartes blanches et graphique `fl_chart`. La grille adapte ses colonnes à la largeur, aux libellés, aux valeurs et à la taille du texte. La navigation commerçant à six onglets est conservée.

Les périodes **7 / 30 / 90 derniers jours**, les calculs, les tendances et la série journalière existants sont conservés. Le graphique utilise uniquement cette série, avec des dates adaptées à la période. Une série vide affiche « Aucune visite sur cette période » sans dessiner de courbe artificielle.

L’exception autorisée dans les repositories expose uniquement des métadonnées de lecture : chargement, lecture réussie, erreur ou indisponibilité. **0 s’affiche seulement après une lecture réussie.** Une lecture en cours affiche un indicateur de chargement ; une erreur affiche « — / Erreur de lecture » et permet de réessayer. Les autres sources déjà chargées restent visibles. Les données en cache ne sont pas effacées.

**Parrainages et En attente** affichent « — / Non disponible » dans la session commerçant : aucune lecture des parrainages de ce commerce n’existe actuellement. Une éventuelle liste de parrainages conservée d’une autre session n’est pas présentée comme un total complet. Aucune requête supplémentaire n’a été ajoutée.

Les visites, clients, récompenses et points conservent leurs filtres temporels. Les offres actives, check-ins et parrainages conservent la portée de leurs getters existants ; aucun nouveau calcul temporel n’a été introduit.

## Fichiers du lot

| Fichier | Changement |
| --- | --- |
| [statistics_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/statistics_screen.dart) | Présentation V3, périodes, états globaux et partiels, nouvel essai. |
| [loyalo_statistics_ui.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_statistics_ui.dart) | Cartes, grille responsive et présentation du graphique. |
| [repository_read_state.dart](/Users/david/dev/flutter_projects/Loyalo/lib/core/data/repository_read_state.dart) | Métadonnées de lecture partagées. |
| [loyalty_repository.dart](/Users/david/dev/flutter_projects/Loyalo/lib/services/loyalty_repository.dart) | Exposition des états des lectures existantes, remise à zéro des métadonnées lors d’un changement de session. |
| [visit_repository.dart](/Users/david/dev/flutter_projects/Loyalo/lib/features/visits/data/visit_repository.dart) | États de chargement et d’erreur des flux local et distant. |
| [checkin_repository.dart](/Users/david/dev/flutter_projects/Loyalo/lib/features/checkins/data/checkin_repository.dart) | Même exposition pour les check-ins. |
| [statistics_screen_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/statistics_screen_test.dart) | 28 tests UI : valeurs, périodes, graphique, états, nouvel essai, navigation, responsive et accessibilité. |
| [statistics_read_state_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/statistics_read_state_test.dart) | 3 tests : arrêt de session, cache de parrainages incomplet, panne distante et reprise sans perte du cache. |
| [statistics_fixture.dart](/Users/david/dev/flutter_projects/Loyalo/test/support/statistics_fixture.dart) | Fixtures locales, erreurs et retards de lecture contrôlés. |
| [Ce rapport](/Users/david/dev/flutter_projects/Loyalo/docs/LOYALO_V3_ETAPE_12_STATISTIQUES.md) | Résultats et limites de vérification. |

## Vérifications

| Contrôle | Résultat |
| --- | --- |
| `dart format --output=none --set-exit-if-changed` | 9 fichiers Dart conformes. |
| `flutter analyze --no-pub` | Aucun diagnostic. |
| `flutter test --no-pub` | **521 tests réussis**, dont **31 nouveaux** pour les statistiques. |
| Données et périodes | Valeurs issues des repositories réels sur fixtures : 2 / 4 / 6 visites et 70 / 140 / 210 points sur 7 / 30 / 90 jours ; isolation entre commerces vérifiée. |
| États | Zéros connus, lecture retardée, erreurs des visites / récompenses / offres / check-ins, reprise, cache conservé, session absente et commerce indisponible. |
| Responsive | Widget tests sur 320 × 568, 360 × 640, 390 × 844, 412 × 915 et 430 × 932, texte ×1 / ×2. Libellés et valeurs sans troncature. |
| iOS | Compilation de l’aperçu puis de la cible normale Pilot réussies. Dix captures relues sur iPhone 16e / iOS 26.2, dont le texte ×2 et les graphiques 7 / 90 jours. |

Les tests et captures utilisent **FakeFirebaseFirestore et une base Drift en mémoire**, avec les méthodes statistiques existantes. Ils ne constituent pas un test d’intégration sur Firebase distant. Aucune écriture de test n’a été effectuée sur Pilot. À texte agrandi, la barre inférieure garde son défilement horizontal existant.

Le contrôle de portée confirme que les requêtes et appels d’écriture des trois repositories sont conservés (245 appels comparés), ainsi que les méthodes métier et les helpers de calcul de l’écran. Seuls quatre fichiers préexistants sont modifiés dans ce lot ; les autres travaux, dont ceux de l’étape 11, sont conservés. Aucun changement du backend, des règles, des permissions, des dépendances ou des assets. Aucun déploiement.

## Captures et preuves

| Vue | Capture |
| --- | --- |
| Statistiques — 30 jours | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-12/01-statistiques-30-jours.png) |
| Zéros connus et données indisponibles | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-12/02-statistiques-vides.png) |
| Graphique — 7 jours | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-12/03-evolution-7-jours.png) |
| Graphique — 90 jours | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-12/04-evolution-90-jours.png) |
| Chargement des visites | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-12/05-chargement-visites.png) |
| Erreur des visites | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-12/06-erreur-visites.png) |
| Erreur des offres | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-12/07-erreur-offres.png) |
| Texte à 200 % | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-12/08-statistiques-texte-200.png) |
| Graphique — texte à 200 % | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-12/09-graphique-texte-200.png) |
| Graphique vide | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-12/10-graphique-vide.png) |

Preuves : [tests](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-12/tests-flutter.log), [analyse](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-12/analyse-flutter.log), [compilation Pilot](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-12/compilation-pilot.log), [contrats conservés](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-12/verification-contrats.json), [sources](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-12/verification-sources.json).
