import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/models/app_user.dart';
import 'package:loyalo/providers/app_providers.dart';
import 'package:loyalo/screens/client/client_visit_history_screen.dart';
import 'package:loyalo/screens/notifications_screen.dart';
import 'package:loyalo/widgets/loyalo_page_header.dart';

import 'support/secondary_pages_fixture.dart';

final _fixtures = <SecondaryPagesFixture>[];

void _notificationTest(
  String description,
  Future<void> Function(WidgetTester) callback,
) {
  testWidgets(description, (tester) async {
    try {
      await callback(tester);
    } finally {
      await tester.runAsync(() async {
        for (final fixture in _fixtures) {
          await fixture.close();
        }
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
      _fixtures.clear();
    }
  });
}

Map<String, Map<String, dynamic>> _notifications() => {
  'morning': notificationDocument(
    title: 'Message reçu ce matin',
    createdAt: DateTime(2026, 11, 15, 10),
  ),
  'earlier': notificationDocument(
    title: 'Message déjà consulté',
    createdAt: DateTime(2026, 11, 15, 9),
    isRead: true,
  ),
  'yesterday': notificationDocument(
    title: 'Message du jour précédent',
    createdAt: DateTime(2026, 11, 14, 16),
  ),
  'other-user': notificationDocument(
    title: 'Donnée d’un autre compte',
    createdAt: DateTime(2026, 11, 15, 11),
    userId: 'other-user',
  ),
};

Future<SecondaryPagesFixture> _openNotifications(
  WidgetTester tester, {
  Map<String, Map<String, dynamic>> notifications = const {},
  bool merchant = false,
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  final fixture = (await tester.runAsync(
    () => SecondaryPagesFixture.create(
      notifications: notifications,
      merchant: merchant,
    ),
  ))!;
  _fixtures.add(fixture);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loyaltyRepositoryProvider.overrideWith((ref) => fixture.repository),
        currentUserProvider.overrideWith(
          (ref) => const AppUser(
            id: 'merchant-one',
            name: 'Compte de contrôle',
            email: 'controle@example.com',
            referralCode: 'TESTCODE',
          ),
        ),
        currentMerchantRestaurantIdProvider.overrideWith(
          (ref) => merchant ? 'shop-one' : null,
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NotificationsScreen(
                    merchant: merchant,
                    restaurantId: merchant ? 'shop-one' : null,
                  ),
                ),
              ),
              child: const Text('Ouvrir les notifications'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Ouvrir les notifications'));
  await tester.pumpAndSettle();
  return fixture;
}

void main() {
  setUpAll(configureSecondaryPageMocks);

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final empty in [true, false]) {
        _notificationTest('Notifications vide=$empty, $size, texte ×$scale', (
          tester,
        ) async {
          await _openNotifications(
            tester,
            notifications: empty ? const {} : _notifications(),
            size: size,
            scale: scale,
          );
          expect(find.byType(LoyaloPageHeader), findsOneWidget);
          expect(find.byType(Image), findsNothing);
          final headerTop = tester.getTopLeft(find.byType(LoyaloPageHeader)).dy;
          expect(headerTop, greaterThanOrEqualTo(47));
          if (empty) {
            expect(find.text('Aucune notification'), findsOneWidget);
            final description = find.text(
              'Vous n’avez aucune notification pour le moment.',
            );
            expect(description, findsOneWidget);
            await tester.ensureVisible(description);
          } else {
            for (final id in ['morning', 'earlier', 'yesterday']) {
              final item = find.byKey(ValueKey('notification-$id'));
              await tester.scrollUntilVisible(item, 350);
              await tester.pumpAndSettle();
              final rect = tester.getRect(item);
              expect(rect.left, greaterThanOrEqualTo(20));
              expect(rect.right, lessThanOrEqualTo(size.width - 20));
              expect(tester.takeException(), isNull);
            }
            expect(find.text('Aucune notification'), findsNothing);
            expect(find.text('Donnée d’un autre compte'), findsNothing);
          }
          expect(
            tester.getTopLeft(find.byType(LoyaloPageHeader)).dy,
            headerTop,
          );
          await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
          await tester.pumpAndSettle();
          expect(find.text('Ouvrir les notifications'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  _notificationTest('Dates regroupées, données exactes et lecture persistée', (
    tester,
  ) async {
    final fixture = await _openNotifications(
      tester,
      notifications: _notifications(),
    );
    expect(find.text('15/11/2026'), findsOneWidget);
    expect(find.text('14/11/2026'), findsOneWidget);
    expect(find.text('15/11/2026 à 10:00'), findsOneWidget);
    final unread = find.byKey(const ValueKey('notification-unread-morning'));
    expect(unread, findsOneWidget);
    expect(
      find.byKey(const ValueKey('notification-unread-earlier')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('notification-morning')));
    await tester.pumpAndSettle();
    final document = await fixture.firestore
        .collection('notifications')
        .doc('morning')
        .get();
    expect(document.data()!['isRead'], true);
    expect(document.data()!['read'], true);
    expect(document.data()!['readAt'], isNotNull);
    expect(unread, findsNothing);
    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  _notificationTest(
    'Le flux réel actualise l’état vide sans contenu de remplacement',
    (tester) async {
      final fixture = await _openNotifications(tester);
      expect(find.text('Aucune notification'), findsOneWidget);
      await fixture.firestore
          .collection('notifications')
          .doc('new')
          .set(
            notificationDocument(
              title: 'Nouvelle donnée reçue',
              body: 'Corps exact transmis par le dépôt.',
              createdAt: DateTime(2026, 11, 15, 12),
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('Aucune notification'), findsNothing);
      expect(find.text('Nouvelle donnée reçue'), findsOneWidget);
      expect(find.text('Corps exact transmis par le dépôt.'), findsOneWidget);
      await fixture.firestore.collection('notifications').doc('new').delete();
      await tester.pumpAndSettle();
      expect(find.text('Aucune notification'), findsOneWidget);
      expect(find.text('Nouvelle donnée reçue'), findsNothing);
    },
  );

  _notificationTest('Notifications commerçant limitées au commerce demandé', (
    tester,
  ) async {
    await _openNotifications(
      tester,
      merchant: true,
      notifications: {
        'owned': notificationDocument(
          title: 'Donnée de mon commerce',
          recipientType: 'merchant',
          createdAt: DateTime(2026, 11, 15, 12),
        ),
        'foreign': notificationDocument(
          title: 'Donnée d’un autre commerce',
          recipientType: 'merchant',
          restaurantId: 'shop-two',
          createdAt: DateTime(2026, 11, 15, 12),
        ),
        'client': notificationDocument(
          title: 'Donnée réservée au client',
          createdAt: DateTime(2026, 11, 15, 12),
        ),
      },
    );
    expect(find.text('Donnée de mon commerce'), findsOneWidget);
    expect(find.text('Donnée d’un autre commerce'), findsNothing);
    expect(find.text('Donnée réservée au client'), findsNothing);
  });

  _notificationTest(
    'La lecture conserve la destination existante de la notification',
    (tester) async {
      final fixture = await _openNotifications(
        tester,
        notifications: {
          'visit': notificationDocument(
            title: 'Visite de contrôle',
            type: 'visit_validated',
            createdAt: DateTime(2026, 11, 15, 12),
          ),
        },
      );
      await tester.tap(find.byKey(const ValueKey('notification-visit')));
      await tester.pumpAndSettle();
      expect(find.byType(ClientVisitHistoryScreen), findsOneWidget);
      final document = await fixture.firestore
          .collection('notifications')
          .doc('visit')
          .get();
      expect(document.data()!['isRead'], true);
    },
  );
}
