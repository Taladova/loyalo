import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loyalo/screens/merchant/merchant_signup_view.dart';
import 'package:loyalo/widgets/loyalo_auth_ui.dart';
import 'package:loyalo/widgets/loyalo_ui.dart';

class _Harness extends StatefulWidget {
  const _Harness({super.key});
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final activity = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool loading = false;
  String? error;
  int submissions = 0;
  int backs = 0;

  void setLoading() => setState(() => loading = true);
  void showError(String message) => setState(() => error = message);

  @override
  void dispose() {
    name.dispose();
    activity.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  String? requiredValue(String? value) =>
      value == null || value.isEmpty ? 'Champ obligatoire.' : null;

  @override
  Widget build(BuildContext context) => LoyaloMerchantSignupView(
    formKey: formKey,
    nameController: name,
    activityController: activity,
    emailController: email,
    passwordController: password,
    validateName: requiredValue,
    validateEmail: requiredValue,
    validatePassword: requiredValue,
    obscurePassword: obscure,
    loading: loading,
    error: error,
    onTogglePassword: () => setState(() => obscure = !obscure),
    onSubmit: () {
      if (formKey.currentState!.validate()) submissions++;
    },
    onBack: () => backs++,
  );
}

const _title = 'Créer un compte commerçant';
const _description =
    'Créez votre espace en quelques instants. Vous pourrez ensuite configurer votre programme de fidélité et vos offres.';
const _button = 'Créer mon espace commerçant';
const _security = 'Vos données sont protégées de façon sécurisée.';

Finder _field(String name) => find.descendant(
  of: find.byKey(Key('merchant-signup-$name')),
  matching: find.byType(TextFormField),
);

Future<_HarnessState> _pumpView(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  final key = GlobalKey<_HarnessState>();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: _Harness(key: key),
    ),
  );
  await tester.pumpAndSettle();
  return key.currentState!;
}

void main() {
  testWidgets(
    'Vue préparée : quatre champs, composants communs et aucune configuration fidélité',
    (tester) async {
      await _pumpView(tester);
      expect(find.byType(LoyaloAuthHeader), findsOneWidget);
      expect(find.byType(LoyaloAuthSurface), findsOneWidget);
      expect(find.byType(LoyaloAuthTextField), findsNWidgets(4));
      expect(find.text('Votre commerce'), findsOneWidget);
      expect(find.text('Vos identifiants'), findsOneWidget);
      expect(find.text('Nom du commerce'), findsOneWidget);
      expect(find.text('Type d’activité / secteur'), findsOneWidget);
      expect(find.text('Programme de fidélité'), findsNothing);
      expect(find.text('Visites requises pour la récompense'), findsNothing);
      expect(find.text('Récompense offerte'), findsNothing);
      expect(
        find.textContaining('Votre restaurant est enregistré'),
        findsNothing,
      );
      for (final finder in [
        find.byType(LoyaloGradientButton),
        find.text(_security),
      ]) {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        expect(tester.getRect(finder).bottom, lessThanOrEqualTo(810));
      }
      expect(
        tester.getSize(find.byType(LoyaloGradientButton)).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Valide les champs reçus et conserve une activité libre facultative',
    (tester) async {
      final state = await _pumpView(tester);
      await tester.ensureVisible(find.text(_button));
      await tester.tap(find.text(_button));
      await tester.pumpAndSettle();
      expect(find.text('Champ obligatoire.'), findsNWidgets(3));
      expect(state.submissions, 0);
      await tester.enterText(_field('name'), 'Mon commerce');
      await tester.enterText(_field('email'), 'merchant@example.org');
      await tester.enterText(_field('password'), 'test-password');
      await tester.ensureVisible(find.text(_button));
      await tester.tap(find.text(_button));
      await tester.pumpAndSettle();
      expect(state.submissions, 1);
      expect(state.activity.text, isEmpty);
      await tester.enterText(_field('activity'), 'Caviste indépendant');
      expect(state.activity.text, 'Caviste indépendant');
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Autofill et visibilité du mot de passe conservés', (
    tester,
  ) async {
    await _pumpView(tester);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].autofillHints, contains(AutofillHints.organizationName));
    expect(fields[2].autofillHints, contains(AutofillHints.email));
    expect(fields[2].keyboardType, TextInputType.emailAddress);
    expect(fields[3].autofillHints, contains(AutofillHints.newPassword));
    expect(fields[3].obscureText, isTrue);
    await tester.ensureVisible(find.byTooltip('Afficher le mot de passe'));
    await tester.tap(find.byTooltip('Afficher le mot de passe'));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<TextField>(find.byType(TextField)).last.obscureText,
      isFalse,
    );
    await tester.tap(find.byTooltip('Masquer le mot de passe'));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<TextField>(find.byType(TextField)).last.obscureText,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Le chargement désactive les contrôles et la soumission clavier',
    (tester) async {
      final state = await _pumpView(tester);
      state.setLoading();
      await tester.pump();
      final button = tester.widget<LoyaloGradientButton>(
        find.byType(LoyaloGradientButton),
      );
      expect(button.loading, isTrue);
      expect(button.onPressed, isNull);
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((field) => field.enabled == false),
        isTrue,
      );
      tester.widgetList<TextField>(find.byType(TextField)).last.onSubmitted!(
        'test-password',
      );
      expect(state.submissions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Affiche l’erreur fournie et transmet le retour', (tester) async {
    final state = await _pumpView(tester);
    state.showError('Adresse email invalide.');
    await tester.pumpAndSettle();
    expect(find.text('Adresse email invalide.'), findsOneWidget);
    expect(find.byType(LoyaloAuthError), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    expect(state.backs, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Clavier ouvert : mot de passe et création accessibles', (
    tester,
  ) async {
    await _pumpView(tester);
    await tester.ensureVisible(_field('password'));
    await tester.tap(_field('password'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.view.padding = const FakeViewPadding(top: 47);
    await tester.pumpAndSettle();
    for (final finder in [_field('password'), find.text(_button)]) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(tester.getRect(finder).center.dy, inInclusiveRange(47, 544));
    }
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(320, 568), scale: 1.0, platform: TargetPlatform.iOS),
    (size: const Size(320, 568), scale: 2.5, platform: TargetPlatform.iOS),
    (size: const Size(430, 932), scale: 1.0, platform: TargetPlatform.iOS),
    (size: const Size(360, 640), scale: 1.0, platform: TargetPlatform.android),
    (size: const Size(412, 915), scale: 1.0, platform: TargetPlatform.android),
  ]) {
    testWidgets('Responsive ${scenario.size}, texte ${scenario.scale}', (
      tester,
    ) async {
      await _pumpView(
        tester,
        size: scenario.size,
        scale: scenario.scale,
        platform: scenario.platform,
      );
      for (final text in [
        _title,
        _description,
        'Votre commerce',
        'Vos identifiants',
        _button,
        _security,
      ]) {
        final finder = find.text(text);
        expect(
          tester.widget<Text>(finder).overflow,
          isNot(TextOverflow.ellipsis),
        );
        expect(
          tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
          isFalse,
        );
      }
      await tester.ensureVisible(find.text(_button));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text(_button)).center.dy,
        inInclusiveRange(47, scenario.size.height - 34),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
