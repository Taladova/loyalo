# Loyalo V3 — Étape 17 : paramètres commerçant

État : réalisé sur `feature/offline-first`. Modifications des étapes précédentes conservées.

## Changements

- Quatre sections V3 : compte et sécurité, notifications, aide et informations, gestion du compte.
- Suppression des anciens accès Restaurant / Mon établissement dans les paramètres ; l’accès de l’accueil reste disponible.
- Email en lecture seule issu de Firebase Auth, liens légaux et contact de support existants.
- Version et numéro de build lus par `PackageInfo.fromPlatform()`. Le package était déjà transitif ; aucune version de dépendance n’a changé.
- Préférences `merchantCheckIns` / `important` relues avant affichage, erreurs explicites et retour à la valeur enregistrée si l’écriture échoue. La méthode d’écriture existante est inchangée.
- Nouveau formulaire de mot de passe : réauthentification avant `updatePassword`, gestion des erreurs et réussite, doubles soumissions bloquées. Mots de passe uniquement en mémoire et dans Firebase Auth, jamais dans Firestore ou les logs. [Mécanisme officiel Firebase](https://firebase.google.com/docs/auth/flutter/manage-users).
- Déconnexion confirmée ; suppression confirmée et réauthentification avant le parcours existant de suppression. Le commerce et son historique suivent le comportement existant.

## Fichiers de cette étape

- `lib/screens/merchant/merchant_settings_screen.dart`
- `lib/screens/merchant/merchant_password_screen.dart` (nouveau)
- `lib/widgets/loyalo_settings_ui.dart` (nouveau)
- `lib/services/auth_service.dart` : ajout des opérations sécurisées, méthodes existantes conservées.
- `lib/services/loyalty_repository.dart` : ajout d’une lecture des préférences, écritures existantes conservées.
- `pubspec.yaml`, `pubspec.lock` : déclaration directe de package_info_plus déjà installé.
- `test/merchant_account_service_test.dart`, `test/merchant_settings_screen_test.dart`, `test/support/merchant_settings_fixture.dart` (nouveaux).
- `test/merchant_dashboard_screen_test.dart` : navigation adaptée à la suppression de l’ancien accès dans Paramètres.

## Vérifications

- `dart format` : conforme.
- `flutter analyze --no-pub` : aucun problème.
- `flutter test --no-pub` : **628 tests réussis**, dont 13 tests du service et 33 tests de l’interface ajoutés.
- Tests : préférences sauvegardées / chargement / erreurs / refus de permissions, préservation des autres valeurs, navigation, déconnexion, suppression annulée / confirmée / refusée, mots de passe incorrects / politique de sécurité / réseau / session expirée, doubles soumissions.
- Responsive : 320×568, 390×844, 430×932, texte ×1 / ×2 ; formulaire avec clavier à 320 dp. Dialogues défilables, aucun débordement détecté.
- Simulateur iPhone 16e : rendu contrôlé dans une application de prévisualisation isolée utilisant les composants réels et des données locales de test ; version native installée 1.0.0, build 1.
- **Firebase Auth Pilot réel** : projet public et audience du jeton vérifiés, compte temporaire créé sur une instance Auth séparée, mauvais mot de passe rejeté, réauthentification puis changement réussi, politique de mot de passe faible vérifiée, ancien mot de passe refusé, nouveau accepté. Compte temporaire supprimé et connexion après suppression refusée. Aucun compte utilisateur existant modifié.
- Déconnexion et suppression métier testées localement ; aucun compte commerçant réel supprimé pour les tests.

## Limite préexistante

Les préférences sont stockées dans `users/{uid}`. Un commerçant sans document utilisateur complet peut recevoir `permission-denied` lors de la sauvegarde, car la création actuelle exige notamment un code de parrainage. L’interface affiche alors l’échec et conserve le réglage précédent. Aucun profil client artificiel n’est créé. Corriger ce cas nécessiterait une décision distincte sur le stockage des préférences ou les permissions, hors de cette étape.

Aucune règle Firebase, Cloud Function, donnée commerciale réelle ou configuration de fidélité modifiée. Aucun déploiement, aucune génération d’image.

## Captures

- [Compte et notifications](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-17/parametres-compte.png)
- [Mot de passe](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-17/mot-de-passe.png)
- [Résultat du test Auth Pilot](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-17/auth-pilot.json)
