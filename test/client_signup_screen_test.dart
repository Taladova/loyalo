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
import 'package:loyalo/screens/auth/client_signup_screen.dart';
import 'package:loyalo/screens/client/client_root_screen.dart';
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
  bool existingAccount = false;
  final operations = <String>[];
  String? email;
  String? password;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  Future<UserCredentialPlatform> createUserWithEmailAndPassword(
    String email,
    String password,
  ) {
    operations.add('create');
    this.email = email;
    this.password = password;
    if (existingAccount) {
      return Future.error(FirebaseAuthException(code: 'email-already-in-use'));
    }
    return response!.future;
  }

  @override
  Future<UserCredentialPlatform> signInWithEmailAndPassword(
    String email,
    String password,
  ) {
    operations.add('signIn');
    this.email = email;
    this.password = password;
    return response!.future;
  }

  void reset() {
    response = null;
    existingAccount = false;
    operations.clear();
    email = null;
    password = null;
  }
}

class _FakeMultiFactor extends MultiFactorPlatform {
  _FakeMultiFactor(super.auth);
}

class _FakeUser extends UserPlatform {
  _FakeUser(FirebaseAuthPlatform auth)
    : super(
        auth,
        _FakeMultiFactor(auth),
        PigeonUserDetails(
          userInfo: PigeonUserInfo(
            uid: 'client-uid',
            isAnonymous: false,
            isEmailVerified: false,
          ),
          providerData: [],
        ),
      );
}

class _FakeCredential extends UserCredentialPlatform {
  _FakeCredential(FirebaseAuthPlatform auth)
    : super(auth: auth, user: _FakeUser(auth));
}

class _RecordingRepository extends LoyaltyRepository {
  _RecordingRepository({
    required FakeFirebaseFirestore firestore,
    required AppDatabase database,
  }) : super(firestore: firestore, database: database);

  final listenedClients = <String>[];

  @override
  void startListeningForClient(String userId) => listenedClients.add(userId);
}

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? replacement;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      replacement = newRoute;
}

final _auth = _FakeAuth();
const _title = 'Créer un compte client';
const _description =
    'Créez votre compte et profitez de tous les avantages Loyalo.';
const _security = 'Vos données sont protégées de façon sécurisée.';

Finder _field(String name) => find.descendant(
  of: find.byKey(Key('client-signup-$name')),
  matching: find.byType(TextFormField),
);

Future<ProviderContainer> _pumpSignup(
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
        home: const ClientSignupScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(ClientSignupScreen)),
    listen: false,
  );
}

Future<void> _fill(
  WidgetTester tester, {
  String email = 'client@example.org',
  String password = 'test-password',
}) async {
  await tester.enterText(_field('name'), '  Camille  ');
  await tester.enterText(_field('email'), email);
  await tester.enterText(_field('password'), password);
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Créer mon compte'));
  await tester.tap(find.text('Créer mon compte'));
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

  testWidgets('Inscription entière visible sans défiler sur iPhone standard', (
    tester,
  ) async {
    await _pumpSignup(tester);
    expect(find.byType(LoyaloAuthHeader), findsOneWidget);
    expect(find.byType(LoyaloAuthSurface), findsOneWidget);
    expect(find.byType(LoyaloAuthTextField), findsNWidgets(3));
    for (final finder in [
      find.byIcon(Icons.arrow_back_ios_new_rounded),
      ...tester.widgetList<Image>(find.byType(Image)).map(find.byWidget),
      find.text(_title),
      find.text(_description),
      _field('name'),
      _field('email'),
      _field('password'),
      find.text('J’ai un code parrain'),
      find.byType(LoyaloGradientButton),
      find.text(_security),
    ]) {
      final rect = tester.getRect(finder);
      expect(rect.top, greaterThanOrEqualTo(47), reason: finder.toString());
      expect(rect.bottom, lessThanOrEqualTo(810), reason: finder.toString());
    }
    expect(Scrollable.of(tester.element(find.byType(Form))).position.pixels, 0);
    for (final finder in [
      find.byType(LoyaloGradientButton),
      find.byTooltip('Afficher le mot de passe'),
      find.widgetWithText(TextButton, 'J’ai un code parrain'),
    ]) {
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(find.textContaining('Votre compte est créé'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Les trois champs requis bloquent une inscription vide', (
    tester,
  ) async {
    await _pumpSignup(tester);
    await _tapSubmit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Renseignez votre prénom.'), findsOneWidget);
    expect(find.text('Renseignez votre adresse email.'), findsOneWidget);
    expect(find.text('Renseignez votre mot de passe.'), findsOneWidget);
    expect(_auth.operations, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Autofill, focus suivant et visibilité du mot de passe', (
    tester,
  ) async {
    await _pumpSignup(tester);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].autofillHints, contains(AutofillHints.givenName));
    expect(fields[0].textCapitalization, TextCapitalization.words);
    expect(fields[1].autofillHints, contains(AutofillHints.email));
    expect(fields[1].keyboardType, TextInputType.emailAddress);
    expect(fields[2].autofillHints, contains(AutofillHints.newPassword));
    expect(fields[2].obscureText, isTrue);
    await tester.tap(_field('name'));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byType(TextField).at(1))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byType(TextField).at(2))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await tester.tap(find.byTooltip('Afficher le mot de passe'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).obscureText,
      isFalse,
    );
    await tester.tap(find.byTooltip('Masquer le mot de passe'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).obscureText,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Le lien révèle le code parrain facultatif', (tester) async {
    await _pumpSignup(tester);
    expect(_field('referral'), findsNothing);
    await tester.tap(find.text('J’ai un code parrain'));
    await tester.pumpAndSettle();
    expect(find.text('J’ai un code parrain'), findsNothing);
    expect(_field('referral'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.textCapitalization, TextCapitalization.characters);
    expect(find.text('Code parrain (optionnel)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final error in [
    (
      code: 'invalid-email',
      message: 'Adresse email invalide.',
      email: 'email-invalide',
      password: 'test-password',
    ),
    (
      code: 'weak-password',
      message: 'Le mot de passe doit contenir au moins 6 caractères.',
      email: 'client@example.org',
      password: '123',
    ),
  ]) {
    testWidgets('Conserve la validation Firebase : ${error.code}', (
      tester,
    ) async {
      _auth.response = Completer<UserCredentialPlatform>();
      await _pumpSignup(tester);
      await _fill(tester, email: error.email, password: error.password);
      await _tapSubmit(tester);
      expect(_auth.operations, ['create']);
      _auth.response!.completeError(FirebaseAuthException(code: error.code));
      await tester.pumpAndSettle();
      expect(find.text(error.message), findsOneWidget);
      expect(find.byType(LoyaloAuthError), findsOneWidget);
      expect(
        tester
            .widget<LoyaloGradientButton>(find.byType(LoyaloGradientButton))
            .loading,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Chargement : formulaire désactivé et double soumission empêchée',
    (tester) async {
      _auth.response = Completer<UserCredentialPlatform>();
      await _pumpSignup(tester);
      await _fill(tester);
      final originalSubmit = tester
          .widget<LoyaloGradientButton>(find.byType(LoyaloGradientButton))
          .onPressed!;
      originalSubmit();
      originalSubmit();
      await tester.pump();
      expect(_auth.operations, ['create']);
      final button = tester.widget<LoyaloGradientButton>(
        find.byType(LoyaloGradientButton),
      );
      expect(button.loading, isTrue);
      expect(button.onPressed, isNull);
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((field) => field.enabled == false),
        isTrue,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
            )
            .onPressed,
        isNull,
      );
      _auth.response!.completeError(
        FirebaseAuthException(code: 'too-many-requests'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Trop de tentatives, réessayez dans quelques minutes.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<LoyaloGradientButton>(find.byType(LoyaloGradientButton))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Le bouton retour conserve la navigation précédente', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ClientSignupScreen(),
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
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.byType(ClientSignupScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Clavier et parrainage ouverts : saisie et bouton accessibles', (
    tester,
  ) async {
    await _pumpSignup(tester);
    await tester.tap(find.text('J’ai un code parrain'));
    await tester.pumpAndSettle();
    await tester.tap(_field('referral'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.view.padding = const FakeViewPadding(top: 47);
    await tester.pumpAndSettle();
    for (final finder in [_field('referral'), find.text('Créer mon compte')]) {
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
      await _pumpSignup(
        tester,
        size: scenario.size,
        textScale: scenario.scale,
        platform: scenario.platform,
      );
      for (final label in [
        _title,
        _description,
        'J’ai un code parrain',
        'Créer mon compte',
        _security,
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
      await tester.ensureVisible(find.text('Créer mon compte'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Créer mon compte')).center.dy,
        inInclusiveRange(47, scenario.size.height - 34),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in [
    (code: null, valid: false, existing: false),
    (code: '', valid: false, existing: false),
    (code: '  loyaparrain  ', valid: true, existing: false),
    (code: 'INCONNU', valid: false, existing: false),
    (code: null, valid: false, existing: true),
  ]) {
    testWidgets(
      'Parcours inscription : code=${scenario.code}, compte existant=${scenario.existing}',
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
        await firestore.collection('referralCodes').doc('LOYAPARRAIN').set({
          'userId': 'referrer-uid',
        });
        if (scenario.existing) {
          await firestore.collection('users').doc('client-uid').set({
            'name': 'Profil conservé',
            'email': 'client@example.org',
            'referralCode': 'LOYACLIENT',
          });
        }
        _auth.existingAccount = scenario.existing;
        _auth.response = Completer<UserCredentialPlatform>();
        final observer = _RouteObserver();
        final container = await _pumpSignup(
          tester,
          repository: repo,
          observer: observer,
        );
        await _fill(tester, email: '  client@example.org  ');
        if (scenario.code != null) {
          await tester.ensureVisible(find.text('J’ai un code parrain'));
          await tester.tap(find.text('J’ai un code parrain'));
          await tester.pumpAndSettle();
          await tester.enterText(_field('referral'), scenario.code!);
        }
        await _tapSubmit(tester);
        _auth.response!.complete(_FakeCredential(_auth));
        await tester.idle();
        final route = observer.replacement as MaterialPageRoute<dynamic>?;
        expect(route, isNotNull);
        expect(
          route!.builder(tester.element(find.byType(ClientSignupScreen))),
          isA<ClientRootScreen>(),
        );
        expect(
          _auth.operations,
          scenario.existing ? ['create', 'signIn'] : ['create'],
        );
        expect(_auth.email, 'client@example.org');
        expect(_auth.password, 'test-password');
        expect(repo.listenedClients, ['client-uid']);
        expect(container.read(currentUserProvider)!.id, 'client-uid');
        final profile =
            (await firestore.collection('users').doc('client-uid').get())
                .data()!;
        expect(
          profile['name'],
          scenario.existing ? 'Profil conservé' : 'Camille',
        );
        expect(profile['email'], 'client@example.org');
        final referrals = await firestore.collection('referrals').get();
        expect(referrals.docs.length, scenario.valid ? 1 : 0);
        if (scenario.valid) {
          final referral = referrals.docs.single;
          expect(referral.id, 'initial_client-uid');
          expect(referral.data()['referrerId'], 'referrer-uid');
          expect(referral.data()['status'], 'pending');
          expect(referral.data()['pointsEarned'], 0);
          expect(
            await repo.redeemReferralCode(
              code: 'LOYAPARRAIN',
              newUserId: 'client-uid',
              newUserName: 'Camille',
            ),
            isFalse,
          );
        }
        expect((await firestore.collection('visits').get()).docs, isEmpty);
        expect((await firestore.collection('rewards').get()).docs, isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('remember_me_client_name'), 'Camille');
        expect(
          prefs.getString('remember_me_client_email'),
          'client@example.org',
        );
        expect(
          await const FlutterSecureStorage().read(
            key: 'remember_me_client_password',
          ),
          'test-password',
        );
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
