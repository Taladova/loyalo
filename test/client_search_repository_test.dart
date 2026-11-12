import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/client_search_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Annuaire commerçant réel : critères existants et isolation', () async {
    final f = await ClientSearchFixture.create();
    addTearDown(f.close);
    expect(f.repo.directory.map((c) => c.id).toSet(), {
      'client-0',
      'client-1',
      'client-2',
    });
    expect(f.repo.searchClients('MÉLIE').map((c) => c.id), ['client-0']);
    expect(f.repo.searchClients('+3361122').map((c) => c.id), ['client-0']);
    expect(f.repo.searchClients('client-1@').map((c) => c.id), ['client-1']);
    expect(f.repo.searchClients('riviere'), isEmpty);
    expect(f.repo.searchClients(' Amélie '), isEmpty);
    expect(f.repo.searchClients('06 11 22'), isEmpty);
    expect(f.repo.searchClients('foreign@'), isEmpty);
    expect(f.repo.searchClients('  '), hasLength(3));
    expect(f.firestore.reads, isNot(contains('foreign-client')));
    expect(f.repo.merchantClientsLoading, false);
    expect(f.repo.merchantClientsLoadError, isNull);
    final reads = f.firestore.reads.length;
    for (final query in ['A', 'Am', 'Amé', 'Amélie', '+336', 'client-0@']) {
      f.repo.searchClients(query);
    }
    expect(f.firestore.reads.length, reads);
  });

  test(
    'Une lecture de profil refusée est exposée comme erreur, pas comme succès vide',
    () async {
      final f = await ClientSearchFixture.create(start: false);
      addTearDown(f.close);
      f.firestore.denied.add('client-0');
      f.repo.startListeningForMerchant(
        ClientSearchFixture.shopId,
        ownerUid: ClientSearchFixture.ownerId,
      );
      await f.waitFor(
        () =>
            f.repo.merchantClientsLoadError != null &&
            !f.repo.merchantClientsLoading,
      );
      expect(f.repo.merchantClientsLoadError, isA<FirebaseException>());
      expect(f.repo.directory.map((c) => c.id), isNot(contains('client-0')));
      f.firestore.denied.clear();
      await f.repo.retryRestaurants();
      await f.waitFor(
        () => f.repo.directory.length == 3 && !f.repo.merchantClientsLoading,
      );
      expect(f.repo.merchantClientsLoadError, isNull);
    },
  );

  test('Chargement asynchrone réel, puis données disponibles', () async {
    final f = await ClientSearchFixture.create(start: false);
    addTearDown(f.close);
    final pending = Completer<void>();
    f.firestore.pendingRead = pending;
    f.repo.startListeningForMerchant(
      ClientSearchFixture.shopId,
      ownerUid: ClientSearchFixture.ownerId,
    );
    await f.waitFor(
      () => f.firestore.reads.isNotEmpty && f.repo.merchantClientsLoading,
    );
    expect(f.repo.merchantClientsLoadError, isNull);
    pending.complete();
    await f.waitFor(
      () => f.repo.directory.length == 3 && !f.repo.merchantClientsLoading,
    );
    expect(f.repo.merchantClientsLoadError, isNull);
  });

  test(
    'Un annuaire réellement vide termine son chargement sans faux clients',
    () async {
      final f = await ClientSearchFixture.create(clients: 0);
      addTearDown(f.close);
      expect(f.repo.directory, isEmpty);
      expect(f.repo.merchantClientsLoading, false);
      expect(f.repo.merchantClientsLoadError, isNull);
      expect(f.firestore.reads, isEmpty);
    },
  );

  test(
    'Une lecture terminée après déconnexion ne republie ni annuaire ni état',
    () async {
      final f = await ClientSearchFixture.create(start: false);
      addTearDown(f.close);
      final pending = Completer<void>();
      f.firestore.pendingRead = pending;
      f.repo.startListeningForMerchant(
        ClientSearchFixture.shopId,
        ownerUid: ClientSearchFixture.ownerId,
      );
      await f.waitFor(
        () => f.firestore.reads.isNotEmpty && f.repo.merchantClientsLoading,
      );
      await f.repo.stopListening();
      expect(f.repo.merchantClientsLoading, false);
      expect(f.repo.merchantClientsLoadError, isNull);
      pending.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(f.repo.directory, isEmpty);
      expect(f.repo.merchantClientsLoading, false);
      expect(f.repo.merchantClientsLoadError, isNull);
    },
  );
}
