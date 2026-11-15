# Loyalo V3 — Stabilisation et préparation Git

Audit du **16 novembre 2026**, branche `feature/offline-first`, base initiale `147cd88`.

Cette branche rassemble les développements V3 existants et sert de référence avant Loyalo V4 — Réseau Local. Aucun développement V4, déploiement Firebase, fusion dans `main`, tag officiel ou envoi aux stores n’est réalisé par cette livraison.

## Périmètre conservé

- Accueil commerçant, établissement et rubriques de profil, paramètres et changement de mot de passe.
- Validation des visites et recherche client, programmes de fidélité, récompenses, offres et statistiques.
- Notifications et pages juridiques ; contenu de `lib/legal_content.dart` inchangé.
- Navigation commerçant à cinq destinations avec échancrure centrale, bouton flottant sans libellé visible et espacements compacts.
- Cache Drift, synchronisation, callables de validation/refus et règles de sécurité préexistants.
- Tous les composants, tests, fixtures et rapports des étapes précédentes ; aucun travail supprimé.

## Corrections de stabilisation

- Deux tests de navigation recherchaient encore le texte visible « Valider », retiré de l’interface. Ils utilisent maintenant les clés des destinations, sans changer les assertions de parcours.
- Le test d’intégration natif initialise explicitement le projet de démonstration des émulateurs et vérifie son identifiant, au lieu d’hériter du projet de la configuration native.
- Le test natif Android a révélé un refus du trafic HTTP local. La configuration **debug seulement** autorise `10.0.2.2`, `127.0.0.1` et `localhost`, avec HTTP toujours refusé pour les autres destinations. Le manifeste et la politique réseau release ne sont pas assouplis.
- La clé entièrement factice du projet démo respecte maintenant le format requis par la [validation du SDK Android](https://github.com/firebase/firebase-android-sdk/blob/main/firebase-installations/src/main/java/com/google/firebase/installations/FirebaseInstallations.java), qui bloquait les callables natives avant l’appel local. Un contrôle de ce format complète le test de configuration ; les clés/options Pilot et Production restent inchangées.
- La CI utilise Flutter 3.47.1, compatible avec le verrou exigeant Flutter >= 3.44 et Dart >= 3.12. L’ancien SDK 3.41.8 était trop ancien.
- Les builds CI choisissent explicitement Pilot, son identifiant de projet et les deux callables sécurisées. Les tests Node et Firebase Emulator existants sont exécutés en CI ; aucun déploiement n’est ajouté.
- Les cinq alertes npm élevées de l’outillage de test provenaient de `@grpc/grpc-js` 1.9.16. Un `override` le fixe à **1.14.6**, version corrigée déjà utilisée par le backend, conformément aux [correctifs du mainteneur](https://github.com/grpc/grpc-node/security/advisories/GHSA-f596-whhp-79r4). Le verrou retire uniquement l’ancienne copie vulnérable ; les versions directes Firebase et les dépendances Flutter restent inchangées.
- Le cache local `android/.kotlin/` est ignoré.

## Vérifications locales

Environnement : Flutter **3.47.1**, Dart **3.13.1**, Node **24.15.0**, Java **21**, Firebase CLI **15.15.0**.

| Contrôle | Résultat |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test integration_test test_driver` | 163 fichiers conformes. |
| `flutter analyze --no-pub` | Aucun problème. |
| `flutter test --no-pub` | **700 tests réussis** après adaptation des deux sélecteurs. |
| `flutter pub get --offline --enforce-lockfile` | Verrou accepté, aucune version changée. |
| `npm --prefix functions test` sous Node 24 | **34 tests réussis**, aucun ignoré. |
| `npm --prefix functions run lint` | Vérification syntaxique réussie. |
| Firebase Emulator Auth / Firestore / Functions / Storage | **70 tests réussis**, aucun ignoré, projet `demo-loyalo-v2`. |
| Test Flutter natif vers les émulateurs | **1 scénario complet réussi** sur Android API 36.1 : Auth → Firestore → Functions, réconciliation locale, récompense/parrainage, rejeu et refus. |
| APK Pilot release | Compilation réussie (`app-pilot-release.apk`, 106,5 Mo). Le manifeste release n’embarque pas la politique HTTP réservée au debug. |
| iOS Pilot release sans signature | Compilation réussie (`Runner.app`, 78,3 Mo), bundle `com.loyalo.loyalo.pilot`, configuration embarquée `loyalo-pilot`. |
| `npm ci --prefix functions --ignore-scripts --no-audit` | Installation du verrou réussie ; toutes les copies gRPC sont à 1.14.6. |
| `npm audit` complet après correction | **0 élevée / 0 critique** ; 9 modérées et 1 faible restantes. |
| CI YAML | Syntaxe YAML contrôlée ; exécution GitHub à vérifier après push. |

Les suites Flutter couvrent notamment la connexion et l’inscription client/commerçant avec services simulés, la navigation, les états d’erreur et de chargement, les formulaires, le cache et la synchronisation, les programmes, les visites, les récompenses, les offres et le responsive. Les tests des émulateurs couvrent les transactions serveur, l’idempotence, les validations concurrentes, les politiques de fréquence, les refus, les récompenses/parrainages et l’isolation des données Firestore/Storage. Ces résultats ne valent pas recette mobile complète sur Firebase Pilot distant.

## Firebase et données sensibles

- Production `loyalo-app` n’est ni modifiée ni utilisée pour les tests. Les règles et sources Functions du dépôt restent inchangées.
- Les tests backend utilisent exclusivement les émulateurs locaux du projet de démonstration. Les commandes distantes sont limitées à des lectures sur `loyalo-pilot`.
- `approveCheckInSecure`, `rejectCheckInSecure` et `sendPushForNotification` sont présentes et **ACTIVE** sur Pilot au moment du contrôle. Cela ne prouve pas la concordance exacte des sources/règles déployées ni le bon fonctionnement d’un parcours mobile réel.
- Les deux applications Android/iOS enregistrées correspondent aux identifiants des configurations Pilot du dépôt. Les deux index distants correspondent aux deux définitions Pilot locales, hors champ de tri `__name__` ajouté implicitement par Firestore ; leur présence ne remplace pas l’essai des requêtes de l’application.
- Les configurations Android/iOS Pilot ciblent `loyalo-pilot` ; Production reste séparée. Un environnement absent/invalide est refusé et ne déclenche pas de fallback Production.
- Contrôle des fichiers à publier par motifs de clés privées, comptes de service, jetons et mots de passe : aucun secret identifié hors valeurs synthétiques des tests. Ce contrôle local n’est pas un audit de sécurité exhaustif de tout l’historique Git.
- `config/firebase/pilot.dart-defines.json`, clés de signature Android, caches, journaux et artefacts ne sont pas livrés. Les identifiants publics de configuration SDK Firebase déjà versionnés ne sont pas des clés administrateur.

## Limites connues et recette restante

1. **QR temporaire sécurisé non implémenté** : les vues l’annoncent comme indisponible. Le QR historique n’est pas un jeton sécurisé de 60 secondes. Voir l’[architecture existante](LOYALO_V3_ETAPE_09_ARCHITECTURE_QR.md).
2. **Validation historique par code/recherche** : `registerVisit` conserve le chemin d’écriture cliente existant, interdit par les règles Pilot locales pour la création directe de visites/récompenses. Ce chemin n’est pas validé comme parcours Pilot opérationnel. La sélection d’un client ne remplace pas un check-in valide ; les callables sécurisées restent le chemin testé pour la validation/refus des check-ins.
3. **Recette Pilot distante à effectuer avec des comptes de test** : connexion/inscription et séparation des rôles, check-in → validation/refus → points/récompense, offres, programme, enregistrement des rubriques établissement, uploads, préférences et réauthentification. La disponibilité des fonctions ne suffit pas à valider ces scénarios.
4. **Préférences commerçant** : leur stockage existant dans `users/{uid}` peut refuser la sauvegarde lorsqu’un commerçant n’a pas de profil utilisateur complet. L’interface conserve alors le réglage précédent et affiche l’erreur. Aucun faux profil client n’est créé pour contourner les règles ; ce cas nécessite encore une décision sur le stockage ou les permissions, comme documenté à l’[étape 17](LOYALO_V3_ETAPE_17_PARAMETRES.md).
5. **Services natifs/distants non recettés intégralement** : livraison des notifications push sur appareils physiques, biométrie, ouverture des liens/cartes, photos/caméra et reprise réseau réelle. Les widgets et services simulés sont testés, pas tous les fournisseurs distants.
6. **Dépendances backend** : après correction des cinq alertes élevées de l’outillage de test, `npm audit` complet relève encore **10 alertes** (9 modérées, 1 faible), aucune élevée ou critique. Une partie des corrections restantes proposées implique un changement majeur de `firebase-admin` ; aucune migration majeure ni `audit fix --force` n’est appliquée dans cette stabilisation. Examiner et traiter ces alertes avant livraison officielle.
7. **Version/signature** : `pubspec.yaml` reste à `1.0.0+1` et la release Android utilise la signature debug existante. « V3 » désigne la base fonctionnelle ; ce n’est pas encore une version store `3.0.0`. Les signatures, versions de distribution et essais de release restent à préparer avant publication officielle.
8. **Captures historiques** : certains rapports d’étapes contiennent des liens absolus vers les captures locales. Ces artefacts ne sont pas ajoutés au dépôt et ces liens ne seront pas consultables sur GitHub.

## Livraison officielle proposée

1. Publier le commit `release: stabilize Loyalo V3` sur la branche existante, sans réécrire l’historique.
2. Contrôler la CI GitHub et effectuer la recette Pilot restante ; traiter les alertes backend et toute anomalie bloquante.
3. Présenter la comparaison `main...feature/offline-first` et la proposition de fusion à l’utilisateur.
4. Après sa validation explicite et les contrôles requis, fusionner dans `main` puis créer/publier le tag `v3.0.0` sur le commit effectivement validé. Aucun tag n’est créé automatiquement par cette étape.

État attendu de cette livraison : **base V3 publiée pour référence et recette ; livraison officielle en attente de validation**. Aucun parcours non testé n’est présenté comme validé.
