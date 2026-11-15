import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/services/auth_service.dart';

import 'support/merchant_settings_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Le changement réauthentifie le même compte avant updatePassword',
    () async {
      final api = SettingsTestFirebaseAuth();
      final auth = AuthService(auth: api);
      await auth.changePassword(
        currentPassword: 'synthetic-current-17',
        newPassword: 'synthetic-new-17',
      );
      expect(api.events, ['reauthenticate', 'update-password']);
      expect(api.updates, 1);
      expect(api.currentUser!.uid, 'settings-merchant');
    },
  );

  test('Les espaces du mot de passe ne sont pas normalisés', () async {
    final api = SettingsTestFirebaseAuth();
    api.user!.expectedPassword = '  synthetic-current-17  ';
    await AuthService(auth: api).changePassword(
      currentPassword: '  synthetic-current-17  ',
      newPassword: '  synthetic-new-17  ',
    );
    expect(api.user!.expectedPassword, '  synthetic-new-17  ');
  });

  for (final code in [
    'wrong-password',
    'invalid-credential',
    'requires-recent-login',
    'network-request-failed',
    'too-many-requests',
  ]) {
    test(
      'Réauthentification $code : aucun changement de mot de passe',
      () async {
        final api = SettingsTestFirebaseAuth()
          ..reauthError = FirebaseAuthException(code: code);
        await expectLater(
          AuthService(auth: api).changePassword(
            currentPassword: 'synthetic-current-17',
            newPassword: 'synthetic-new-17',
          ),
          throwsA(isA<FirebaseAuthException>()),
        );
        expect(api.updates, 0);
        expect(api.events, ['reauthenticate']);
      },
    );
  }

  test('Un refus de politique de sécurité reste une erreur lisible', () async {
    final api = SettingsTestFirebaseAuth()
      ..updateError = FirebaseAuthException(code: 'weak-password');
    await expectLater(
      AuthService(auth: api).changePassword(
        currentPassword: 'synthetic-current-17',
        newPassword: 'synthetic-new-17',
      ),
      throwsA(isA<FirebaseAuthException>()),
    );
    expect(api.events, ['reauthenticate', 'update-password']);
    expect(api.updates, 0);
  });

  test(
    'Un changement de session pendant la réauthentification bloque updatePassword',
    () async {
      final api = SettingsTestFirebaseAuth()..changeSessionDuringReauth = true;
      await expectLater(
        AuthService(auth: api).changePassword(
          currentPassword: 'synthetic-current-17',
          newPassword: 'synthetic-new-17',
        ),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'user-mismatch',
          ),
        ),
      );
      expect(api.updates, 0);
    },
  );

  test(
    'Session absente, anonyme ou fournisseur externe : aucune opération sensible',
    () async {
      for (final kind in ['missing', 'anonymous', 'external']) {
        final api = SettingsTestFirebaseAuth();
        if (kind == 'missing') {
          api.user = null;
        }
        if (kind == 'anonymous') {
          api.user!.isAnonymous = true;
        }
        if (kind == 'external') {
          api.user!.provider = 'google.com';
        }
        final auth = AuthService(auth: api);
        expect(auth.supportsPasswordAuthentication, false);
        await expectLater(
          auth.reauthenticateWithPassword(password: 'synthetic-current-17'),
          throwsA(isA<FirebaseAuthException>()),
        );
        expect(api.events, isEmpty);
      }
    },
  );

  test('Les erreurs ne recopient ni message serveur ni donnée sensible', () {
    final message = AuthService.accountError(
      FirebaseAuthException(
        code: 'unexpected',
        message: 'synthetic-private-value',
      ),
    );
    expect(message, isNot(contains('synthetic-private-value')));
    expect(message, isNot(contains('unexpected')));
  });

  test(
    'Lecture des préférences et modification ciblée conservent les autres données',
    () async {
      final f = await MerchantSettingsFixture.create();
      try {
        final values = await f.repo.loadMerchantNotificationPreferences(
          MerchantSettingsFixture.uid,
        );
        expect(values, {'merchantCheckIns': false, 'important': true});
        await f.repo.updateNotificationPreference(
          userId: MerchantSettingsFixture.uid,
          key: 'merchantCheckIns',
          enabled: true,
        );
        final stored =
            (await f.db
                    .collection('users')
                    .doc(MerchantSettingsFixture.uid)
                    .get())
                .data()!;
        expect(stored['notificationPreferences'], {
          'merchantCheckIns': true,
          'important': true,
          'offers': false,
        });
        expect(stored['unchanged'], 'conserver');
        expect(stored['email'], 'firestore-email@example.org');
      } finally {
        await f.close();
      }
    },
  );

  test(
    'Une lecture sans profil utilise les défauts existants sans créer de client',
    () async {
      final f = await MerchantSettingsFixture.create(existingProfile: false);
      try {
        expect(
          await f.repo.loadMerchantNotificationPreferences(
            MerchantSettingsFixture.uid,
          ),
          {'merchantCheckIns': true, 'important': true},
        );
        expect((await f.db.collection('users').get()).docs, isEmpty);
        expect(
          (await f.db
                  .collection('merchants')
                  .doc(MerchantSettingsFixture.uid)
                  .get())
              .exists,
          true,
        );
      } finally {
        await f.close();
      }
    },
  );
}
