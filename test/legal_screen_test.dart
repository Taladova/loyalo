import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/legal_content.dart';
import 'package:loyalo/screens/legal_screen.dart';
import 'package:loyalo/widgets/loyalo_page_header.dart';

Future<void> _openDocument(
  WidgetTester tester, {
  required String title,
  required String content,
  required Size size,
  required double scale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
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
                builder: (_) => LegalScreen(title: title, content: content),
              ),
            ),
            child: const Text('Ouvrir le document'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Ouvrir le document'));
  await tester.pumpAndSettle();
}

void main() {
  const documents = {
    'Politique de confidentialité': kPrivacyPolicyText,
    'Conditions d’utilisation': kTermsOfServiceText,
  };
  for (final document in documents.entries) {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(430, 932),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '${document.key}, texte complet et défilement $size ×$scale',
          (tester) async {
            await _openDocument(
              tester,
              title: document.key,
              content: document.value,
              size: size,
              scale: scale,
            );
            final paragraphs = document.value.trim().split('\n\n');
            final displayed = <String>[];
            final headerTop = tester
                .getTopLeft(find.byType(LoyaloPageHeader))
                .dy;
            expect(headerTop, greaterThanOrEqualTo(47));
            expect(find.byType(Image), findsNothing);
            expect(find.text('Dernière mise à jour : 2026'), findsOneWidget);
            for (var i = 0; i < paragraphs.length; i++) {
              final block = find.byKey(ValueKey('legal-block-$i'));
              final texts = tester.widgetList<Text>(
                find.descendant(of: block, matching: find.byType(Text)),
              );
              displayed.add(texts.map((text) => text.data!).join('\n'));
              await tester.ensureVisible(block);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
            expect(displayed.join('\n\n'), document.value.trim());
            expect(
              tester.getTopLeft(find.byType(LoyaloPageHeader)).dy,
              headerTop,
            );
            final contact = find.text('Taladova — contact@taladova.com');
            final scrollable = tester.state<ScrollableState>(
              find.descendant(
                of: find.byKey(const Key('legal-scroll')),
                matching: find.byType(Scrollable),
              ),
            );
            scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(
              tester.getBottomLeft(contact).dy,
              lessThanOrEqualTo(size.height - 34),
            );
            await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
            await tester.pumpAndSettle();
            expect(find.text('Ouvrir le document'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
