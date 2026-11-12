import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loyalo/screens/auth/client_login_screen.dart';
import 'package:loyalo/screens/auth/client_signup_screen.dart';
import 'package:loyalo/widgets/loyalo_ui.dart';

class _FakeFirebaseCore extends FirebasePlatform {
  final _app = FirebaseAppPlatform(
    defaultFirebaseAppName,
    const FirebaseOptions(
      apiKey: 'test',
      appId: 'test',
      messagingSenderId: 'test',
      projectId: 'test',
    ),
  );

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) => _app;
}

class _FakeFirebaseAuth extends FirebaseAuthPlatform {
  Completer<UserCredentialPlatform>? response;
  String? email;
  String? password;
  String? resetEmail;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  Future<UserCredentialPlatform> signInWithEmailAndPassword(
    String email,
    String password,
  ) {
    this.email = email;
    this.password = password;
    return response!.future;
  }

  @override
  Future<void> sendPasswordResetEmail(
    String email, [
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    resetEmail = email;
  }

  void reset() {
    response = null;
    email = null;
    password = null;
    resetEmail = null;
  }
}

final _auth = _FakeFirebaseAuth();

Future<void> _pumpLogin(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ClientLoginScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _field(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(TextFormField),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FirebasePlatform.instance = _FakeFirebaseCore();
    FirebaseAuthPlatform.instance = _auth;
  });

  setUp(() {
    _auth.reset();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Affiche le formulaire et charge la nouvelle illustration', (
    tester,
  ) async {
    await _pumpLogin(tester);

    for (final text in [
      'Connexion client',
      'Se souvenir de moi',
      'Mot de passe oublié ?',
      'Se connecter',
      'Créer un compte',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(_field('client-login-email'), findsOneWidget);
    expect(_field('client-login-password'), findsOneWidget);
    final emailInput = tester.widget<TextField>(
      find.descendant(
        of: _field('client-login-email'),
        matching: find.byType(TextField),
      ),
    );
    final passwordInput = tester.widget<TextField>(
      find.descendant(
        of: _field('client-login-password'),
        matching: find.byType(TextField),
      ),
    );
    expect(emailInput.autofillHints, contains(AutofillHints.email));
    expect(passwordInput.autofillHints, contains(AutofillHints.password));
    final images = tester.widgetList<Image>(find.byType(Image)).map((image) {
      final provider = image.image;
      final source = provider is ResizeImage
          ? provider.imageProvider
          : provider;
      return source is AssetImage ? source.assetName : null;
    });
    expect(images, contains('assets/images/login/client_login_hero.png'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Les deux actions sont visibles sans défiler sur iPhone standard',
    (tester) async {
      await _pumpLogin(tester);
      final essential = [
        find.byIcon(Icons.arrow_back_ios_new_rounded),
        ...tester.widgetList<Image>(find.byType(Image)).map(find.byWidget),
        find.text('Connexion client'),
        find.text(
          'Accédez à votre compte Loyalo et profitez de vos avantages.',
        ),
        _field('client-login-email'),
        _field('client-login-password'),
        find.text('Se souvenir de moi'),
        find.text('Mot de passe oublié ?'),
        find.byType(LoyaloGradientButton),
        find.text('ou'),
        find.byType(OutlinedButton),
      ];
      for (final item in essential) {
        final rect = tester.getRect(item);
        expect(rect.top, greaterThanOrEqualTo(47), reason: item.toString());
        expect(
          rect.bottom,
          lessThanOrEqualTo(844 - 34),
          reason: item.toString(),
        );
      }
      final scroll = Scrollable.of(tester.element(find.byType(Form)));
      expect(scroll.position.pixels, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Valide les champs vides et les emails invalides', (
    tester,
  ) async {
    await _pumpLogin(tester);
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Renseignez votre adresse email.'), findsOneWidget);
    expect(find.text('Renseignez votre mot de passe.'), findsOneWidget);
    expect(_auth.email, isNull);

    await tester.enterText(_field('client-login-email'), 'adresse-invalide');
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Saisissez une adresse email valide.'), findsOneWidget);
    expect(_auth.email, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bascule la visibilité du mot de passe', (tester) async {
    await _pumpLogin(tester);
    final password = find.descendant(
      of: _field('client-login-password'),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(password).obscureText, isTrue);
    await tester.tap(find.byTooltip('Afficher le mot de passe'));
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(password).obscureText, isFalse);
    await tester.tap(find.byTooltip('Masquer le mot de passe'));
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(password).obscureText, isTrue);
  });

  testWidgets('Conserve des zones tactiles accessibles', (tester) async {
    await _pumpLogin(tester);
    final back = find.ancestor(
      of: find.byIcon(Icons.arrow_back_ios_new_rounded),
      matching: find.byType(InkWell),
    );
    for (final target in [
      back,
      find.byType(Checkbox),
      find.byTooltip('Afficher le mot de passe'),
      find.widgetWithText(TextButton, 'Mot de passe oublié ?'),
      find.byType(LoyaloGradientButton),
      find.byType(OutlinedButton),
    ]) {
      final size = tester.getSize(target);
      expect(size.width, greaterThanOrEqualTo(48), reason: target.toString());
      expect(size.height, greaterThanOrEqualTo(48), reason: target.toString());
    }
  });

  testWidgets('Conserve la case et le parcours de mot de passe oublié', (
    tester,
  ) async {
    await _pumpLogin(tester);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    await tester.tap(find.text('Se souvenir de moi'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();
    expect(
      find.text('Renseignez votre email ci-dessus puis réessayez.'),
      findsOneWidget,
    );
    expect(_auth.resetEmail, isNull);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('client-login-email'), 'client@example.org');
    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();
    expect(_auth.resetEmail, 'client@example.org');
    expect(find.text('Email envoyé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Aligne les options quand leur largeur le permet', (
    tester,
  ) async {
    await _pumpLogin(tester, size: const Size(800, 844), textScale: 0.8);
    final remember = tester.getRect(find.text('Se souvenir de moi'));
    final forgot = tester.getRect(find.text('Mot de passe oublié ?'));
    expect((remember.center.dy - forgot.center.dy).abs(), lessThan(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empile les options avec un texte agrandi sur petit écran', (
    tester,
  ) async {
    await _pumpLogin(tester, size: const Size(320, 568), textScale: 2.5);
    final remember = tester.getRect(find.text('Se souvenir de moi'));
    final forgot = tester.getRect(find.text('Mot de passe oublié ?'));
    expect(forgot.top, greaterThanOrEqualTo(remember.bottom));
    for (final label in [
      'Se souvenir de moi',
      'Mot de passe oublié ?',
      'Se connecter',
      'Créer un compte',
    ]) {
      final finder = find.text(label);
      final text = tester.widget<Text>(finder);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(
        tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
        isFalse,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Conserve le chargement et affiche une erreur authentifiée simulée',
    (tester) async {
      _auth.response = Completer<UserCredentialPlatform>();
      await _pumpLogin(tester);
      await tester.enterText(
        _field('client-login-email'),
        'client@example.org',
      );
      await tester.enterText(_field('client-login-password'), 'secret123');
      await tester.ensureVisible(find.text('Se connecter'));
      await tester.tap(find.text('Se connecter'));
      await tester.pump();

      expect(_auth.email, 'client@example.org');
      expect(_auth.password, 'secret123');
      final button = tester.widget<LoyaloGradientButton>(
        find.byType(LoyaloGradientButton),
      );
      expect(button.loading, isTrue);
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      _auth.response!.completeError(
        FirebaseAuthException(code: 'wrong-password'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Email ou mot de passe incorrect.'), findsOneWidget);
      expect(
        tester
            .widget<LoyaloGradientButton>(find.byType(LoyaloGradientButton))
            .loading,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Le lien de création ouvre le formulaire client', (tester) async {
    await _pumpLogin(tester);
    await tester.ensureVisible(find.text('Créer un compte'));
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();
    expect(find.byType(ClientSignupScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Le bouton retour revient à l’écran précédent', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ClientLoginScreen(),
                  ),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byType(ClientLoginScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Le clavier laisse le formulaire et la connexion accessibles', (
    tester,
  ) async {
    await _pumpLogin(tester);
    await tester.tap(_field('client-login-email'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.view.padding = const FakeViewPadding(top: 47);
    await tester.pumpAndSettle();

    await tester.ensureVisible(_field('client-login-email'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(_field('client-login-email')).center.dy,
      lessThan(544),
    );
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Se connecter')).center.dy, lessThan(544));
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(320, 568), scale: 1.0, platform: TargetPlatform.iOS),
    (size: const Size(390, 844), scale: 2.5, platform: TargetPlatform.iOS),
    (size: const Size(430, 932), scale: 1.0, platform: TargetPlatform.iOS),
    (size: const Size(360, 640), scale: 1.0, platform: TargetPlatform.android),
    (size: const Size(412, 915), scale: 1.0, platform: TargetPlatform.android),
  ]) {
    testWidgets(
      'Reste accessible : ${scenario.size}, texte ${scenario.scale}',
      (tester) async {
        await _pumpLogin(
          tester,
          size: scenario.size,
          textScale: scenario.scale,
          platform: scenario.platform,
        );
        for (final text in ['Se connecter', 'Créer un compte']) {
          await tester.ensureVisible(find.text(text));
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.text(text)).center.dy,
            inInclusiveRange(47, scenario.size.height - 34),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
