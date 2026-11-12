# Loyalo V3 — étape 06 : configuration du programme classique

État au 11 novembre 2026 : refonte implémentée et vérifiée localement, avec captures du simulateur iPhone. La recette sur Firebase Pilot distant reste à réaliser avant validation complète en environnement.

## Résultat

L’écran présente un en-tête navy avec le titre, le bouton retour et l’illustration fournie, puis une surface blanche arrondie. Les sections suivent l’ordre demandé : Type de fidélité, Objectif, Récompense, Validation des visites, Aperçu client, activation.

Le formulaire défile naturellement. Le bouton reste en bas du contenu, sans superposition fixe. Le retour appartient à l’en-tête et défile avec lui pour ne pas recouvrir les champs. Les labels restent visibles et peuvent revenir à la ligne. Les sélecteurs passent en disposition verticale lorsque la largeur ou le texte agrandi l’exige. Les contrôles numériques conservent des cibles d’au moins 48 × 48 dp.

Les sélections sont indiquées par une coche et par la couleur. Les transitions de contenu sont légères et désactivées lorsque le système demande de réduire les animations.

## Analyse et paramètres conservés

| Paramètre | Mode Visites | Mode Points | Validation conservée |
| --- | --- | --- | --- |
| rewardThreshold | Nombre de visites nécessaires | Objectif de points | Entier supérieur ou égal à 1 |
| pointsPerVisit | Points attribués à chaque visite validée | Points par visite, utilisés aussi pour la progression du programme | Entier supérieur ou égal à 1 |
| rewardLabel | Nom de la récompense | Identique | Texte obligatoire après trim ; aucune nouvelle liste de caractères ou limite de longueur |
| rewardDescription | Description facultative | Identique | Limite existante de 140 caractères, avec compteur |
| validationPolicy | Jour, X h ou Ticket | Identique | oncePerDay, onceEveryXHours, perTransaction |
| minimumHoursBetweenVisits | Visible uniquement pour X h | Identique | Entier supérieur ou égal à 1 lorsque le champ est affiché |

Le code serveur attribue les points par visite indépendamment du type de programme. Le champ des points reste donc disponible dans les deux modes. Le changement de mode conserve les valeurs saisies et change leur présentation ; aucun nouveau calcul ou seuil par défaut n’est introduit.

Aucun plafond métier supplémentaire n’est défini dans le formulaire existant. Les boutons −/+ respectent le minimum 1 et évitent le dépassement de la représentation entière native. La saisie numérique reste filtrée par le filtre Flutter existant.

Le préremplissage, le calcul de l’aperçu et la validation des nombres sont conservés. Le calcul utilise toujours loyaltyProgressFor du repository, avec la même formule de progression. L’aperçu adapte ses unités, son objectif et le nom de la récompense aux contrôleurs ; il ne crée aucune visite, aucun point ni aucune récompense.

## Activation, modification et brouillon

- Un nouveau brouillon utilise toujours completeMerchantOnboarding, ajouté et validé à l’étape 05. La configuration et la publication restent transactionnelles dans le repository inchangé.
- Un programme existant utilise toujours updateLoyaltyProgram. Son bouton affiche « Enregistrer » et ne publie pas automatiquement le commerce. Un statut pendingReview reste inchangé après enregistrement.
- La confirmation existante d’un changement important avec des clients est conservée. Une protection de soumission couvre désormais aussi l’attente de cette confirmation, pour éviter plusieurs dialogues ou demandes simultanées.
- Pendant l’enregistrement, les champs, sélecteurs et boutons sont désactivés et le bouton principal affiche son chargement.
- Une erreur apparaît dans le formulaire, près du bouton, avec une région accessible dynamique. Elle ne recouvre plus le bouton de nouvelle tentative.
- La confirmation de succès et la navigation vers l’espace commerçant restent celles du parcours existant.
- Quitter l’écran ne publie pas et n’enregistre pas les saisies incomplètes. Aucune sauvegarde partielle persistante n’a été ajoutée.

La description annonçant le brouillon et le bouton « Activer et publier » sont réservés au véritable état needsLoyaltySetup. Les autres commerces reçoivent une description de modification et le bouton « Enregistrer », sans promesse de publication administrative immédiate.

## Fichiers de l’étape 06

Les modifications des étapes précédentes restent présentes. Cette liste décrit uniquement le périmètre de l’étape 06.

| Fichier | Modification |
| --- | --- |
| [rewards_management_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/rewards_management_screen.dart) | Présentation, états de soumission et de confirmation, erreurs intégrées au formulaire et retour sans publication. Les mêmes méthodes de persistance sont appelées avec les mêmes paramètres. |
| [loyalo_auth_ui.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_auth_ui.dart) | En-tête personnalisable, bouton retour réutilisable, options de saisie multiligne/compteur/filtre. Les valeurs par défaut des écrans existants sont conservées. |
| [loyalo_program_ui.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_program_ui.dart) | Composants visuels modulaires du programme. |
| [pubspec.yaml](/Users/david/dev/flutter_projects/Loyalo/pubspec.yaml) | Déclaration de l’illustration du programme. |
| [program_setup_hero.png](/Users/david/dev/flutter_projects/Loyalo/assets/images/program/program_setup_hero.png) | Copie exacte de icon5.png fourni. |
| [rewards_management_screen_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/rewards_management_screen_test.dart) | 26 nouveaux tests du formulaire et des parcours conservés. |
| [merchant_signup_screen_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/merchant_signup_screen_test.dart) | Adaptation des sélecteurs de champs et du défilement au nouvel affichage ; assertions métier conservées. |
| [Ce rapport](/Users/david/dev/flutter_projects/Loyalo/docs/LOYALO_V3_ETAPE_06_CONFIGURATION.md) | Résultats, périmètre, captures et limites. |

## Composants et asset

Composants réutilisés : LoyaloAuthScaffold, LoyaloAuthSurface, LoyaloAuthTextField, LoyaloAuthPrimaryButton, LoyaloGradientButton, LoyaloAuthError et LoyaloCard. Les couleurs et le dégradé proviennent des tokens existants ; aucun nouveau thème n’a été créé.

Composants ajoutés : LoyaloProgramHeader, LoyaloSectionHeader, LoyaloProgramSection, LoyaloSegmentedControl, LoyaloProgramField, LoyaloNumericSelector, LoyaloProgramPreview et LoyaloAuthBackButton. Ce dernier extrait le contrôle existant pour partager son style avec les autres écrans.

L’asset fourni mesure 1536 × 1024 pixels et possède une transparence réelle : alpha minimal 0, pixels totalement transparents présents. Le SHA-256 du fichier intégré correspond à celui de icon5.png. Ses lueurs et ombres intégrées sont conservées. Le sujet visible mesure environ 80 dp sur le format iPhone standard contrôlé, et se réduit sur les formats compacts.

Aucune image, illustration, ressource 3D ou icône personnalisée n’a été générée ni téléchargée. Les autres icônes sont les icônes Flutter standard.

## Vérifications

| Contrôle | Résultat |
| --- | --- |
| dart format | Fichiers formatés |
| flutter analyze --no-pub | Aucune anomalie |
| flutter test --no-pub | 330 tests réussis, dont les 26 nouveaux tests de l’écran |
| Comparaisons visuelles des connexions | Quatre références de pixels réussies, client/commerçant, texte normal et agrandi |
| npm test des fonctions sécurisées | 34 tests réussis ; sources inchangées |
| Règles Pilot sur Firestore Emulator | Quatre scénarios réussis, plus le test conteneur : liaison, confidentialité du brouillon, champs requis et publication |
| git diff --check | Réussi |

Les nouveaux tests couvrent les modes Visites/Points, les boutons numériques, la saisie filtrée, le minimum et le dépassement entier, les champs obligatoires, le compteur 140, les trois politiques de validation, la conservation des heures masquées, l’aperçu sans écriture, les erreurs et nouvelles tentatives, les soumissions multiples, la confirmation/annulation, les statuts de publication, la sortie sans sauvegarde, le clavier et les animations réduites.

Les formats de widgets vérifiés incluent 320 × 568, 390 × 844, 430 × 932, 360 × 640 et 412 × 915, avec texte agrandi jusqu’à 2,5. Les comportements Android sont couverts par ces tests de widgets ; aucune capture d’un appareil Android n’est présentée comme réalisée.

Les empreintes des modèles, repositories, services, providers, environnements, règles et sources des Cloud Functions correspondent à leur état au début de l’étape 06. Le code de Loyalo Réseau Local n’a pas été modifié.

## Captures du simulateur iPhone 16e

Toutes les images ci-dessous sont des captures réelles du véritable écran Flutter, dans une application d’aperçu isolée utilisant le thème de Loyalo et des données en mémoire. Les exemples sont saisis dans les contrôleurs de l’aperçu ; aucun compte réel ni donnée distante n’a été créé.

| Contrôle visuel | Capture |
| --- | --- |
| En-tête, illustration, début du formulaire | [01 — En-tête](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-program-06/01-en-tete.png) |
| Objectif et paramètres numériques | [02 — Objectif](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-program-06/02-objectif.png) |
| Récompense, description et compteur | [03 — Récompense](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-program-06/03-recompense.png) |
| X h et délai conditionnel | [04 — Validation](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-program-06/04-validation.png) |
| Aperçu Visites et mode Ticket | [05 — Aperçu client](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-program-06/05-apercu-client.png) |
| Aperçu Points et bouton accessible | [06 — Publication](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-program-06/06-publication.png) |
| Choix Points et champs correspondants | [07 — Mode Points](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-program-06/07-mode-points.png) |
| Champ actif avec clavier natif ouvert | [08 — Clavier](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-program-06/08-clavier.png) |
| Bouton accessible avec clavier ouvert | [09 — Publication avec clavier](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-program-06/09-publication-clavier.png) |
| Texte à 2,5 et sélecteurs adaptés | [10 — Texte agrandi](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-program-06/10-texte-agrandi.png) |

L’application d’aperçu a été retirée du simulateur après les captures ; l’application Loyalo existante n’a pas été remplacée. Les émulateurs locaux ont été arrêtés.

## Limites et suite de recette

Le parcours distant Auth/Firestore sur Firebase Pilot et l’état effectivement déployé des règles/fonctions ne sont pas validés par ces tests locaux. Une recette Pilot distante reste nécessaire pour valider complètement l’étape en environnement. Aucun test destructif n’a été effectué sur Production.

Aucune modification métier supplémentaire n’est nécessaire pour cette refonte. Aucune règle Firebase, aucun schéma Firestore, contrôle de rôle, mécanisme anti-doublon serveur, calcul de points, mécanisme de récompense ou déploiement n’a été modifié.

La branche feature/offline-first et les modifications préexistantes sont conservées. Aucun commit, reset Git ou suppression de travail existant n’a été effectué.
