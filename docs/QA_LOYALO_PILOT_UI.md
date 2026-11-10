# Loyalo Pilot — Guide de validation manuelle UI

## Objectif et périmètre

Ce document permet de valider manuellement Loyalo sur l'environnement Firebase **Pilot uniquement**.

- Projet Firebase attendu : `loyalo-pilot`
- Flavor Flutter attendu : `pilot`
- Fichier de paramètres obligatoire : `config/firebase/pilot.dart-defines.json`
- Ne jamais remplacer ces paramètres par ceux de Production.
- Ne jamais saisir un compte Production dans une build Pilot.

Les résultats ci-dessous sont volontairement initialisés à **NON TESTÉ**. Ne passer un scénario à PASS ou FAIL qu'après avoir réellement effectué toutes ses actions dans l'interface.

## Comptes et données de démonstration

Les comptes Pilot suivants existent au moment de la préparation :

- Client : `client.demo@loyalo-pilot.test`
- Commerçant : `merchant.demo@loyalo-pilot.test`

Les mots de passe ne sont pas stockés dans ce document. Utiliser le canal sécurisé prévu pour l'équipe pilote.

Restaurant associé au commerçant :

- Nom : **Restaurant Démo Pilot**
- Identifiant : `demo-merchant-restaurant`
- Catégorie : Restaurant
- Statut : actif
- Points par visite : 120
- Palier : 10 visites
- Récompense : Une récompense offerte
- Fréquence : une validation par jour
- Adresse : absente au moment de l'audit

L'absence d'adresse et les coordonnées de fallback historiques empêchent de valider correctement « Y aller » avec cette fiche. Ajouter ultérieurement une vraie adresse ou de vraies coordonnées Pilot avant ce test.

## Observations réelles — étape 5C.5-B (8 novembre 2026)

L'application a été lancée sur l'iPhone 16e iOS 26.2 avec le flavor et les dart-defines Pilot.

Observé réellement à l'écran :

- démarrage réussi sans crash ;
- reprise automatique d'une session client existante ;
- affichage de l'accueil client ;
- solde de 120 points ;
- progression indiquant 9 visites restantes ;
- récompense cible « Une récompense offerte » ;
- état vide « Aucune offre exclusive active pour le moment » ;
- état vide des récompenses ;
- badge d'une notification ;
- barre de navigation client complète.

Limite de cette exécution : le CoreSimulator a permis le lancement et la capture de l'écran, mais pas l'automatisation des gestes tactiles. Les scénarios C01 à C13 restent donc au statut **NON TESTÉ** tant que toutes leurs actions n'ont pas été effectuées manuellement. Cette observation ne constitue pas un PASS pour la connexion, la découverte, la fiche restaurant ou le check-in.

Données manquantes confirmées :

- aucune adresse ;
- aucune latitude ;
- aucune longitude ;
- aucun document `rewardDefinitions` spécifique au restaurant ; le palier utilisé provient directement de la fiche restaurant.

## Lancement

### VS Code — iOS

1. Ouvrir **Run and Debug**.
2. Choisir `Loyalo Pilot iOS (iPhone 16e)`.
3. Lancer avec F5.
4. Vérifier dans les logs qu'aucune référence à `loyalo-app` n'apparaît.

Commande équivalente :

```bash
flutter run \
  -d B993E489-8956-4C0D-B8A9-D3DE0C4913E8 \
  --flavor pilot \
  --dart-define-from-file=config/firebase/pilot.dart-defines.json
```

### VS Code — Android

1. Démarrer un émulateur ou connecter un appareil Android.
2. Choisir `Loyalo Pilot Android`.
3. Si VS Code ne résout pas automatiquement `android`, sélectionner l'appareil dans la barre d'état puis relancer.
4. Vérifier que l'application installée porte l'identifiant Pilot.

Commande équivalente :

```bash
flutter run \
  -d <ANDROID_DEVICE_ID> \
  --flavor pilot \
  --dart-define-from-file=config/firebase/pilot.dart-defines.json
```

## Règles de consignation

Pour chaque scénario :

- **Résultat observé** : décrire précisément l'écran, le message et les valeurs constatées.
- **Statut** : `PASS`, `FAIL` ou `NON TESTÉ`.
- En cas de FAIL, joindre une capture et les logs Flutter correspondants.
- Ne jamais copier un mot de passe, token Firebase ou code privé dans ce document.

---

# Parcours client

## C01 — Inscription client

**Prérequis** : utiliser une adresse réservée aux tests Pilot et encore inconnue de Firebase Auth.

**Actions exactes** :

1. Depuis l'accueil, toucher `Je suis un client`.
2. Ouvrir l'inscription.
3. Remplir tous les champs obligatoires.
4. Valider.

**Résultat attendu** : le compte et le profil sont créés, puis l'espace client s'ouvre sans écran blanc ni boucle de chargement.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## C02 — Connexion, reprise de session et profil

**Prérequis** : compte client Pilot existant.

**Actions exactes** :

1. Se connecter avec le compte client Pilot.
2. Vérifier l'accueil et ouvrir `Profil`.
3. Vérifier le nom et l'email.
4. Fermer complètement l'application puis la relancer.

**Résultat attendu** : connexion réussie, profil réel affiché et session reprise directement dans l'espace client.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## C03 — Accueil et états vides

**Prérequis** : session client active.

**Actions exactes** :

1. Ouvrir `Accueil`.
2. Vérifier le solde, la prochaine récompense, les offres, récompenses et visites récentes.
3. Vérifier qu'une collection vide affiche un message professionnel et pas de fausses données.

**Résultat attendu** : données Pilot cohérentes, chargement transitoire compréhensible et aucun restaurant fictif injecté.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## C04 — Découverte, recherche et favoris

**Prérequis** : session client active et Internet disponible.

**Actions exactes** :

1. Ouvrir `Découvrir`.
2. Rechercher `Restaurant Démo Pilot`.
3. Tester les filtres disponibles.
4. Ajouter puis retirer le restaurant des favoris.
5. Ouvrir la recherche externe et saisir au moins trois caractères.

**Résultat attendu** : les partenaires viennent de Firestore Pilot ; la recherche externe est clairement distincte des partenaires et ajoute uniquement à la liste personnelle.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## C05 — Carte et géolocalisation

**Prérequis** : fiche partenaire avec coordonnées réelles.

**Actions exactes** :

1. Autoriser puis refuser successivement la permission de localisation sur deux essais.
2. Ouvrir la carte et vérifier le marqueur.
3. Vérifier les états lorsque la position est indisponible.

**Résultat attendu** : aucun crash, permission compréhensible et aucune position fictive présentée comme réelle.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## C06 — Fiche commerce et « Y aller »

**Prérequis** : vraie adresse ou coordonnées Pilot configurées.

**Actions exactes** :

1. Ouvrir la fiche du restaurant.
2. Vérifier nom, catégorie, programme, horaires, images et avis.
3. Toucher `Y aller`.

**Résultat attendu** : l'application cartographique ouvre un itinéraire vers ce restaurant, sans utiliser l'adresse ou les coordonnées de démonstration historiques.

**Résultat observé** : _bloqué tant que Restaurant Démo Pilot n'a pas de destination réelle_

**Statut** : NON TESTÉ

## C07 — Création d'un check-in

**Prérequis** : client et commerçant Pilot connectables sur deux sessions, restaurant actif.

**Actions exactes** :

1. Depuis la fiche, toucher `Je suis ici`.
2. Vérifier le message de confirmation.
3. Revenir sur la fiche ou l'accueil.

**Résultat attendu** : une seule demande `pending` apparaît, avec un état en attente clairement présenté et sans points définitifs.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## C08 — Validation, points et historique

**Prérequis** : scénario C07 et commerçant connecté.

**Actions exactes** :

1. Faire approuver la demande côté commerçant.
2. Revenir côté client ou relancer l'écran.
3. Vérifier le solde, l'historique, la progression et la notification.

**Résultat attendu** : +120 points une seule fois, une seule visite, état approuvé et progression actualisée.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## C09 — Refus

**Prérequis** : nouvelle demande pending autorisée par la fréquence du programme.

**Actions exactes** :

1. Refuser la demande côté commerçant.
2. Actualiser côté client.

**Résultat attendu** : état refusé explicite, aucun point, aucune visite et aucune récompense.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## C10 — Récompenses

**Prérequis** : compte disposant d'une récompense Pilot disponible.

**Actions exactes** :

1. Ouvrir `Avantages`.
2. Vérifier les onglets et conditions.
3. Faire utiliser la récompense par le commerçant si le parcours est proposé.
4. Vérifier qu'elle passe une seule fois à l'état utilisé.

**Résultat attendu** : données Firestore réelles, aucun double usage et état actualisé des deux côtés.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## C11 — Parrainage

**Prérequis** : deux comptes client Pilot sans visite préalable pour le filleul.

**Actions exactes** :

1. Ouvrir le parrainage du parrain et copier son code.
2. Associer le code au compte filleul.
3. Valider la première visite du filleul.
4. Rejouer ou actualiser le parcours.

**Résultat attendu** : bonus serveur de 500 points attribué une seule fois, statuts et notification cohérents.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## C12 — Notifications

**Prérequis** : appareil physique recommandé pour APNs.

**Actions exactes** :

1. Autoriser les notifications.
2. Générer une validation, une récompense ou un parrainage.
3. Ouvrir la notification reçue.

**Résultat attendu** : notification visible une seule fois et ouverture du bon écran.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## C13 — Déconnexion

**Prérequis** : session client active.

**Actions exactes** :

1. Toucher le bouton de déconnexion du header ou celui des paramètres.
2. Vérifier le retour à l'accueil d'authentification.
3. Utiliser le geste/bouton retour.
4. Se reconnecter.

**Résultat attendu** : Firebase Auth déconnecté, impossible de revenir aux données privées, reconnexion fonctionnelle et PendingActions non détruites.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

---

# Parcours commerçant

## M01 — Connexion et association au commerce

**Prérequis** : compte commerçant Pilot existant.

**Actions exactes** :

1. Ouvrir `Je suis commerçant`.
2. Se connecter.
3. Vérifier le nom du commerce et ouvrir ses paramètres.

**Résultat attendu** : profil chargé et association exclusive à `Restaurant Démo Pilot`.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## M02 — Tableau de bord et statistiques

**Prérequis** : session commerçant active.

**Actions exactes** :

1. Vérifier visites, nouveaux clients et points attribués.
2. Changer la période `Aujourd'hui` si possible.
3. Ouvrir `Voir tout` puis `Stats`.

**Résultat attendu** : valeurs calculées depuis les visites Pilot, liste d'accueil limitée et historique complet accessible.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## M03 — Loyalo Express et approbation

**Prérequis** : check-in client pending.

**Actions exactes** :

1. Vérifier que Loyalo Express indique un client en attente.
2. Ouvrir la liste centrale de validation.
3. Vérifier le client puis approuver une seule fois.
4. Attendre l'actualisation sans relancer l'application.

**Résultat attendu** : demande visible en temps réel, loader borné, message de succès, disparition de la liste pending et aucune duplication.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## M04 — Refus et gestion d'erreur

**Prérequis** : nouveau check-in pending.

**Actions exactes** :

1. Refuser la demande.
2. Réessayer la même action.
3. Couper brièvement le réseau pendant une nouvelle action.

**Résultat attendu** : refus idempotent, aucun point, état provisoire compréhensible hors ligne et aucune roue infinie.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## M05 — Clients et historique

**Prérequis** : au moins une visite réelle Pilot.

**Actions exactes** :

1. Ouvrir `Clients` et rechercher le client.
2. Ouvrir sa fiche.
3. Vérifier visites et récompenses.
4. Ouvrir l'historique complet depuis le tableau de bord.

**Résultat attendu** : uniquement les clients liés au restaurant courant, données cohérentes avec les visites.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## M06 — Programme de fidélité et récompenses

**Prérequis** : session commerçant active.

**Actions exactes** :

1. Ouvrir `Récompenses`.
2. Vérifier les paramètres actuels.
3. Modifier une valeur de test autorisée puis enregistrer.
4. Revenir et vérifier la persistance.

**Résultat attendu** : validation des champs, écriture limitée au restaurant propriétaire et retour utilisateur clair.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## M07 — Offres

**Prérequis** : session commerçant active.

**Actions exactes** :

1. Ouvrir `Offres`.
2. Créer une offre temporaire.
3. Vérifier son affichage client.
4. Désactiver ou supprimer l'offre.

**Résultat attendu** : offre liée uniquement au restaurant, erreurs visibles et actualisation temps réel côté client.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## M08 — Informations et images du commerce

**Prérequis** : session commerçant, JPEG/PNG/WebP de moins de 8 Mio.

**Actions exactes** :

1. Ouvrir les paramètres puis l'établissement.
2. Modifier une information non sensible et enregistrer.
3. Envoyer logo, couverture puis photo de galerie.
4. Remplacer une image et supprimer uniquement l'image de test.

**Résultat attendu** : images visibles après upload, ancien objet nettoyé après remplacement et accès refusé depuis un autre compte.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## M09 — Déconnexion

**Prérequis** : session commerçant active.

**Actions exactes** :

1. Toucher la déconnexion.
2. Vérifier le retour à l'authentification.
3. Tester le retour arrière puis une reconnexion.

**Résultat attendu** : aucune donnée commerçant visible après logout et reconnexion normale.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

---

# Scénarios transversaux et offline-first

## T01 — Approbation hors ligne puis synchronisation

**Prérequis** : check-in pending déjà reçu côté commerçant.

**Actions exactes** :

1. Couper Internet.
2. Approuver.
3. Vérifier l'état « en attente de synchronisation ».
4. Fermer et relancer l'application toujours hors ligne.
5. Rétablir Internet.

**Résultat attendu** : PendingAction conservée, validation non présentée comme définitive avant le serveur, synchronisation automatique et une seule visite.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## T02 — Refus hors ligne

**Prérequis** : check-in pending.

**Actions exactes** : répéter T01 en choisissant le refus.

**Résultat attendu** : synchronisation sécurisée, aucun point et aucune visite.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## T03 — Expiration pendant la coupure

**Prérequis** : check-in proche de son expiration.

**Actions exactes** : approuver hors ligne, attendre l'expiration serveur, puis reconnecter.

**Résultat attendu** : refus serveur explicite, aucune attribution définitive et données locales cohérentes.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

## T04 — Isolation des comptes

**Prérequis** : deux clients ou deux commerçants de restaurants distincts.

**Actions exactes** : vérifier qu'un compte ne peut lire ou modifier les données privées de l'autre.

**Résultat attendu** : accès refusé sans fuite visuelle de données précédemment chargées.

**Résultat observé** : _à compléter_

**Statut** : NON TESTÉ

---

# Fiche d'incident

Pour chaque FAIL, copier ce modèle :

```text
Identifiant : BUG-UI-XXX
Écran :
Compte/restaurant de test :
Étapes de reproduction :
Résultat attendu :
Résultat observé :
Logs utiles :
Capture :
Fréquence : systématique / intermittente
Priorité proposée : P0 / P1 / P2
```
