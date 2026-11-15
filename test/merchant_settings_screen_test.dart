import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:loyalo/providers/app_providers.dart';
import 'package:loyalo/screens/legal_screen.dart';
import 'package:loyalo/screens/merchant/merchant_password_screen.dart';
import 'package:loyalo/screens/merchant/merchant_settings_screen.dart';
import 'package:loyalo/screens/welcome_screen.dart';
import 'package:loyalo/widgets/loyalo_auth_ui.dart';
import 'package:loyalo/widgets/loyalo_logo.dart';
import 'package:loyalo/widgets/loyalo_settings_ui.dart';

import 'support/merchant_settings_fixture.dart';

final _installed = PackageInfo(
  appName: 'Loyalo Test',
  packageName: 'com.loyalo.test',
  version: '7.8.9',
  buildNumber: '321',
);
Finder keyed(String key) => find.byKey(ValueKey(key));
Finder get save => keyed('password-save');
Finder input(String key) => keyed('password-$key');

Future<void> reach(WidgetTester t, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump(const Duration(milliseconds: 300));
  await t.ensureVisible(target);
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> tap(WidgetTester t, Finder target) async {
  await reach(t, target);
  await t.tap(target);
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> flush(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await t.pumpAndSettle();
}

void ui(
  String name,
  Future<void> Function(WidgetTester, MerchantSettingsFixture) body, {
  FutureOr<void> Function(MerchantSettingsFixture)? prepare,
  bool profile = true,
  bool password = false,
  bool ready = true,
  bool merchant = true,
  Size size = const Size(390, 844),
  double scale = 1,
  Future<PackageInfo> Function()? versionLoader,
}) {
  testWidgets(name, (t) async {
    final f = (await t.runAsync(
      () => MerchantSettingsFixture.create(existingProfile: profile),
    ))!;
    await prepare?.call(f);
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    t.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    t.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(t.view.reset);
    try {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            loyaltyRepositoryProvider.overrideWith((ref) => f.repo),
            currentMerchantRestaurantIdProvider.overrideWith(
              (ref) => merchant ? MerchantSettingsFixture.shop : null,
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: password
                ? MerchantPasswordScreen(auth: f.auth)
                : MerchantSettingsScreen(
                    auth: f.auth,
                    versionLoader: versionLoader ?? () async => _installed,
                  ),
          ),
        ),
      );
      if (ready) {
        await flush(t);
      } else {
        await t.pump(const Duration(milliseconds: 100));
      }
      await body(t, f);
    } finally {
      for (final hold in [
        f.repo.heldRead,
        f.repo.heldWrite,
        f.api.heldReauth,
      ]) {
        if (hold != null && !hold.isCompleted) hold.complete();
      }
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await f.repo.stopListening();
      });
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
      await t.runAsync(() => f.close(disposeRepository: false));
    }
  });
}

Future<void> fill(
  WidgetTester t, {
  String current = 'synthetic-current-17',
  String next = 'synthetic-new-17',
  String? confirmation,
}) async {
  for (final entry in {
    'current': current,
    'new': next,
    'confirm': confirmation ?? next,
  }.entries) {
    await reach(t, input(entry.key));
    await t.enterText(input(entry.key), entry.value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ui(
    'Les quatre sections affichent Auth, version installée et préférences réelles',
    (t, f) async {
      for (final title in [
        'Compte et sécurité',
        'Notifications',
        'Aide et informations',
        'Gestion du compte',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('auth-merchant@example.org'), findsOneWidget);
      expect(find.text('firestore-email@example.org'), findsNothing);
      expect(find.byType(LoyaloWordmark), findsNothing);
      expect(find.byType(LoyaloDashboardMark), findsNothing);
      expect(find.text('Restaurant'), findsNothing);
      expect(find.text('Mon établissement'), findsNothing);
      expect(
        t.widget<LoyaloSettingsItem>(keyed('settings-email')).onTap,
        isNull,
      );
      expect(
        t.widget<LoyaloSettingsItem>(keyed('settings-version')).onTap,
        isNull,
      );
      expect(find.text('v7.8.9 (build 321)'), findsOneWidget);
      expect(
        t.widget<Switch>(keyed('settings-switch-merchantCheckIns')).value,
        false,
      );
      expect(t.widget<Switch>(keyed('settings-switch-important')).value, true);
      expect(f.repo.preferenceUsers, [MerchantSettingsFixture.uid]);
    },
  );

  ui(
    'Préférences : chargement sans faux interrupteurs, puis valeurs sauvegardées',
    (t, f) async {
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      f.repo.heldRead!.complete();
      await flush(t);
      expect(find.byType(Switch), findsNWidgets(2));
      expect(
        t.widget<Switch>(keyed('settings-switch-merchantCheckIns')).value,
        false,
      );
    },
    ready: false,
    prepare: (f) {
      f.repo.heldRead = Completer<void>();
    },
  );

  ui(
    'Préférences : erreur de lecture, aucune valeur inventée et nouvel essai',
    (t, f) async {
      expect(find.byType(Switch), findsNothing);
      expect(
        find.text('Impossible de charger vos préférences de notification.'),
        findsOneWidget,
      );
      f.repo.readError = null;
      await tap(t, keyed('settings-preferences-retry'));
      await flush(t);
      expect(
        t.widget<Switch>(keyed('settings-switch-merchantCheckIns')).value,
        false,
      );
      expect(f.repo.preferenceUsers.length, 2);
    },
    prepare: (f) {
      f.repo.readError = StateError('lecture refusée');
    },
  );

  ui(
    'Interrupteurs : écriture ciblée et valeurs conservées après réouverture',
    (t, f) async {
      await reach(t, keyed('settings-switch-merchantCheckIns'));
      await t.runAsync(() async {
        await t.tap(keyed('settings-switch-merchantCheckIns'));
        await f.waitFor(() => f.repo.completedWrites == 1);
      });
      await t.pumpAndSettle();
      expect(
        t.widget<Switch>(keyed('settings-switch-merchantCheckIns')).value,
        true,
      );
      final stored = await f.db
          .collection('users')
          .doc(MerchantSettingsFixture.uid)
          .get();
      expect(stored.data()!['notificationPreferences'], {
        'merchantCheckIns': true,
        'important': true,
        'offers': false,
      });
      expect(stored.data()!['unchanged'], 'conserver');
      expect(
        await f.repo.loadMerchantNotificationPreferences(
          MerchantSettingsFixture.uid,
        ),
        {'merchantCheckIns': true, 'important': true},
      );
      expect(f.repo.writes.single.uid, MerchantSettingsFixture.uid);
    },
  );

  ui(
    'Échec de sauvegarde : retour au réglage enregistré sans message technique',
    (t, f) async {
      f.repo.writeError = StateError('private-server-data');
      await tap(t, keyed('settings-switch-merchantCheckIns'));
      await flush(t);
      expect(
        t.widget<Switch>(keyed('settings-switch-merchantCheckIns')).value,
        false,
      );
      expect(
        find.textContaining('Votre réglage précédent est conservé'),
        findsOneWidget,
      );
      expect(find.textContaining('private-server-data'), findsNothing);
      expect(f.repo.writes.length, 1);
    },
  );

  ui('Commerçant sans profil client : refus visible sans création de profil', (
    t,
    f,
  ) async {
    f.repo.enforceMissingProfileRule = true;
    await tap(t, keyed('settings-switch-important'));
    await flush(t);
    expect(t.widget<Switch>(keyed('settings-switch-important')).value, true);
    expect(find.textContaining('Impossible d’enregistrer'), findsOneWidget);
    expect((await f.db.collection('users').get()).docs, isEmpty);
  }, profile: false);

  ui('Écriture en cours : double soumission et déconnexion bloquées', (
    t,
    f,
  ) async {
    f.repo.heldWrite = Completer<void>();
    await tap(t, keyed('settings-switch-important'));
    expect(find.text('Enregistrement…'), findsOneWidget);
    expect(keyed('settings-switch-important'), findsNothing);
    await tap(t, keyed('settings-logout'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(f.repo.writes.length, 1);
    f.repo.heldWrite!.complete();
    await flush(t);
    expect(t.widget<Switch>(keyed('settings-switch-important')).value, false);
  });

  var versionAttempts = 0;
  ui(
    'Version indisponible puis relue depuis le fournisseur système',
    (t, f) async {
      expect(find.text('Indisponible'), findsOneWidget);
      await tap(t, find.byTooltip('Réessayer la lecture de la version'));
      await flush(t);
      expect(find.text('v7.8.9 (build 321)'), findsOneWidget);
    },
    versionLoader: () async {
      versionAttempts++;
      if (versionAttempts == 1) throw StateError('platform failure');
      return _installed;
    },
  );

  for (final kind in ['privacy', 'terms']) {
    ui('Navigation légale existante : $kind', (t, f) async {
      await tap(t, keyed('settings-$kind'));
      await t.pumpAndSettle();
      expect(find.byType(LegalScreen), findsOneWidget);
      await t.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await t.pumpAndSettle();
      expect(find.byType(MerchantSettingsScreen), findsOneWidget);
    });
  }
  ui(
    'Support présente le contact existant et le mot de passe ouvre son formulaire',
    (t, f) async {
      await tap(t, keyed('settings-support'));
      expect(find.textContaining('contact@taladova.com'), findsOneWidget);
      await tap(t, find.text('Fermer'));
      await tap(t, keyed('settings-password'));
      await t.pumpAndSettle();
      expect(find.byType(MerchantPasswordScreen), findsOneWidget);
      await tap(t, find.byType(LoyaloAuthBackButton));
      expect(find.byType(MerchantSettingsScreen), findsOneWidget);
    },
  );

  ui(
    'Session commerçant absente : aucun accès sensible ni lecture de préférences',
    (t, f) async {
      expect(f.repo.preferenceUsers, isEmpty);
      await tap(t, keyed('settings-delete'));
      expect(find.byType(AlertDialog), findsNothing);
      await tap(t, keyed('settings-logout'));
      expect(f.auth.logouts, 0);
      expect(find.byType(Switch), findsNothing);
    },
    merchant: false,
  );

  ui(
    'Déconnexion : confirmation annulée puis mécanisme existant et retour accueil public',
    (t, f) async {
      await tap(t, keyed('settings-logout'));
      expect(f.auth.logouts, 0);
      await tap(t, find.text('Annuler'));
      expect(f.auth.logouts, 0);
      await tap(t, keyed('settings-logout'));
      await tap(t, find.widgetWithText(TextButton, 'Se déconnecter'));
      await flush(t);
      expect(f.auth.logouts, 1);
      expect(f.api.events.take(2), ['stop-listening', 'sign-out']);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    },
  );

  ui('Déconnexion en erreur : session conservée et erreur visible', (
    t,
    f,
  ) async {
    f.auth.logoutError = StateError('offline');
    await tap(t, keyed('settings-logout'));
    await tap(t, find.widgetWithText(TextButton, 'Se déconnecter'));
    await flush(t);
    expect(find.text('Déconnexion impossible. Réessayez.'), findsOneWidget);
    expect(find.byType(MerchantSettingsScreen), findsOneWidget);
    expect(f.api.currentUser, isNotNull);
  });

  ui(
    'Suppression : liste et annulation ne suppriment rien ; mauvais mot de passe sans unlink',
    (t, f) async {
      await tap(t, keyed('settings-delete'));
      expect(f.repo.unlinks, 0);
      expect(f.auth.deletions, 0);
      await tap(t, find.text('Annuler'));
      await tap(t, keyed('settings-delete'));
      await tap(t, keyed('settings-delete-confirm'));
      expect(
        find.text('Renseignez votre mot de passe actuel.'),
        findsOneWidget,
      );
      await t.enterText(keyed('settings-delete-password'), 'incorrect');
      await tap(t, keyed('settings-delete-confirm'));
      await flush(t);
      expect(
        find.text('Le mot de passe actuel est incorrect.'),
        findsOneWidget,
      );
      expect(f.repo.unlinks, 0);
      expect(f.auth.deletions, 0);
    },
  );

  ui(
    'Suppression confirmée : réauthentification avant parcours existant et commerce préservé',
    (t, f) async {
      await tap(t, keyed('settings-delete'));
      await t.enterText(
        keyed('settings-delete-password'),
        'synthetic-current-17',
      );
      await reach(t, keyed('settings-delete-confirm'));
      await t.runAsync(() async {
        await t.tap(keyed('settings-delete-confirm'));
        await f.waitFor(() => f.auth.deletions == 1);
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await t.pumpAndSettle();
      expect(f.api.events.take(4), [
        'reauthenticate',
        'unlink-merchant',
        'delete-auth',
        'stop-listening',
      ]);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(
        (await f.db
                .collection('restaurants')
                .doc(MerchantSettingsFixture.shop)
                .get())
            .exists,
        true,
      );
      expect(
        (await f.db
                .collection('merchants')
                .doc(MerchantSettingsFixture.uid)
                .get())
            .exists,
        false,
      );
    },
  );

  ui('Suppression en erreur : aucun faux succès, mot de passe effacé', (
    t,
    f,
  ) async {
    f.repo.unlinkError = StateError('network');
    await tap(t, keyed('settings-delete'));
    await t.enterText(
      keyed('settings-delete-password'),
      'synthetic-current-17',
    );
    await tap(t, keyed('settings-delete-confirm'));
    await flush(t);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(LoyaloAuthError), findsOneWidget);
    expect(
      t
          .widget<TextFormField>(keyed('settings-delete-password'))
          .controller!
          .text,
      isEmpty,
    );
    expect(f.auth.deletions, 0);
  });

  ui('Formulaire de mot de passe : validations locales sans appel Auth', (
    t,
    f,
  ) async {
    await tap(t, save);
    expect(find.text('Renseignez votre mot de passe actuel.'), findsOneWidget);
    expect(f.api.events, isEmpty);
    await fill(t, next: '123', confirmation: 'different');
    await tap(t, save);
    expect(find.text('Utilisez au moins 6 caractères.'), findsOneWidget);
    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
    expect(f.api.updates, 0);
  }, password: true);

  ui('Mot de passe actuel incorrect : aucun changement et message visible', (
    t,
    f,
  ) async {
    await fill(t, current: 'incorrect');
    await tap(t, save);
    await t.pumpAndSettle();
    expect(find.text('Le mot de passe actuel est incorrect.'), findsOneWidget);
    expect(t.widget<TextFormField>(input('current')).controller!.text, isEmpty);
    expect(f.api.updates, 0);
    expect(
      t.getRect(find.byType(LoyaloAuthError)).top,
      greaterThanOrEqualTo(0),
    );
  }, password: true);

  ui(
    'Mot de passe : succès réel du service, champs effacés et aucune écriture Firestore',
    (t, f) async {
      final before = f.db.dump();
      await fill(t);
      await tap(t, save);
      await t.pumpAndSettle();
      expect(find.text('Votre mot de passe a été modifié.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(f.api.events, ['reauthenticate', 'update-password']);
      expect(f.api.updates, 1);
      expect(f.db.dump(), before);
    },
    password: true,
  );

  for (final code in [
    'network-request-failed',
    'requires-recent-login',
    'weak-password',
  ]) {
    ui('Formulaire de mot de passe : erreur Auth $code sans faux succès', (
      t,
      f,
    ) async {
      f.api.updateError = FirebaseAuthException(
        code: code,
        message: 'private-server-data',
      );
      await fill(t);
      await tap(t, save);
      await t.pumpAndSettle();
      expect(find.byType(LoyaloAuthError), findsOneWidget);
      expect(find.text('Votre mot de passe a été modifié.'), findsNothing);
      expect(find.textContaining('private-server-data'), findsNothing);
      expect(f.api.updates, 0);
    }, password: true);
  }

  ui('Mot de passe en cours : double soumission bloquée et retour désactivé', (
    t,
    f,
  ) async {
    f.api.heldReauth = Completer<void>();
    await fill(t);
    await tap(t, save);
    expect(t.widget<LoyaloAuthPrimaryButton>(save).onPressed, isNull);
    expect(
      t
          .widget<LoyaloAuthBackButton>(find.byType(LoyaloAuthBackButton))
          .onPressed,
      isNull,
    );
    expect(f.api.events, ['reauthenticate']);
    f.api.heldReauth!.complete();
    await t.pumpAndSettle();
    expect(f.api.updates, 1);
  }, password: true);

  for (final kind in ['missing', 'external']) {
    ui(
      'Mot de passe indisponible pour compte $kind',
      (t, f) async {
        expect(find.byType(TextFormField), findsNothing);
        expect(save, findsNothing);
        expect(f.api.events, isEmpty);
      },
      password: true,
      prepare: (f) {
        if (kind == 'missing') {
          f.api.user = null;
        } else {
          f.api.user!.provider = 'google.com';
        }
      },
    );
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 2.0]) {
      ui(
        'Paramètres responsive $size texte ×$scale sans troncature',
        (t, f) async {
          await reach(t, keyed('settings-delete'));
          expect(t.takeException(), isNull);
          for (final e in find.byType(RichText).evaluate()) {
            final render = e.renderObject;
            if (render is RenderParagraph) {
              expect(render.didExceedMaxLines, false);
            }
          }
          await tap(t, keyed('settings-delete'));
          expect(t.takeException(), isNull);
          await tap(t, find.text('Annuler'));
        },
        size: size,
        scale: scale,
      );
    }
  }
  ui(
    'Mot de passe à 320 dp, texte ×2 et clavier ouvert : formulaire défilable',
    (t, f) async {
      t.view.viewInsets = const FakeViewPadding(bottom: 260);
      await t.pump();
      await fill(t);
      await tap(t, save);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Votre mot de passe a été modifié.'), findsOneWidget);
    },
    password: true,
    size: const Size(320, 568),
    scale: 2,
  );
}
