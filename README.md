# Loyalo

Application mobile de fidélité pour les commerçants indépendants (restaurants, cafés...). Un client cumule des visites chez ses commerces partenaires et débloque des récompenses ; le commerçant valide chaque visite en saisissant le code personnel à 6 chiffres du client (renouvelé régulièrement, pour éviter la fraude).

Stack : Flutter + Riverpod (état), Firebase Auth + Cloud Firestore (backend temps réel), `flutter_map` (carte, OpenStreetMap), CI/CD via GitHub Actions.

La base Loyalo V3 est conservée sur `feature/offline-first`. Le [rapport de stabilisation](docs/LOYALO_V3_RELEASE.md) décrit les vérifications, les limites connues et les conditions de livraison officielle. Le développement Réseau Local n’a pas commencé.

## Démarrer le projet

Utiliser Flutter **3.47.1** / Dart **3.13.1**, versions de la vérification V3. Le verrou de dépendances exige au minimum Flutter 3.44 et Dart 3.12. Pour la recette mobile Pilot avec des comptes de test :

```bash
flutter pub get
flutter run --flavor pilot \
  --dart-define=LOYALO_FIREBASE_ENV=pilot \
  --dart-define=LOYALO_FIREBASE_PROJECT_ID=loyalo-pilot \
  --dart-define=LOYALO_SECURE_APPROVE_CHECKIN=true \
  --dart-define=LOYALO_SECURE_REJECT_CHECKIN=true
```

L’environnement est obligatoire ; une configuration Pilot invalide ne bascule pas vers Production. Les configurations natives Pilot versionnées contiennent les identifiants publics du SDK Firebase, pas de compte de service. Les paramètres privés locaux restent exclus de Git. Voir les [environnements Firebase](config/firebase/README.md) et les limitations du [rapport V3](docs/LOYALO_V3_RELEASE.md) avant la recette.

Version web déployée : https://loyalo-app.web.app

## Structure du projet

### `lib/main.dart`
Point d'entrée : initialise Firebase et Crashlytics, puis lance l'app.

### `lib/app.dart`
Configuration racine de `MaterialApp` (thème, suivi analytics des écrans, écran de démarrage).

### `lib/firebase_options.dart`
Config Firebase générée automatiquement par FlutterFire (une par plateforme). Ne pas modifier à la main.

### `lib/theme/`
- `app_theme.dart` — charte graphique (couleurs de marque, dégradé, typographie, thème Material).

### `lib/models/`
Structures de données, chacune avec sa conversion Firestore (`fromFirestore` / `toMap`) :
- `app_user.dart` — profil client (nom, email, code de parrainage).
- `restaurant.dart` — un commerce partenaire (nom, cuisine, seuil de récompense, position GPS...).
- `visit.dart` — une visite validée (qui, où, quand).
- `reward.dart` (`RewardItem`) — une récompense obtenue par un client (disponible/utilisée).
- `reward_definition.dart` — la règle définie par un commerçant (ex: "10 visites = café offert").
- `referral.dart` — un filleul parrainé par un client.

### `lib/providers/app_providers.dart`
Déclarations Riverpod globales : le repository de données, l'utilisateur client connecté, le restaurant du commerçant connecté.

### `lib/services/`
Logique métier et accès externes, indépendants de l'UI :
- `loyalty_repository.dart` — cœur de l'app : cache temps réel synchronisé avec Firestore (restaurants, visites, récompenses...), toutes les écritures (valider une visite, créer une récompense...).
- `auth_service.dart` — fine couche au-dessus de Firebase Auth (connexion, inscription, déconnexion, messages d'erreur en français).
- `remember_me_service.dart` — mémorise localement email/prénom/mot de passe pour pré-remplir les écrans de connexion (mot de passe stocké de façon chiffrée via le Keychain/Keystore).
- `biometric_service.dart` — verrou Face ID / empreinte digitale optionnel au démarrage de l'app.
- `analytics_service.dart` — centralise les événements suivis (connexion, visite validée, récompense débloquée...).

### `lib/screens/`
Un dossier par espace utilisateur.

**Racine**
- `welcome_screen.dart` — écran d'accueil (choix client / commerçant).
- `onboarding_screen.dart` — 3 écrans d'introduction affichés au tout premier lancement.
- `auth_gate_screen.dart` — écran de démarrage : reprend automatiquement la session Firebase existante (avec verrou biométrique si activé) et redirige vers le bon espace, sans jamais bloquer sur un écran de chargement.

**`auth/`** (connexion client)
- `client_login_screen.dart` — connexion/inscription client (compte créé automatiquement à la première connexion).

**`client/`** (espace client)
- `client_root_screen.dart` — barre de navigation du bas + les 5 onglets.
- `client_dashboard_screen.dart` — accueil : points, prochain palier, dernières récompenses (déclenche l'animation de célébration quand une récompense se débloque).
- `restaurant_list_screen.dart` / `restaurant_detail_screen.dart` — liste des commerces partenaires et fiche détaillée (avec carte).
- `my_code_screen.dart` — le code personnel à 6 chiffres à montrer au commerçant.
- `rewards_screen.dart` — liste complète des récompenses (disponibles / utilisées).
- `referral_screen.dart` / `referrals_list_screen.dart` — parrainage : partager son code, voir ses filleuls.
- `client_profile_screen.dart` — profil, accès aux réglages.
- `settings_screen.dart` — notifications, sécurité (Face ID), infos du compte, suppression du compte.

**`merchant/`** (espace commerçant)
- `merchant_login_screen.dart` / `merchant_signup_screen.dart` — connexion et création de compte commerçant (crée aussi le restaurant).
- `merchant_root_screen.dart` — barre de navigation du bas + les 5 onglets.
- `merchant_dashboard_screen.dart` — accueil : résumé du jour, statistiques rapides, activité récente.
- `validate_visit_screen.dart` — pavé numérique pour saisir le code d'un client et valider sa visite.
- `client_search_screen.dart` / `merchant_client_profile_screen.dart` — rechercher un client et valider sa visite depuis sa fiche.
- `rewards_management_screen.dart` — créer/activer les règles de récompense du restaurant.
- `statistics_screen.dart` — graphique d'évolution des visites + indicateurs clés.
- `activity_history_screen.dart` — historique complet des visites validées.

### `lib/widgets/`
Composants réutilisables :
- `loyalo_logo.dart` — logo officiel (avec ou sans slogan).
- `main_bottom_nav.dart` — barre de navigation avec bouton central mis en avant.
- `stat_pill.dart` — carte statistique (icône, valeur, tendance).
- `reward_card.dart` — carte d'affichage d'une récompense.
- `reward_unlocked_dialog.dart` — animation de célébration (confettis) à l'obtention d'une récompense.
- `restaurant_map.dart` — carte OpenStreetMap avec géolocalisation, zoom et distance jusqu'au commerce.
- `section_header.dart` — titre de section avec lien "Voir tout".

## Backend Firebase

- `firestore.rules` — règles de sécurité : seul un compte commerçant vérifié peut enregistrer une visite ou créer une récompense (empêche un client de tricher).
- `firebase.json` — config d'hébergement (web) et de génération des fichiers de config par plateforme.

## CI/CD

`.github/workflows/ci.yml` — sur les pushes `main` / `feature/offline-first` et les PR vers `main` : formatage, analyse et tests Flutter, puis tests Node et Firebase Emulator sur le projet local `demo-loyalo-v2`. Les builds Android et iOS utilisent explicitement le flavor Pilot et les callables sécurisées. L’APK de vérification Android utilise la configuration de signature de développement existante ; il n’est pas destiné aux stores. Aucun job ne déploie Firebase, ne publie sur les stores ou ne fusionne les branches.
