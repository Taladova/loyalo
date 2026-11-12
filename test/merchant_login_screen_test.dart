import 'dart:async';

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/providers/app_providers.dart';
import 'package:loyalo/screens/merchant/merchant_establishment_screen.dart';
import 'package:loyalo/screens/merchant/merchant_login_screen.dart';
import 'package:loyalo/screens/merchant/merchant_root_screen.dart';
import 'package:loyalo/screens/merchant/merchant_signup_screen.dart';
import 'package:loyalo/services/loyalty_repository.dart';
import 'package:loyalo/widgets/loyalo_auth_ui.dart';
import 'package:loyalo/widgets/loyalo_ui.dart';

class _FakeCore extends FirebasePlatform {
  final value = FirebaseAppPlatform(
    defaultFirebaseAppName,
    const FirebaseOptions(
      apiKey: 'test',
      appId: 'test',
      messagingSenderId: 'test',
      projectId: 'test',
    ),
  );

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) => value;
}

class _FakeAuth extends FirebaseAuthPlatform {
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
    ActionCodeSettings? settings,
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

class _FakeMultiFactor extends MultiFactorPlatform {
  _FakeMultiFactor(super.auth);
}

class _FakeUser extends UserPlatform {
  _FakeUser(FirebaseAuthPlatform auth, String uid)
    : super(
        auth,
        _FakeMultiFactor(auth),
        PigeonUserDetails(
          userInfo: PigeonUserInfo(
            uid: uid,
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: [],
        ),
      );
}

class _FakeCredential extends UserCredentialPlatform {
  _FakeCredential(FirebaseAuthPlatform auth, String uid)
    : super(auth: auth, user: _FakeUser(auth, uid));
}

class _RecordingRepository extends LoyaltyRepository {
  _RecordingRepository({
    required FakeFirebaseFirestore firestore,
    required AppDatabase database,
  }) : super(firestore: firestore, database: database);

  final operations = <String>[];

  @override
  Future<String?> restaurantIdForMerchant(String uid) async {
    operations.add('lookup:$uid');
    return super.restaurantIdForMerchant(uid);
  }

  @override
  Future<void> stopListening() async {
    operations.add('stop');
    await super.stopListening();
  }

  @override
  void startListeningForMerchant(String restaurantId, {String? ownerUid}) {
    operations.add('listen:$restaurantId:$ownerUid');
  }
}

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? replacement;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacement = newRoute;
  }
}

final _auth = _FakeAuth();
const _description =
    'Accédez à votre espace professionnel Loyalo et fidélisez vos clients.';

Finder _field(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(TextFormField),
);

Future<ProviderContainer> _pumpMerchant(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
  LoyaltyRepository? repository,
  NavigatorObserver? observer,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (repository != null)
          loyaltyRepositoryProvider.overrideWith((ref) => repository),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        navigatorObservers: [?observer],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const MerchantLoginScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(MerchantLoginScreen)),
    listen: false,
  );
}

Future<void> _submit(WidgetTester tester) async {
  await tester.enterText(
    _field('merchant-login-email'),
    'merchant@example.org',
  );
  await tester.enterText(_field('merchant-login-password'), 'test-password');
  await tester.ensureVisible(find.text('Se connecter'));
  await tester.tap(find.text('Se connecter'));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    FirebasePlatform.instance = _FakeCore();
    FirebaseAuthPlatform.instance = _auth;
  });
  setUp(() {
    _auth.reset();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_analytics'),
          (call) async => null,
        );
  });

  testWidgets('Formulaire entier visible sans défiler sur iPhone standard', (
    tester,
  ) async {
    await _pumpMerchant(tester);
    expect(find.byType(LoyaloAuthHeader), findsOneWidget);
    expect(find.byType(LoyaloAuthCard), findsOneWidget);
    expect(find.byType(LoyaloAuthTextField), findsNWidgets(2));
    expect(find.byIcon(Icons.add_business_outlined), findsOneWidget);
    for (final finder in [
      find.byIcon(Icons.arrow_back_ios_new_rounded),
      ...tester.widgetList<Image>(find.byType(Image)).map(find.byWidget),
      find.text('Connexion commerçant'),
      find.text(_description),
      _field('merchant-login-email'),
      _field('merchant-login-password'),
      find.text('Se souvenir de moi'),
      find.text('Mot de passe oublié ?'),
      find.byType(LoyaloGradientButton),
      find.text('ou'),
      find.byType(OutlinedButton),
    ]) {
      final rect = tester.getRect(finder);
      expect(rect.top, greaterThanOrEqualTo(47), reason: finder.toString());
      expect(rect.bottom, lessThanOrEqualTo(810), reason: finder.toString());
    }
    expect(Scrollable.of(tester.element(find.byType(Form))).position.pixels, 0);
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      final provider = image.image;
      final asset = provider is ResizeImage ? provider.imageProvider : provider;
      expect(asset, isA<AssetImage>());
      expect(image.fit, BoxFit.contain);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Valide les champs vides et les emails invalides avant authentification',
    (tester) async {
      await _pumpMerchant(tester);
      await tester.ensureVisible(find.text('Se connecter'));
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      expect(find.text('Renseignez votre adresse email.'), findsOneWidget);
      expect(find.text('Renseignez votre mot de passe.'), findsOneWidget);
      await tester.enterText(_field('merchant-login-email'), 'email-invalide');
      await tester.ensureVisible(find.text('Se connecter'));
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      expect(find.text('Saisissez une adresse email valide.'), findsOneWidget);
      expect(_auth.email, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Conserve autofill, visibilité du mot de passe et options', (
    tester,
  ) async {
    await _pumpMerchant(tester);
    final inputs = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(inputs.first.autofillHints, contains(AutofillHints.email));
    expect(inputs.last.autofillHints, contains(AutofillHints.password));
    expect(inputs.last.obscureText, isTrue);
    await tester.tap(find.byTooltip('Afficher le mot de passe'));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<TextField>(find.byType(TextField)).last.obscureText,
      isFalse,
    );
    await tester.tap(find.byTooltip('Masquer le mot de passe'));
    await tester.tap(find.text('Se souvenir de moi'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Renseignez votre email professionnel ci-dessus puis réessayez.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(
      _field('merchant-login-email'),
      'merchant@example.org',
    );
    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();
    expect(_auth.resetEmail, 'merchant@example.org');
    expect(find.text('Email envoyé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chargement, désactivation et erreur Firebase simulée', (
    tester,
  ) async {
    _auth.response = Completer<UserCredentialPlatform>();
    await _pumpMerchant(tester);
    await _submit(tester);
    final button = tester.widget<LoyaloGradientButton>(
      find.byType(LoyaloGradientButton),
    );
    expect(button.loading, isTrue);
    expect(button.onPressed, isNull);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
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
  });

  testWidgets('La création de compte ouvre l’inscription commerçant', (
    tester,
  ) async {
    await _pumpMerchant(tester);
    await tester.ensureVisible(find.text('Créer un compte'));
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();
    expect(find.byType(MerchantSignupScreen), findsOneWidget);
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
                    builder: (_) => const MerchantLoginScreen(),
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
    expect(find.byType(MerchantLoginScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Préremplit uniquement les identifiants commerçant mémorisés', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'remember_me_merchant_email': 'saved-merchant@example.org',
      'remember_me_client_email': 'saved-client@example.org',
    });
    FlutterSecureStorage.setMockInitialValues({
      'remember_me_merchant_password': 'merchant-password',
      'remember_me_client_password': 'client-password',
    });
    await _pumpMerchant(tester);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.first.controller!.text, 'saved-merchant@example.org');
    expect(fields.last.controller!.text, 'merchant-password');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Clavier ouvert : champ actif et connexion accessibles', (
    tester,
  ) async {
    await _pumpMerchant(tester);
    await tester.tap(_field('merchant-login-email'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.view.padding = const FakeViewPadding(top: 47);
    await tester.pumpAndSettle();
    for (final finder in [
      _field('merchant-login-email'),
      find.text('Se connecter'),
    ]) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(tester.getRect(finder).center.dy, inInclusiveRange(47, 544));
    }
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(320, 568), scale: 1.0, platform: TargetPlatform.iOS),
    (size: const Size(320, 568), scale: 2.5, platform: TargetPlatform.iOS),
    (size: const Size(430, 932), scale: 1.0, platform: TargetPlatform.iOS),
    (size: const Size(360, 640), scale: 1.0, platform: TargetPlatform.android),
    (size: const Size(412, 915), scale: 1.0, platform: TargetPlatform.android),
  ]) {
    testWidgets('Responsive ${scenario.size}, texte ${scenario.scale}', (
      tester,
    ) async {
      await _pumpMerchant(
        tester,
        size: scenario.size,
        textScale: scenario.scale,
        platform: scenario.platform,
      );
      for (final label in [
        'Se connecter',
        'Créer un compte',
        'Se souvenir de moi',
        'Mot de passe oublié ?',
      ]) {
        final finder = find.text(label);
        expect(
          tester.widget<Text>(finder).overflow,
          isNot(TextOverflow.ellipsis),
        );
        expect(
          tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
          isFalse,
        );
      }
      for (final label in ['Se connecter', 'Créer un compte']) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text(label)).center.dy,
          inInclusiveRange(47, scenario.size.height - 34),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in [
    (linked: true, remember: true),
    (linked: true, remember: false),
    (linked: false, remember: true),
  ]) {
    testWidgets(
      'Parcours conservé : établissement lié=${scenario.linked}, mémorisation=${scenario.remember}',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = _RecordingRepository(
          firestore: firestore,
          database: database,
        );
        addTearDown(() async {
          await repo.stopListening();
          await database.close();
        });
        await firestore.collection('merchants').doc('other-owner').set({
          'restaurantId': 'other-restaurant',
        });
        if (scenario.linked) {
          await firestore.collection('merchants').doc('merchant-uid').set({
            'restaurantId': 'merchant-restaurant',
          });
        }
        _auth.response = Completer<UserCredentialPlatform>();
        final observer = _RouteObserver();
        if (!scenario.remember) {
          SharedPreferences.setMockInitialValues({
            'remember_me_merchant_email': 'previous@example.org',
          });
          FlutterSecureStorage.setMockInitialValues({
            'remember_me_merchant_password': 'previous-password',
          });
        }
        final container = await _pumpMerchant(
          tester,
          repository: repo,
          observer: observer,
        );
        if (!scenario.remember) {
          await tester.tap(find.text('Se souvenir de moi'));
          await tester.pump();
        }
        await _submit(tester);
        _auth.response!.complete(_FakeCredential(_auth, 'merchant-uid'));
        await tester.idle();
        final route = observer.replacement as MaterialPageRoute<dynamic>?;
        expect(route, isNotNull);
        final destination = route!.builder(
          tester.element(find.byType(MerchantLoginScreen)),
        );
        if (scenario.linked) {
          expect(destination, isA<MerchantRootScreen>());
          expect(repo.operations, [
            'lookup:merchant-uid',
            'stop',
            'listen:merchant-restaurant:merchant-uid',
          ]);
          expect(
            container.read(currentMerchantRestaurantIdProvider),
            'merchant-restaurant',
          );
          final prefs = await SharedPreferences.getInstance();
          final password = await const FlutterSecureStorage().read(
            key: 'remember_me_merchant_password',
          );
          expect(
            prefs.getString('remember_me_merchant_email'),
            scenario.remember ? 'merchant@example.org' : isNull,
          );
          expect(password, scenario.remember ? 'test-password' : isNull);
        } else {
          expect(destination, isA<MerchantEstablishmentScreen>());
          expect(
            (destination as MerchantEstablishmentScreen).requireSetup,
            isTrue,
          );
          expect(repo.operations, ['lookup:merchant-uid']);
          expect(container.read(currentMerchantRestaurantIdProvider), isNull);
        }
        expect(_auth.email, 'merchant@example.org');
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
