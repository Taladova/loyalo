# Environnements Firebase Loyalo

La sélection est obligatoire avec `LOYALO_FIREBASE_ENV` :

- `production` cible exclusivement `loyalo-app` ;
- `pilot` cible exclusivement `loyalo-pilot` et exige ses vrais paramètres ;
- `emulator` cible exclusivement `demo-loyalo-v2` et exige
  `LOYALO_USE_FIREBASE_EMULATORS=true`.

Une build sans environnement explicite s'arrête avant de lancer
l'application. Une build pilote incomplète ne revient jamais vers la
production.

## Commandes locales

Production explicite :

```sh
flutter run --dart-define=LOYALO_FIREBASE_ENV=production
```

Emulator :

```sh
flutter run \
  --dart-define=LOYALO_FIREBASE_ENV=emulator \
  --dart-define=LOYALO_USE_FIREBASE_EMULATORS=true \
  --dart-define=LOYALO_SECURE_APPROVE_CHECKIN=true \
  --dart-define=LOYALO_SECURE_REJECT_CHECKIN=true
```

Pilote, uniquement après création des applications Firebase iOS/Android :

```sh
flutter run --dart-define-from-file=config/firebase/pilot.dart-defines.json
```

Copier `pilot.dart-defines.example.json` vers le fichier non versionné
`pilot.dart-defines.json`, puis remplacer chaque placeholder par la valeur
de la plateforme concernée. Ne jamais réutiliser les paramètres de
`loyalo-app`.

Les commandes Firebase CLI doivent toujours préciser l'alias :

```sh
firebase emulators:exec --project emulator "..."
firebase deploy --project pilot
firebase deploy --project production
```

La dernière commande est uniquement documentaire : aucun déploiement n'est
autorisé pendant l'étape 5C.2.
