# Loyalo V3 — Étape 15 — Mon établissement

12 novembre 2026 — branche `feature/offline-first`.

L’entrée existante « Mon établissement » ouvre une page de navigation V3, puis cinq pages indépendantes : informations générales, adresse, horaires, photos et visibilité. Les accès depuis l’accueil et Paramètres, le retour, la fiche publique et les liens Fidélité / Offres sont conservés.

Chaque rubrique dispose de sa sauvegarde, d’une confirmation avant abandon et des états chargement / succès / erreur. Les retours de sauvegarde et le premier champ invalide sont ramenés dans la zone visible. Une erreur conserve la saisie ; un double appui ne crée pas une deuxième sauvegarde.

## Enregistrement et données

L’audit a confirmé que `updateRestaurantProfile` écrivait la fiche entière. L’adaptation présentée avant implémentation ajoute `updateRestaurantSection` : champs autorisés par rubrique, contrôle du propriétaire sur le document courant et écriture transactionnelle des seuls champs modifiés. Un conflit sur un champ édité est signalé ; les modifications d’autres champs, y compris les champs backend inconnus du modèle, sont conservées. Les méthodes préexistantes du repository restent inchangées.

Les horaires conservent une seule plage par jour et la validation HH:MM existante. Les valeurs proposées par défaut, absentes du document, ne comptent pas comme des horaires enregistrés. La progression décrit cinq repères réels : nom / catégorie, adresse / ville, horaires enregistrés utilisables, présence d’une photo et configuration du programme. Adresse, horaires et photos restent facultatifs ; le compteur n’accorde aucune autorisation de publication.

La visibilité se modifie uniquement dans sa rubrique et après « Enregistrer ». Un brouillon nécessitant sa configuration de fidélité ne peut pas être activé par ce formulaire. Les statuts en attente et suspendu sont conservés. La configuration / publication du brouillon utilise l’écran Fidélité existant.

Les nouvelles photos sont chargées dans des fichiers distincts au moyen d’une option du service existant. Les références du commerce changent après sauvegarde explicite. Les fichiers remplacés sont nettoyés après succès ; une image potentiellement enregistrée reste protégée si la réponse réseau est perdue. La galerie reste limitée à huit photos. Les chemins historiques et les limites de taille / formats du service sont conservés.

## Fichiers

| Fichier | Modification |
| --- | --- |
| [merchant_establishment_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_establishment_screen.dart) | Page principale, identité réelle, progression et navigation. |
| [merchant_establishment_section_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_establishment_section_screen.dart) | Cinq éditeurs indépendants et protection des modifications non enregistrées. |
| [merchant_establishment_setup_screen.dart](/Users/david/dev/flutter_projects/Loyalo/lib/screens/merchant/merchant_establishment_setup_screen.dart) | Extraction du formulaire de création de secours, logique préservée. |
| [loyalo_establishment_ui.dart](/Users/david/dev/flutter_projects/Loyalo/lib/widgets/loyalo_establishment_ui.dart) | Composants V3 de présentation. |
| [restaurant_profile_section.dart](/Users/david/dev/flutter_projects/Loyalo/lib/models/restaurant_profile_section.dart) | Rubriques, champs autorisés, comparaisons et validateurs existants. |
| [restaurant.dart](/Users/david/dev/flutter_projects/Loyalo/lib/models/restaurant.dart) | Lecture des horaires réellement enregistrés et construction depuis une carte ; sérialisation Firestore inchangée. |
| [loyalty_repository.dart](/Users/david/dev/flutter_projects/Loyalo/lib/services/loyalty_repository.dart) | Nouvelle sauvegarde partielle ; opérations existantes conservées. |
| [merchant_image_service.dart](/Users/david/dev/flutter_projects/Loyalo/lib/services/merchant_image_service.dart) | Option de fichier distinct avant validation ; comportement par défaut conservé. |
| [merchant_dashboard_screen_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/merchant_dashboard_screen_test.dart) | Adaptation du parcours des deux accès et vérification du retour avec la période conservée. |
| [merchant_establishment_repository_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/merchant_establishment_repository_test.dart) | 15 nouveaux tests de sauvegarde et de préservation des données. |
| [merchant_establishment_screen_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/merchant_establishment_screen_test.dart) | 40 nouveaux tests de navigation, formulaires, erreurs, photos, publication et responsive. |
| [merchant_establishment_image_paths_test.dart](/Users/david/dev/flutter_projects/Loyalo/test/merchant_establishment_image_paths_test.dart) | 4 nouveaux tests des chemins photo, sans upload. |
| [establishment_fixture.dart](/Users/david/dev/flutter_projects/Loyalo/test/support/establishment_fixture.dart) | Firestore, Drift et service d’images simulés pour les tests. |
| [Ce rapport](/Users/david/dev/flutter_projects/Loyalo/docs/LOYALO_V3_ETAPE_15_ETABLISSEMENT.md) | Résultats et captures. |

## Vérifications

- **582 tests réussis**, dont **59 nouveaux**. Sauvegardes indépendantes, champs non modifiés, conflits, propriétaire incorrect, erreurs / nouvel essai, abandon / poursuite, double appui, galerie, activation interdite et parcours de secours couverts.
- `dart format` et `flutter analyze --no-pub` conformes.
- Widget tests sur 320 × 568, 360 × 740, 390 × 844, 412 × 915 et 430 × 932, texte ×1 / ×2 et clavier simulé.
- Dix captures relues sur iPhone 16e / iOS 26.2, dont les cinq rubriques et le texte à 200 %. Le clavier iOS et les uploads distants n’ont pas été testés sur le simulateur.
- Les tests de données utilisent **FakeFirebaseFirestore et Drift en mémoire**. Le service photo est simulé, et les tests de chemins arrêtent l’opération avant l’upload. Aucune écriture de test sur Firebase distant.
- Les applications installées sont restées intactes pendant l’aperçu isolé, ensuite désinstallé. La cible normale Pilot a été relancée.

Aucun changement des règles Firestore / Storage, des Cloud Functions, des permissions, des dépendances ni des assets. Les écrans Fidélité, Offres, Accueil et Paramètres sont conservés. Aucun déploiement. Aucun point bloquant identifié.

## Captures et preuves

| Vue | Capture |
| --- | --- |
| Page principale | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-15/01-mon-etablissement.png) |
| Rubriques et activité | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-15/02-rubriques-et-activite.png) |
| Informations générales | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-15/03-informations-generales.png) |
| Adresse | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-15/04-adresse-localisation.png) |
| Horaires — début / fin | [Début](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-15/05-horaires.png), [fin et sauvegarde](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-15/10-horaires-enregistrer.png) |
| Photos | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-15/06-photos-identite.png) |
| Visibilité | [PNG](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-15/07-visibilite.png) |
| Texte à 200 % | [Formulaire](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-15/08-formulaire-texte-200.png), [rubriques](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-15/09-rubriques-texte-200.png) |

Preuves : [tests](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-15/tests-flutter.log), [analyse](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-15/analyse-flutter.log), [contrats conservés](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-15/verification-contrats.json), [sources](/Users/david/.codex/visualizations/2026/11/10/01a1c637-e7b1-7e82-9fd2-0a9df071c51d/loyalo-etape-15/verification-sources.json).
