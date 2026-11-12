import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loyalo/models/app_user.dart';
import 'package:loyalo/providers/app_providers.dart';
import 'package:loyalo/screens/auth/client_login_screen.dart';
import 'package:loyalo/screens/auth/client_signup_screen.dart';
import 'package:loyalo/screens/client/client_dashboard_screen.dart';
import 'package:loyalo/screens/client/my_code_screen.dart';
import 'package:loyalo/screens/merchant/merchant_login_screen.dart';
import 'package:loyalo/screens/merchant/merchant_signup_screen.dart';
import 'package:loyalo/theme/app_theme.dart';
import 'package:loyalo/widgets/loyalo_logo.dart';

import 'support/merchant_dashboard_fixture.dart';

Finder asset(String name) => find.byWidgetPredicate((widget) {
  if (widget is! Image) return false;
  final source = widget.image is ResizeImage
      ? (widget.image as ResizeImage).imageProvider
      : widget.image;
  return source is AssetImage && source.assetName.endsWith(name);
});

void main() {
  setUpAll(() {
    FirebasePlatform.instance = DashboardTestCore();
    FirebaseAuthPlatform.instance = DashboardTestAuth();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('les quatre formulaires partagent les proportions officielles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    final sizes = <Size>{};
    for (final screen in const <Widget>[
      ClientLoginScreen(),
      MerchantLoginScreen(),
      ClientSignupScreen(),
      MerchantSignupScreen(),
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          child: MaterialApp(theme: AppTheme.light(), home: screen),
        ),
      );
      await tester.pumpAndSettle();
      final logo = asset('logo_loyalo_v3_light.png');
      expect(logo, findsOneWidget);
      final size = tester.getSize(logo);
      sizes.add(size);
      expect(size.width / size.height, closeTo(3, 0.001));
      expect(size.height, lessThanOrEqualTo(64));
      expect(tester.widget<Image>(logo).fit, BoxFit.contain);
      expect(find.text('La fidélité qui récompense.'), findsNothing);
      expect(tester.takeException(), isNull);
    }
    expect(sizes, hasLength(1));
  });

  for (final empty in [false, true]) {
    testWidgets('marque client discrète et retour préservé (vide=$empty)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = DashboardTestRepository()..hasRestaurant = !empty;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loyaltyRepositoryProvider.overrideWith((ref) => repo),
            currentUserProvider.overrideWith(
              (ref) => const AppUser(
                id: 'a',
                name: 'Alex',
                email: 'alex@example.org',
                referralCode: 'ALEX10',
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ClientDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoyaloDashboardMark), findsOneWidget);
      expect(asset('logo_loyalo_v3_light.png'), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byTooltip('Déconnexion'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const ClientDashboardScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byType(LoyaloDashboardMark), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(LoyaloDashboardMark), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repo.database.close);
    });
  }

  testWidgets('ma carte sans logo conserve QR, code, points et retour', (
    tester,
  ) async {
    final repo = DashboardTestRepository();
    var backs = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loyaltyRepositoryProvider.overrideWith((ref) => repo),
          currentUserProvider.overrideWith(
            (ref) => const AppUser(
              id: 'a',
              name: 'Alex',
              email: 'alex@example.org',
              referralCode: 'ALEX10',
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: MyCodeScreen(onBack: () => backs++),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoyaloWordmark), findsNothing);
    expect(find.byType(LoyaloDashboardMark), findsNothing);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Points'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      find.text(repo.dailyCodeFor('a').split('').join(' ')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Retour'));
    expect(backs, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repo.database.close);
  });
}
