# Loyalo V3 — livraison des étapes 04 et 05

État au 11 novembre 2026 : inscriptions client et commerçant implémentées et testées localement. Le parcours commerçant en brouillon a été explicitement validé par l’utilisateur avant son branchement. La recette sur Firebase Pilot distant reste à effectuer.

## Résultat UX/UI

Les deux inscriptions réutilisent le fond navy, le logo officiel, la carte blanche arrondie, les champs et le bouton dégradé du Design System. Le formulaire complet, le bouton et le message de sécurité sont visibles sans défilement sur l’iPhone 16e contrôlé. Les petits formats, le clavier ouvert et le texte agrandi utilisent le défilement.

L’inscription client conserve les trois champs, le parrainage facultatif et sa logique existante. Les validations obligatoires sont affichées près des champs ; les règles email et mot de passe restent celles de Firebase. Le message annonçant un compte déjà créé a été remplacé par la description demandée. L’affichage du mot de passe, l’autofill, le chargement et la protection contre les doubles soumissions sont présents.

L’inscription commerçant affiche quatre champs : nom du commerce, activité libre facultative, email et mot de passe. Les deux paramètres de fidélité ont disparu du formulaire. Aucune catégorie métier n’a été ajoutée ; les clés internes restent inchangées.

## Décision métier appliquée après validation

Le compte utilise toujours `AuthService.signUpOrSignIn`. Le commerce est ensuite créé avec les données de brouillon approuvées :

| Champ existant | Valeur initiale |
| --- | --- |
| active | false |
| status | draft |
| loyaltyProgramEnabled | false |
| rewardThreshold | 10, valeur technique de compatibilité |
| rewardLabel | chaîne vide |

Ces valeurs ne constituent pas un programme actif ni une récompense promise. Aucun nouveau champ Firestore n’a été introduit. Les valeurs par défaut du constructeur `Restaurant`, `createRestaurant` et les programmes existants restent inchangés.

`loadOrCreateMerchantDraft` réutilise d’abord une liaison existante ou un commerce appartenant déjà au compte. Pour une nouvelle création, l’identifiant est stable par propriétaire. Les transactions lisent la liaison commerçant avant d’écrire : une reprise tardive ne doit pas écraser un commerce déjà lié et configuré. Si plusieurs commerces existants appartiennent au compte sans liaison exploitable, le parcours s’arrête avec un message au lieu d’en créer un autre.

Les règles actuelles utilisent `get()` pour vérifier le propriétaire lors de la liaison. Le commerce est donc enregistré avant la liaison ; les deux écritures ne peuvent pas être réunies arbitrairement dans un batch avec ces règles. Une interruption entre elles reprend le commerce existant. Le cache est alimenté pour ouvrir immédiatement la configuration.

Le nouveau brouillon ouvre `RewardsManagementScreen`. Un compte déjà configuré retrouve `MerchantRootScreen`. Le parcours de secours de `MerchantEstablishmentScreen` crée également un brouillon ; son interrupteur de publication est désactivé tant que le programme n’est pas configuré. Un commerce déjà configuré repris par ce parcours conserve ses paramètres.

L’écran existant de configuration exige un objectif positif et une récompense renseignée. `completeMerchantOnboarding` vérifie à nouveau le propriétaire et les valeurs avant de publier, puis enregistre la configuration, l’activation de la fidélité et la publication dans la même transaction. Une nouvelle tentative après publication conserve le programme validé. Le parcours d’inscription ouvre ensuite l’espace commerçant. Lors d’une connexion ultérieure, le programme reste accessible depuis l’onglet Récompenses existant.

## Dépendances et sécurité

| Dépendance | Traitement |
| --- | --- |
| Modèle et règles exigent un seuil entier et un libellé texte | Champs conservés, avec les valeurs de brouillon approuvées. |
| Dashboard utilise notamment count % rewardThreshold | Seuil de compatibilité positif ; aucun seuil zéro enregistré. |
| Création historique activait le programme et publiait le commerce | Nouvelle méthode dédiée au brouillon ; appels historiques conservés. |
| Rôle commerçant lié à merchants/{uid} et restaurantId | Propriétaire contrôlé et liaison conservée ; règles inchangées. |
| Commerce non publié | Écarté de la découverte ; règles Pilot testées avec un client distinct. |
| Récompenses et parrainage | Aucune attribution depuis le formulaire. Fonctions sécurisées inchangées. |
| Validation administrative | Aucune nouvelle validation administrative ajoutée. Le statut pendingReview existant n’est pas détourné. |
| Navigation | Navigator et MaterialPageRoute existants ; aucune migration vers GoRouter. |

Le code des services Auth, Analytics, RememberMe, des providers, des environnements, des règles et des Cloud Functions n’a pas été modifié par ces étapes. Le repository a reçu les deux méthodes approuvées ; ses méthodes existantes de création classique, configuration et parrainage sont conservées.

## Fichiers de cette livraison

Les modifications préexistantes des étapes 01 à 03 restent présentes. Le tableau ci-dessous concerne le travail des étapes 04 et 05 ; le fichier des composants communs avait été créé pendant l’étape 03.

| Fichier | Changement |
| --- | --- |
| [client_signup_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/auth/client_signup_screen.dart) | Nouvelle présentation client, validation des champs requis, autofill et états de soumission. |
| [loyalo_auth_ui.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_auth_ui.dart) | Cadre, carte, titre, bouton et message de sécurité communs ; options d’en-tête conservant les valeurs par défaut des connexions. |
| [merchant_signup_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_signup_screen.dart) | Branchement de l’inscription simplifiée sur le brouillon et la configuration. |
| [merchant_signup_view.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_signup_view.dart) | Présentation des quatre champs, indépendante des services. |
| [rewards_management_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/rewards_management_screen.dart) | Configuration initiale, activation et publication après validation. |
| [merchant_establishment_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_establishment_screen.dart) | Parcours de secours aligné sur le brouillon. |
| [restaurant.dart](/Users/david/dev/flutter_projects/Loyalo/lib/models/restaurant.dart) | Getter needsLoyaltySetup ; aucune modification de la sérialisation ou des valeurs par défaut. |
| [loyalty_repository.dart](/Users/david/dev/flutter_projects/Loyalo/lib/services/loyalty_repository.dart) | Création/reprise du brouillon et finalisation transactionnelle. |
| [pubspec.yaml](/Users/david/dev/flutter_projects/Loyalo/pubspec.yaml) | Déclaration des deux assets d’inscription. |
| [client_signup_hero.png](/Users/david/dev/flutter_projects/Loyalo/assets/images/signup/client_signup_hero.png) | Copie exacte de icon4.png fourni. |
| [merchant_signup_hero.png](/Users/david/dev/flutter_projects/Loyalo/assets/images/signup/merchant_signup_hero.png) | Copie exacte de icon8.png fourni. |
| [client_signup_screen_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/client_signup_screen_test.dart) | 19 tests client : validation, clavier, responsive, chargement, navigation, inscription et parrainage. |
| [merchant_signup_view_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/merchant_signup_view_test.dart) | 11 tests de présentation et d’accessibilité. |
| [merchant_signup_screen_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/merchant_signup_screen_test.dart) | 12 tests du parcours commerçant, dont reprise, configuration et secours. |
| [merchant_onboarding_repository_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/merchant_onboarding_repository_test.dart) | 14 tests du brouillon, de la concurrence, de la publication et des propriétaires. |
| [merchant_onboarding.emulator.test.js](/Users/david/dev/flutter_projects/Loyalo/functions/test/emulator/merchant_onboarding.emulator.test.js) | Tests locaux des règles Pilot inchangées. |
| [Ce rapport](/Users/david/dev/flutter_projects/Loyalo/docs/LOYALO_V3_ETAPE_05_DEPENDANCES.md) | Décision, dépendances, contrôles et limites. |

## Composants et assets

Composants partagés : LoyaloAuthScaffold, LoyaloAuthHeader, LoyaloAuthSurface, LoyaloAuthHeading, LoyaloAuthTextField, LoyaloAuthPrimaryButton, LoyaloAuthError et LoyaloAuthSecurityNote. Le bouton principal utilise toujours LoyaloGradientButton. Aucun nouveau thème n’a été créé.

Le logo officiel est utilisé comme image, avec BoxFit.contain. Les deux illustrations fournies sont copiées sans modification ; leurs SHA-256 correspondent aux fichiers sources. Elles possèdent une transparence réelle, avec des pixels alpha nuls. Les légères lueurs et ombres intégrées aux fichiers sont conservées, sans fond opaque ajouté. Aucun outil de génération graphique n’a été utilisé.

Sur le format iPhone contrôlé, la hauteur du sujet visible est d’environ 81 dp pour le profil client et 70 dp pour la boutique, en tenant compte des marges transparentes du fichier.

## Vérifications

- dart format : fichiers formatés.
- flutter analyze --no-pub : aucune anomalie.
- flutter test --no-pub : 304 tests réussis.
- Fonctions sécurisées, npm test : 34 tests réussis, sources inchangées.
- Règles Pilot sur Firestore Emulator local : 4 scénarios réussis, plus le test conteneur. Création et liaison autorisées, brouillon privé, propriétaire distinct refusé, champs de compatibilité obligatoires et publication autorisée.
- Quatre comparaisons de pixels des connexions client/commerçant, en format normal et avec texte agrandi : réussies après la mutualisation. Le rendu de ces écrans reste inchangé.
- Clavier, petits/grands iPhone, Android et texte à 2,5 : vérifiés par les tests de widgets.
- git diff --check : réussi.

L’émulateur utilisait le projet demo-loyalo-onboarding-ui05, sur la boucle locale, avec les règles Pilot lues depuis le dépôt. Aucun service Firebase distant n’a été utilisé pour ces tests et aucun déploiement n’a été réalisé.

## Captures et limites de recette

| Écran | Capture réelle du simulateur iPhone 16e |
| --- | --- |
| Inscription client | [Capture étape 04](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-client-signup-04-iphone16e.png) |
| Inscription commerçant branchée | [Capture étape 05](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-merchant-signup-05-iphone16e.png) |

Ces captures montrent les écrans réels dans une application d’aperçu isolée, avec le thème de l’application et Firebase simulé. Aucun compte réel n’a été créé. Les aperçus temporaires ont été retirés du simulateur ; l’application Loyalo existante n’a pas été remplacée.

La saisie avec le clavier natif n’a pas été contrôlée manuellement ; sa gestion est vérifiée par les tests de widgets. Le parcours Auth/Firestore sur Firebase Pilot distant et l’état effectivement déployé de ses règles/fonctions ne sont pas validés par ces contrôles locaux. Une recette Pilot distante reste nécessaire avant validation complète en environnement.

Branche conservée : feature/offline-first. Aucun commit, reset, suppression de modification existante ou changement d’environnement Firebase n’a été effectué.
