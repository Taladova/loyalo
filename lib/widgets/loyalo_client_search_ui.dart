import 'package:flutter/material.dart';

import 'loyalo_auth_ui.dart';
import 'loyalo_page_header.dart';

/// Présentation uniquement : aucun accès à l'annuaire ni à Firestore.
class LoyaloClientSearchHeader extends StatelessWidget {
  const LoyaloClientSearchHeader({
    super.key,
    required this.onBack,
    required this.showDescription,
  });
  final VoidCallback? onBack;
  final bool showDescription;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: Column(
      children: [
        LoyaloPageHeader(
          title: 'Rechercher un client',
          onBack: onBack,
          showBackButton: onBack != null,
        ),
        if (showDescription) ...[
          const SizedBox(height: 8),
          const Text(
            'Recherchez un client pour consulter son profil ou accéder aux actions disponibles.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
          ),
        ],
      ],
    ),
  );
}

class LoyaloSearchField extends StatelessWidget {
  const LoyaloSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onClear,
    required this.onSubmitted,
    this.enabled = true,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;
  final VoidCallback onSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: Color(0xFFD5DEED), width: 1.2),
    );
    return Semantics(
      label: 'Rechercher un client',
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        onSubmitted: (_) => onSubmitted(),
        onTapOutside: (_) => focusNode.unfocus(),
        style: const TextStyle(
          color: LoyaloAuthColors.textPrimary,
          fontSize: 16,
          height: 1.25,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: MediaQuery.textScalerOf(context).scale(16) > 23
              ? 'Nom ou téléphone'
              : 'Rechercher par nom, téléphone…',
          hintStyle: const TextStyle(
            color: LoyaloAuthColors.textSecondary,
            fontSize: 14.5,
          ),
          prefixIcon: const ExcludeSemantics(
            child: Icon(
              Icons.search_rounded,
              color: LoyaloAuthColors.purple,
              size: 25,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Effacer la recherche',
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: LoyaloAuthColors.textSecondary,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: border,
          enabledBorder: border,
          disabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(
              color: LoyaloAuthColors.purple,
              width: 1.7,
            ),
          ),
        ),
      ),
    );
  }
}

/// Le champ reste accessible quand la liste défile et quand le clavier s'ouvre.
class LoyaloSearchBarDelegate extends SliverPersistentHeaderDelegate {
  LoyaloSearchBarDelegate({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox(
    height: height,
    child: ColoredBox(
      color: LoyaloAuthColors.navy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: child,
      ),
    ),
  );
  @override
  bool shouldRebuild(covariant LoyaloSearchBarDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}

class LoyaloClientCard extends StatelessWidget {
  const LoyaloClientCard({super.key, required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = name.trim().isEmpty ? 'Profil client' : name;
    return Semantics(
      button: true,
      label: 'Consulter le profil de $label',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFDDE3F0)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: LoyaloAuthColors.purple.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: LoyaloAuthColors.purple,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: LoyaloAuthColors.textPrimary,
                          fontSize: 16,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Consulter le profil',
                        style: TextStyle(
                          color: LoyaloAuthColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: LoyaloAuthColors.textSecondary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoyaloClientSearchState extends StatelessWidget {
  const LoyaloClientSearchState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String message;
  final IconData icon;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: LoyaloAuthColors.purple.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: loading
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: LoyaloAuthColors.purple,
                          ),
                        ),
                      )
                    : Icon(icon, size: 38, color: LoyaloAuthColors.purple),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LoyaloAuthColors.textPrimary,
                fontSize: 20,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LoyaloAuthColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 22),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: LoyaloAuthColors.purple,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.all(12),
                ),
                child: Text(
                  actionLabel!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
