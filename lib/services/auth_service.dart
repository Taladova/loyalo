import 'package:firebase_auth/firebase_auth.dart';

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
  Future<User> signUpOrSignIn({required String email, required String password}) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
        return cred.user!;
      }
      rethrow;
    }
  }

  Future<User> signIn({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return cred.user!;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail({required String email}) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Supprime définitivement le compte Firebase Auth. Si la session est
  /// trop ancienne, Firebase exige une reconnexion récente
  /// (FirebaseAuthException code `requires-recent-login`) : l'appelant
  /// doit alors inviter l'utilisateur à se reconnecter puis réessayer.
  Future<void> deleteAccount() async {
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
