import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/widgets/loyalo_auth_ui.dart';
import 'package:loyalo/widgets/loyalo_merchant_dashboard_ui.dart';
import 'package:loyalo/widgets/main_bottom_nav.dart';

const _items = [
  NavItemData(icon: Icons.home_outlined, label: 'Accueil'),
  NavItemData(icon: Icons.people_outline, label: 'Clients'),
  NavItemData(icon: Icons.qr_code_scanner_rounded, label: 'Valider'),
  NavItemData(icon: Icons.card_giftcard_outlined, label: 'Récompenses'),
  NavItemData(icon: Icons.local_fire_department_outlined, label: 'Offres'),
];

Future<List<int>> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  int initial = 0,
  bool enabled = true,
  bool reduceMotion = false,
  bool withInput = false,
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  final taps = <int>[];
  var selected = initial;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final bottom = platform == TargetPlatform.iOS ? 34.0 : 24.0;
  tester.view.padding = FakeViewPadding(top: 47, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: 47, bottom: bottom);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduceMotion,
        ),
        child: child!,
      ),
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          backgroundColor: LoyaloAuthColors.navy,
          body: Center(
            key: const Key('nav-test-body'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('page $selected'),
                if (withInput) const TextField(key: Key('nav-test-input')),
              ],
            ),
          ),
          bottomNavigationBar: LoyaloMerchantBottomNav(
            items: _items,
            selectedIndex: selected,
            enabled: enabled,
            onTap: (index) {
              taps.add(index);
              setState(() => selected = index);
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return taps;
}

void main() {
  testWidgets(
    'Les cinq libellés, les états et les actions sémantiques sont accessibles',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final taps = await _pump(tester);
      for (var i = 0; i < _items.length; i++) {
        final target = find.bySemanticsLabel(_items[i].label);
        final data = tester.getSemantics(target).getSemanticsData();
        expect(data.flagsCollection.isButton, true);
        expect(
          data.flagsCollection.isSelected,
          i == 0 ? Tristate.isTrue : Tristate.isFalse,
        );
        expect(data.hasAction(SemanticsAction.tap), true);
        expect(
          find.text(_items[i].label),
          i == 2 ? findsNothing : findsOneWidget,
        );
        await tester.tap(find.byKey(ValueKey('merchant-nav-item-$i')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<LoyaloMerchantBottomNav>(
                find.byType(LoyaloMerchantBottomNav),
              )
              .selectedIndex,
          i,
        );
        expect(find.text('page $i'), findsOneWidget);
      }
      expect(taps, [0, 1, 2, 3, 4]);
      expect(find.text('Stats'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'Le bouton central garde son dégradé quand Accueil est sélectionné',
    (tester) async {
      await _pump(tester);
      final icon = tester.widget<AnimatedContainer>(
        find.byKey(const Key('merchant-nav-validate-icon')),
      );
      final decoration = icon.decoration! as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.borderRadius, isNull);
      expect(decoration.boxShadow, isNotEmpty);
      expect(
        tester.getSize(find.byKey(const Key('merchant-nav-validate-icon'))),
        const Size(56, 56),
      );
      final surface = tester.getRect(
        find.byKey(const Key('merchant-nav-surface')),
      );
      final raised = tester.getRect(
        find.byKey(const Key('merchant-nav-validate-icon')),
      );
      expect(surface.top - raised.top, 12);
      expect(surface.left, 8);
      expect(surface.right, 382);
      expect(surface.bottom, 844 - 34);
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.descendant(
          of: find.byType(LoyaloMerchantBottomNav),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );
      expect(overlay.value.systemNavigationBarColor, LoyaloAuthColors.navy);
      expect(overlay.value.systemNavigationBarIconBrightness, Brightness.light);
      expect(raised.center.dx, 195);
      final hitArea = tester.getRect(
        find.byKey(const Key('merchant-nav-hit-area')),
      );
      expect(hitArea.contains(raised.topLeft), true);
      expect(
        hitArea.contains(raised.bottomRight - const Offset(0.1, 0.1)),
        true,
      );
      expect(
        tester.getRect(find.byKey(const Key('nav-test-body'))).bottom,
        lessThanOrEqualTo(hitArea.top),
      );
      expect(hitArea.height, lessThanOrEqualTo(94));
    },
  );

  testWidgets('La barre est réellement découpée autour du bouton flottant', (
    tester,
  ) async {
    await _pump(tester);
    final surfaceFinder = find.byKey(const Key('merchant-nav-surface'));
    final surface = tester.getRect(surfaceFinder);
    final bar = tester.widget<PhysicalShape>(surfaceFinder);
    final path = bar.clipper.getClip(surface.size);
    final circle = tester
        .getRect(find.byKey(const Key('merchant-nav-validate-icon')))
        .shift(-surface.topLeft);
    expect(bar.clipBehavior, Clip.antiAlias);
    expect(path.contains(Offset(surface.width / 2, 1)), isFalse);
    // Une vraie zone transparente sépare le cercle de la barre blanche.
    expect(path.contains(circle.centerRight + const Offset(3, 0)), isFalse);
    expect(path.contains(circle.bottomCenter + const Offset(0, 3)), isFalse);
    expect(path.contains(circle.bottomCenter + const Offset(0, 7)), isTrue);
    expect(path.contains(const Offset(50, 1)), isTrue);
    expect(path.contains(const Offset(1, 1)), isFalse);
    expect(
      find.byKey(const ValueKey('merchant-nav-label-Valider')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Toute la surface surélevée est cliquable : haut, côtés et quatre coins',
    (tester) async {
      final taps = await _pump(tester);
      final rect = tester.getRect(
        find.byKey(const Key('merchant-nav-validate-icon')),
      );
      for (final point in [
        rect.topLeft + const Offset(1, 1),
        rect.topRight + const Offset(-1, 1),
        rect.bottomLeft + const Offset(1, -1),
        rect.bottomRight - const Offset(1, 1),
        rect.topCenter + const Offset(0, 1),
        rect.centerLeft + const Offset(1, 0),
        rect.centerRight - const Offset(1, 0),
        rect.bottomCenter - const Offset(0, 1),
        rect.center,
      ]) {
        await tester.tapAt(point);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('merchant-nav-validate-tap')));
      await tester.pumpAndSettle();
      expect(taps, List.filled(10, 2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pression animée en 180 ms puis repos sans animation permanente',
    (tester) async {
      await _pump(tester);
      final target = find.byKey(const Key('merchant-nav-validate-icon'));
      final gesture = await tester.startGesture(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 120));
      var animation = tester.widget<AnimatedScale>(
        find.byKey(const Key('merchant-nav-validate-press')),
      );
      expect(animation.duration, const Duration(milliseconds: 180));
      expect(animation.scale, 0.95);
      await gesture.up();
      await tester.pumpAndSettle();
      animation = tester.widget<AnimatedScale>(
        find.byKey(const Key('merchant-nav-validate-press')),
      );
      expect(animation.scale, 1);
      expect(tester.binding.hasScheduledFrame, false);
    },
  );

  testWidgets('Réduction des animations respectée', (tester) async {
    await _pump(tester, reduceMotion: true);
    final animation = tester.widget<AnimatedScale>(
      find.byKey(const Key('merchant-nav-validate-press')),
    );
    expect(animation.duration, Duration.zero);
    for (final container in tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    )) {
      expect(container.duration, Duration.zero);
    }
    for (final item in _items.where((item) => item.label != 'Valider')) {
      final label = tester.widget<AnimatedDefaultTextStyle>(
        find.byKey(ValueKey('merchant-nav-label-${item.label}')),
      );
      expect(label.duration, Duration.zero);
    }
    for (final icon in tester.widgetList<TweenAnimationBuilder<Color?>>(
      find.byType(TweenAnimationBuilder<Color?>),
    )) {
      expect(icon.duration, Duration.zero);
    }
  });

  testWidgets('Transition de couleur discrète en 180 ms', (tester) async {
    await _pump(tester);
    final animatedStyle = find.byKey(
      const ValueKey('merchant-nav-label-Clients'),
    );
    final renderedStyle = find.descendant(
      of: animatedStyle,
      matching: find.byType(DefaultTextStyle),
    );
    expect(
      tester.widget<DefaultTextStyle>(renderedStyle).style.color,
      LoyaloAuthColors.textSecondary,
    );
    await tester.tap(find.text('Clients'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final color = tester.widget<DefaultTextStyle>(renderedStyle).style.color;
    expect(color, isNot(LoyaloAuthColors.textSecondary));
    expect(color, isNot(LoyaloAuthColors.purple));
    expect(
      tester.widget<AnimatedDefaultTextStyle>(animatedStyle).duration,
      const Duration(milliseconds: 180),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<DefaultTextStyle>(renderedStyle).style.color,
      LoyaloAuthColors.purple,
    );
    expect(tester.binding.hasScheduledFrame, false);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('Clavier ouvert : saisie et onglet préservés sur $platform', (
      tester,
    ) async {
      await _pump(tester, initial: 3, platform: platform, withInput: true);
      await tester.enterText(
        find.byKey(const Key('nav-test-input')),
        'Saisie conservée',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('merchant-nav-hit-area')), findsNothing);
      expect(find.text('Saisie conservée'), findsOneWidget);
      expect(find.text('page 3'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('nav-test-body'))).bottom,
        lessThanOrEqualTo(544),
      );
      tester.view.viewInsets = const FakeViewPadding();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('merchant-nav-hit-area')), findsOneWidget);
      expect(
        tester
            .widget<LoyaloMerchantBottomNav>(
              find.byType(LoyaloMerchantBottomNav),
            )
            .selectedIndex,
        3,
      );
      expect(find.text('Saisie conservée'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Encoche latérale : destinations sûres et centre équilibré', (
    tester,
  ) async {
    await _pump(tester, size: const Size(844, 390));
    tester.view.padding = const FakeViewPadding(left: 44, bottom: 21);
    tester.view.viewPadding = const FakeViewPadding(left: 44, bottom: 21);
    await tester.pumpAndSettle();
    final circle = tester.getRect(
      find.byKey(const Key('merchant-nav-validate-icon')),
    );
    expect(circle.center.dx, 422);
    final first = tester.getRect(
      find.byKey(const ValueKey('merchant-nav-item-0')),
    );
    final last = tester.getRect(
      find.byKey(const ValueKey('merchant-nav-item-4')),
    );
    expect(first.left, greaterThanOrEqualTo(44));
    expect(last.right, lessThanOrEqualTo(800));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Surface initialement étroite puis taille réelle sans perdre l’onglet',
    (tester) async {
      await _pump(
        tester,
        size: const Size(240, 568),
        initial: 3,
        platform: TargetPlatform.android,
      );
      expect(find.byKey(const Key('merchant-nav-validate-icon')), findsNothing);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LoyaloMerchantBottomNav>(
              find.byType(LoyaloMerchantBottomNav),
            )
            .selectedIndex,
        3,
      );
      expect(
        find.byKey(const Key('merchant-nav-validate-icon')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Navigation indisponible : aucune destination activée au toucher',
    (tester) async {
      final taps = await _pump(tester, enabled: false);
      for (var index = 0; index < _items.length; index++) {
        await tester.tap(find.byKey(ValueKey('merchant-nav-item-$index')));
        await tester.pumpAndSettle();
      }
      expect(taps, isEmpty);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(412, 915),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 2.0, 2.5]) {
      testWidgets('Navigation sans débordement $size texte ×$scale', (
        tester,
      ) async {
        final platform = size.width == 360 || size.width == 412
            ? TargetPlatform.android
            : TargetPlatform.iOS;
        final taps = await _pump(
          tester,
          size: size,
          scale: scale,
          platform: platform,
        );
        final icon = tester.getRect(
          find.byKey(const Key('merchant-nav-validate-icon')),
        );
        expect(icon.center.dx, closeTo(size.width / 2, 0.01));
        final safeBottom = platform == TargetPlatform.iOS ? 34 : 24;
        final surface = tester.getRect(
          find.byKey(const Key('merchant-nav-surface')),
        );
        expect(surface.bottom, size.height - safeBottom);
        expect(icon.width, inInclusiveRange(56, 60));
        for (var index = 0; index < 5; index++) {
          final target = find.byKey(ValueKey('merchant-nav-item-$index'));
          final rect = tester.getRect(target);
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width + 0.01));
          expect(
            rect.bottom,
            lessThanOrEqualTo(size.height - safeBottom + 0.01),
          );
          if (scale > 1.3 && index != 2) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: find.byKey(
                  ValueKey('merchant-nav-label-${_items[index].label}'),
                ),
                matching: find.byType(RichText),
              ),
            );
            for (final box in paragraph.getBoxesForSelection(
              TextSelection(
                baseOffset: 0,
                extentOffset: _items[index].label.length,
              ),
            )) {
              final left = paragraph.localToGlobal(box.toRect().topLeft).dx;
              final right = paragraph
                  .localToGlobal(box.toRect().bottomRight)
                  .dx;
              expect(left, greaterThanOrEqualTo(rect.left + 3.9));
              expect(right, lessThanOrEqualTo(rect.right - 3.9));
            }
          }
          await tester.tap(target);
          await tester.pumpAndSettle();
        }
        for (final paragraph in tester.renderObjectList<RenderParagraph>(
          find.byType(RichText),
        )) {
          expect(paragraph.didExceedMaxLines, false);
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.1,
            ),
          );
        }
        expect(taps, [0, 1, 2, 3, 4]);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
