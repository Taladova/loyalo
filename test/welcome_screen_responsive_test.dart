import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loyalo/screens/auth/client_login_screen.dart';
import 'package:loyalo/screens/merchant/merchant_login_screen.dart';
import 'package:loyalo/screens/merchant/merchant_onboarding_screen.dart';
import 'package:loyalo/screens/welcome_screen.dart';

const _benefits = [
  'Découvrez les commerces',
  'Cumulez des points',
  'Profitez de récompenses',
];

const _profiles = ['Je suis un client', 'Je suis commerçant'];

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? pushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) pushedRoute = route;
  }
}

Future<void> _pumpWelcome(
  WidgetTester tester, {
  required Size size,
  TargetPlatform platform = TargetPlatform.iOS,
  double textScale = 1,
  NavigatorObserver? observer,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        navigatorObservers: [?observer],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            padding: const EdgeInsets.only(top: 32, bottom: 16),
          ),
          child: child!,
        ),
        home: const WelcomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _profileInkWell(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'merchant_onboarding_seen': true});
  });

  for (final scenario in [
    (
      name: 'iPhone compact',
      size: const Size(320, 568),
      platform: TargetPlatform.iOS,
    ),
    (
      name: 'iPhone standard',
      size: const Size(390, 844),
      platform: TargetPlatform.iOS,
    ),
    (
      name: 'iPhone grand',
      size: const Size(430, 932),
      platform: TargetPlatform.iOS,
    ),
    (
      name: 'Android compact',
      size: const Size(360, 640),
      platform: TargetPlatform.android,
    ),
    (
      name: 'Android standard',
      size: const Size(412, 915),
      platform: TargetPlatform.android,
    ),
  ]) {
    testWidgets('${scenario.name} : contenu lisible et boutons visibles', (
      tester,
    ) async {
      await _pumpWelcome(
        tester,
        size: scenario.size,
        platform: scenario.platform,
      );

      for (final label in [..._benefits, ..._profiles]) {
        final textFinder = find.text(label);
        expect(textFinder, findsOneWidget);
        final text = tester.widget<Text>(textFinder);
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(
          tester.renderObject<RenderParagraph>(textFinder).didExceedMaxLines,
          isFalse,
        );
      }

      for (final label in _profiles) {
        final rect = tester.getRect(_profileInkWell(label));
        expect(rect.height, greaterThanOrEqualTo(60));
        expect(rect.top, greaterThanOrEqualTo(32));
        expect(rect.bottom, lessThanOrEqualTo(scenario.size.height - 16));
      }
      final clientButton = tester.getRect(_profileInkWell(_profiles.first));
      final merchantButton = tester.getRect(_profileInkWell(_profiles.last));
      expect(
        merchantButton.top - clientButton.bottom,
        inInclusiveRange(12, 16),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Texte agrandi : libellés complets et défilement accessible', (
    tester,
  ) async {
    await _pumpWelcome(tester, size: const Size(320, 568), textScale: 2.5);

    for (final label in [..._benefits, ..._profiles]) {
      final textFinder = find.text(label);
      expect(textFinder, findsOneWidget);
      final text = tester.widget<Text>(textFinder);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(
        tester.renderObject<RenderParagraph>(textFinder).didExceedMaxLines,
        isFalse,
      );
    }

    for (final label in _profiles) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      final rect = tester.getRect(_profileInkWell(label));
      expect(rect.height, greaterThanOrEqualTo(60));
      expect(rect.center.dy, inInclusiveRange(32, 568 - 16));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Charge le logo et les illustrations fournies', (tester) async {
    await _pumpWelcome(tester, size: const Size(390, 844));

    final assetNames = tester.widgetList<Image>(find.byType(Image)).map((
      image,
    ) {
      final provider = image.image;
      final source = provider is ResizeImage
          ? provider.imageProvider
          : provider;
      return source is AssetImage ? source.assetName : null;
    });
    expect(
      assetNames,
      containsAll([
        'assets/images/logo_loyalo_v3_light.png',
        'assets/images/welcome/welcome_hero.png',
        'assets/images/welcome/welcome_city.png',
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Avantages informatifs et boutons accessibles', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpWelcome(tester, size: const Size(390, 844));

      for (final label in _benefits) {
        final data = tester.getSemantics(find.text(label)).getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isFalse);
        expect(data.flagsCollection.isButton, isFalse);
        expect(_profileInkWell(label), findsNothing);
      }
      for (final label in _profiles) {
        final data = tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.flagsCollection.isButton, isTrue);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Le bouton client conserve sa destination', (tester) async {
    final observer = _RouteObserver();
    await _pumpWelcome(tester, size: const Size(390, 844), observer: observer);

    await tester.tap(find.text('Je suis un client'));
    await tester.idle();
    final route = observer.pushedRoute as MaterialPageRoute<dynamic>?;
    expect(route, isNotNull);
    expect(
      route!.builder(tester.element(find.byType(WelcomeScreen))),
      isA<ClientLoginScreen>(),
    );
    await tester.pumpWidget(const SizedBox());
  });

  for (final seen in [false, true]) {
    testWidgets('Destination commerçant selon onboarding déjà vu : $seen', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'merchant_onboarding_seen': seen,
      });
      final observer = _RouteObserver();
      await _pumpWelcome(
        tester,
        size: const Size(390, 844),
        observer: observer,
      );

      await tester.tap(find.text('Je suis commerçant'));
      await tester.idle();
      final route = observer.pushedRoute as MaterialPageRoute<dynamic>?;
      expect(route, isNotNull);
      final destination = route!.builder(
        tester.element(find.byType(WelcomeScreen)),
      );
      expect(
        destination,
        seen ? isA<MerchantLoginScreen>() : isA<MerchantOnboardingScreen>(),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
