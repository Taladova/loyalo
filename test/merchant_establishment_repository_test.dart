import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/models/restaurant.dart';
import 'package:loyalo/models/restaurant_profile_section.dart';

import 'support/establishment_fixture.dart';
import 'support/merchant_dashboard_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    FirebasePlatform.instance = DashboardTestCore();
    FirebaseAuthPlatform.instance = DashboardTestAuth();
  });

  for (final section in RestaurantProfileSection.values) {
    test(
      'Sauvegarde ${section.name} : seuls les champs choisis changent',
      () async {
        final f = await EstablishmentFixture.create();
        try {
          final before = await f.data();
          final changes = switch (section) {
            RestaurantProfileSection.general => <String, dynamic>{
              'name': 'Le nouveau café',
            },
            RestaurantProfileSection.address => <String, dynamic>{
              'city': 'Bain-de-Bretagne',
            },
            RestaurantProfileSection.hours => <String, dynamic>{
              'openingHours.sunday': const OpeningHours(
                open: true,
                opensAt: '10:00',
                closesAt: '15:00',
              ).toMap(),
            },
            RestaurantProfileSection.photos => <String, dynamic>{
              'logoUrl': null,
            },
            RestaurantProfileSection.visibility => <String, dynamic>{
              'active': false,
            },
          };
          final updated = await f.repo.updateRestaurantSection(
            restaurantId: EstablishmentFixture.id,
            ownerId: EstablishmentFixture.owner,
            section: section,
            changes: changes,
            previousValues: restaurantProfileValues(f.restaurant),
          );
          final after = await f.data();
          final expected = Map<String, dynamic>.of(before)..remove('updatedAt');
          if (section == RestaurantProfileSection.hours) {
            expected['openingHours'] = {
              ...before['openingHours'] as Map,
              'sunday': changes.values.single,
            };
          } else if (section == RestaurantProfileSection.photos) {
            expected.remove('logoUrl');
          } else {
            expected.addAll(changes);
            if (section == RestaurantProfileSection.visibility) {
              expected['status'] = 'draft';
            }
          }
          after.remove('updatedAt');
          expect(after, expected);
          expect(updated.rewardLabel, 'Un café offert');
          expect(updated.pointsPerVisit, 35);
          expect(updated.latitude, 48.11);
          expect(updated.longitude, -1.68);
        } finally {
          await f.close();
        }
      },
    );
  }

  test(
    'Une autre rubrique et les champs backend ajoutés entre ouverture et sauvegarde sont conservés',
    () async {
      final f = await EstablishmentFixture.create();
      try {
        final initial = restaurantProfileValues(f.restaurant);
        await f.doc.update({
          'city': 'Nouvelle ville',
          'rewardThreshold': 23,
          'backendOnly.other': 'conserver',
        });
        await f.repo.updateRestaurantSection(
          restaurantId: EstablishmentFixture.id,
          ownerId: EstablishmentFixture.owner,
          section: RestaurantProfileSection.general,
          changes: {'name': 'Nouveau nom'},
          previousValues: initial,
        );
        final data = await f.data();
        expect(data['name'], 'Nouveau nom');
        expect(data['city'], 'Nouvelle ville');
        expect(data['rewardThreshold'], 23);
        expect(data['backendOnly'], {'preserve': true, 'other': 'conserver'});
      } finally {
        await f.close();
      }
    },
  );

  test(
    'Un conflit sur le champ édité ne remplace pas la version récente',
    () async {
      final f = await EstablishmentFixture.create();
      try {
        final initial = restaurantProfileValues(f.restaurant);
        await f.doc.update({'name': 'Nom plus récent'});
        await expectLater(
          f.repo.updateRestaurantSection(
            restaurantId: EstablishmentFixture.id,
            ownerId: EstablishmentFixture.owner,
            section: RestaurantProfileSection.general,
            changes: {'name': 'Ancien écran'},
            previousValues: initial,
          ),
          throwsStateError,
        );
        expect((await f.data())['name'], 'Nom plus récent');
      } finally {
        await f.close();
      }
    },
  );

  test(
    'Une sauvegarde d’horaires conserve les autres jours modifiés à distance',
    () async {
      final f = await EstablishmentFixture.create();
      try {
        final original = restaurantProfileValues(f.restaurant);
        const friday = OpeningHours(
          open: true,
          opensAt: '11:00',
          closesAt: '23:00',
        );
        await f.doc.update({'openingHours.friday': friday.toMap()});
        await f.repo.updateRestaurantSection(
          restaurantId: EstablishmentFixture.id,
          ownerId: EstablishmentFixture.owner,
          section: RestaurantProfileSection.hours,
          changes: {
            'openingHours.sunday': const OpeningHours(
              open: true,
              opensAt: '12:00',
              closesAt: '16:00',
            ).toMap(),
          },
          previousValues: original,
        );
        expect((await f.data())['openingHours']['friday'], friday.toMap());
      } finally {
        await f.close();
      }
    },
  );

  test(
    'Propriétaire incorrect, champ étranger et commerce supprimé : aucune écriture',
    () async {
      final f = await EstablishmentFixture.create();
      try {
        final original = await f.data();
        await expectLater(
          f.repo.updateRestaurantSection(
            restaurantId: EstablishmentFixture.id,
            ownerId: 'autre-compte',
            section: RestaurantProfileSection.general,
            changes: {'name': 'Interdit'},
          ),
          throwsStateError,
        );
        await expectLater(
          f.repo.updateRestaurantSection(
            restaurantId: EstablishmentFixture.id,
            ownerId: EstablishmentFixture.owner,
            section: RestaurantProfileSection.general,
            changes: {'pointsPerVisit': 9999},
          ),
          throwsArgumentError,
        );
        expect(await f.data(), original);
        await f.doc.delete();
        await expectLater(
          f.repo.updateRestaurantSection(
            restaurantId: EstablishmentFixture.id,
            ownerId: EstablishmentFixture.owner,
            section: RestaurantProfileSection.general,
            changes: {'name': 'Absent'},
          ),
          throwsStateError,
        );
      } finally {
        await f.close();
      }
    },
  );

  for (final status in [
    RestaurantStatus.pendingReview,
    RestaurantStatus.suspended,
    RestaurantStatus.draft,
  ]) {
    test(
      'Activation interdite pour ${status.name}, profil modifiable sans changer son statut',
      () async {
        final f = await EstablishmentFixture.create(
          status: status,
          draft: status == RestaurantStatus.draft,
        );
        try {
          await expectLater(
            f.repo.updateRestaurantSection(
              restaurantId: EstablishmentFixture.id,
              ownerId: EstablishmentFixture.owner,
              section: RestaurantProfileSection.visibility,
              changes: {'active': true},
            ),
            throwsStateError,
          );
          await f.repo.updateRestaurantSection(
            restaurantId: EstablishmentFixture.id,
            ownerId: EstablishmentFixture.owner,
            section: RestaurantProfileSection.address,
            changes: {'city': 'Rennes sud'},
          );
          final data = await f.data();
          expect(data['active'], false);
          expect(data['status'], status.firestoreValue);
          if (status == RestaurantStatus.draft) {
            expect(data['loyaltyProgramEnabled'], false);
          }
        } finally {
          await f.close();
        }
      },
    );
  }

  test(
    'La réactivation explicite d’un commerce configuré ne modifie pas la fidélité',
    () async {
      final f = await EstablishmentFixture.create(
        status: RestaurantStatus.draft,
        active: false,
      );
      try {
        await f.repo.updateRestaurantSection(
          restaurantId: EstablishmentFixture.id,
          ownerId: EstablishmentFixture.owner,
          section: RestaurantProfileSection.visibility,
          changes: {'active': true},
        );
        final data = await f.data();
        expect(data['active'], true);
        expect(data['status'], 'active');
        expect(data['rewardLabel'], 'Un café offert');
        expect(data['pointsPerVisit'], 35);
      } finally {
        await f.close();
      }
    },
  );

  test(
    'La limite de galerie et les validateurs existants sont conservés',
    () async {
      final f = await EstablishmentFixture.create();
      try {
        for (final changes in [
          <String, dynamic>{'name': ''},
          <String, dynamic>{'email': 'invalide'},
          <String, dynamic>{'website': 'site sans domaine'},
        ]) {
          await expectLater(
            f.repo.updateRestaurantSection(
              restaurantId: EstablishmentFixture.id,
              ownerId: EstablishmentFixture.owner,
              section: RestaurantProfileSection.general,
              changes: changes,
            ),
            throwsArgumentError,
          );
        }
        await expectLater(
          f.repo.updateRestaurantSection(
            restaurantId: EstablishmentFixture.id,
            ownerId: EstablishmentFixture.owner,
            section: RestaurantProfileSection.photos,
            changes: {'galleryUrls': List.generate(9, (i) => 'image-$i')},
          ),
          throwsArgumentError,
        );
        await expectLater(
          f.repo.updateRestaurantSection(
            restaurantId: EstablishmentFixture.id,
            ownerId: EstablishmentFixture.owner,
            section: RestaurantProfileSection.hours,
            changes: {
              'openingHours.monday': {
                'open': true,
                'opensAt': '9h',
                'closesAt': '18:00',
              },
            },
          ),
          throwsArgumentError,
        );
      } finally {
        await f.close();
      }
    },
  );

  test('Des horaires absents ne sont pas comptés comme enregistrés', () async {
    for (final raw in [
      null,
      <String, dynamic>{},
      {'inconnu': true},
      {
        'monday': {'open': true, 'opensAt': 'invalide', 'closesAt': 'invalide'},
      },
    ]) {
      expect(
        Restaurant.fromMap('missing', {
          'openingHours': raw,
        }).hasSavedOpeningHours,
        false,
      );
    }
    final f = await EstablishmentFixture.create(omitHours: true);
    try {
      expect(f.restaurant.hasSavedOpeningHours, false);
      expect((await f.data()).containsKey('openingHours'), false);
      await f.repo.updateRestaurantSection(
        restaurantId: EstablishmentFixture.id,
        ownerId: EstablishmentFixture.owner,
        section: RestaurantProfileSection.hours,
        changes: {
          for (final entry in f.restaurant.openingHours.entries)
            'openingHours.${entry.key}': entry.value.toMap(),
        },
      );
      expect(f.restaurant.hasSavedOpeningHours, true);
      expect((await f.data())['openingHours'].length, 7);
    } finally {
      await f.close();
    }
  });
}
