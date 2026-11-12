import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'loyalo_auth_ui.dart';

enum LoyaloVisitMethod {
  scanner('Scanner QR', Icons.qr_code_scanner_rounded),
  code('Code à 6 chiffres', Icons.dialpad_rounded),
  search('Rechercher', Icons.person_search_outlined);

  const LoyaloVisitMethod(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Sélection de présentation uniquement ; les parcours restent dans l'écran.
class LoyaloVisitMethodSelector extends StatelessWidget {
  const LoyaloVisitMethodSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final LoyaloVisitMethod selected;
  final ValueChanged<LoyaloVisitMethod> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 23;
    Widget item(LoyaloVisitMethod method) {
      final active = method == selected;
      final color = active ? Colors.white : LoyaloAuthColors.textPrimary;
      final label = Text(
        method.label,
        textAlign: largeText ? TextAlign.start : TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: largeText ? 14 : 12.5,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
      );
      final icon = Icon(
        method.icon,
        size: 22,
        color: active ? Colors.white : LoyaloAuthColors.purple,
      );
      return Semantics(
        selected: active,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: active ? AppColors.brandGradient : null,
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextButton(
            key: ValueKey('visit-method-${method.name}'),
            onPressed: enabled ? () => onSelected(method) : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 56),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: largeText
                ? Row(
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(child: label),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [icon, const SizedBox(height: 5), label],
                  ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: largeText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final method in LoyaloVisitMethod.values) item(method),
                ],
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final method in LoyaloVisitMethod.values)
                      Expanded(child: item(method)),
                  ],
                ),
              ),
      ),
    );
  }
}

class LoyaloVisitCodePane extends StatelessWidget {
  const LoyaloVisitCodePane({
    super.key,
    required this.digits,
    required this.loading,
    required this.onDigit,
    required this.onBackspace,
    required this.onPaste,
    required this.onValidate,
  });

  final String digits;
  final bool loading;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onPaste;
  final VoidCallback? onValidate;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 23;
    return LoyaloAuthSurface(
      compact: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!largeText) ...[
                const _VisitIllustration(
                  asset: 'assets/images/validation/visit_code_illustration.png',
                  size: 48,
                ),
                const SizedBox(width: 10),
              ],
              const Expanded(
                child: Text(
                  'Demandez le code à 6 chiffres à votre client',
                  style: TextStyle(
                    color: LoyaloAuthColors.textPrimary,
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Coller un code à 6 chiffres',
                onPressed: loading ? null : onPaste,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(
                  Icons.content_paste_rounded,
                  color: LoyaloAuthColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Les règles du programme de fidélité s’appliquent.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LoyaloAuthColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            key: const Key('visit-code-digits'),
            label: 'Code de validation, 6 chiffres',
            value: digits.isEmpty
                ? 'Aucun chiffre saisi'
                : digits.split('').join(' '),
            liveRegion: true,
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 50),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: i == digits.length && !loading
                                ? LoyaloAuthColors.purple
                                : const Color(0xFFD5DEED),
                            width: i == digits.length && !loading ? 1.8 : 1.2,
                          ),
                        ),
                        child: Text(
                          i < digits.length ? digits[i] : '',
                          style: const TextStyle(
                            color: LoyaloAuthColors.textPrimary,
                            fontSize: 21,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', '⌫'],
          ]) ...[
            Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: row[i].isEmpty
                        ? const SizedBox.shrink()
                        : TextButton(
                            onPressed: loading
                                ? null
                                : () => row[i] == '⌫'
                                      ? onBackspace()
                                      : onDigit(row[i]),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 4,
                              ),
                              foregroundColor: LoyaloAuthColors.textPrimary,
                              backgroundColor: const Color(0xFFF8FAFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Semantics(
                              label: row[i] == '⌫'
                                  ? 'Effacer le dernier chiffre'
                                  : row[i],
                              excludeSemantics: true,
                              child: Text(
                                row[i],
                                style: const TextStyle(
                                  fontSize: 20,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          LoyaloAuthPrimaryButton(
            label: 'Valider la visite',
            onPressed: onValidate,
            loading: loading,
          ),
        ],
      ),
    );
  }
}

/// Aucun flux caméra ou faux QR avant la disponibilité du service sécurisé.
class LoyaloVisitQrUnavailable extends StatelessWidget {
  const LoyaloVisitQrUnavailable({
    super.key,
    required this.client,
    required this.onCode,
    this.onSearch,
  });
  final bool client;
  final VoidCallback onCode;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 23;
    return LoyaloAuthSurface(
      compact: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!largeText) ...[
                const _VisitIllustration(
                  asset: 'assets/images/validation/visit_qr_illustration.png',
                  size: 48,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: const Text(
                    'QR temporaire indisponible',
                    style: TextStyle(
                      color: LoyaloAuthColors.textPrimary,
                      fontSize: 18,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            client
                ? 'Vous pouvez continuer à présenter votre code à 6 chiffres au commerçant.'
                : 'Le scan QR n’est pas encore disponible. Utilisez le code à 6 chiffres ou recherchez un client.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: LoyaloAuthColors.textSecondary,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          if (!largeText) ...[
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(minHeight: 96),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1EDFF),
                border: Border.all(color: const Color(0xFFD8C8F9)),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: LoyaloAuthColors.purple,
                  size: 36,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          LoyaloAuthPrimaryButton(
            label: client
                ? 'Voir mon code à 6 chiffres'
                : 'Utiliser le code à 6 chiffres',
            onPressed: onCode,
          ),
          if (onSearch != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onSearch,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.person_search_outlined),
              label: const Text(
                'Rechercher un client',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VisitIllustration extends StatelessWidget {
  const _VisitIllustration({required this.asset, required this.size});
  final String asset;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
    ),
  );
}
