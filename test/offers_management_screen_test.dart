import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:loyalo/providers/app_providers.dart';
import 'package:loyalo/screens/merchant/merchant_root_screen.dart';
import 'package:loyalo/screens/merchant/offers_management_screen.dart';
import 'package:loyalo/theme/app_theme.dart';
import 'package:loyalo/widgets/loyalo_auth_ui.dart';
import 'package:loyalo/widgets/loyalo_logo.dart';
import 'package:loyalo/widgets/loyalo_merchant_dashboard_ui.dart';
import 'package:loyalo/widgets/loyalo_page_header.dart';
import 'package:loyalo/widgets/loyalo_ui.dart';

import 'support/merchant_dashboard_fixture.dart';
import 'support/offers_fixture.dart';

void offersTest(
  String name,
  Future<void> Function(WidgetTester, OffersUiFixture) body,
) {
  testWidgets(name, (tester) async {
    final f = (await tester.runAsync(OffersUiFixture.create))!;
    try {
      await body(tester, f);
    } finally {
      await tester.runAsync(f.repo.stopListening);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(f.database.close);
    }
  });
}

Future<void> pump(
  WidgetTester tester,
  OffersUiFixture f, {
  Widget screen = const OffersManagementScreen(),
  Size size = const Size(390, 844),
  double scale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loyaltyRepositoryProvider.overrideWith((ref) => f.repo),
        currentMerchantRestaurantIdProvider.overrideWith(
          (ref) => OffersUiFixture.shopId,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light().copyWith(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder field(String name) => find.descendant(
  of: find.byKey(Key('offer-$name')),
  matching: find.byType(TextFormField),
);
Finder get publish => find.descendant(
  of: find.byKey(const Key('offer-publish')),
  matching: find.byType(LoyaloGradientButton),
);

Future<void> reach(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await reach(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String name, String value) async {
  await reach(tester, field(name));
  await tester.enterText(field(name), value);
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester) =>
    tap(tester, find.byKey(const Key('offers-create')));

Future<void> selectDate(WidgetTester tester, String name, DateTime date) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tap(tester, find.byKey(Key('offer-$name')));
  final picker = find.byType(DatePickerDialog);
  expect(tester.widget<DatePickerDialog>(picker).firstDate, DateTime(2024));
  expect(tester.widget<DatePickerDialog>(picker).lastDate, DateTime(2035));
  await tester.tap(find.byTooltip('Switch to input'));
  await tester.pumpAndSettle();
  final input = find.descendant(of: picker, matching: find.byType(TextField));
  final text = MaterialLocalizations.of(
    tester.element(picker),
  ).formatCompactDate(date);
  await tester.enterText(input, text);
  await tester.tap(find.descendant(of: picker, matching: find.text('OK')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    FirebasePlatform.instance = DashboardTestCore();
    FirebaseAuthPlatform.instance = DashboardTestAuth();
  });

  offersTest('état vide compact, messages exacts, CTA et aucun logo', (
    tester,
    f,
  ) async {
    await pump(tester, f);
    expect(find.text('Offres exclusives'), findsOneWidget);
    expect(find.text('Aucune offre exclusive pour le moment.'), findsOneWidget);
    expect(
      find.text('Créez une offre temporaire pour vos clients Loyalo.'),
      findsOneWidget,
    );
    expect(find.byType(LoyaloWordmark), findsNothing);
    expect(find.byType(LoyaloDashboardMark), findsNothing);
    expect(find.byType(LoyaloAuthHeader), findsNothing);
    final icon = find.byWidgetPredicate(
      (widget) => widget is Image && (widget.image is ResizeImage),
    );
    expect(icon, findsOneWidget);
    expect(tester.getSize(icon).height, 80);
    expect(tester.widget<Image>(icon).fit, BoxFit.contain);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      tester.getBottomLeft(find.byKey(const Key('offers-create'))).dy,
      lessThan(600),
    );
    await open(tester);
    expect(find.text('Créer une offre exclusive'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  offersTest(
    'liste issue du repository, périodes, statuts et conditions disponibles',
    (tester, f) async {
      final current = OffersUiFixture.sample(newCustomersOnly: true);
      await tester.runAsync(
        () => f.seed([
          current,
          OffersUiFixture.sample(
            id: 'future',
            title: 'À découvrir bientôt',
            startDays: 2,
          ),
          OffersUiFixture.sample(
            id: 'inactive',
            title: 'Offre mise en pause',
            active: false,
          ),
          OffersUiFixture.sample(
            id: 'expired',
            title: 'Offre terminée',
            startDays: -10,
            endDays: -1,
          ),
          OffersUiFixture.sample(
            id: 'foreign',
            title: 'Offre autre commerce',
            restaurantId: 'other-shop',
          ),
        ]),
      );
      await pump(tester, f);
      for (final title in [
        'Pause café',
        'À découvrir bientôt',
        'Offre mise en pause',
        'Offre terminée',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      for (final status in ['Active', 'Inactive', 'Expirée', 'À venir']) {
        expect(find.text(status), findsOneWidget);
      }
      expect(find.text('Offre autre commerce'), findsNothing);
      expect(find.text('3 visites min.'), findsNWidgets(4));
      expect(find.text('Nouveaux clients uniquement'), findsOneWidget);
      final date = DateFormat('dd/MM/yyyy');
      expect(
        find.text(
          'Du ${date.format(current.startsAt)} au ${date.format(current.endsAt)}',
        ),
        findsNWidgets(2),
      );
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('offer-toggle-expired')))
            .onChanged,
        isNull,
      );
      expect(find.text('Aucune offre exclusive pour le moment.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  offersTest(
    'titre obligatoire, valeurs initiales et annulation sans écriture',
    (tester, f) async {
      await pump(tester, f);
      await open(tester);
      expect(tester.widget<LoyaloGradientButton>(publish).onPressed, isNull);
      expect(
        tester.widget<TextFormField>(field('min-visits')).controller!.text,
        '0',
      );
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('offer-active')))
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('offer-new-customers')),
            )
            .value,
        isFalse,
      );
      await enter(tester, 'title', '   ');
      expect(tester.widget<LoyaloGradientButton>(publish).onPressed, isNull);
      await enter(tester, 'title', 'Offre non publiée');
      expect(tester.widget<LoyaloGradientButton>(publish).onPressed, isNotNull);
      await tap(tester, find.byKey(const Key('offer-cancel')));
      expect(find.byType(Dialog), findsNothing);
      expect(f.repo.publications, 0);
      expect(
        (await f.firestore.collection('exclusiveOffers').get()).docs,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  offersTest(
    'publication conserve tous les champs, le commerce et la borne 999',
    (tester, f) async {
      await pump(tester, f);
      await open(tester);
      final before = DateTime.now();
      await enter(tester, 'title', '  Goûter du quartier  ');
      await enter(tester, 'description', '  Un dessert avec votre boisson.  ');
      await enter(tester, 'min-visits', '1234');
      await tap(tester, find.byKey(const Key('offer-active')));
      await tap(tester, find.byKey(const Key('offer-new-customers')));
      await tap(tester, publish);
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Offre exclusive publiée.'), findsOneWidget);
      final data = (await f.firestore.collection('exclusiveOffers').get())
          .docs
          .single
          .data();
      expect(data['restaurantId'], OffersUiFixture.shopId);
      expect(data['title'], 'Goûter du quartier');
      expect(data['description'], 'Un dessert avec votre boisson.');
      expect(data['minVisitsRequired'], 999);
      expect(data['active'], false);
      expect(data['newCustomersOnly'], true);
      final starts = (data['startsAt'] as Timestamp).toDate();
      final ends = (data['endsAt'] as Timestamp).toDate();
      expect(starts.difference(before).inSeconds.abs(), lessThan(10));
      expect(ends.difference(starts).inDays, 7);
      expect(f.repo.publications, 1);
      expect(tester.takeException(), isNull);
    },
  );

  offersTest(
    'description et visites vides restent facultatives, saisie numérique',
    (tester, f) async {
      await pump(tester, f);
      await open(tester);
      await enter(tester, 'title', 'Offre simple');
      await enter(tester, 'min-visits', 'a12z');
      expect(
        tester.widget<TextFormField>(field('min-visits')).controller!.text,
        '12',
      );
      await enter(tester, 'min-visits', '');
      await tap(tester, publish);
      final data = (await f.firestore.collection('exclusiveOffers').get())
          .docs
          .single
          .data();
      expect(data['minVisitsRequired'], 0);
      expect(data['description'], '');
      expect(data['active'], true);
      expect(tester.takeException(), isNull);
    },
  );

  offersTest(
    'dates invalides : message existant, blocage puis réajustement de la fin',
    (tester, f) async {
      await pump(tester, f);
      await open(tester);
      await enter(tester, 'title', 'Offre datée');
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      await selectDate(tester, 'end', yesterday);
      expect(
        find.text('La date de fin doit être après la date de début.'),
        findsOneWidget,
      );
      expect(tester.widget<LoyaloGradientButton>(publish).onPressed, isNull);
      final next = DateTime(now.year, now.month, now.day + 2);
      await selectDate(tester, 'start', next);
      expect(
        find.text('La date de fin doit être après la date de début.'),
        findsNothing,
      );
      expect(tester.widget<LoyaloGradientButton>(publish).onPressed, isNotNull);
      await tap(tester, publish);
      final data = (await f.firestore.collection('exclusiveOffers').get())
          .docs
          .single
          .data();
      expect((data['startsAt'] as Timestamp).toDate(), next);
      expect((data['endsAt'] as Timestamp).toDate(), next);
      expect(tester.takeException(), isNull);
    },
  );

  offersTest(
    'modification préremplie, identifiant conservé et aucune création',
    (tester, f) async {
      final offer = OffersUiFixture.sample(
        active: false,
        newCustomersOnly: true,
      );
      await tester.runAsync(() => f.seed([offer]));
      await pump(tester, f);
      await tap(tester, find.byKey(const Key('offer-edit-current')));
      expect(find.text('Modifier l’offre exclusive'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(field('title')).controller!.text,
        offer.title,
      );
      expect(
        tester.widget<TextFormField>(field('description')).controller!.text,
        offer.description,
      );
      expect(
        tester.widget<TextFormField>(field('min-visits')).controller!.text,
        '3',
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('offer-new-customers')),
            )
            .value,
        true,
      );
      await enter(tester, 'title', 'Nouvelle pause');
      await enter(tester, 'min-visits', '5');
      await tap(tester, publish);
      expect(find.text('Offre exclusive modifiée.'), findsOneWidget);
      final docs = (await f.firestore.collection('exclusiveOffers').get()).docs;
      expect(docs, hasLength(1));
      expect(docs.single.id, offer.id);
      expect(docs.single.data()['minVisitsRequired'], 5);
      expect(docs.single.data()['title'], 'Nouvelle pause');
      expect(docs.single.data()['active'], false);
      expect(f.repo.publications, 0);
      expect(tester.takeException(), isNull);
    },
  );

  offersTest(
    'activation réelle et erreur de modification sans changement local',
    (tester, f) async {
      await tester.runAsync(() => f.seed([OffersUiFixture.sample()]));
      await pump(tester, f);
      await tap(tester, find.byKey(const Key('offer-toggle-current')));
      expect(
        (await f.firestore.collection('exclusiveOffers').doc('current').get())
            .data()!['active'],
        false,
      );
      f.repo.toggleError = StateError('Réseau indisponible');
      await tap(tester, find.byKey(const Key('offer-toggle-current')));
      expect(
        find.textContaining('Impossible de modifier l’offre :'),
        findsOneWidget,
      );
      expect(
        (await f.firestore.collection('exclusiveOffers').doc('current').get())
            .data()!['active'],
        false,
      );
      expect(tester.takeException(), isNull);
    },
  );

  offersTest('suppression : annulation et confirmation préservées', (
    tester,
    f,
  ) async {
    await tester.runAsync(() => f.seed([OffersUiFixture.sample()]));
    await pump(tester, f);
    await tap(tester, find.byKey(const Key('offer-edit-current')));
    await tap(tester, find.byKey(const Key('offer-delete')));
    expect(find.text('Supprimer l’offre ?'), findsOneWidget);
    await tap(tester, find.widgetWithText(TextButton, 'Annuler'));
    expect(
      (await f.firestore.collection('exclusiveOffers').get()).docs,
      hasLength(1),
    );
    await tap(tester, find.byKey(const Key('offer-delete')));
    await tap(tester, find.widgetWithText(TextButton, 'Supprimer').last);
    expect(
      (await f.firestore.collection('exclusiveOffers').get()).docs,
      isEmpty,
    );
    expect(find.text('Offre supprimée.'), findsOneWidget);
    expect(find.text('Aucune offre exclusive pour le moment.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  offersTest(
    'erreur de publication visible, saisie conservée et nouvel essai',
    (tester, f) async {
      f.repo.publishError = StateError('Réseau indisponible');
      await pump(tester, f);
      await open(tester);
      await enter(tester, 'title', 'Mon offre conservée');
      await enter(tester, 'description', 'Description conservée');
      await tap(tester, publish);
      expect(
        find.text(
          'Impossible de publier l\'offre : Bad state: Réseau indisponible',
        ),
        findsOneWidget,
      );
      expect(find.byType(LoyaloAuthError), findsOneWidget);
      expect(
        tester.widget<TextFormField>(field('title')).controller!.text,
        'Mon offre conservée',
      );
      expect(
        tester.widget<TextFormField>(field('description')).controller!.text,
        'Description conservée',
      );
      expect(
        (await f.firestore.collection('exclusiveOffers').get()).docs,
        isEmpty,
      );
      f.repo.publishError = null;
      await tap(tester, publish);
      expect(find.text('Offre exclusive publiée.'), findsOneWidget);
      expect(
        (await f.firestore.collection('exclusiveOffers').get()).docs,
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  offersTest('publication en cours : double appui ne crée qu’une offre', (
    tester,
    f,
  ) async {
    f.repo.publicationGate = Completer<void>();
    await pump(tester, f);
    await open(tester);
    await enter(tester, 'title', 'Une seule offre');
    await reach(tester, publish);
    final callback = tester.widget<LoyaloGradientButton>(publish).onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(f.repo.publications, 1);
    expect(tester.widget<LoyaloGradientButton>(publish).loading, true);
    expect(tester.widget<LoyaloGradientButton>(publish).onPressed, isNull);
    f.repo.publicationGate!.complete();
    await tester.pumpAndSettle();
    expect(
      (await f.firestore.collection('exclusiveOffers').get()).docs,
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  offersTest(
    'fermeture pendant la requête : aucune mise à jour d’un dialogue détruit',
    (tester, f) async {
      f.repo.publicationGate = Completer<void>();
      await pump(tester, f);
      await open(tester);
      await enter(tester, 'title', 'Requête déjà envoyée');
      await reach(tester, publish);
      tester.widget<LoyaloGradientButton>(publish).onPressed!();
      await tester.pump();
      final cancel = find.byKey(const Key('offer-cancel'));
      await tester.ensureVisible(cancel);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      f.repo.publicationGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  offersTest(
    'erreur de suppression conserve le dialogue et permet de réessayer',
    (tester, f) async {
      await tester.runAsync(() => f.seed([OffersUiFixture.sample()]));
      f.repo.deleteError = StateError('Réseau indisponible');
      await pump(tester, f);
      await tap(tester, find.byKey(const Key('offer-edit-current')));
      await tap(tester, find.byKey(const Key('offer-delete')));
      await tap(tester, find.widgetWithText(TextButton, 'Supprimer').last);
      expect(
        find.textContaining('Impossible de supprimer l’offre :'),
        findsOneWidget,
      );
      expect(
        (await f.firestore.collection('exclusiveOffers').get()).docs,
        hasLength(1),
      );
      f.repo.deleteError = null;
      await tap(tester, find.byKey(const Key('offer-delete')));
      await tap(tester, find.widgetWithText(TextButton, 'Supprimer').last);
      expect(
        (await f.firestore.collection('exclusiveOffers').get()).docs,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  offersTest(
    'navigation commerçant : cinq onglets, Offres sélectionné et retour du formulaire',
    (tester, f) async {
      await pump(tester, f, screen: const MerchantRootScreen());
      final nav = find.byType(LoyaloMerchantBottomNav);
      tester.widget<LoyaloMerchantBottomNav>(nav).onTap(4);
      await tester.pumpAndSettle();
      expect(tester.widget<LoyaloMerchantBottomNav>(nav).selectedIndex, 4);
      expect(
        tester
            .widget<LoyaloMerchantBottomNav>(nav)
            .items
            .map((item) => item.label),
        ['Accueil', 'Clients', 'Valider', 'Récompenses', 'Offres'],
      );
      expect(find.byType(LoyaloPageHeader), findsOneWidget);
      await open(tester);
      await tap(tester, find.byKey(const Key('offer-cancel')));
      expect(tester.widget<LoyaloMerchantBottomNav>(nav).selectedIndex, 4);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in const [
    Size(320, 568),
    Size(390, 844),
    Size(430, 932),
    Size(360, 640),
    Size(412, 915),
  ]) {
    for (final scale in [1.0, 2.0]) {
      offersTest('vide, liste et formulaire avec clavier — $size texte $scale', (
        tester,
        f,
      ) async {
        await pump(
          tester,
          f,
          size: size,
          scale: scale,
          platform: size.width == 360 || size.width == 412
              ? TargetPlatform.android
              : TargetPlatform.iOS,
        );
        await reach(tester, find.byKey(const Key('offers-create')));
        expect(tester.takeException(), isNull);
        await tester.runAsync(
          () => f.seed([
            OffersUiFixture.sample(
              title:
                  'Une offre dont le titre doit rester lisible sur un écran étroit',
              newCustomersOnly: true,
            ),
          ]),
        );
        await tester.pumpAndSettle();
        expect(find.text('Pause café'), findsNothing);
        await tap(tester, find.byKey(const Key('offer-edit-current')));
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        for (final name in ['title', 'description', 'min-visits']) {
          await enter(
            tester,
            name,
            name == 'min-visits' ? '8' : 'Offre accessible',
          );
          final bounds = tester.getRect(field(name));
          expect(bounds.bottom, lessThanOrEqualTo(size.height - 280 + 1));
          expect(tester.takeException(), isNull);
        }
        for (final key in [
          'offer-start',
          'offer-end',
          'offer-active',
          'offer-new-customers',
          'offer-publish',
          'offer-cancel',
        ]) {
          await reach(tester, find.byKey(Key(key)));
          final bounds = tester.getRect(find.byKey(Key(key)));
          // Les grands contrôles défilent ; au moins leur début reste atteignable.
          expect(bounds.top, lessThan(size.height - 280));
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(size.width));
          expect(tester.takeException(), isNull);
        }
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        await tap(tester, find.byKey(const Key('offer-cancel')));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
