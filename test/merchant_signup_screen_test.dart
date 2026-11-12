import 'dart:async';

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/providers/app_providers.dart';
import 'package:loyalo/screens/merchant/merchant_signup_screen.dart';
import 'package:loyalo/screens/merchant/merchant_root_screen.dart';
import 'package:loyalo/screens/merchant/rewards_management_screen.dart';
import 'package:loyalo/screens/merchant/merchant_establishment_screen.dart';
import 'package:loyalo/models/restaurant.dart';
import 'package:loyalo/services/loyalty_repository.dart';
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
  @override
  UserPlatform get currentUser => _FakeUser(this);

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
            uid: 'merchant-uid',
            email: 'merchant@example.org',
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
  final listeners = <String>[];
  bool failAfterCreation = false;
  @override
  void startListeningForMerchant(String restaurantId, {String? ownerUid}) =>
      listeners.add(restaurantId);
  @override
  Future<Restaurant> loadOrCreateMerchantDraft({
    required String ownerId,
    required String name,
    required String cuisine,
    required String email,
  }) async {
    final restaurant = await super.loadOrCreateMerchantDraft(
      ownerId: ownerId,
      name: name,
      cuisine: cuisine,
      email: email,
    );
    if (failAfterCreation) {
      failAfterCreation = false;
      throw StateError('Interruption simulée. Réessayez.');
    }
    return restaurant;
  }
}

class _Observer extends NavigatorObserver {
  Route<dynamic>? latest;
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      latest = newRoute;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      latest = route;
}

final _auth = _FakeAuth();
Finder _field(String name) => find.descendant(
  of: find.byKey(Key('merchant-signup-$name')),
  matching: find.byType(TextFormField),
);
Finder _label(String name) {
  const programFields = {
    'Visites nécessaires': 'program-threshold',
    'Points nécessaires': 'program-threshold',
    'Points gagnés par visite': 'program-points',
    'Nom de la récompense': 'program-reward',
  };
  final key = programFields[name];
  if (key != null) {
    return find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(TextField),
    );
  }
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == name,
  );
}

({FakeFirebaseFirestore firestore, _RecordingRepository repo}) _fixture() {
  final firestore = FakeFirebaseFirestore();
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final repo = _RecordingRepository(firestore: firestore, database: database);
  addTearDown(() async {
    await repo.stopListening();
    await database.close();
  });
  return (firestore: firestore, repo: repo);
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _RecordingRepository repo, {
  Widget screen = const MerchantSignupScreen(),
  String? restaurantId,
  _Observer? observer,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loyaltyRepositoryProvider.overrideWith((ref) => repo),
        if (restaurantId != null)
          currentMerchantRestaurantIdProvider.overrideWith(
            (ref) => restaurantId,
          ),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        navigatorObservers: [?observer],
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(screen.runtimeType)),
    listen: false,
  );
}

Future<void> _fill(WidgetTester tester) async {
  await tester.enterText(_field('name'), '  Atelier local  ');
  await tester.enterText(_field('email'), '  merchant@example.org  ');
  await tester.enterText(_field('password'), 'test-password');
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Créer mon espace commerçant'));
  await tester.tap(find.text('Créer mon espace commerçant'));
  await tester.pump();
}

Future<void> _reach(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Widget _destination(WidgetTester tester, _Observer observer, Type screenType) =>
    (observer.latest! as MaterialPageRoute<dynamic>).builder(
      tester.element(find.byType(screenType)),
    );

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

  testWidgets('Le formulaire réel bloque les trois champs obligatoires', (
    tester,
  ) async {
    final f = _fixture();
    await _pump(tester, f.repo);
    await _submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Renseignez le nom du commerce.'), findsOneWidget);
    expect(find.text('Renseignez votre adresse email.'), findsOneWidget);
    expect(find.text('Renseignez votre mot de passe.'), findsOneWidget);
    expect(_auth.operations, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final error in [
    (code: 'invalid-email', message: 'Adresse email invalide.'),
    (
      code: 'weak-password',
      message: 'Le mot de passe doit contenir au moins 6 caractères.',
    ),
  ]) {
    testWidgets('Les erreurs Firebase restent visibles : ${error.code}', (
      tester,
    ) async {
      final f = _fixture();
      _auth.response = Completer<UserCredentialPlatform>();
      await _pump(tester, f.repo);
      await _fill(tester);
      await _submit(tester);
      _auth.response!.completeError(FirebaseAuthException(code: error.code));
      await tester.pumpAndSettle();
      expect(find.text(error.message), findsOneWidget);
      expect((await f.firestore.collection('restaurants').get()).docs, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Le formulaire réel empêche les soumissions multiples', (
    tester,
  ) async {
    final f = _fixture();
    _auth.response = Completer<UserCredentialPlatform>();
    await _pump(tester, f.repo);
    await _fill(tester);
    final submit = tester
        .widget<LoyaloGradientButton>(find.byType(LoyaloGradientButton))
        .onPressed!;
    submit();
    submit();
    await tester.pump();
    expect(_auth.operations, ['create']);
    expect(
      tester
          .widget<LoyaloGradientButton>(find.byType(LoyaloGradientButton))
          .loading,
      isTrue,
    );
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .every((field) => field.enabled == false),
      isTrue,
    );
    _auth.response!.completeError(
      FirebaseAuthException(code: 'too-many-requests'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (activity: '', existingAuth: false),
    (activity: 'Caviste indépendant', existingAuth: false),
    (activity: '', existingAuth: true),
  ]) {
    testWidgets(
      'Inscription vers configuration : activité=${scenario.activity}, reprise=${scenario.existingAuth}',
      (tester) async {
        final f = _fixture();
        _auth.existingAccount = scenario.existingAuth;
        _auth.response = Completer<UserCredentialPlatform>();
        final observer = _Observer();
        final container = await _pump(tester, f.repo, observer: observer);
        await _fill(tester);
        if (scenario.activity.isNotEmpty) {
          await tester.enterText(_field('activity'), scenario.activity);
        }
        await _submit(tester);
        _auth.response!.complete(_FakeCredential(_auth));
        await tester.idle();
        final destination = _destination(
          tester,
          observer,
          MerchantSignupScreen,
        );
        expect(destination, isA<RewardsManagementScreen>());
        expect(
          (destination as RewardsManagementScreen).completeOnboarding,
          isTrue,
        );
        final restaurants = await f.firestore.collection('restaurants').get();
        expect(restaurants.docs, hasLength(1));
        final data = restaurants.docs.single.data();
        expect(data['name'], 'Atelier local');
        expect(
          data['cuisine'],
          scenario.activity.isEmpty ? 'Restaurant' : scenario.activity,
        );
        expect(data['active'], isFalse);
        expect(data['loyaltyProgramEnabled'], isFalse);
        expect(data['rewardLabel'], '');
        expect(
          container.read(currentMerchantRestaurantIdProvider),
          restaurants.docs.single.id,
        );
        expect(f.repo.listeners, [restaurants.docs.single.id]);
        expect(
          _auth.operations,
          scenario.existingAuth ? ['create', 'signIn'] : ['create'],
        );
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Un compte commerçant déjà configuré retrouve son commerce', (
    tester,
  ) async {
    final f = _fixture();
    final original = await f.repo.loadOrCreateMerchantDraft(
      ownerId: 'merchant-uid',
      name: 'Commerce existant',
      cuisine: 'Café',
      email: 'merchant@example.org',
    );
    await f.repo.completeMerchantOnboarding(
      restaurantId: original.id,
      ownerId: 'merchant-uid',
      type: LoyaltyProgramType.visits,
      rewardThreshold: 7,
      pointsPerVisit: 100,
      rewardLabel: 'Café offert',
      validationPolicy: VisitValidationPolicy.oncePerDay,
      minimumHoursBetweenVisits: 4,
    );
    _auth.existingAccount = true;
    _auth.response = Completer<UserCredentialPlatform>();
    final observer = _Observer();
    await _pump(tester, f.repo, observer: observer);
    await _fill(tester);
    await _submit(tester);
    _auth.response!.complete(_FakeCredential(_auth));
    await tester.idle();
    expect(
      _destination(tester, observer, MerchantSignupScreen),
      isA<MerchantRootScreen>(),
    );
    final restaurants = await f.firestore.collection('restaurants').get();
    expect(restaurants.docs, hasLength(1));
    expect(restaurants.docs.single.data()['rewardLabel'], 'Café offert');
    expect(restaurants.docs.single.data()['name'], 'Commerce existant');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Une interruption se reprend sans créer de second commerce', (
    tester,
  ) async {
    final f = _fixture();
    f.repo.failAfterCreation = true;
    _auth.response = Completer<UserCredentialPlatform>();
    final observer = _Observer();
    await _pump(tester, f.repo, observer: observer);
    await _fill(tester);
    await _submit(tester);
    _auth.response!.complete(_FakeCredential(_auth));
    await tester.pumpAndSettle();
    expect(find.text('Interruption simulée. Réessayez.'), findsOneWidget);
    expect(
      (await f.firestore.collection('restaurants').get()).docs,
      hasLength(1),
    );
    _auth.existingAccount = true;
    _auth.response = Completer<UserCredentialPlatform>();
    await _submit(tester);
    _auth.response!.complete(_FakeCredential(_auth));
    await tester.idle();
    expect(
      _destination(tester, observer, MerchantSignupScreen),
      isA<RewardsManagementScreen>(),
    );
    expect(
      (await f.firestore.collection('restaurants').get()).docs,
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('La configuration refuse une récompense vide et un seuil nul', (
    tester,
  ) async {
    final f = _fixture();
    final draft = await f.repo.loadOrCreateMerchantDraft(
      ownerId: 'merchant-uid',
      name: 'Commerce',
      cuisine: 'Café',
      email: 'merchant@example.org',
    );
    await _pump(
      tester,
      f.repo,
      screen: const RewardsManagementScreen(completeOnboarding: true),
      restaurantId: draft.id,
    );
    expect(find.text('Configurer mon programme'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    await _reach(tester, _label('Visites nécessaires'));
    await tester.enterText(_label('Visites nécessaires'), '0');
    await _reach(tester, find.text('Activer et publier'));
    await tester.tap(find.text('Activer et publier'));
    await tester.pumpAndSettle();
    expect(find.text('Récompense obligatoire'), findsOneWidget);
    expect(
      (await f.firestore.collection('restaurants').doc(draft.id).get())
          .data()!['active'],
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'La configuration valide active, publie et ouvre l’espace commerçant',
    (tester) async {
      final f = _fixture();
      final draft = await f.repo.loadOrCreateMerchantDraft(
        ownerId: 'merchant-uid',
        name: 'Commerce',
        cuisine: 'Café',
        email: 'merchant@example.org',
      );
      final observer = _Observer();
      await _pump(
        tester,
        f.repo,
        screen: const RewardsManagementScreen(completeOnboarding: true),
        restaurantId: draft.id,
        observer: observer,
      );
      await _reach(tester, _label('Nom de la récompense'));
      await tester.enterText(_label('Nom de la récompense'), 'Café offert');
      await _reach(tester, find.text('Activer et publier'));
      await tester.tap(find.text('Activer et publier'));
      await tester.idle();
      expect(
        _destination(tester, observer, RewardsManagementScreen),
        isA<MerchantRootScreen>(),
      );
      final data =
          (await f.firestore.collection('restaurants').doc(draft.id).get())
              .data()!;
      expect(data['active'], isTrue);
      expect(data['status'], 'active');
      expect(data['loyaltyProgramEnabled'], isTrue);
      expect(data['rewardLabel'], 'Café offert');
      expect((await f.firestore.collection('rewards').get()).docs, isEmpty);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Le parcours de secours conserve un brouillon et mène à sa configuration',
    (tester) async {
      final f = _fixture();
      final observer = _Observer();
      await _pump(
        tester,
        f.repo,
        screen: const MerchantEstablishmentScreen(requireSetup: true),
        observer: observer,
      );
      await tester.enterText(_label('Nom du commerce'), 'Commerce repris');
      await _reach(tester, find.byType(SwitchListTile));
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      await _reach(tester, find.text('Créer mon établissement'));
      await tester.tap(find.text('Créer mon établissement'));
      await tester.idle();
      expect(
        _destination(tester, observer, MerchantEstablishmentScreen),
        isA<RewardsManagementScreen>(),
      );
      final restaurants = await f.firestore.collection('restaurants').get();
      expect(restaurants.docs, hasLength(1));
      expect(restaurants.docs.single.data()['active'], isFalse);
      expect(restaurants.docs.single.data()['rewardLabel'], '');
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
