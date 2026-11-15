# Loyalo V3 — Étape 18 : harmonisation commerçant

Réalisé sur `feature/offline-first`. Le travail des étapes précédentes est conservé. Loyalo Pilot a été recompilé, relancé sur l’iPhone 16e et laissé ouvert sur l’accueil avec sa session existante.

**Modifications**

- Accueil : suppression de « Bonjour » et des actions rapides ; nom complet conservé dans les données, affichage sur une ligne avec ellipse ; bouton Mon établissement conservé. Sélecteur de période de 48 dp, aligné à droite, avec les trois options et leurs calculs existants. Statistiques et Loyalo Express conservés.
- Récompenses : titre à gauche et absence de retour dans la navigation principale. Les accès secondaires à la configuration conservent leur retour et leur fonctionnement. Les offres restent distinctes.
- Valider / Rechercher : champ et résultats directement dans l’onglet, à partir du cache et de `searchClients` existants. Chargement, liste vide et erreurs distingués. Aucun départ automatique vers Clients, aucune attribution à la sélection.
- Confirmation : uniquement pour une arrivée existante valide du client dans le commerce, avec confirmation explicite puis `approveCheckIn`, comme Loyalo Express. Le nouveau parcours exige l’option d’approbation sécurisée déjà activée dans Pilot et une connexion disponible. Une synchronisation en attente n’est pas annoncée comme un succès définitif. Aucun appel à `registerVisit` depuis la nouvelle recherche.
- Le code à six chiffres, son collage et ses traitements restent inchangés. Les six onglets sont conservés.

**Fichiers de cette étape**

- [Accueil](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_dashboard_screen.dart), [composants du tableau de bord](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_merchant_dashboard_ui.dart).
- [Récompenses](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/rewards_management_screen.dart), [conteneur des six onglets](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_root_screen.dart).
- [Valider](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/validate_visit_screen.dart), [recherche intégrée — nouveau](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/visit_client_search_pane.dart).
- [Tests accueil](/Users/david/dev/flutter_projects/Loyalo/test/merchant_dashboard_screen_test.dart), [récompenses](/Users/david/dev/flutter_projects/Loyalo/test/rewards_management_screen_test.dart), [validation](/Users/david/dev/flutter_projects/Loyalo/test/visit_validation_screen_test.dart), [recherche intégrée — nouveau](/Users/david/dev/flutter_projects/Loyalo/test/visit_client_search_pane_test.dart).

**Vérifications**

- `dart format --output=none --set-exit-if-changed` : conforme ; `flutter analyze --no-pub` : aucun problème.
- `flutter test --no-pub` : **640 tests réussis**.
- Recherche avec `--dart-define=LOYALO_SECURE_APPROVE_CHECKIN=true` : **24 scénarios réussis**. Ils recouvrent notamment : absence de redirection, sélection sans écriture, confirmation / annulation, doubles soumissions, hors ligne, session expirée, autre propriétaire, commerce inactif, arrivée déjà traitée, refus et erreurs.
- Filtre des trois périodes, ellipse du nom, navigation et retours testés. Responsive de l’accueil jusqu’à 320×568 et texte ×2,5 ; recherche à 320×568 et 390×844, texte ×1 / ×2, clavier ouvert. Aucun débordement détecté.
- Rendu contrôlé sur simulateur iPhone 16e dans une prévisualisation isolée avec données locales de test. Les trois méthodes ont été vérifiées ; prévisualisation désinstallée ensuite. L’accueil de Pilot réel a aussi été contrôlé après relance.
- Aucun repository, provider métier, calcul, programme de fidélité, règle Firestore, Cloud Function ou composant Réseau Local modifié pendant cette étape. Aucune génération d’image ni aucun déploiement.

**Limites conservées**

Le QR temporaire reste indisponible tant que le backend de l’étape 09 n’est pas autorisé et implémenté. Un client sans check-in valide ne peut pas être confirmé par sa seule sélection : l’écran lui demande d’effectuer un check-in. L’adaptation serveur permettant une validation par identité seule reste hors périmètre.

Le chemin historique à six chiffres garde ses limites Pilot documentées dans [l’architecture de l’étape 09](/Users/david/dev/flutter_projects/Loyalo/docs/LOYALO_V3_ETAPE_09_ARCHITECTURE_QR.md). Les tests d’approbation de cette étape utilisent des doubles locaux du service existant ; aucune validation de visite commerciale distante n’a été déclenchée.

**Captures**

[Accueil Pilot réel](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-18/accueil-pilot.png) · [Récompenses](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-18/recompenses.png) · [Recherche](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-18/recherche.png) · [Client sélectionné](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-18/client-selectionne.png) · [Code à six chiffres](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-18/code-six-chiffres.png) · [QR indisponible](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-18/scanner-qr.png) · [Texte agrandi](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-18/recherche-texte-agrandi.png)
