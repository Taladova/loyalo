import 'package:flutter/material.dart';

import '../../widgets/loyalo_auth_ui.dart';

/// Présentation de l'inscription simplifiée, sans accès aux services métier.
/// Le parcours de brouillon est porté par MerchantSignupScreen et le repository.
class LoyaloMerchantSignupView extends StatelessWidget {
  const LoyaloMerchantSignupView({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.activityController,
    required this.emailController,
    required this.passwordController,
    required this.validateName,
    required this.validateEmail,
    required this.validatePassword,
    required this.obscurePassword,
    required this.loading,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onBack,
    this.error,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController activityController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String? Function(String?) validateName;
  final String? Function(String?) validateEmail;
  final String? Function(String?) validatePassword;
  final bool obscurePassword;
  final bool loading;
  final VoidCallback? onTogglePassword;
  final VoidCallback? onSubmit;
  final VoidCallback? onBack;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return LoyaloAuthScaffold(
      illustrationAsset: 'assets/images/signup/merchant_signup_hero.png',
      onBack: loading ? null : onBack,
      contentBuilder: (context, compact) => LoyaloAuthSurface(
        compact: true,
        child: Form(
          key: formKey,
          child: AutofillGroup(
            child: Column(
              children: [
                const LoyaloAuthHeading(
                  title: 'Créer un compte commerçant',
                  description:
                      'Créez votre espace en quelques instants. Vous pourrez ensuite configurer votre programme de fidélité et vos offres.',
                  titleFontSize: 23,
                ),
                const SizedBox(height: 12),
                const _SignupSectionTitle(
                  'Votre commerce',
                  icon: Icons.storefront_outlined,
                ),
                const SizedBox(height: 8),
                LoyaloAuthTextField(
                  key: const Key('merchant-signup-name'),
                  controller: nameController,
                  validator: validateName,
                  hintText: 'Nom du commerce',
                  prefixIcon: Icons.storefront_outlined,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.organizationName],
                  textInputAction: TextInputAction.next,
                  enabled: !loading,
                ),
                const SizedBox(height: 10),
                LoyaloAuthTextField(
                  key: const Key('merchant-signup-activity'),
                  controller: activityController,
                  validator: (_) => null,
                  hintText: 'Type d’activité / secteur',
                  prefixIcon: Icons.category_outlined,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  enabled: !loading,
                ),
                const SizedBox(height: 20),
                const _SignupSectionTitle(
                  'Vos identifiants',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 8),
                LoyaloAuthTextField(
                  key: const Key('merchant-signup-email'),
                  controller: emailController,
                  validator: validateEmail,
                  hintText: 'Email',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  enabled: !loading,
                ),
                const SizedBox(height: 10),
                LoyaloAuthTextField(
                  key: const Key('merchant-signup-password'),
                  controller: passwordController,
                  validator: validatePassword,
                  hintText: 'Mot de passe',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: obscurePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!loading) onSubmit?.call();
                  },
                  enabled: !loading,
                  suffixIcon: IconButton(
                    tooltip: obscurePassword
                        ? 'Afficher le mot de passe'
                        : 'Masquer le mot de passe',
                    onPressed: loading ? null : onTogglePassword,
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  LoyaloAuthError(message: error!),
                ],
                const SizedBox(height: 12),
                LoyaloAuthPrimaryButton(
                  label: 'Créer mon espace commerçant',
                  onPressed: loading ? null : onSubmit,
                  loading: loading,
                ),
                const SizedBox(height: 8),
                const LoyaloAuthSecurityNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignupSectionTitle extends StatelessWidget {
  const _SignupSectionTitle(this.title, {required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: LoyaloAuthColors.purple, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: LoyaloAuthColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
