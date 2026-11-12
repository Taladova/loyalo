import 'dart:async';

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/models/restaurant.dart';
import 'package:loyalo/providers/app_providers.dart';
import 'package:loyalo/screens/merchant/merchant_root_screen.dart';
import 'package:loyalo/screens/merchant/rewards_management_screen.dart';
import 'package:loyalo/services/loyalty_repository.dart';
import 'package:loyalo/widgets/loyalo_program_ui.dart';
import 'package:loyalo/widgets/loyalo_ui.dart';

class _Core extends FirebasePlatform {
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

class _Auth extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) => this;
  @override
  UserPlatform get currentUser => _User(this);
}

class _MultiFactor extends MultiFactorPlatform {
  _MultiFactor(super.auth);
}

class _User extends UserPlatform {
  _User(FirebaseAuthPlatform auth)
    : super(
        auth,
        _MultiFactor(auth),
        PigeonUserDetails(
          userInfo: PigeonUserInfo(
            uid: 'merchant-uid',
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: [],
        ),
      );
}

class _Repository extends LoyaltyRepository {
  _Repository({
    required FakeFirebaseFirestore firestore,
    required AppDatabase database,
  }) : super(firestore: firestore, database: database);
  Completer<void>? publication;
  int publications = 0;
  int clients = 0;
  @override
  int uniqueClientsForRestaurant(String restaurantId) => clients;
  @override
  Future<Restaurant> completeMerchantOnboarding({
    required String restaurantId,
    required String ownerId,
    required LoyaltyProgramType type,
    required int rewardThreshold,
    required int pointsPerVisit,
    required String rewardLabel,
    String rewardDescription = '',
    required VisitValidationPolicy validationPolicy,
    required int minimumHoursBetweenVisits,
  }) async {
    publications++;
    if (publication != null) await publication!.future;
    return super.completeMerchantOnboarding(
      restaurantId: restaurantId,
      ownerId: ownerId,
      type: type,
      rewardThreshold: rewardThreshold,
      pointsPerVisit: pointsPerVisit,
      rewardLabel: rewardLabel,
      rewardDescription: rewardDescription,
      validationPolicy: validationPolicy,
      minimumHoursBetweenVisits: minimumHoursBetweenVisits,
    );
  }
}

class _Observer extends NavigatorObserver {
  Route<dynamic>? latest;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      latest = route;
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      latest = newRoute;
}

Finder _field(String name) => find.descendant(
  of: find.byKey(Key('program-$name')),
  matching: find.byType(TextFormField),
);
Finder _step(String action, String label) => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == '$action : $label',
);

Future<void> _reach(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String field, String value) async {
  await _reach(tester, _field(field));
  await tester.enterText(_field(field), value);
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, {bool pump = true}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await _reach(tester, find.byKey(const Key('program-save')));
  await tester.tap(find.byKey(const Key('program-save')));
  if (pump) await tester.pump();
}

Future<
  ({
    FakeFirebaseFirestore firestore,
    _Repository repo,
    Restaurant restaurant,
    _Observer observer,
  })
>
_pump(
  WidgetTester tester, {
  bool draft = true,
  bool completeOnboarding = false,
  int clients = 0,
  Size size = const Size(390, 844),
  double scale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
  bool reduceMotion = false,
  RestaurantStatus status = RestaurantStatus.active,
}) async {
  final firestore = FakeFirebaseFirestore();
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final repo = _Repository(firestore: firestore, database: database)
    ..clients = clients;
  addTearDown(() async {
    await repo.stopListening();
    await database.close();
  });
  if (!draft) {
    final existing = Restaurant(
      id: 'existing-commerce',
      ownerId: 'merchant-uid',
      name: 'Commerce',
      cuisine: 'Café',
      distanceKm: 0,
      rewardThreshold: 10,
      rewardLabel: 'Un café offert',
      icon: Icons.storefront,
      status: status,
      active: status == RestaurantStatus.active,
    );
    await firestore
        .collection('restaurants')
        .doc(existing.id)
        .set(existing.toMap());
    await firestore.collection('merchants').doc('merchant-uid').set({
      'restaurantId': existing.id,
    });
  }
  final restaurant = await repo.loadOrCreateMerchantDraft(
    ownerId: 'merchant-uid',
    name: 'Commerce',
    cuisine: 'Café',
    email: 'merchant@example.org',
  );
  final observer = _Observer();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loyaltyRepositoryProvider.overrideWith((ref) => repo),
        currentMerchantRestaurantIdProvider.overrideWith(
          (ref) => restaurant.id,
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        navigatorObservers: [observer],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: RewardsManagementScreen(completeOnboarding: completeOnboarding),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    firestore: firestore,
    repo: repo,
    restaurant: restaurant,
    observer: observer,
  );
}

Future<Map<String, dynamic>> _data(
  ({
    FakeFirebaseFirestore firestore,
    _Repository repo,
    Restaurant restaurant,
    _Observer observer,
  })
  f,
) async =>
    (await f.firestore.collection('restaurants').doc(f.restaurant.id).get())
        .data()!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    FirebasePlatform.instance = _Core();
    FirebaseAuthPlatform.instance = _Auth();
  });

  testWidgets('Structure sans illustration décorative et brouillon intact', (
    tester,
  ) async {
    final f = await _pump(tester);
    for (final label in [
      'Configurer mon programme',
      'Type de fidélité',
      'Objectif',
      'Récompense',
      'Validation des visites',
      'Aperçu client',
      'Activer et publier',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(LoyaloProgramHeader), findsOneWidget);
    expect(find.byType(LoyaloProgramSection), findsNWidgets(5));
    expect(find.byType(Image), findsNothing);
    expect((await _data(f))['active'], isFalse);
    expect(f.repo.publications, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Visites et Points conservent les paramètres et adaptent l’aperçu',
    (tester) async {
      final f = await _pump(tester);
      final before = await _data(f);
      await _enter(tester, 'threshold', '12');
      await _enter(tester, 'points', '450');
      expect(find.text('0 / 12 visites'), findsOneWidget);
      await _reach(tester, find.text('Points'));
      await tester.tap(find.text('Points'));
      await tester.pumpAndSettle();
      expect(find.text('Points nécessaires'), findsOneWidget);
      expect(find.text('Points gagnés par visite'), findsOneWidget);
      expect(find.text('0 / 12 points'), findsOneWidget);
      expect(find.textContaining('1 visite = +450 pts'), findsOneWidget);
      await _reach(tester, find.text('Visites'));
      await tester.tap(find.text('Visites'));
      await tester.pumpAndSettle();
      expect(find.text('0 / 12 visites'), findsOneWidget);
      expect(await _data(f), before);
      for (final collection in ['visits', 'rewards', 'referrals']) {
        expect((await f.firestore.collection(collection).get()).docs, isEmpty);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Sélecteurs numériques : minimum, saisie filtrée et dépassement évité',
    (tester) async {
      await _pump(tester);
      await _enter(tester, 'threshold', '1');
      expect(
        tester
            .widget<IconButton>(_step('Diminuer', 'Visites nécessaires'))
            .onPressed,
        isNull,
      );
      await _reach(tester, _step('Augmenter', 'Visites nécessaires'));
      await tester.tap(_step('Augmenter', 'Visites nécessaires'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<TextField>(
              find.descendant(
                of: find.byKey(const Key('program-threshold')),
                matching: find.byType(TextField),
              ),
            )
            .single
            .controller!
            .text,
        '2',
      );
      await tester.tap(_step('Diminuer', 'Visites nécessaires'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(_step('Diminuer', 'Visites nécessaires'))
            .onPressed,
        isNull,
      );
      await _enter(tester, 'threshold', 'abc12x');
      expect(find.text('0 / 12 visites'), findsOneWidget);
      await _enter(tester, 'threshold', '9223372036854775807');
      expect(
        tester
            .widget<IconButton>(_step('Augmenter', 'Visites nécessaires'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final invalid in [
    (field: 'threshold', value: '0'),
    (field: 'threshold', value: ''),
    (field: 'points', value: '0'),
  ]) {
    testWidgets('Valeur invalide : ${invalid.field}=${invalid.value}', (
      tester,
    ) async {
      final f = await _pump(tester);
      await _enter(tester, 'reward', 'Café offert');
      await _enter(tester, invalid.field, invalid.value);
      await _submit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Nombre obligatoire'), findsOneWidget);
      expect(f.repo.publications, 0);
      expect((await _data(f))['active'], isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Récompense obligatoire, description facultative limitée à 140 caractères',
    (tester) async {
      final f = await _pump(tester);
      expect(find.text('0 / 140'), findsOneWidget);
      await _submit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Récompense obligatoire'), findsOneWidget);
      expect(f.repo.publications, 0);
      await _enter(tester, 'description', List.filled(160, 'é').join());
      expect(find.text('140 / 140'), findsOneWidget);
      final controller = tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('program-description')),
              matching: find.byType(TextField),
            ),
          )
          .controller!;
      expect(controller.text.length, 140);
      await _enter(tester, 'reward', 'Café — douceur 🎁');
      expect(
        find.text('Encore 10 visites avant : Café — douceur 🎁'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('X h conserve sa valeur lorsque le champ devient masqué', (
    tester,
  ) async {
    await _pump(tester);
    await _reach(tester, find.text('X h'));
    await tester.tap(find.text('X h'));
    await tester.pumpAndSettle();
    expect(_field('hours'), findsOneWidget);
    await _enter(tester, 'hours', '7');
    await _reach(tester, find.text('Ticket'));
    await tester.tap(find.text('Ticket'));
    await tester.pumpAndSettle();
    expect(_field('hours'), findsNothing);
    await tester.tap(find.text('X h'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('program-hours')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      '7',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Un délai nul interdit la publication', (tester) async {
    final f = await _pump(tester);
    await _enter(tester, 'reward', 'Café offert');
    await _reach(tester, find.text('X h'));
    await tester.tap(find.text('X h'));
    await tester.pumpAndSettle();
    await _enter(tester, 'hours', '0');
    await _submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Nombre obligatoire'), findsOneWidget);
    expect(f.repo.publications, 0);
    expect((await _data(f))['active'], isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final policy in [
    (label: 'Jour', value: 'oncePerDay'),
    (label: 'X h', value: 'onceEveryXHours'),
    (label: 'Ticket', value: 'perTransaction'),
  ]) {
    testWidgets('Publication conserve le mode ${policy.value}', (tester) async {
      final f = await _pump(tester);
      await _enter(tester, 'reward', '  Café offert  ');
      await _reach(tester, find.text(policy.label));
      await tester.tap(find.text(policy.label));
      await tester.pumpAndSettle();
      if (policy.label == 'X h') await _enter(tester, 'hours', '6');
      await _submit(tester);
      await tester.pumpAndSettle();
      final data = await _data(f);
      expect(data['validationPolicy'], policy.value);
      expect(data['minimumHoursBetweenVisits'], policy.label == 'X h' ? 6 : 4);
      expect(data['rewardLabel'], 'Café offert');
      expect(data['active'], isTrue);
      expect(data['loyaltyProgramEnabled'], isTrue);
      expect(find.text('Programme de fidélité enregistré.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Mode Points publié avec les valeurs saisies et navigation existante',
    (tester) async {
      final f = await _pump(tester, completeOnboarding: true);
      await _reach(tester, find.text('Points'));
      await tester.tap(find.text('Points'));
      await tester.pumpAndSettle();
      await _enter(tester, 'threshold', '1000');
      await _enter(tester, 'points', '100');
      await _enter(tester, 'reward', 'Un café offert');
      await _submit(tester, pump: false);
      await tester.idle();
      final destination = (f.observer.latest! as MaterialPageRoute<dynamic>)
          .builder(tester.element(find.byType(RewardsManagementScreen)));
      expect(destination, isA<MerchantRootScreen>());
      final data = await _data(f);
      expect(data['loyaltyProgramType'], 'points');
      expect(data['rewardThreshold'], 1000);
      expect(data['pointsPerVisit'], 100);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Chargement, double soumission, erreur puis nouvelle tentative', (
    tester,
  ) async {
    final f = await _pump(tester);
    f.repo.publication = Completer<void>();
    await _enter(tester, 'reward', 'Café offert');
    final callback = tester
        .widget<LoyaloGradientButton>(find.byType(LoyaloGradientButton))
        .onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(f.repo.publications, 1);
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
    expect(
      tester
          .widget<SegmentedButton<LoyaltyProgramType>>(
            find.byType(SegmentedButton<LoyaltyProgramType>),
          )
          .onSelectionChanged,
      isNull,
    );
    f.repo.publication!.completeError(StateError('Connexion indisponible.'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Impossible d’enregistrer'), findsOneWidget);
    expect((await _data(f))['active'], isFalse);
    f.repo.publication = null;
    await _submit(tester);
    await tester.pumpAndSettle();
    expect(f.repo.publications, 2);
    expect((await _data(f))['active'], isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Modification d’un programme actif : confirmation unique et annulation conservée',
    (tester) async {
      final f = await _pump(tester, draft: false, clients: 2);
      expect(find.text('Activer et publier'), findsNothing);
      await _enter(tester, 'threshold', '12');
      final callback = tester
          .widget<LoyaloGradientButton>(find.byType(LoyaloGradientButton))
          .onPressed!;
      callback();
      callback();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect((await _data(f))['rewardThreshold'], 10);
      await _submit(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect((await _data(f))['rewardThreshold'], 12);
      expect(f.repo.publications, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Un commerce en attente de revue n’est pas publié par Enregistrer',
    (tester) async {
      final f = await _pump(
        tester,
        draft: false,
        status: RestaurantStatus.pendingReview,
      );
      expect(
        find.textContaining('Votre commerce reste en brouillon.'),
        findsNothing,
      );
      expect(find.text('Enregistrer'), findsOneWidget);
      await _submit(tester);
      await tester.pumpAndSettle();
      final data = await _data(f);
      expect(data['status'], 'pendingReview');
      expect(data['active'], isFalse);
      expect(f.repo.publications, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Désactivation existante et aperçu désactivé conservés', (
    tester,
  ) async {
    final f = await _pump(tester, draft: false);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      find.text('Ce commerce n’a pas encore activé son programme de fidélité.'),
      findsOneWidget,
    );
    await _submit(tester);
    await tester.pumpAndSettle();
    expect((await _data(f))['loyaltyProgramEnabled'], isFalse);
    expect((await _data(f))['active'], isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quitter ne sauvegarde ni ne publie les paramètres incomplets', (
    tester,
  ) async {
    final f = await _pump(tester);
    final before = await _data(f);
    await _enter(tester, 'threshold', '15');
    await _reach(tester, find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.idle();
    expect(await _data(f), before);
    expect(f.repo.publications, 0);
    final destination = (f.observer.latest! as MaterialPageRoute<dynamic>)
        .builder(tester.element(find.byType(RewardsManagementScreen)));
    expect(destination, isA<MerchantRootScreen>());
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Clavier ouvert : champ actif et bouton accessibles', (
    tester,
  ) async {
    await _pump(tester);
    await _reach(tester, _field('reward'));
    await tester.tap(_field('reward'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.view.padding = const FakeViewPadding(top: 47);
    await tester.pumpAndSettle();
    for (final finder in [
      _field('reward'),
      find.byKey(const Key('program-save')),
    ]) {
      await _reach(tester, finder);
      expect(tester.getRect(finder).center.dy, inInclusiveRange(47, 544));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Réduction des animations respectée', (tester) async {
    await _pump(tester, reduceMotion: true);
    final animation = tester.widget<AnimatedSize>(
      find
          .descendant(
            of: find.byKey(const Key('program-section-preview')),
            matching: find.byType(AnimatedSize),
          )
          .first,
    );
    expect(animation.duration, Duration.zero);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(320, 568), scale: 1.0, platform: TargetPlatform.iOS),
    (size: const Size(320, 568), scale: 2.5, platform: TargetPlatform.iOS),
    (size: const Size(390, 844), scale: 2.5, platform: TargetPlatform.iOS),
    (size: const Size(430, 932), scale: 1.0, platform: TargetPlatform.iOS),
    (size: const Size(360, 640), scale: 1.0, platform: TargetPlatform.android),
    (size: const Size(412, 915), scale: 1.0, platform: TargetPlatform.android),
  ]) {
    testWidgets('Responsive ${scenario.size}, texte ${scenario.scale}', (
      tester,
    ) async {
      await _pump(
        tester,
        size: scenario.size,
        scale: scenario.scale,
        platform: scenario.platform,
      );
      for (final label in [
        'Configurer mon programme',
        'Type de fidélité',
        'Objectif',
        'Récompense',
        'Validation des visites',
        'Aperçu client',
        'Visites nécessaires',
        'Points gagnés par visite',
        'Nom de la récompense',
        'Description optionnelle',
        'Activer et publier',
      ]) {
        final finder = find.text(label);
        expect(
          tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
          isFalse,
        );
        expect(
          tester.widget<Text>(finder).overflow,
          isNot(TextOverflow.ellipsis),
        );
      }
      for (final finder in [
        _step('Augmenter', 'Visites nécessaires'),
        _step('Diminuer', 'Visites nécessaires'),
      ]) {
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      if (scenario.scale > 1) {
        expect(
          tester
              .widget<SegmentedButton<LoyaltyProgramType>>(
                find.byType(SegmentedButton<LoyaltyProgramType>),
              )
              .direction,
          Axis.vertical,
        );
      }
      await _reach(tester, find.byKey(const Key('program-save')));
      expect(
        tester.getRect(find.byKey(const Key('program-save'))).center.dy,
        inInclusiveRange(47, scenario.size.height - 34),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
