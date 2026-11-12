import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/screens/merchant/validate_visit_screen.dart';
import 'package:loyalo/theme/app_theme.dart';
import 'package:loyalo/widgets/loyalo_ui.dart';

void main() {
  for (final size in const [
    Size(320, 568),
    Size(390, 844),
    Size(430, 932),
    Size(360, 640),
    Size(412, 915),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('validation accessible $size texte $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const ValidateVisitScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BackButton), findsNothing);
        expect(tester.takeException(), isNull);
        for (final digit in ['1', '2', '3', '4', '5', '6']) {
          final key = find.widgetWithText(TextButton, digit);
          await tester.ensureVisible(key);
          await tester.tap(key);
          await tester.pump();
        }
        final submit = find.widgetWithText(
          LoyaloGradientButton,
          'Valider la visite',
        );
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        expect(
          tester.widget<LoyaloGradientButton>(submit).onPressed,
          isNotNull,
        );
        final erase = find.widgetWithText(TextButton, '⌫');
        await tester.ensureVisible(erase);
        await tester.tap(erase);
        await tester.pump();
        expect(tester.widget<LoyaloGradientButton>(submit).onPressed, isNull);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
