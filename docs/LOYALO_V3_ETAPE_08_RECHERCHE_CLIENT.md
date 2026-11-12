# Loyalo V3 — Étape 08 — Rechercher un client

État au 11 novembre 2026. Branche `feature/offline-first`. L’interface est intégrée ; la validation locale est décrite ci-dessous. Aucun commit, reset Git ou déploiement n’a été effectué.

## Analyse et périmètre

L’écran utilise `loyaltyRepositoryProvider` et l’identifiant courant du commerce. La recherche existante est un filtrage **synchrone du cache autorisé**, par nom, téléphone et email. Le repository charge individuellement les profils liés aux visites ou arrivées du commerce. Il ne lance pas une recherche globale dans la collection users à chaque caractère.

La méthode `searchClients`, ses critères, la sélection des identifiants et les requêtes Firestore sont conservés. La recherche reste insensible à la casse et conserve la suppression des espaces pour la comparaison des téléphones. Elle n’ajoute ni suppression des accents, ni conversion automatique entre 06 et +33, ni nouvelle normalisation des saisies.

L’ancienne carte affichait automatiquement l’email. La nouvelle carte affiche le nom et « Consulter le profil ». Les coordonnées ne sont pas ajoutées à l’écran de recherche. Le profil existant et ses actions restent inchangés.

Le projet possède un fil de visites, mais pas d’historique des profils récemment consultés ni de règle de sélection des « clients récents » pour cette page. Cette section n’est pas inventée. L’état initial explique la recherche et propose, si disponible, « Afficher les clients du commerce » : cela présente l’annuaire déjà accessible auparavant lorsque la recherche était vide, sans nouvelle collection ni nouvelle route.

## Exception expressément autorisée

Le repository masquait les erreurs de lecture des profils. L’utilisateur a autorisé : **« Autoriser uniquement ces états de lecture »**, sans changement des requêtes, de la recherche ou des permissions.

Les getters `merchantClientsLoading` et `merchantClientsLoadError` exposent maintenant le chargement de l’annuaire commerçant et les erreurs de lecture auparavant absorbées. Une version de lecture empêche un chargement terminé après un autre chargement ou après déconnexion de republier un état et un annuaire obsolètes. Les notifications sont émises au début et à la fin de la lecture, sans notification tardive après destruction.

L’écran distingue chargement, erreur, session absente, commerce indisponible, état initial et absence de résultat. Pendant une erreur ou une lecture incomplète, il n’affiche pas une liste partielle comme résultat complet. La saisie est conservée et reste utilisable pendant le chargement. « Réessayer » réutilise `retryRestaurants`, qui relance les listeners de la session existante. Aucun nouveau service ou provider n’est ajouté.

## Fichiers de cette étape

| Fichier | Modification |
| --- | --- |
| [client_search_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/client_search_screen.dart) | Composition, champ fixé pendant le défilement, clavier, états et navigation existante. |
| [loyalty_repository.dart](/Users/david/dev/flutter_projects/Loyalo/lib/services/loyalty_repository.dart) | États de lecture autorisés et cohérence de leur cycle de vie. |
| [pubspec.yaml](/Users/david/dev/flutter_projects/Loyalo/pubspec.yaml) | Déclaration de l’illustration, sans nouvelle dépendance. |
| [loyalo_client_search_ui.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_client_search_ui.dart) | Composants de présentation de la recherche. |
| [client_search_illustration.png](/Users/david/dev/flutter_projects/Loyalo/assets/images/merchant/client_search_illustration.png) | Copie exacte de l’asset fourni. |
| [client_search_screen_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/client_search_screen_test.dart) | 27 tests d’interface et de responsive. |
| [client_search_repository_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/client_search_repository_test.dart) | 5 tests du repository réel, critères, erreurs et déconnexion. |
| [client_search_fixture.dart](/Users/david/dev/flutter_projects/Loyalo/test/support/client_search_fixture.dart) | Firestore simulé et base mémoire réservés aux tests et à l’aperçu local. |
| [client_search.emulator.test.js](/Users/david/dev/flutter_projects/Loyalo/functions/test/emulator/client_search.emulator.test.js) | Tests de permissions sous les règles Pilot existantes sur émulateur. |

Les autres modifications présentes avant cette étape ont été préservées. Les seuls fichiers préexistants modifiés pendant cette étape sont les trois premiers du tableau.

Contrôle final par empreintes : **353 fichiers préexistants identiques** à leur état au début de l’étape. Les bundles complets des applications déjà installées Pilot et Emulator ont également été comparés avant/après : ils sont identiques. Seul l’aperçu dédié a été installé puis retiré.

## Composants et comportement

Réutilisation des couleurs `LoyaloAuthColors`, du bouton `LoyaloAuthBackButton`, du thème Poppins et du parcours `MerchantClientProfileScreen(clientId: ...)`. La navigation retour conserve `Navigator.maybePop` ; le bouton n’est pas présenté sur une racine sans destination de retour.

Nouveaux composants : `LoyaloClientSearchHeader`, `LoyaloSearchField`, `LoyaloSearchBarDelegate`, `LoyaloClientCard`, `LoyaloClientSearchState`. Aucun accès Firestore dans ces widgets de présentation.

L’en-tête et l’illustration accompagnent la recherche. Le champ reste fixé pendant le défilement des résultats. Les cartes se construisent à la demande dans une SliverList. Le filtrage local ne nécessite ni debounce réseau ni délai artificiel. Les déplacements du curseur ne relancent pas le filtrage inutilement.

Le clavier et le texte agrandi réduisent l’en-tête décoratif. À grande taille de texte, le retour passe au-dessus du titre et les textes peuvent s’étendre verticalement. Les cibles tactiles mesurent au moins 48 dp. Les cartes disposent d’une action sémantique vers le profil ; les messages de résultat et d’état sont accessibles. Les illustrations décoratives sont exclues de la sémantique.

Aucun nom de la maquette n’a été ajouté aux données de production. Aucun email, téléphone ou texte de recherche n’est journalisé par le nouveau code.

## Illustration fournie

Source : [11.png](/Users/david/Desktop/11.png). PNG RGBA 1536 × 1024, avec transparence réelle : 742 151 pixels entièrement transparents, alpha compris entre 0 et 254. Le panneau bleu/violet et ses halos font partie du visuel fourni et sont conservés.

La copie et la source possèdent le même SHA-256 :
`fd6606258bc28d6b4f4ae55f20b08267e71c4e72cb4adcc14ca90d8492cb8d09`.

Boîte de 144 × 96 dp, `BoxFit.contain`, hauteur visible du sujet d’environ **81 dp** compte tenu des marges transparentes. L’image est masquée lorsque l’espace ou la saisie doivent être prioritaires. Aucune image générée, recréée ou téléchargée.

## Vérifications

| Contrôle | Résultat |
| --- | --- |
| dart format sur les six fichiers Dart concernés | Conforme |
| flutter analyze --no-pub | Aucune anomalie |
| Suite Flutter complète | **400 tests réussis** |
| Tests ciblés de l’étape 08 | **32 tests réussis**, inclus dans la suite complète |
| Règles Pilot sur Firestore Emulator | **4 scénarios réussis**, 5 tests Node avec le conteneur |
| Compilation iOS simulateur | Réussie |
| git diff --check | Conforme |

Les tests vérifient le nom, le téléphone et l’email selon les critères existants, l’effacement, l’absence de résultat, les erreurs sans détails privés, le nouvel essai avec conservation de la saisie, la session absente, l’ouverture du bon profil, le retour et l’actualisation du cache. Ils contrôlent aussi que la saisie et le défilement ne provoquent pas de lectures supplémentaires de profils.

Le repository réel est testé sur Firestore simulé et SQLite en mémoire, avec un client d’un autre commerce qui possède un nom et un téléphone similaires. Il n’apparaît pas dans l’annuaire du commerce courant. Un refus de lecture est exposé comme erreur, puis récupéré par le mécanisme de reprise existant. Une lecture terminée après déconnexion ne republie pas les profils.

Les tests sous les règles Pilot vérifient les profils individuellement associés, les refus d’accès aux autres commerces ou aux clients non associés, l’interdiction des recherches globales ou filtrées sur users, et le refus de lecture sans session. Ils utilisent uniquement `demo-loyalo-client-search-ui08` sur boucle locale. Aucun changement des règles.

Responsive : 320 × 568, 390 × 844, 430 × 932 en configuration iOS ; 360 × 740 et 412 × 915 en configuration Android. Chaque taille est testée à ×1 et ×2,5, avec réduction de la zone visible par un clavier de 280 dp. Les variantes agrandies incluent aussi la navigation avec bouton retour. Aucun overflow constaté dans ces tests.

La méthode de recherche, les collections lues, les filtres et la sélection des identifiants ont été comparés au code présent au début de cette étape : ils sont inchangés. Les modèles, providers, profil client, mécanismes de validation, programmes, récompenses, Cloud Functions et configurations/règles Firebase restent identiques à leur état initial.

## Captures natives

iPhone 16e, iOS 26.2, 390 × 844 dp ; captures 1170 × 2532 px. L’aperçu utilise les véritables widgets et le repository avec un backend simulé local et une base mémoire. Les profils des captures sont des fixtures de test, sans lecture de données Pilot.

1. [Champ vide](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-08/01-champ-vide.png).
2. [Résultats autorisés](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-08/02-resultats-autorises.png).
3. [Aucun résultat](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-08/03-aucun-resultat.png).
4. [Champ actif](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-08/04-champ-actif.png), sans clavier logiciel visible.
5. [Erreur de lecture](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-08/05-erreur-lecture.png).
6. [Reprise après erreur](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-08/06-reprise-apres-erreur.png).
7. [Texte agrandi ×2,5](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-08/07-texte-agrandi.png).

Sur l’iPhone standard, le champ commence à y = 267 dp et mesure 56 dp. Une fois la saisie active, il remonte à y = 115 dp. L’illustration reste compacte, les cartes sont alignées et les coordonnées ne sont pas affichées automatiquement.

L’aperçu est installé sous `com.loyalo.loyalo.clientsearchpreview08`, distinct des applications Pilot et Emulator, puis retiré après vérification. Sa copie est terminée et son identifiant contrôlé avant installation. Aucun contrôle temporaire d’aperçu n’est inclus dans le code de production.

## Points restant à vérifier

- **Firebase Pilot distant** : la recette avec un compte et des données réels du projet Pilot n’a pas été exécutée. Les tests de permissions ci-dessus s’appuient sur ses règles inchangées dans l’émulateur local ; ils ne remplacent pas cette recette.
- **Clavier logiciel natif** : le champ reçoit le focus, mais le simulateur n’affiche pas son clavier logiciel dans cette session. L’accès graphique à Device Hub a expiré. Aucun réglage du simulateur n’a été modifié. Les captures ne sont donc pas présentées comme une preuve visuelle du clavier ouvert ; le comportement de redimensionnement reste couvert par les tests sur les cinq tailles.
- Les états ajoutés concernent la lecture des profils clients. Ils ne reconstruisent pas la stratégie de récupération ou les flux de visites existants : la recherche reste celle du cache local autorisé.
- L’avertissement existant de Swift Package Manager pour `flutter_local_notifications` n’empêche pas la compilation iOS.

Aucune nouvelle fonctionnalité métier de « clients récents », nouvelle route ou étape suivante n’a été commencée.

