import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'loyalo_ui.dart';

/// Présentation commune aux connexions client et commerçant.
/// Les callbacks et les décisions de navigation restent dans chaque écran.
class LoyaloAuthLayout extends StatelessWidget {
  const LoyaloAuthLayout({
    super.key,
    required this.title,
    required this.description,
    required this.formKey,
    required this.emailKey,
    required this.passwordKey,
    required this.emailController,
    required this.passwordController,
    required this.passwordFocusNode,
    required this.obscurePassword,
    required this.rememberMe,
    required this.loading,
    required this.error,
    required this.validateEmail,
    required this.validatePassword,
    required this.onTogglePassword,
    required this.onRememberMeChanged,
    required this.onForgotPassword,
    required this.onLogin,
    required this.onCreateAccount,
    required this.onBack,
    this.titleFontSize = 26,
    this.standardHeroHeight = 88,
    this.createAccountIcon = Icons.person_add_alt_1_rounded,
    this.fadeAnimation,
    this.slideAnimation,
  });

  final String title;
  final String description;
  final GlobalKey<FormState> formKey;
  final Key emailKey;
  final Key passwordKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode passwordFocusNode;
  final bool obscurePassword;
  final bool rememberMe;
  final bool loading;
  final String? error;
  final String? Function(String?) validateEmail;
  final String? Function(String?) validatePassword;
  final VoidCallback? onTogglePassword;
  final ValueChanged<bool?>? onRememberMeChanged;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onLogin;
  final VoidCallback? onCreateAccount;
  final VoidCallback? onBack;
  final double titleFontSize;
  final double standardHeroHeight;
  final IconData createAccountIcon;
  final Animation<double>? fadeAnimation;
  final Animation<Offset>? slideAnimation;

  @override
  Widget build(BuildContext context) {
    return LoyaloAuthScaffold(
      onBack: onBack,
      standardHeroHeight: standardHeroHeight,
      fadeAnimation: fadeAnimation,
      slideAnimation: slideAnimation,
      contentBuilder: (context, compact) => LoyaloAuthCard(
        title: title,
        description: description,
        emailKey: emailKey,
        passwordKey: passwordKey,
        titleFontSize: titleFontSize,
        createAccountIcon: createAccountIcon,
        compact: compact,
        formKey: formKey,
        emailController: emailController,
        passwordController: passwordController,
        passwordFocusNode: passwordFocusNode,
        obscurePassword: obscurePassword,
        rememberMe: rememberMe,
        loading: loading,
        error: error,
        validateEmail: validateEmail,
        validatePassword: validatePassword,
        onTogglePassword: onTogglePassword,
        onRememberMeChanged: onRememberMeChanged,
        onForgotPassword: onForgotPassword,
        onLogin: onLogin,
        onCreateAccount: onCreateAccount,
      ),
    );
  }
}

/// Cadre visuel partagé, indépendant du contenu des formulaires.
class LoyaloAuthScaffold extends StatelessWidget {
  const LoyaloAuthScaffold({
    super.key,
    required this.contentBuilder,
    required this.onBack,
    this.illustrationAsset = 'assets/images/login/client_login_hero.png',
    this.standardHeroHeight = 88,
    this.standardLogoHeight = 64,
    this.standardHeaderBottomSpacing = 8,
    this.headerBuilder,
    this.showBackButton = true,
    this.fadeAnimation,
    this.slideAnimation,
  });

  final Widget Function(BuildContext context, bool compact) contentBuilder;
  final VoidCallback? onBack;
  final String illustrationAsset;
  final bool showBackButton;
  final double standardHeroHeight;
  final double standardLogoHeight;
  final double standardHeaderBottomSpacing;
  final Widget Function(BuildContext context, bool compact, bool veryCompact)?
  headerBuilder;
  final Animation<double>? fadeAnimation;
  final Animation<Offset>? slideAnimation;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: LoyaloAuthColors.navy,
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _AuthBackground(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 700;
                  final veryCompact = constraints.maxHeight < 560;
                  final page = SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 12),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      children: [
                        if (headerBuilder != null)
                          headerBuilder!(context, compact, veryCompact)
                        else
                          LoyaloAuthHeader(
                            compact: compact,
                            veryCompact: veryCompact,
                            standardHeroHeight: standardHeroHeight,
                            standardLogoHeight: standardLogoHeight,
                            standardHeaderBottomSpacing:
                                standardHeaderBottomSpacing,
                            illustrationAsset: illustrationAsset,
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: contentBuilder(context, compact),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (reduceMotion || fadeAnimation == null) return page;
                  return FadeTransition(
                    opacity: fadeAnimation!,
                    child: slideAnimation == null
                        ? page
                        : SlideTransition(
                            position: slideAnimation!,
                            child: page,
                          ),
                  );
                },
              ),
            ),
            if (showBackButton)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: LoyaloAuthBackButton(onPressed: onBack),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LoyaloAuthBackButton extends StatelessWidget {
  const LoyaloAuthBackButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Retour',
    child: Material(
      color: const Color(0xFF16274A).withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 23,
          ),
        ),
      ),
    ),
  );
}

class LoyaloAuthHeader extends StatelessWidget {
  const LoyaloAuthHeader({
    super.key,
    required this.compact,
    required this.veryCompact,
    this.standardHeroHeight = 88,
    this.illustrationAsset = 'assets/images/login/client_login_hero.png',
    this.standardLogoHeight = 64,
    this.standardHeaderBottomSpacing = 8,
  });

  final bool compact;
  final bool veryCompact;
  final double standardHeroHeight;
  final String illustrationAsset;
  final double standardLogoHeight;
  final double standardHeaderBottomSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        final logoHeight = math.min(
          veryCompact ? 52.0 : (compact ? 56.0 : standardLogoHeight),
          math.min(192.0, math.max(0.0, constraints.maxWidth - 112)) / 3,
        );
        final logoWidth = logoHeight * 3;
        final heroHeight = veryCompact
            ? 54.0
            : (compact ? 72.0 : standardHeroHeight);
        final showIllustration =
            MediaQuery.viewInsetsOf(context).bottom == 0 &&
            MediaQuery.textScalerOf(context).scale(16) <= 23;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            compact ? 4 : standardHeaderBottomSpacing,
          ),
          child: Column(
            children: [
              Semantics(
                image: true,
                label: 'Loyalo, la fidélité qui récompense',
                child: ExcludeSemantics(
                  child: Image.asset(
                    'assets/images/logo_loyalo_v3_light.png',
                    width: logoWidth,
                    height: logoHeight,
                    fit: BoxFit.contain,
                    cacheWidth: math.max(1, (logoWidth * pixelRatio).ceil()),
                  ),
                ),
              ),
              if (showIllustration)
                ExcludeSemantics(
                  child: SizedBox(
                    height: heroHeight,
                    width: double.infinity,
                    child: Image.asset(
                      illustrationAsset,
                      fit: BoxFit.contain,
                      cacheHeight: (heroHeight * pixelRatio).ceil(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class LoyaloAuthCard extends StatelessWidget {
  const LoyaloAuthCard({
    super.key,
    required this.title,
    required this.description,
    required this.emailKey,
    required this.passwordKey,
    this.titleFontSize = 26,
    this.createAccountIcon = Icons.person_add_alt_1_rounded,
    required this.compact,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.passwordFocusNode,
    required this.obscurePassword,
    required this.rememberMe,
    required this.loading,
    required this.error,
    required this.validateEmail,
    required this.validatePassword,
    required this.onTogglePassword,
    required this.onRememberMeChanged,
    required this.onForgotPassword,
    required this.onLogin,
    required this.onCreateAccount,
  });

  final String title;
  final String description;
  final Key emailKey;
  final Key passwordKey;
  final double titleFontSize;
  final IconData createAccountIcon;
  final bool compact;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode passwordFocusNode;
  final bool obscurePassword;
  final bool rememberMe;
  final bool loading;
  final String? error;
  final String? Function(String?) validateEmail;
  final String? Function(String?) validatePassword;
  final VoidCallback? onTogglePassword;
  final ValueChanged<bool?>? onRememberMeChanged;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onLogin;
  final VoidCallback? onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return LoyaloAuthSurface(
      compact: compact,
      child: Form(
        key: formKey,
        child: AutofillGroup(
          child: Column(
            children: [
              LoyaloAuthHeading(
                title: title,
                description: description,
                titleFontSize: titleFontSize,
              ),
              SizedBox(height: compact ? 12 : 16),
              LoyaloAuthTextField(
                key: emailKey,
                controller: emailController,
                validator: validateEmail,
                hintText: 'Email',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                onFieldSubmitted: (_) => passwordFocusNode.requestFocus(),
              ),
              const SizedBox(height: 10),
              LoyaloAuthTextField(
                key: passwordKey,
                controller: passwordController,
                focusNode: passwordFocusNode,
                validator: validatePassword,
                hintText: 'Mot de passe',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => onLogin?.call(),
                suffixIcon: IconButton(
                  tooltip: obscurePassword
                      ? 'Afficher le mot de passe'
                      : 'Masquer le mot de passe',
                  onPressed: onTogglePassword,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (context, constraints) {
                  double measure(String text, TextStyle style) {
                    final painter = TextPainter(
                      text: TextSpan(
                        text: text,
                        style: DefaultTextStyle.of(context).style.merge(style),
                      ),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout();
                    final width = painter.width;
                    painter.dispose();
                    return width;
                  }

                  final remember = _RememberMe(
                    value: rememberMe,
                    onChanged: onRememberMeChanged,
                  );
                  final forgot = TextButton(
                    onPressed: onForgotPassword,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: const Text(
                      'Mot de passe oublié ?',
                      style: _forgotLabelStyle,
                    ),
                  );
                  final requiredWidth =
                      48 +
                      measure('Se souvenir de moi', _rememberLabelStyle) +
                      4 +
                      math.max(
                        48,
                        measure('Mot de passe oublié ?', _forgotLabelStyle) + 8,
                      );
                  if (constraints.maxWidth >= requiredWidth) {
                    return Row(
                      children: [
                        Expanded(child: remember),
                        const SizedBox(width: 4),
                        forgot,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(alignment: Alignment.centerLeft, child: remember),
                      Align(alignment: Alignment.centerRight, child: forgot),
                    ],
                  );
                },
              ),
              if (error != null) ...[
                const SizedBox(height: 4),
                LoyaloAuthError(message: error!),
              ],
              const SizedBox(height: 8),
              LoyaloAuthPrimaryButton(
                label: 'Se connecter',
                onPressed: onLogin,
                loading: loading,
              ),
              const SizedBox(height: 12),
              const _OrDivider(),
              const SizedBox(height: 12),
              LoyaloAuthOutlinedButton(
                onPressed: onCreateAccount,
                icon: createAccountIcon,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoyaloAuthSurface extends StatelessWidget {
  const LoyaloAuthSurface({
    super.key,
    required this.compact,
    required this.child,
  });

  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: LoyaloAuthColors.white,
        borderRadius: BorderRadius.all(Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 28,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 17,
              compact ? 16 : 20,
              compact ? 16 : 17,
              compact ? 18 : 22,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class LoyaloAuthHeading extends StatelessWidget {
  const LoyaloAuthHeading({
    super.key,
    required this.title,
    required this.description,
    this.titleFontSize = 26,
  });

  final String title;
  final String description;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: LoyaloAuthColors.textPrimary,
            fontSize: titleFontSize,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: LoyaloAuthColors.textSecondary,
            fontSize: 13.5,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class LoyaloAuthPrimaryButton extends StatelessWidget {
  const LoyaloAuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: DefaultTextStyle.of(context).style.merge(
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: math.max(0.0, constraints.maxWidth - 44));
        final buttonHeight = math.max(56.0, labelPainter.height + 20);
        labelPainter.dispose();
        return LoyaloGradientButton(
          label: label,
          onPressed: onPressed,
          trailingIcon: Icons.arrow_forward_rounded,
          loading: loading,
          height: buttonHeight,
          borderRadius: 22,
        );
      },
    );
  }
}

class LoyaloAuthError extends StatelessWidget {
  const LoyaloAuthError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: AppColors.danger,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class LoyaloAuthSecurityNote extends StatelessWidget {
  const LoyaloAuthSecurityNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: LoyaloAuthColors.purple.withValues(alpha: 0.09),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            color: LoyaloAuthColors.purple,
            size: 22,
          ),
        ),
        const SizedBox(width: 8),
        const Flexible(
          child: Text(
            'Vos données sont protégées de façon sécurisée.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LoyaloAuthColors.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class LoyaloAuthTextField extends StatelessWidget {
  const LoyaloAuthTextField({
    super.key,
    required this.controller,
    required this.validator,
    required this.hintText,
    required this.prefixIcon,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.suffixIcon,
    this.onFieldSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
    this.buildCounter,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final String hintText;
  final IconData prefixIcon;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;
  final TextCapitalization textCapitalization;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final int? maxLength;
  final InputCounterWidgetBuilder? buildCounter;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(19),
      borderSide: const BorderSide(color: Color(0xFFD5DEED), width: 1.3),
    );
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscureText,
      enableSuggestions: !obscureText,
      autocorrect: false,
      onFieldSubmitted: onFieldSubmitted,
      textCapitalization: textCapitalization,
      enabled: enabled,
      onChanged: onChanged,
      maxLines: maxLines,
      maxLength: maxLength,
      buildCounter: buildCounter,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        color: LoyaloAuthColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: LoyaloAuthColors.textSecondary),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF7586A6)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(
            color: LoyaloAuthColors.purple,
            width: 1.7,
          ),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 1.7),
        ),
        errorMaxLines: 2,
      ),
    );
  }
}

class _RememberMe extends StatelessWidget {
  const _RememberMe({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: LoyaloAuthColors.turquoise,
            checkColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            side: const BorderSide(color: Color(0xFF9AABC5)),
          ),
          const Flexible(
            child: Text('Se souvenir de moi', style: _rememberLabelStyle),
          ),
        ],
      ),
    );
  }
}

const _rememberLabelStyle = TextStyle(
  color: LoyaloAuthColors.textPrimary,
  fontSize: 13,
  fontWeight: FontWeight.w500,
);

const _forgotLabelStyle = TextStyle(
  color: LoyaloAuthColors.purple,
  fontSize: 13,
  fontWeight: FontWeight.w700,
);

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFD8E0ED))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'ou',
            style: TextStyle(
              color: LoyaloAuthColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFD8E0ED))),
      ],
    );
  }
}

class LoyaloAuthOutlinedButton extends StatelessWidget {
  const LoyaloAuthOutlinedButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.person_add_alt_1_rounded,
  });

  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 25),
        label: const Text(
          'Créer un compte',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: LoyaloAuthColors.purple,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          side: const BorderSide(color: LoyaloAuthColors.purple, width: 1.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: LoyaloAuthColors.navy),
          Positioned(
            top: -170,
            right: -170,
            child: _Glow(
              color: LoyaloAuthColors.turquoise.withValues(alpha: 0.35),
              size: 360,
            ),
          ),
          Positioned(
            top: 40,
            left: -190,
            child: _Glow(
              color: LoyaloAuthColors.purple.withValues(alpha: 0.30),
              size: 330,
            ),
          ),
          Positioned(
            bottom: -190,
            right: -170,
            child: _Glow(
              color: LoyaloAuthColors.turquoise.withValues(alpha: 0.28),
              size: 360,
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

abstract final class LoyaloAuthColors {
  static const navy = Color(0xFF000B27);
  static const turquoise = Color(0xFF00DCCB);
  static const purple = Color(0xFF8338EC);
  static const white = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF101D38);
  static const textSecondary = Color(0xFF64748B);
}
