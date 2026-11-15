import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/models/restaurant.dart';
import 'package:loyalo/models/restaurant_profile_section.dart';
import 'package:loyalo/providers/app_providers.dart';
import 'package:loyalo/screens/client/restaurant_detail_screen.dart';
import 'package:loyalo/screens/merchant/merchant_establishment_screen.dart';
import 'package:loyalo/screens/merchant/merchant_establishment_section_screen.dart';
import 'package:loyalo/screens/merchant/offers_management_screen.dart';
import 'package:loyalo/screens/merchant/rewards_management_screen.dart';
import 'package:loyalo/widgets/loyalo_auth_ui.dart';
import 'package:loyalo/widgets/loyalo_logo.dart';
import 'package:loyalo/services/merchant_image_service.dart';

import 'support/establishment_fixture.dart';
import 'support/merchant_dashboard_fixture.dart';

class _Observer extends NavigatorObserver {
  Route<dynamic>? latest;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      latest = route;
}

Future<void> reach(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  if (tester.widget(target) is! TextFormField) {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await reach(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder field(String key) => find.byKey(ValueKey('profile-field-$key'));
Finder get save => find.byKey(const Key('profile-save'));
Future<void> open(WidgetTester tester, RestaurantProfileSection section) =>
    tap(tester, find.byKey(ValueKey('establishment-section-${section.name}')));
Future<void> back(WidgetTester tester) =>
    tap(tester, find.byType(LoyaloAuthBackButton));
Future<void> commit(WidgetTester tester, EstablishmentFixture f) async {
  await reach(tester, save);
  final next = f.repo.completedWrites + 1;
  await tester.runAsync(() async {
    await tester.tap(save);
    await f.waitFor(() => f.repo.completedWrites >= next);
  });
  await tester.pumpAndSettle();
  final feedback = find.byType(LoyaloAuthError).evaluate().isNotEmpty
      ? find.byType(LoyaloAuthError)
      : find.text('Rubrique enregistrée.');
  expect(feedback, findsOneWidget);
  final rect = tester.getRect(feedback);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
}

Future<void> edit(WidgetTester tester, RestaurantProfileSection section) async {
  switch (section) {
    case RestaurantProfileSection.general:
      await reach(tester, field('name'));
      await tester.enterText(field('name'), 'Maison rénovée');
    case RestaurantProfileSection.address:
      await reach(tester, field('city'));
      await tester.enterText(field('city'), 'Bain-de-Bretagne');
    case RestaurantProfileSection.hours:
      await tap(tester, find.byKey(const Key('profile-day-sunday')));
    case RestaurantProfileSection.photos:
      await tap(tester, find.byKey(const Key('profile-gallery-add')));
    case RestaurantProfileSection.visibility:
      await tap(tester, find.byKey(const Key('profile-active')));
  }
  await tester.pumpAndSettle();
}

void _ui(
  String name,
  Future<void> Function(WidgetTester, EstablishmentFixture, _Observer) body, {
  bool draft = false,
  bool omitHours = false,
  bool emptyOptional = false,
  int gallery = 1,
  RestaurantStatus status = RestaurantStatus.active,
  Size size = const Size(390, 844),
  double scale = 1,
}) {
  testWidgets(name, (tester) async {
    final f = (await tester.runAsync(
      () => EstablishmentFixture.create(
        draft: draft,
        omitHours: omitHours,
        emptyOptional: emptyOptional,
        gallery: gallery,
        status: status,
      ),
    ))!;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    final observer = _Observer();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loyaltyRepositoryProvider.overrideWith((ref) => f.repo),
            currentMerchantRestaurantIdProvider.overrideWith(
              (ref) => EstablishmentFixture.id,
            ),
            merchantImageServiceProvider.overrideWith((ref) => f.images),
          ],
          child: MaterialApp(
            navigatorObservers: [observer],
            theme: ThemeData(useMaterial3: true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const MerchantEstablishmentScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await body(tester, f, observer);
    } finally {
      if (f.repo.heldWrite != null && !f.repo.heldWrite!.isCompleted) {
        f.repo.heldWrite!.complete();
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await f.repo.stopListening();
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.runAsync(() => f.close(disposeRepository: false));
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final auth = DashboardTestAuth();
  setUpAll(() {
    FirebasePlatform.instance = DashboardTestCore();
    FirebaseAuthPlatform.instance = auth;
  });
  setUp(() {
    auth.signedIn = true;
    auth.name = 'Camille';
  });

  _ui(
    'Une page de navigation réelle, sans formulaire ni logo, ouvre les cinq rubriques',
    (tester, f, observer) async {
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(LoyaloWordmark), findsNothing);
      expect(find.byType(LoyaloDashboardMark), findsNothing);
      expect(find.text('Maison du coin'), findsOneWidget);
      expect(find.text('Rennes'), findsOneWidget);
      expect(find.text('Commerce actif'), findsOneWidget);
      expect(find.text('5 sur 5 renseignés'), findsOneWidget);
      for (final section in RestaurantProfileSection.values) {
        await open(tester, section);
        expect(
          tester
              .widget<MerchantEstablishmentSectionScreen>(
                find.byType(MerchantEstablishmentSectionScreen),
              )
              .section,
          section,
        );
        expect(find.text('Enregistrer'), findsOneWidget);
        await back(tester);
        expect(find.byType(MerchantEstablishmentSectionScreen), findsNothing);
        expect(find.byType(MerchantEstablishmentScreen), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final section in RestaurantProfileSection.values) {
    _ui('Enregistrement indépendant : ${section.name}', (
      tester,
      f,
      observer,
    ) async {
      final original = await tester.runAsync(f.data);
      await open(tester, section);
      await edit(tester, section);
      expect(await tester.runAsync(f.data), original);
      await commit(tester, f);
      expect(find.text('Rubrique enregistrée.'), findsOneWidget);
      expect(f.repo.writes, hasLength(1));
      final sent = f.repo.writes.single;
      expect(sent.section, section);
      expect(sent.changes.keys.every(section.fields.contains), true);
      final stored = (await tester.runAsync(f.data))!;
      expect(stored['rewardThreshold'], original!['rewardThreshold']);
      expect(stored['rewardLabel'], original['rewardLabel']);
      expect(
        stored['loyaltyProgramEnabled'],
        original['loyaltyProgramEnabled'],
      );
      expect(stored['backendOnly'], original['backendOnly']);
      if (section != RestaurantProfileSection.general) {
        expect(stored['name'], original['name']);
      }
      if (section != RestaurantProfileSection.address) {
        expect(stored['city'], original['city']);
      }
      if (section != RestaurantProfileSection.hours) {
        expect(stored['openingHours'], original['openingHours']);
      }
      if (section != RestaurantProfileSection.photos) {
        expect(stored['galleryUrls'], original['galleryUrls']);
      }
      if (section != RestaurantProfileSection.visibility) {
        expect(stored['active'], original['active']);
        expect(stored['status'], original['status']);
      }
      await back(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    _ui('Erreur ${section.name} : saisie conservée et nouvel essai', (
      tester,
      f,
      observer,
    ) async {
      f.repo.writeError = StateError('Réseau indisponible');
      final original = await tester.runAsync(f.data);
      await open(tester, section);
      await edit(tester, section);
      await commit(tester, f);
      expect(find.textContaining('Impossible d’enregistrer'), findsOneWidget);
      expect(await tester.runAsync(f.data), original);
      f.repo.writeError = null;
      await commit(tester, f);
      expect(find.text('Rubrique enregistrée.'), findsOneWidget);
      expect(f.repo.writes, hasLength(2));
    });

    _ui(
      'Quitter ${section.name} : confirmation, poursuite et abandon sans écriture',
      (tester, f, observer) async {
        final original = await tester.runAsync(f.data);
        await open(tester, section);
        await edit(tester, section);
        await back(tester);
        expect(find.text('Modifications non enregistrées'), findsOneWidget);
        await tap(tester, find.text('Continuer la modification'));
        expect(find.byType(MerchantEstablishmentSectionScreen), findsOneWidget);
        await back(tester);
        await tap(tester, find.text('Quitter sans enregistrer'));
        expect(find.byType(MerchantEstablishmentScreen), findsOneWidget);
        expect(find.byType(MerchantEstablishmentSectionScreen), findsNothing);
        expect(f.repo.writes, isEmpty);
        expect(await tester.runAsync(f.data), original);
        if (section == RestaurantProfileSection.photos) {
          expect(
            f.images.deleted,
            contains('https://images.example/new-gallery-1.jpg'),
          );
        }
      },
    );
  }

  _ui(
    'Horaires par défaut : progression honnête et confirmation explicite',
    (tester, f, observer) async {
      expect(find.text('1 sur 5 renseignés'), findsOneWidget);
      expect(
        (await tester.runAsync(f.data))!.containsKey('openingHours'),
        false,
      );
      await open(tester, RestaurantProfileSection.hours);
      expect(find.textContaining('Les horaires par défaut'), findsOneWidget);
      await commit(tester, f);
      await back(tester);
      expect(find.text('2 sur 5 renseignés'), findsOneWidget);
      expect((await tester.runAsync(f.data))!['active'], false);
    },
    draft: true,
    emptyOptional: true,
    omitHours: true,
  );

  for (final status in [
    RestaurantStatus.draft,
    RestaurantStatus.pendingReview,
    RestaurantStatus.suspended,
  ]) {
    _ui(
      'Visibilité ${status.name} : activation indisponible et aucune publication automatique',
      (tester, f, observer) async {
        final original = await tester.runAsync(f.data);
        await open(tester, RestaurantProfileSection.visibility);
        expect(
          tester
              .widget<SwitchListTile>(find.byKey(const Key('profile-active')))
              .onChanged,
          isNull,
        );
        expect(await tester.runAsync(f.data), original);
        expect(f.repo.writes, isEmpty);
        await back(tester);
        await open(tester, RestaurantProfileSection.address);
        await edit(tester, RestaurantProfileSection.address);
        await commit(tester, f);
        final stored = (await tester.runAsync(f.data))!;
        expect(stored['active'], false);
        expect(stored['status'], status.firestoreValue);
      },
      status: status,
      draft: status == RestaurantStatus.draft,
    );
  }

  _ui('Les validateurs nom, email, site et horaires restent effectifs', (
    tester,
    f,
    observer,
  ) async {
    await open(tester, RestaurantProfileSection.general);
    for (final entry in [
      ('name', '', 'Nom obligatoire'),
      ('email', 'email faux', 'Email invalide'),
      ('website', 'site sans point', 'Site invalide'),
    ]) {
      await reach(tester, field(entry.$1));
      final initial = tester
          .widget<TextFormField>(field(entry.$1))
          .controller!
          .text;
      await tester.enterText(field(entry.$1), entry.$2);
      await tap(tester, save);
      expect(find.text(entry.$3), findsOneWidget);
      expect(tester.getRect(find.text(entry.$3)).top, greaterThanOrEqualTo(0));
      expect(
        tester.getRect(find.text(entry.$3)).bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
      expect(f.repo.writes, isEmpty);
      await tester.enterText(field(entry.$1), initial);
    }
    await back(tester);
    await open(tester, RestaurantProfileSection.hours);
    await tester.enterText(field('monday-open'), '9h');
    await tap(tester, save);
    expect(find.text('HH:MM'), findsOneWidget);
    expect(f.repo.writes, isEmpty);
  });

  _ui(
    'Photos : upload isolé, sauvegarde explicite et suppression après succès',
    (tester, f, observer) async {
      await open(tester, RestaurantProfileSection.photos);
      await tap(tester, find.byKey(const Key('profile-photo-logo-add')));
      expect(f.images.requests.single.isolated, true);
      expect(
        (await tester.runAsync(f.data))!['logoUrl'],
        'https://images.example/logo.jpg',
      );
      expect(f.images.deleted, isEmpty);
      await commit(tester, f);
      expect(
        (await tester.runAsync(f.data))!['logoUrl'],
        'https://images.example/new-logo-1.jpg',
      );
      expect(f.images.deleted, contains('https://images.example/logo.jpg'));
      expect(
        f.images.deleted,
        isNot(contains('https://images.example/new-logo-1.jpg')),
      );
    },
  );

  _ui('Erreur de sélection de photo : message lisible et aucune sauvegarde', (
    tester,
    f,
    observer,
  ) async {
    final original = await tester.runAsync(f.data);
    f.images.error = const MerchantImageException(
      'Format non supporté. Utilisez une image JPG, PNG ou WebP.',
    );
    await open(tester, RestaurantProfileSection.photos);
    await tap(tester, find.byKey(const Key('profile-photo-logo-add')));
    expect(find.textContaining('Format non supporté'), findsOneWidget);
    expect(f.repo.writes, isEmpty);
    expect(await tester.runAsync(f.data), original);
    await back(tester);
    expect(find.byType(AlertDialog), findsNothing);
  });

  _ui('Accessibilité : commandes des rubriques et progression annoncée', (
    tester,
    f,
    observer,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpAndSettle();
      for (final section in RestaurantProfileSection.values) {
        final target = find.byKey(
          ValueKey('establishment-section-${section.name}'),
        );
        await reach(tester, target);
        final semantic = find.bySemanticsLabel(RegExp(section.title));
        expect(
          tester
              .getSemantics(semantic)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          true,
        );
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    } finally {
      handle.dispose();
    }
  });

  _ui(
    'Une réponse perdue après sauvegarde ne provoque pas la suppression de l’image enregistrée',
    (tester, f, observer) async {
      f.repo.failAfterCommit = true;
      await open(tester, RestaurantProfileSection.photos);
      await tap(tester, find.byKey(const Key('profile-photo-logo-add')));
      await commit(tester, f);
      expect(find.textContaining('Réponse réseau perdue'), findsOneWidget);
      await back(tester);
      await tap(tester, find.text('Quitter sans enregistrer'));
      expect(
        (await tester.runAsync(f.data))!['logoUrl'],
        'https://images.example/new-logo-1.jpg',
      );
      expect(
        f.images.deleted,
        isNot(contains('https://images.example/new-logo-1.jpg')),
      );
    },
  );

  _ui('Galerie : limite de 8, retrait différé et sélection annulée', (
    tester,
    f,
    observer,
  ) async {
    await open(tester, RestaurantProfileSection.photos);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('profile-gallery-add')))
          .onPressed,
      isNull,
    );
    await tap(tester, find.byTooltip('Retirer la photo 1'));
    expect(find.text('Galerie (7/8)'), findsOneWidget);
    expect((await tester.runAsync(f.data))!['galleryUrls'], hasLength(8));
    f.images.cancel = true;
    await tap(tester, find.byKey(const Key('profile-gallery-add')));
    expect(find.text('Galerie (7/8)'), findsOneWidget);
    f.images.cancel = false;
    await tap(tester, find.byKey(const Key('profile-gallery-add')));
    expect(find.text('Galerie (8/8)'), findsOneWidget);
    await commit(tester, f);
    expect((await tester.runAsync(f.data))!['galleryUrls'], hasLength(8));
  }, gallery: 8);

  _ui('Double appui et retour pendant une sauvegarde : une seule écriture', (
    tester,
    f,
    observer,
  ) async {
    await open(tester, RestaurantProfileSection.general);
    await edit(tester, RestaurantProfileSection.general);
    f.repo.heldWrite = Completer<void>();
    await reach(tester, save);
    final action = tester.widget<LoyaloAuthPrimaryButton>(save).onPressed!;
    action();
    action();
    await tester.pump();
    expect(f.repo.writes, hasLength(1));
    expect(tester.widget<LoyaloAuthPrimaryButton>(save).onPressed, isNull);
    expect(tester.widget<TextFormField>(field('name')).enabled, false);
    await tester.runAsync(() async {
      f.repo.heldWrite!.complete();
      await f.waitFor(() => f.repo.completedWrites == 1);
    });
    await tester.pumpAndSettle();
    expect(find.text('Rubrique enregistrée.'), findsOneWidget);
  });

  for (final item in [
    ('establishment-public', RestaurantDetailScreen),
    ('establishment-loyalty', RewardsManagementScreen),
    ('establishment-offers', OffersManagementScreen),
  ]) {
    _ui('Navigation existante : ${item.$1}', (tester, f, observer) async {
      final target = find.byKey(ValueKey(item.$1));
      await reach(tester, target);
      final context = tester.element(find.byType(MerchantEstablishmentScreen));
      await tester.tap(target);
      await tester.idle();
      final route = observer.latest! as MaterialPageRoute<dynamic>;
      expect(route.builder(context).runtimeType, item.$2);
    });
  }

  for (final size in const [
    Size(320, 568),
    Size(360, 740),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    for (final scale in [1.0, 2.0]) {
      _ui(
        'Responsive $size texte ×$scale, cinq rubriques et clavier',
        (tester, f, observer) async {
          for (final section in RestaurantProfileSection.values) {
            await open(tester, section);
            if (section == RestaurantProfileSection.general ||
                section == RestaurantProfileSection.address) {
              tester.view.viewInsets = const FakeViewPadding(bottom: 280);
              await tester.pumpAndSettle();
            }
            await reach(tester, save);
            expect(tester.getRect(save).right, lessThanOrEqualTo(size.width));
            for (final paragraph in tester.renderObjectList<RenderParagraph>(
              find.byType(RichText),
            )) {
              expect(
                paragraph.didExceedMaxLines,
                false,
                reason: '${section.name}: ${paragraph.text.toPlainText()}',
              );
            }
            expect(tester.takeException(), isNull);
            tester.view.viewInsets = FakeViewPadding.zero;
            await tester.pumpAndSettle();
            await back(tester);
          }
          for (final paragraph in tester.renderObjectList<RenderParagraph>(
            find.byType(RichText),
          )) {
            expect(paragraph.didExceedMaxLines, false);
          }
          expect(tester.takeException(), isNull);
        },
        size: size,
        scale: scale,
        emptyOptional: true,
      );
    }
  }
}
