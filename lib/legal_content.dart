/// Contenu des pages légales, utilisé à la fois par l'écran in-app
/// ([LegalScreen]) et par les pages web statiques (web/privacy.html,
/// web/terms.html) qui doivent rester synchronisées avec ce texte.
///
/// ATTENTION : les mentions entre crochets (ex: [nom de contact]) sont des
/// placeholders à remplacer par les vraies coordonnées avant publication.
const String kPrivacyPolicyText = '''
Dernière mise à jour : 2026

Loyalo respecte votre vie privée. Cette politique explique quelles données sont collectées, pourquoi, et comment les contrôler.

DONNÉES COLLECTÉES
- Compte : prénom/nom et email (pour créer votre compte et vous identifier).
- Activité de fidélité : visites validées, récompenses obtenues, restaurant concerné.
- Position géographique : uniquement si vous l'autorisez, pour afficher votre distance jusqu'aux commerces sur la carte. Jamais partagée avec des tiers.
- Données techniques : rapports de plantage et statistiques d'usage anonymisées (écrans consultés, actions réalisées), pour améliorer l'application.

POURQUOI CES DONNÉES
Elles servent uniquement à faire fonctionner le programme de fidélité (suivi des visites, attribution des récompenses) et à améliorer la fiabilité de l'application.

OÙ SONT STOCKÉES VOS DONNÉES
Vos données sont hébergées sur les serveurs de Google Firebase (Google Cloud), avec chiffrement en transit et au repos. Le mot de passe mémorisé sur votre appareil (option "Se souvenir de moi") est stocké de façon chiffrée localement (Keychain iOS / Keystore Android), jamais en clair.

PARTAGE DES DONNÉES
Vos données ne sont jamais vendues. Le commerçant que vous visitez voit uniquement votre prénom et votre historique de visites chez lui — jamais vos données chez d'autres commerces.

VOS DROITS
Vous pouvez à tout moment :
- consulter vos informations (Profil > Paramètres),
- supprimer définitivement votre compte et vos données (Paramètres > Supprimer mon compte),
- nous contacter pour toute question à contact@taladova.com.

CONTACT
Taladova — contact@taladova.com
''';

const String kTermsOfServiceText = '''
Dernière mise à jour : 2026

En utilisant Loyalo, vous acceptez les conditions suivantes.

OBJET
Loyalo est un programme de fidélité permettant à un client de cumuler des visites chez des commerces partenaires et de débloquer des récompenses définies par chaque commerçant.

FONCTIONNEMENT
- Chaque client dispose d'un code personnel à 6 chiffres, renouvelé régulièrement.
- Seul un commerçant partenaire vérifié peut valider une visite en saisissant ce code.
- Les récompenses sont définies librement par chaque commerçant et ne sont pas garanties par Loyalo.

COMPTES
- Un compte est nécessaire pour utiliser l'application (client ou commerçant).
- Vous êtes responsable de la confidentialité de votre mot de passe.
- Toute utilisation frauduleuse constatée (tentative de contournement du système de validation) peut entraîner la suspension du compte.

RESPONSABILITÉ
Loyalo met à disposition la plateforme technique. Les récompenses, leur disponibilité et leur qualité relèvent de la seule responsabilité du commerçant qui les propose.

MODIFICATIONS
Ces conditions peuvent évoluer ; toute modification substantielle sera signalée dans l'application.

CONTACT
Taladova — contact@taladova.com
''';
