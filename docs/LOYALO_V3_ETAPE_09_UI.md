# Loyalo V3 — Étape 09 — Lot UX/UI uniquement

12 novembre 2026 — branche `feature/offline-first`.

**Périmètre livré selon votre dernière instruction : interface uniquement. Backend QR non implémenté, services existants conservés, aucun déploiement.**

## 1. Fichiers de ce lot

- [lib/screens/merchant/validate_visit_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/validate_visit_screen.dart) — Trois méthodes, saisie / collage, retours et erreurs de présentation ; mêmes appels métier.
- [lib/widgets/loyalo_visit_validation_ui.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_visit_validation_ui.dart) — Sélecteur, pavé numérique et état QR indisponible partagés.
- [lib/screens/client/my_code_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/client/my_code_screen.dart) — Accès à Mon QR code ; code quotidien et QR historique conservés.
- [lib/screens/client/my_qr_code_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/client/my_qr_code_screen.dart) — Nouvel écran client, sans jeton ni appel serveur.
- [pubspec.yaml](/Users/david/dev/flutter_projects/Loyalo/pubspec.yaml) — Deux déclarations d’assets seulement ; aucune dépendance modifiée.
- [assets/images/validation/visit_code_illustration.png](/Users/david/dev/flutter_projects/Loyalo/assets/images/validation/visit_code_illustration.png) — Copie conforme de icon12.png fourni.
- [assets/images/validation/visit_qr_illustration.png](/Users/david/dev/flutter_projects/Loyalo/assets/images/validation/visit_qr_illustration.png) — Copie conforme de icon10.png fourni.
- [test/visit_validation_screen_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/visit_validation_screen_test.dart) — 34 nouveaux tests UI, retours, erreurs, saisie et responsive.
- [test/support/visit_validation_fixture.dart](/Users/david/dev/flutter_projects/Loyalo/test/support/visit_validation_fixture.dart) — Doubles locaux sans accès Firebase distant.
- [docs/LOYALO_V3_ETAPE_09_ARCHITECTURE_QR.md](/Users/david/dev/flutter_projects/Loyalo/docs/LOYALO_V3_ETAPE_09_ARCHITECTURE_QR.md) — Audit, architecture cible, résumé de 14 lignes, coûts potentiels et garanties complémentaires.
- [docs/LOYALO_V3_ETAPE_09_UI.md](/Users/david/dev/flutter_projects/Loyalo/docs/LOYALO_V3_ETAPE_09_UI.md) — Ce rapport.

## 2. Fonctionnalités d’interface

En-tête compact sans logo ; trois méthodes « Scanner QR », « Code à 6 chiffres », « Rechercher ». Le code reste sélectionné au départ, puisque le scanner n’est pas opérationnel.

Six cases, pavé numérique, zéro initial, effacement, collage explicite et clavier physique. Les doubles soumissions sont bloquées dans l’écran ; les erreurs affichent un message lisible et permettent un nouvel essai. Une réponse reçue après fermeture ne déclenche pas de validation supplémentaire.

La recherche ouvre le même `ClientSearchScreen` et revient sans perdre la saisie. Les six onglets commerçant sont conservés ; les racines de navigation client et commerçant n’ont pas changé.

« Mon QR code » est accessible depuis la carte client. Les deux vues QR affichent **« QR temporaire indisponible »**, sans faux jeton, fausse validation ou ouverture de caméra. Le statut passe avant la décoration et reste visible en texte agrandi. Les visuels fournis sont limités à 48 dp et masqués si nécessaire.

Le QR historique de la carte contient toujours le code quotidien ; il n’est pas présenté comme le futur jeton sécurisé de 60 secondes. Les services du code quotidien et de la recherche sont inchangés, conformément à votre choix.

## 3. Vérifications

| Vérification | Résultat |
| --- | --- |
| Format Dart | Six fichiers contrôlés, format conforme. |
| Analyse Flutter | Aucun diagnostic. |
| Suite Flutter complète | **466 tests réussis**, dont 34 nouveaux tests UI. |
| Responsive | 320 × 568, 390 × 844, 430 × 932, 360 × 640, 412 × 915 ; textes jusqu’à ×2,5 selon les suites. |
| Compilation iOS normale | Réussie sur `lib/main.dart`, sans installation ni lancement de cette application. |
| Diff Git | Contrôlé sans erreur de whitespace. |
| Modifications antérieures | Conservées ; aucun commit, reset ou suppression. |
| Backend / modèles / services / providers / règles / plateformes / thème / racines de navigation | Inchangés par comparaison SHA-256 avec le début de ce lot. |
| Assets | Deux copies conformes aux fichiers fournis ; aucun asset préexistant retouché ou supprimé, aucune génération graphique. |
| Applications installées | 498 fichiers Emulator et 266 fichiers Pilot identiques avant / après ; aperçu distinct désinstallé et port local fermé. |

Les tests UI couvrent saisie, collage valide / invalide, code introuvable, double appui, erreurs et nouvel essai, fermeture pendant résolution, recherche / retour, QR non activé, conservation du code quotidien et des onglets. **Ils ne constituent pas des tests d’un backend QR.**

## 4. Captures

Neuf captures natives relues sur **iPhone 16e / iOS 26.2**, 390 × 844 points, PNG 1170 × 2532 ; taille normale et texte ×2. Aperçu distinct, données et Analytics locaux ; aucune résolution de code ni validation appelée pendant les captures. Aucun débordement observé dans ces scénarios.

| Vue | Capture |
| --- | --- |
| Code vide, navigation commerçant | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-09/01-validation-code.png) |
| Code saisi, zéro initial conservé | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-09/02-code-saisi.png) |
| Scanner explicitement indisponible | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-09/03-scanner-indisponible.png) |
| Recherche existante | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-09/04-recherche-existante.png) |
| Mon QR code, état indisponible | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-09/05-mon-qr-code-indisponible.png) |
| Code à texte ×2, début | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-09/06-code-texte-200.png) |
| Code à texte ×2, action atteignable | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-09/07-code-texte-200-validation.png) |
| Scanner à texte ×2 | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-09/08-scanner-texte-200.png) |
| Mon QR code à texte ×2 | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-09/09-mon-qr-code-texte-200.png) |

Android et les autres tailles sont vérifiés en widget tests, sans appareil Android natif. À texte agrandi, les méthodes peuvent être disposées verticalement ; la vue choisie est amenée dans la zone visible. La navigation inférieure conserve son comportement existant.

## 5. Points différés

- L’[architecture QR](/Users/david/dev/flutter_projects/Loyalo/docs/LOYALO_V3_ETAPE_09_ARCHITECTURE_QR.md) est conservée avec les quatre garanties du complément : consommation irréversible malgré renouvellement, relation dans le seul commit de réussite, aucun mode QR hors ligne / point local et résultat idempotent durable. Les tests prévus sont conservés et ces cas y sont précisés ; l’implémentation backend reste hors du lot autorisé.
- Le blocage Pilot du chemin historique à écritures directes est documenté et conservé à votre demande ; aucun élargissement des permissions.
- Caméra réelle, permissions caméra, jetons valides / expirés / réutilisés, anti-rejeu serveur, concurrence QR et intégration Pilot attendent un backend approuvé. Aucun de ces résultats n’est revendiqué ici.
- `mobile_scanner 7.4.0` et `qr_flutter 4.1.0` sont déjà installés ; pas de nouveau paquet. La description d’usage caméra iOS sera nécessaire avant activation réelle ; elle n’a pas été ajoutée dans ce lot.
- La compilation conserve l’avertissement existant de compatibilité future Swift Package Manager pour `flutter_local_notifications`. Cette dépendance n’a pas été modifiée.

Journaux et preuves : [tests](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-09/tests-flutter.log), [analyse](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-09/analyse-flutter.log), [compilation](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-09/compilation-ios.log), [sources](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-09/verification-sources.json), [applications](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-09/verification-applications.json).
