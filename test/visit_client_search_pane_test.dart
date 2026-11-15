import 'dart:async';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/core/network/network_monitor.dart';
import 'package:loyalo/features/checkins/data/check_in_remote_data_source.dart';
import 'package:loyalo/models/check_in_request.dart';
import 'package:loyalo/models/restaurant.dart';
import 'package:loyalo/providers/app_providers.dart';
import 'package:loyalo/screens/merchant/client_search_screen.dart';
import 'package:loyalo/screens/merchant/merchant_root_screen.dart';
import 'package:loyalo/screens/merchant/validate_visit_screen.dart';
import 'package:loyalo/screens/merchant/visit_client_search_pane.dart';
import 'package:loyalo/services/loyalty_repository.dart';
import 'package:loyalo/widgets/loyalo_auth_ui.dart';
import 'package:loyalo/widgets/loyalo_merchant_dashboard_ui.dart';
import 'package:loyalo/widgets/loyalo_visit_validation_ui.dart';
import 'support/merchant_dashboard_fixture.dart';

class _Network implements NetworkMonitor {
  bool online = true;
  @override
  Future<bool> get isNetworkAvailable async => online;
  @override
  Stream<bool> get onAvailabilityChanged => const Stream.empty();
}

class _Repo extends LoyaltyRepository {
  _Repo(this.database)
    : super(
        firestore: FakeFirebaseFirestore(),
        database: database,
        networkMonitor: _Network(),
      );
  final AppDatabase database;
  Restaurant shop = const Restaurant(
    id: 'shop-one',
    ownerId: 'merchant-one',
    name: 'Maison du coin',
    cuisine: 'Boulangerie',
    distanceKm: 0,
    rewardThreshold: 10,
    rewardLabel: 'Une douceur offerte',
    icon: Icons.storefront,
  );
  bool loading = false;
  Object? error;
  bool queryFails = false;
  int retries = 0;
  final queries = <String>[];
  final watches = <({String shop, String? owner})>[];
  List<CheckInRequest> arrivals = [];
  Stream<List<CheckInRequest>>? queueOverride;
  Completer<CheckInValidationResult>? heldApproval;
  Object? approvalError;
  CheckInValidationOutcome outcome = CheckInValidationOutcome.validated;
  bool synced = true;
  final approvals = <String>[];
  int directWrites = 0;
  final _directory = const [
    DirectoryClient(
      id: 'client-one',
      name: 'Amélie Rivière',
      email: 'a@example.org',
      phone: '0611223344',
    ),
    DirectoryClient(
      id: 'client-two',
      name: 'Noé Laurent',
      email: 'n@example.org',
      phone: '0677889900',
    ),
  ];
  @override
  List<Restaurant> get restaurants => [shop];
  @override
  Restaurant? restaurantByIdOrNull(String id) => id == shop.id ? shop : null;
  @override
  Restaurant restaurantById(String id) => restaurantByIdOrNull(id)!;
  @override
  bool get merchantClientsLoading => loading;
  @override
  Object? get merchantClientsLoadError => error;
  @override
  List<DirectoryClient> searchClients(String query) {
    queries.add(query);
    if (queryFails) throw StateError('private-server-detail');
    final q = query.toLowerCase();
    return _directory
        .where((c) => c.name.toLowerCase().contains(q) || c.phone.contains(q))
        .toList();
  }

  @override
  Future<void> retryRestaurants() async {
    retries++;
    error = null;
    queryFails = false;
    notifyListeners();
  }

  @override
  Stream<List<CheckInRequest>> watchMerchantValidationQueue(
    String restaurantId, {
    String? ownerUid,
  }) {
    watches.add((shop: restaurantId, owner: ownerUid));
    return queueOverride ?? Stream.value(arrivals);
  }

  @override
  Future<CheckInValidationResult> approveCheckIn({
    required String checkInId,
    required String merchantId,
  }) async {
    expect(merchantId, 'merchant-one');
    approvals.add(checkInId);
    if (approvalError != null) throw approvalError!;
    return heldApproval == null
        ? CheckInValidationResult(
            outcome: outcome,
            restaurant: shop,
            synced: synced,
          )
        : heldApproval!.future;
  }

  @override
  Future<VisitResult> registerVisit({
    required String userId,
    required String restaurantId,
  }) async {
    directWrites++;
    throw StateError('Attribution directe interdite dans la recherche');
  }

  CheckInRequest arrival({
    String id = 'arrival-one',
    String customer = 'client-one',
    String? restaurant,
    bool expired = false,
  }) => CheckInRequest(
    id: id,
    customerId: customer,
    restaurantId: restaurant ?? shop.id,
    requestedAt: DateTime.now().subtract(const Duration(minutes: 1)),
    expiresAt: DateTime.now().add(Duration(minutes: expired ? -1 : 5)),
    status: CheckInStatus.pending,
  );
}

class _Observer extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

Future<void> reach(WidgetTester t, Finder f) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump(const Duration(milliseconds: 300));
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> tap(WidgetTester t, Finder f) async {
  await reach(t, f);
  await t.tap(f);
  await t.pump(const Duration(milliseconds: 300));
}

Finder key(String v) => find.byKey(ValueKey(v));
Future<void> search(WidgetTester t, [String query = 'Amélie']) async {
  final field = find.descendant(
    of: key('visit-search-field'),
    matching: find.byType(TextField),
  );
  await reach(t, field);
  await t.enterText(field, query);
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> select(WidgetTester t) async {
  await search(t);
  await tap(t, find.text('Amélie Rivière'));
  await t.pump(const Duration(milliseconds: 300));
}

final _auth = DashboardTestAuth();
void _ui(
  String name,
  Future<void> Function(WidgetTester, _Repo, _Network, _Observer) body, {
  void Function(_Repo)? prepare,
  bool root = false,
  bool settle = true,
  Size size = const Size(390, 844),
  double scale = 1,
}) {
  testWidgets(name, (t) async {
    final repo = _Repo(AppDatabase.forTesting(NativeDatabase.memory()));
    final network = _Network();
    final observer = _Observer();
    prepare?.call(repo);
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    t.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    t.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(t.view.reset);
    try {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            loyaltyRepositoryProvider.overrideWith((ref) => repo),
            networkMonitorProvider.overrideWith((ref) => network),
            currentMerchantRestaurantIdProvider.overrideWith(
              (ref) => repo.shop.id,
            ),
          ],
          child: MaterialApp(
            navigatorObservers: [observer],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: root
                ? const MerchantRootScreen()
                : const Scaffold(body: ValidateVisitScreen()),
          ),
        ),
      );
      if (root) await tap(t, key('merchant-nav-validate-tap'));
      await tap(t, key('visit-method-search'));
      if (settle) await t.pumpAndSettle();
      await body(t, repo, network, observer);
    } finally {
      if (repo.heldApproval != null && !repo.heldApproval!.isCompleted) {
        repo.heldApproval!.complete(
          const CheckInValidationResult(
            outcome: CheckInValidationOutcome.notFound,
          ),
        );
      }
      await t.runAsync(repo.stopListening);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      await t.runAsync(repo.database.close);
    }
  });
}

void main() {
  setUpAll(() {
    FirebasePlatform.instance = DashboardTestCore();
    FirebaseAuthPlatform.instance = _auth;
  });
  setUp(() => _auth.signedIn = true);

  _ui(
    'Recherche dans Valider sans route Clients, navigation inférieure conservée',
    (t, r, n, o) async {
      expect(find.byType(VisitClientSearchPane), findsOneWidget);
      expect(find.byType(ClientSearchScreen), findsNothing);
      expect(
        t
            .widget<LoyaloMerchantBottomNav>(
              find.byType(LoyaloMerchantBottomNav),
            )
            .selectedIndex,
        2,
      );
      final before = o.pushes;
      await search(t, '061122');
      expect(find.text('Amélie Rivière'), findsOneWidget);
      expect(find.text('Noé Laurent'), findsNothing);
      expect(r.queries, contains('061122'));
      await tap(t, find.text('Amélie Rivière'));
      expect(o.pushes, before);
      expect(r.directWrites, 0);
      expect(r.approvals, isEmpty);
      expect(r.watches.last, (shop: r.shop.id, owner: 'merchant-one'));
      expect(key('visit-search-selection'), findsOneWidget);
    },
    root: true,
  );

  _ui('Aucun résultat sans annuaire global ni contenu fictif', (
    t,
    r,
    n,
    o,
  ) async {
    await search(t, 'étranger');
    expect(key('visit-search-empty'), findsOneWidget);
    expect(r.approvals, isEmpty);
    expect(r.directWrites, 0);
  });
  _ui(
    'Chargement distinct de la liste vide',
    (t, r, n, o) async {
      expect(key('visit-search-loading'), findsOneWidget);
      expect(key('visit-search-empty'), findsNothing);
    },
    prepare: (r) => r.loading = true,
    settle: false,
  );
  _ui('Erreur des lectures puis nouvel essai', (t, r, n, o) async {
    expect(key('visit-search-error'), findsOneWidget);
    expect(key('visit-search-empty'), findsNothing);
    await tap(t, find.text('Réessayer'));
    await t.pumpAndSettle();
    expect(r.retries, 1);
    await search(t);
    expect(find.text('Amélie Rivière'), findsOneWidget);
  }, prepare: (r) => r.error = StateError('permission denied'));
  _ui('Exception de recherche sans exposition du message technique', (
    t,
    r,
    n,
    o,
  ) async {
    expect(key('visit-search-error'), findsOneWidget);
    expect(find.textContaining('private-server-detail'), findsNothing);
    await tap(t, find.text('Réessayer'));
    await t.pumpAndSettle();
    expect(key('visit-search-initial'), findsOneWidget);
  }, prepare: (r) => r.queryFails = true);

  _ui('Client sans arrivée valide : explication et aucune attribution', (
    t,
    r,
    n,
    o,
  ) async {
    r.arrivals = [
      r.arrival(expired: true),
      r.arrival(customer: 'client-two'),
      r.arrival(restaurant: 'foreign-shop'),
    ];
    await select(t);
    expect(find.textContaining('Aucune arrivée valide'), findsOneWidget);
    expect(key('visit-search-approve'), findsNothing);
    expect(r.approvals, isEmpty);
    expect(r.directWrites, 0);
  });
  _ui('Erreur des arrivées sans bouton de confirmation', (t, r, n, o) async {
    r.queueOverride = Stream.error(StateError('private error'));
    await select(t);
    expect(
      find.textContaining('Impossible de charger les arrivées'),
      findsOneWidget,
    );
    expect(key('visit-search-approve'), findsNothing);
  });
  _ui('Les trois méthodes restent accessibles et le code saisi est conservé', (
    t,
    r,
    n,
    o,
  ) async {
    await tap(t, key('visit-method-code'));
    final pane = t.widget<LoyaloVisitCodePane>(
      find.byType(LoyaloVisitCodePane),
    );
    pane.onDigit('0');
    pane.onDigit('1');
    await t.pump();
    await tap(t, key('visit-method-search'));
    await search(t);
    await tap(t, key('visit-method-scanner'));
    expect(find.byType(LoyaloVisitQrUnavailable), findsOneWidget);
    await tap(t, key('visit-method-code'));
    expect(
      t.widget<LoyaloVisitCodePane>(find.byType(LoyaloVisitCodePane)).digits,
      '01',
    );
    expect(r.approvals, isEmpty);
  });

  if (!secureApproveCheckInEnabled) {
    _ui('Backend sécurisé désactivé : aucun repli vers la validation directe', (
      t,
      r,
      n,
      o,
    ) async {
      r.arrivals = [r.arrival()];
      await select(t);
      expect(
        find.textContaining('confirmation sécurisée est indisponible'),
        findsOneWidget,
      );
      expect(key('visit-search-approve'), findsNothing);
      expect(r.directWrites, 0);
    });
  } else {
    for (final blocked in ['inactive', 'foreign-owner']) {
      _ui('Commerce $blocked : aucune confirmation possible', (
        t,
        r,
        n,
        o,
      ) async {
        r.shop = blocked == 'inactive'
            ? r.shop.copyWith(active: false)
            : r.shop.copyWith(ownerId: 'another-merchant');
        r.arrivals = [r.arrival()];
        await select(t);
        expect(key('visit-search-approve'), findsNothing);
        expect(r.approvals, isEmpty);
        expect(r.directWrites, 0);
      });
    }
    _ui(
      'Arrivée traitée pendant la confirmation : aucune deuxième approbation',
      (t, r, n, o) async {
        late final StreamController<List<CheckInRequest>> stream;
        stream = StreamController<List<CheckInRequest>>.broadcast(
          onListen: () => stream.add([r.arrival()]),
        );
        try {
          r.queueOverride = stream.stream;
          await select(t);
          await tap(t, key('visit-search-approve'));
          stream.add([]);
          await t.pump(const Duration(milliseconds: 300));
          await tap(t, key('visit-search-confirm'));
          await t.pumpAndSettle();
          expect(r.approvals, isEmpty);
          expect(find.textContaining('n’est plus disponible'), findsOneWidget);
        } finally {
          await stream.close();
        }
      },
    );
    _ui(
      'Sélection, annulation et confirmation : seul le service sécurisé existant est appelé',
      (t, r, n, o) async {
        r.arrivals = [r.arrival()];
        await select(t);
        expect(r.approvals, isEmpty);
        await tap(t, key('visit-search-approve'));
        expect(r.approvals, isEmpty);
        await tap(t, find.text('Annuler'));
        expect(r.approvals, isEmpty);
        await tap(t, key('visit-search-approve'));
        await tap(t, key('visit-search-confirm'));
        await t.pumpAndSettle();
        expect(r.approvals, ['arrival-one']);
        expect(r.directWrites, 0);
        expect(find.text('Visite confirmée.'), findsOneWidget);
      },
    );
    _ui('Confirmation hors ligne refusée avant appel du service', (
      t,
      r,
      n,
      o,
    ) async {
      r.arrivals = [r.arrival()];
      n.online = false;
      await select(t);
      await tap(t, key('visit-search-approve'));
      await tap(t, key('visit-search-confirm'));
      await t.pumpAndSettle();
      expect(r.approvals, isEmpty);
      expect(find.textContaining('Connectez-vous à Internet'), findsOneWidget);
    });
    _ui('Session perdue pendant la confirmation : aucune approbation', (
      t,
      r,
      n,
      o,
    ) async {
      r.arrivals = [r.arrival()];
      await select(t);
      await tap(t, key('visit-search-approve'));
      _auth.signedIn = false;
      await tap(t, key('visit-search-confirm'));
      await t.pumpAndSettle();
      expect(r.approvals, isEmpty);
      expect(r.directWrites, 0);
    });
    _ui(
      'Approbation en cours : doubles soumissions et changement de méthode bloqués',
      (t, r, n, o) async {
        r.arrivals = [r.arrival()];
        r.heldApproval = Completer<CheckInValidationResult>();
        await select(t);
        await tap(t, key('visit-search-approve'));
        await tap(t, key('visit-search-confirm'));
        expect(r.approvals.length, 1);
        expect(
          t
              .widget<LoyaloVisitMethodSelector>(
                find.byType(LoyaloVisitMethodSelector),
              )
              .enabled,
          false,
        );
        expect(
          t
              .widget<LoyaloAuthPrimaryButton>(key('visit-search-approve'))
              .onPressed,
          isNull,
        );
        r.heldApproval!.complete(
          const CheckInValidationResult(
            outcome: CheckInValidationOutcome.validated,
            synced: true,
          ),
        );
        await t.pumpAndSettle();
        expect(r.approvals.length, 1);
      },
    );
    _ui('Réponse non synchronisée : aucun succès ou point définitif annoncé', (
      t,
      r,
      n,
      o,
    ) async {
      r.arrivals = [r.arrival()];
      r.synced = false;
      await select(t);
      await tap(t, key('visit-search-approve'));
      await tap(t, key('visit-search-confirm'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('restent à confirmer après synchronisation'),
        findsOneWidget,
      );
      expect(find.text('Visite confirmée.'), findsNothing);
    });
    _ui('Erreur du service : retour explicite et nouvel essai disponible', (
      t,
      r,
      n,
      o,
    ) async {
      r.arrivals = [r.arrival()];
      r.approvalError = StateError('private-server-detail');
      await select(t);
      await tap(t, key('visit-search-approve'));
      await tap(t, key('visit-search-confirm'));
      await t.pumpAndSettle();
      expect(find.textContaining('Confirmation indisponible'), findsOneWidget);
      expect(find.textContaining('private-server-detail'), findsNothing);
      expect(
        t
            .widget<LoyaloAuthPrimaryButton>(key('visit-search-approve'))
            .onPressed,
        isNotNull,
      );
    });
    for (final outcome in [
      CheckInValidationOutcome.alreadyValidated,
      CheckInValidationOutcome.expired,
      CheckInValidationOutcome.unauthorized,
    ]) {
      _ui('Confirmation refusée : $outcome sans faux succès', (
        t,
        r,
        n,
        o,
      ) async {
        r.arrivals = [r.arrival()];
        r.outcome = outcome;
        await select(t);
        await tap(t, key('visit-search-approve'));
        await tap(t, key('visit-search-confirm'));
        await t.pumpAndSettle();
        expect(key('visit-search-feedback'), findsOneWidget);
        expect(find.text('Visite confirmée.'), findsNothing);
        expect(r.directWrites, 0);
      });
    }
  }
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    for (final scale in [1.0, 2.0]) {
      _ui(
        'Recherche responsive $size texte ×$scale avec clavier',
        (t, r, n, o) async {
          t.view.viewInsets = const FakeViewPadding(bottom: 210);
          await t.pump();
          await search(t);
          expect(t.takeException(), isNull);
          await select(t);
          expect(t.takeException(), isNull);
          await tap(t, key('visit-search-reset'));
          expect(t.takeException(), isNull);
        },
        size: size,
        scale: scale,
      );
    }
  }
}
