import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/theme/app_theme.dart';
import 'package:loyalo/widgets/loyalo_page_header.dart';

void main() {
  for (final size in const [
    Size(320, 568),
    Size(390, 844),
    Size(430, 932),
    Size(360, 640),
    Size(412, 915),
  ]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('titre long et actions accessibles $size × $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var previews = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                appBar: loyaloPageAppBar(
                  context,
                  title: const Text('Historique des visites de mon commerce'),
                  actionsWidth: 96,
                  actions: [
                    TextButton(
                      onPressed: () => previews++,
                      child: const Text('Aperçu'),
                    ),
                  ],
                ),
                body: const Text('Contenu'),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(BackButton), findsNothing);
        final titleRect = tester.getRect(
          find.text('Historique des visites de mon commerce'),
        );
        final appBarRect = tester.getRect(find.byType(AppBar));
        expect(titleRect.bottom, lessThanOrEqualTo(appBarRect.bottom));
        expect(titleRect.right, lessThanOrEqualTo(size.width));
        await tester.tap(find.text('Aperçu'));
        expect(previews, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('conserve le retour natif après une ouverture de page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  appBar: loyaloPageAppBar(
                    context,
                    title: const Text('Mes récompenses'),
                  ),
                ),
              ),
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    expect(
      tester.getSize(find.byType(BackButton)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('en-tête personnalisé avec retour et action × $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var backs = 0;
      var actions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: LoyaloPageHeader(
                title: 'Configurer mon programme de fidélité',
                showBackButton: true,
                onBack: () => backs++,
                actions: [
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => actions++,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.tap(find.byTooltip('Fermer'));
      expect(backs, 1);
      expect(actions, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
