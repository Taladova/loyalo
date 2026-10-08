import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mémorise localement l'email, le prénom (côté client) et le mot de passe
/// saisis lors de la dernière connexion, pour pré-remplir le formulaire la
/// prochaine fois qu'un écran de connexion doit s'afficher (ex: après une
/// déconnexion explicite). N'a aucun lien avec la session Firebase
/// elle-même, qui est déjà conservée automatiquement par [AuthGateScreen].
///
/// Le mot de passe est stocké via [FlutterSecureStorage] (Keychain sur iOS,
/// Keystore/EncryptedSharedPreferences sur Android) plutôt qu'en clair dans
/// les préférences, contrairement au nom/email qui ne sont pas sensibles.
class RememberMeService {
  static const _clientEmailKey = 'remember_me_client_email';
  static const _clientNameKey = 'remember_me_client_name';
  static const _merchantEmailKey = 'remember_me_merchant_email';
  static const _clientPasswordKey = 'remember_me_client_password';
  static const _merchantPasswordKey = 'remember_me_merchant_password';

  final _secureStorage = const FlutterSecureStorage();

  Future<void> saveClient({
    required String name,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clientNameKey, name);
    await prefs.setString(_clientEmailKey, email);
    await _secureStorage.write(key: _clientPasswordKey, value: password);
  }

  Future<void> clearClient() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clientNameKey);
    await prefs.remove(_clientEmailKey);
    await _secureStorage.delete(key: _clientPasswordKey);
  }

  Future<(String name, String email, String password)> loadClient() async {
    final prefs = await SharedPreferences.getInstance();
    final password = await _secureStorage.read(key: _clientPasswordKey);
    return (
      prefs.getString(_clientNameKey) ?? '',
      prefs.getString(_clientEmailKey) ?? '',
      password ?? '',
    );
  }

  Future<void> saveMerchant({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_merchantEmailKey, email);
    await _secureStorage.write(key: _merchantPasswordKey, value: password);
  }

  Future<void> clearMerchant() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_merchantEmailKey);
    await _secureStorage.delete(key: _merchantPasswordKey);
  }

  Future<(String email, String password)> loadMerchant() async {
    final prefs = await SharedPreferences.getInstance();
    final password = await _secureStorage.read(key: _merchantPasswordKey);
    return (prefs.getString(_merchantEmailKey) ?? '', password ?? '');
  }
}
