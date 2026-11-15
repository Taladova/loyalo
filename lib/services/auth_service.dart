import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

/// Fine couche au-dessus de Firebase Auth. Ne connaît rien du modèle
/// métier (client/commerçant) : ça reste la responsabilité de
/// [LoyaltyRepository] et des écrans de connexion.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  /// Crée un compte, ou se connecte si un compte existe déjà avec cet
  /// email (évite d'avoir à distinguer "inscription" et "connexion"
  /// dans l'app pendant la phase de test).
  Future<User> signUpOrSignIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        final cred = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return cred.user!;
      }
      rethrow;
    }
  }

  Future<User> signIn({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user!;
  }

  Future<void> signOut() async {
    await NotificationService().detachCurrentDevice(_auth.currentUser?.uid);
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail({required String email}) =>
      _auth.sendPasswordResetEmail(email: email);

  bool get supportsPasswordAuthentication {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || user.email?.isNotEmpty != true) {
      return false;
    }
    return user.providerData.isEmpty ||
        user.providerData.any((provider) => provider.providerId == 'password');
  }

  Future<User> reauthenticateWithPassword({required String password}) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'user-token-expired');
    if (!supportsPasswordAuthentication) {
      throw FirebaseAuthException(code: 'operation-not-allowed');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    final result = await user.reauthenticateWithCredential(credential);
    if (_auth.currentUser?.uid != user.uid || result.user?.uid != user.uid) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    return _auth.currentUser!;
  }

  /// Les deux mots de passe restent uniquement en mémoire et dans Firebase Auth.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = await reauthenticateWithPassword(password: currentPassword);
    if (_auth.currentUser?.uid != user.uid) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    await user.updatePassword(newPassword);
    if (_auth.currentUser?.uid != user.uid) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
  }

  static String accountError(Object error) {
    if (error is! FirebaseAuthException) {
      return 'Une erreur est survenue. Vérifiez votre connexion et réessayez.';
    }
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' => 'Le mot de passe actuel est incorrect.',
      'weak-password' =>
        'Le nouveau mot de passe ne respecte pas les exigences de sécurité du compte.',
      'requires-recent-login' =>
        'Votre session doit être confirmée à nouveau. Ressaisissez votre mot de passe actuel.',
      'user-token-expired' ||
      'invalid-user-token' ||
      'user-not-found' ||
      'user-mismatch' =>
        'Votre session a expiré. Reconnectez-vous pour continuer.',
      'network-request-failed' =>
        'Connexion indisponible. Réessayez lorsque le réseau est rétabli.',
      'too-many-requests' =>
        'Trop de tentatives. Réessayez dans quelques minutes.',
      'user-disabled' => 'Ce compte est désactivé.',
      'operation-not-allowed' =>
        'Ce compte ne permet pas cette opération avec un mot de passe. Utilisez votre mode de connexion habituel.',
      _ => 'Impossible de terminer cette opération. Réessayez.',
    };
  }

  /// Supprime définitivement le compte Firebase Auth. Si la session est
  /// trop ancienne, Firebase exige une reconnexion récente
  /// (FirebaseAuthException code `requires-recent-login`) : l'appelant
  /// doit alors inviter l'utilisateur à se reconnecter puis réessayer.
  Future<void> deleteAccount() async {
    await NotificationService().detachCurrentDevice(_auth.currentUser?.uid);
    await _auth.currentUser?.delete();
  }

  /// Traduit les erreurs Firebase Auth les plus courantes en messages
  /// compréhensibles pour un commerçant ou un client non technique.
  static String readableError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'weak-password':
        return 'Le mot de passe doit contenir au moins 6 caractères.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email ou mot de passe incorrect.';
      case 'too-many-requests':
        return 'Trop de tentatives, réessayez dans quelques minutes.';
      default:
        return 'Une erreur est survenue (${e.code}).';
    }
  }
}
