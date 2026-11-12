# Loyalo V3 — Étape 09 — Architecture QR

État : architecture cible du 12 novembre 2026, **backend non modifié et aucun déploiement autorisé à ce stade**. Branche `feature/offline-first`. Les étapes précédentes, dont l’harmonisation 10, sont conservées.

Périmètre courant : seules les modifications UX/UI indépendantes sont autorisées ; les services du code à six chiffres et de la recherche sont conservés strictement. Le complément utilisateur du 12 novembre précise les quatre garanties ci-dessous sans ajouter de fonctionnalité ni autoriser une modification backend ou un déploiement.

## Audit du dépôt

| Élément | Constat vérifié |
| --- | --- |
| Validation à six chiffres | `ValidateVisitScreen` appelle `resolveUserIdFromCode`, puis `registerVisit`. Aucun scanner opérationnel actuellement. |
| Recherche | `ClientSearchScreen` utilise l’annuaire autorisé existant, puis ouvre `MerchantClientProfileScreen`. Sa validation appelle aussi `registerVisit`. |
| QR actuel | `MyCodeScreen` encode le code quotidien dans `QrImageView`. Ce QR historique n’est pas un jeton aléatoire de 60 secondes. Il ne sera pas accepté comme nouveau QR sécurisé. |
| Moteur serveur | `approveCheckInSecure`, région `us-central1`, possède déjà transaction, rôle commerçant, commerce associé, propriétaire, activité, expiration du check-in, verrou par commerce/client, règles Jour / X h / Ticket et idempotence. Il calcule lui-même points, récompenses, notifications et parrainage. |
| Contrat actuel de la fonction | Uniquement `{checkInId, operationId}`, avec `operationId = approveCheckIn:<checkInId>`. Un simple scan ne peut donc pas être branché en sécurité sans évolution serveur. |
| Packages | Déjà installés : `mobile_scanner 7.4.0` (contrainte ^7.2.0) et `qr_flutter 4.1.0`. Aucun nouveau paquet ni mise à jour nécessaire. |
| Caméra | Le manifeste Android de mobile_scanner déclare CAMERA et une caméra facultative. La description iOS `NSCameraUsageDescription` manque dans l’application ; elle sera nécessaire à l’activation réelle du scanner. |
| Pilot | `firebase.pilot.json` référence `config/firebase/pilot/firestore.rules`. Ces règles refusent toute création directe de visites et récompenses par Flutter. |
| Écritures historiques | `registerVisit` passe par `FirestoreVisitRemoteDataSource.upsertVisit`, donc par une écriture Firestore cliente, éventuellement mise en attente locale. Ce chemin ne constitue pas une validation serveur compatible avec les règles Pilot du dépôt. |
| Recherche Pilot | Lecture globale de users interdite ; lecture d’un client limitée à son propriétaire ou au commerçant lié par restaurantCustomers. Ce périmètre doit rester inchangé. |

L’état du déploiement distant n’est pas déduit des fichiers locaux. Aucun changement distant ni validation d’une nouvelle fonction sur Pilot n’a été effectué.

## Architecture cible conservée

### 1. Émettre le QR personnel

Nouvelle callable indicative `issueVisitQr`, client connecté et profil utilisateur existant vérifiés côté serveur.

- Secret de 256 bits issu de `crypto.randomBytes(32)`, encodé base64url.
- Contenu strict : `loyalo:visit:v1:<secret>`. Aucun nom, email, téléphone, identifiant client, point ou montant dans le QR.
- Validité : 60 secondes, déterminée par l’horloge du serveur ; réponse avec payload, expiresAt et serverNow.
- Stockage privé de l’empreinte SHA-256 seulement, du client associé, des dates et de l’état. Le secret brut n’est ni stocké, ni journalisé.
- Un pointeur privé par utilisateur identifie la génération courante. Renouveler invalide l’ancienne génération dans la même transaction.
- Limites de fréquence d’émission côté serveur ; jeton en mémoire seulement dans Flutter, effacé / masqué lorsque l’écran quitte le premier plan.
- L’application affiche le décompte, masque un jeton expiré et renouvelle via le serveur ; aucun jeton créé hors ligne.

Collections privées proposées : `visitQrTokens` et `visitQrIssuers`. Accès SDK client refusé. Pas de nouvelle permission de recherche.

### 2. Scanner et préparer une confirmation

Nouvelle callable indicative `prepareVisitQrValidation`, entrée `{qrPayload}`. Le commerce est dérivé du document merchants lié à l’UID Firebase Auth ; il n’est jamais accepté sur la seule parole du téléphone.

- Vérifier syntaxe, empreinte, génération courante, expiration, absence de consommation, profil client, rôle commerçant, lien au commerce, propriété, commerce actif et programme utilisable.
- Répondre avec un `confirmationId` opaque, le seul nom d’affichage nécessaire et l’identité du commerce. Ne pas renvoyer email ou téléphone.
- Stocker une confirmation privée liée au jeton, au commerçant, au commerce et à l’expiration originale, dans `visitQrConfirmations`.
- **Aucune visite, aucun point, aucune récompense, aucun check-in en attente et aucun lien restaurantCustomers créés au scan.**
- Plusieurs scans ne valent pas plusieurs visites. Le scanner est suspendu après la première détection jusqu’à annulation ou confirmation explicite.

Cette identification ponctuelle par présentation du QR ne crée pas un annuaire global. Un client nouveau pour le commerce n’apparaît dans sa relation client qu’après une visite effectivement confirmée.

### 3. Confirmer via la fonction sécurisée existante

Faire évoluer `approveCheckInSecure` avec une variante strictement distincte `{qrConfirmationId, operationId}`. L’ancien contrat check-in et tous ses tests restent conservés.

La branche QR réutilise le moteur d’attribution existant, sans recopier ses calculs dans Flutter. L’extraction éventuelle de helpers transactionnels doit préserver le comportement du chemin historique.

Dans **une seule transaction Firestore** :

1. Vérifier l’identité Auth et la liaison commerçant / commerce / confirmation / opération. Si cette opération possède déjà un résultat réussi autorisé, restituer ce résultat sans nouvelle écriture et sans exiger un jeton encore courant ou non expiré.
2. Pour une nouvelle validation seulement, relire marchand, commerce, client, confirmation, jeton et pointeur de génération, puis recontrôler propriétaire / commerce / activité / programme, expiration serveur et non-réutilisation. L’expiration QR doit être réévaluée à chaque tentative de transaction.
3. Réutiliser le verrou commerce/client, les contrôles Jour / X h / Ticket et les identifiants déterministes existants.
4. Créer la visite et les seules écritures métier calculées par le serveur ; consommer le jeton et la confirmation dans ce même commit.
5. Écrire le lien client-commerce nécessaire à la lecture autorisée dans ce même commit de réussite, sans écriture préalable ou séparée. Si un check-in de compatibilité est nécessaire au modèle existant, il est créé directement approuvé dans ce même commit, avec source QR : aucun passage par la file des arrivées en attente.
6. Enregistrer le résultat idempotent dans businessOperations, lié au commerçant et au commerce.

L’identifiant d’opération QR est stable et lié à la confirmation par le serveur. Le même nouvel essai après perte de réponse retourne le résultat déjà acquis sans nouvelle attribution, y compris après expiration ou renouvellement ; il doit vérifier la même identité et la même opération. Une autre confirmation ou un autre commerçant ne peut réutiliser le jeton consommé.

Le mode Ticket permet plusieurs visites légitimes avec des jetons distincts, mais jamais deux validations du même jeton. Les modes Jour / X h gardent leur verrou de fréquence, même en cas de confirmations concurrentes avec deux jetons.

Un échec métier ne doit pas créer une visite partielle. Une erreur réseau n’est jamais annoncée comme une validation acquise ; Flutter réessaie la même opération ou demande son résultat au serveur. Ce flux QR ne passe pas par une écriture Firestore directe ni par un fallback d’attribution hors ligne.

### 3 bis. Garanties obligatoires du complément

Ces précisions conservent les trois appels, le jeton de 60 secondes et le moteur transactionnel prévus. Ce sont des exigences du futur backend, pas des protections QR déjà implémentées dans le lot UX/UI.

1. **Un jeton consommé reste consommé après tout renouvellement.** La preuve de consommation est liée à son empreinte, à la visite et à l’opération gagnante ; elle n’est jamais remise à zéro par une nouvelle émission. Le renouvellement crée un jeton distinct, sans écraser l’ancien document. Une empreinte déjà consommée ne peut pas être réémise comme jeton neuf. Un jeton absent, expiré, remplacé ou consommé ne peut pas ouvrir une nouvelle validation ; un document manquant ne doit jamais être recréé à partir du QR scanné. Les preuves de consommation ne sont pas supprimées par le renouvellement ou le nettoyage TTL. La garantie porte sur l’ancien jeton : un nouveau jeton reste soumis aux règles Jour / X h / Ticket existantes.

2. **La relation client-commerçant appartient au commit de réussite.** L’écriture de `restaurantCustomers` n’existe que dans la même transaction sécurisée que la visite réussie, la consommation et son résultat idempotent. Ni émission, ni scan, ni identification, ni confirmation en attente ne créent cette relation. Une transaction refusée ou annulée ne crée ni ne modifie de relation ; une relation préexistante est conservée. La restitution d’un résultat déjà acquis n’effectue aucune nouvelle écriture de relation.

3. **Aucune validation QR hors ligne ni attribution locale.** Une confirmation QR ne démarre pas hors ligne et n’est pas placée dans une file Drift ou une file d’écritures Firestore à rejouer ultérieurement. Aucun fallback QR vers `registerVisit`, l’approbation locale des arrivées ou un calcul Flutter de points / récompenses. Si la connexion est perdue après l’envoi, le serveur peut avoir validé : l’écran indique alors un résultat non confirmé, conserve la même clé d’opération et attend la vérification serveur. Il ne fabrique ni succès, ni visite provisoire, ni points locaux. Les parcours historiques restent inchangés.

4. **Une réponse perdue ne fait pas perdre le succès idempotent.** Pour une nouvelle tentative de la même opération, vérifier l’identité et la liaison immuable commerçant / commerce / confirmation, puis rechercher le résultat réussi dans `businessOperations` avant d’exiger un jeton encore courant ou non expiré. La récupération ne doit pas dépendre de la présence d’un document QR éphémère. Les champs métier enregistrés — notamment visite, points, récompense et opération — sont restitués sans recalcul ni attribution supplémentaire ; l’indicateur `alreadyProcessed` peut signaler la répétition. Le résultat réussi et les liaisons nécessaires à son contrôle ne sont pas purgés par le renouvellement ou le TTL. Une opération différente utilisant l’ancien QR est refusée ; un autre utilisateur ne peut pas récupérer ce résultat.

### 4. Permissions et données

Les nouvelles collections privées restent sous le refus général des règles existantes ; si des matches explicites de refus sont ajoutés pour documenter cette règle, ils attendent la même validation. Aucune ouverture de users, visits, rewards ou restaurantCustomers.

Le TTL Firestore, facultatif pour le nettoyage, n’est jamais un contrôle de validité : le serveur contrôle expiresAt pour toute nouvelle validation. Un éventuel nettoyage se limite aux données éphémères devenues inutiles ; il exclut les preuves de consommation et les résultats idempotents réussis. Leur conservation et son stockage font partie des coûts à estimer. Aucune activation de politique TTL, d’App Check obligatoire ou de service cloud supplémentaire sans revue de la configuration Pilot.

Le parcours des arrivées, Loyalo Réseau Local, les règles existantes, le parrainage et les calculs de fidélité ne sont pas redéfinis.

## Décision distincte : compatibilité du code et de la recherche avec Pilot

Le chemin actuel à six chiffres et celui de la fiche client ne peuvent pas être présentés comme validés sur Pilot avec les règles présentes dans le dépôt.

Deux périmètres possibles :

- **Interface seule pour ces deux parcours** : conserver exactement leurs services et leurs autorisations actuels. Le blocage Pilot est documenté ; aucune garantie de validation distante.
- **Adaptation serveur séparément autorisée** : garder le code quotidien, la saisie, la recherche limitée et le résultat utilisateur, mais faire résoudre et valider la demande côté serveur via le moteur sécurisé. Sans ouvrir les règles et sans attribution Flutter. La recherche ne permettrait de valider que les clients déjà autorisés pour ce commerce.

L’architecture QR n’implique pas à elle seule l’autorisation de modifier ces deux chemins historiques.

## Travail Flutter indépendant avant accord backend

- Moderniser l’écran de validation : titre compact sans logo, trois méthodes, navigation commerçant conservée.
- Garder **Code à 6 chiffres comme méthode initiale**, puisque le scanner ne peut pas être opérationnel avant le serveur.
- Présenter Scanner QR comme indisponible, avec accès aux deux méthodes existantes ; ne pas ouvrir la caméra ni simuler une vérification serveur.
- Ajouter l’écran client « Mon QR code » et son accès depuis la carte, sans fabriquer de jeton ni substituer le QR quotidien au futur QR sécurisé.
- Utiliser les deux assets fournis en petits formats secondaires ; ne générer aucun visuel.
- Réutiliser `LoyaloPageHeader`, le fond / surfaces Loyalo V3, les boutons et les routes Navigator présentes. Aucun onglet inférieur supprimé.
- Exécuter les tests de présentation et des parcours conservés. Les tests d’un QR valide / expiré / réutilisé et l’intégration Pilot restent conditionnés au backend réellement implémenté.

## Plan de validation après accord

Tests unitaires et émulateurs avant toute proposition de déploiement : client absent, non authentifié, jeton incorrect / expiré / remplacé / réutilisé, nonce imprévisible, commerçant étranger, commerce inactif, programme invalide, scan sans mutation métier, concurrence, résultat rejoué, règles Jour / X h / Ticket, pannes réseau et contrat check-in historique.

Tests mobile : permission caméra autorisée / refusée / absence caméra, reprise après arrière-plan, suspension pendant confirmation, double détection, double soumission, QR expiré pendant la confirmation, retour / changement d’onglet / déconnexion, renouvellement, SafeArea et tailles de texte.

Les tests précédents sont conservés. Les cas ci-dessous précisent les quatre garanties demandées et restent **prévus, non implémentés ni exécutés en tant que tests backend QR** :

| Garantie | Cas de régression prévus | Résultat exigé |
| --- | --- | --- |
| Consommation irréversible | Consommer Q0, renouveler en Q1, rejouer Q0 avec une autre opération ; lancer deux confirmations concurrentes de Q0, y compris en mode Ticket ; tenter de réutiliser son empreinte à l’émission. | Une seule visite possible pour Q0, jamais de remise à zéro ni de seconde attribution. Q1 ne contourne pas les règles de fréquence du programme. |
| Relation après réussite seulement | Émission et scan sans validation ; refus d’autorisation, commerce inactif, expiration, fréquence bloquée ou transaction annulée ; réussite atomique. | Aucune relation créée ou modifiée en cas d’échec ; aucune écriture partielle. La relation et la visite sont engagées ensemble lors du succès. |
| Absence de validation hors ligne | Confirmation tentée hors ligne ; coupure avant envoi puis reconnexion ; perte réseau après envoi dont le résultat est inconnu. | Aucun nouvel ordre hors ligne mis en attente, aucune visite ou attribution locale. Une requête déjà envoyée reste à réconcilier, sans annoncer un succès local. |
| Résultat idempotent durable | Commit réussi puis réponse perdue ; expiration et renouvellement du QR ; nouvel essai avec la même opération ; tentative avec une autre identité. | Même visite et mêmes attributions retournées au commerçant autorisé, sans nouvelle écriture métier ; aucun rejet fondé uniquement sur le renouvellement / l’expiration pour ce résultat historique, aucun accès étranger. |

Intégration distante exclusivement sur **loyalo-pilot** et comptes de test, après revue du diff backend puis autorisation du déploiement. Aucun accès de test à la production ni remplacement de l’application Pilot installée pour un aperçu UI.

## Références techniques vérifiées

- [mobile_scanner 7.4.0, documentation du package](https://pub.dev/packages/mobile_scanner/versions/7.4.0) : configuration caméra et plateformes. Version installée confirmée dans pubspec.lock et code local du package ; pas de mise à jour proposée.
- [qr_flutter 4.1.0, documentation du package](https://pub.dev/packages/qr_flutter/versions/4.1.0) : rendu QR, qui ne fournit pas à lui seul une sécurité serveur.
- [Transactions Firestore](https://firebase.google.com/docs/firestore/manage-data/transactions) : transaction atomique, lectures avant écritures et possibilité de reprise.
- [TTL Firestore](https://firebase.google.com/docs/firestore/ttl) : nettoyage différé des documents, à distinguer d’un contrôle d’expiration.

## Résumé demandé, 14 lignes

1. Jeton aléatoire serveur de 256 bits, valable 60 secondes.
2. Aucun nom, email, téléphone, identifiant client ou point dans le QR.
3. Empreinte seule stockée ; renouvellement invalidant l’ancienne génération.
4. Scan limité à la vérification et à la préparation d’une confirmation.
5. Aucun point ni visite avant confirmation explicite du commerçant.
6. Contrat check-in actuel de `approveCheckInSecure` conservé.
7. Ajout proposé d’une branche QR distincte : une évolution backend reste nécessaire.
8. Consommation du jeton et attribution réunies dans une transaction atomique.
9. Clé d’opération stable pour rejouer une réponse perdue sans doubler l’attribution.
10. Contrôles serveur : commerçant, commerce actif, règles Jour / X h / Ticket.
11. Permissions de recherche inchangées et code quotidien conservé.
12. Environ trois appels serveur par parcours, plus les renouvellements et opérations Firestore.
13. Coût dépendant des appels, du calcul, des documents relus / écrits, du stockage et du nettoyage éventuel.
14. Aucun montant promis sans volumétrie ; lot actuel limité à l’UX/UI, sans backend ni déploiement.

## Coûts Firebase potentiels de cette proposition, non engagés

Les trois appels correspondent à émission, préparation et confirmation ; un QR renouvelé sans visite ou des scans répétés ajoutent des appels. Le moteur existant relit les visites et parrainages concernés : le coût de confirmation dépend donc aussi de cet historique, pas uniquement du nombre de visites nouvelles.

Les opérations Firestore supplémentaires comprennent les jetons, le pointeur d’émission et les confirmations privées. Les lectures, écritures, stockage et éventuelles suppressions sont à intégrer à une estimation. Les quotas gratuits sont partagés au niveau du projet ; ils ne garantissent pas un coût nul pour ce nouveau parcours. Les suppressions TTL, si ce nettoyage est retenu plus tard, n’incluent pas d’usage gratuit. [Facturation Firestore](https://firebase.google.com/docs/firestore/pricing).

Les exécutions de fonctions, le calcul, le réseau et les artefacts de déploiement peuvent également être facturés selon l’usage et les quotas disponibles. Aucun service tiers payant, aucune nouvelle dépendance Flutter et aucune instance maintenue à chaud ne sont proposés ici. Aucun plan, quota, instance minimale ou politique TTL n’a été changé. [Tarifs Firebase](https://firebase.google.com/pricing).

## Points différés, selon la décision utilisateur

1. Architecture cible conservée avec les quatre garanties du complément ; son implémentation backend reste hors du lot UX/UI autorisé.
2. Choix acté : services actuels du code à six chiffres et de la recherche inchangés, blocage Pilot documenté.
3. Aucun déploiement. Les tests d’intégration QR sur Pilot attendront un backend approuvé et réellement disponible.
