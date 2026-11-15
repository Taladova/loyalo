import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/checkins/data/check_in_remote_data_source.dart';
import '../../models/check_in_request.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/loyalty_repository.dart';
import '../../widgets/loyalo_auth_ui.dart';
import '../../widgets/loyalo_client_search_ui.dart';
import '../../widgets/loyalo_ui.dart';

/// Recherche dans le cache autorisé existant ; aucune visite créée à la sélection.
class VisitClientSearchPane extends ConsumerStatefulWidget {
  const VisitClientSearchPane({super.key, required this.onBusyChanged});
  final ValueChanged<bool> onBusyChanged;

  @override
  ConsumerState<VisitClientSearchPane> createState() =>
      _VisitClientSearchPaneState();
}

class _VisitClientSearchPaneState extends ConsumerState<VisitClientSearchPane> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  DirectoryClient? _selected;
  Stream<List<CheckInRequest>>? _arrivals;
  CheckInRequest? _latest;
  String? _selectedShop;
  String? _selectedOwner;
  String? _message;
  bool _busy = false;
  bool _processed = false;
  bool _retrying = false;
  bool _retryFailed = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(_changed);
  }

  void _changed() => setState(() {
    _selected = null;
    _arrivals = null;
    _latest = null;
    _message = null;
    _processed = false;
  });

  @override
  void dispose() {
    _query.removeListener(_changed);
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _select(DirectoryClient client, String shop, LoyaltyRepository repo) {
    if (_busy) return;
    _focus.unfocus();
    final owner = AuthService().currentUser?.uid;
    setState(() {
      _selected = client;
      _selectedShop = shop;
      _selectedOwner = owner;
      _message = null;
      _processed = false;
      _latest = null;
      _arrivals = owner == null
          ? null
          : repo.watchMerchantValidationQueue(shop, ownerUid: owner);
    });
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retryFailed = false;
    });
    try {
      await ref.read(loyaltyRepositoryProvider).retryRestaurants();
    } catch (_) {
      if (mounted) setState(() => _retryFailed = true);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  bool _sameSession() =>
      _selectedOwner != null &&
      AuthService().currentUser?.uid == _selectedOwner &&
      ref.read(currentMerchantRestaurantIdProvider) == _selectedShop;

  Future<void> _confirm(CheckInRequest request) async {
    if (_busy || _processed || !secureApproveCheckInEnabled) return;
    _focus.unfocus();
    setState(() {
      _busy = true;
      _message = null;
    });
    widget.onBusyChanged(true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Confirmer la visite ?'),
          content: Text(
            'Confirmer l’arrivée de ${_selected!.name} dans votre commerce ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              key: const Key('visit-search-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final repo = ref.read(loyaltyRepositoryProvider);
      final shop = repo.restaurantByIdOrNull(_selectedShop!);
      if (!_sameSession() || shop?.ownerId != _selectedOwner) {
        setState(
          () => _message = 'Session commerçant indisponible. Reconnectez-vous.',
        );
        return;
      }
      final stillAuthorized = repo
          .searchClients(_query.text)
          .any((c) => c.id == _selected?.id);
      if (!stillAuthorized ||
          _latest?.id != request.id ||
          request.customerId != _selected?.id ||
          request.restaurantId != _selectedShop ||
          !request.isPending ||
          request.isExpired(DateTime.now())) {
        setState(
          () => _message =
              'Cette arrivée n’est plus disponible. Actualisez votre recherche.',
        );
        return;
      }
      if (!shop!.active) {
        setState(
          () => _message =
              'Ce commerce est inactif. La visite ne peut pas être confirmée.',
        );
        return;
      }
      if (!await ref.read(networkMonitorProvider).isNetworkAvailable) {
        if (mounted) {
          setState(
            () => _message =
                'Connectez-vous à Internet pour confirmer cette arrivée.',
          );
        }
        return;
      }
      if (!mounted || !_sameSession()) return;
      // Même service que Loyalo Express, avec la clé de l'arrivée existante.
      // Aucun registerVisit, calcul ou écriture de points dans cet écran.
      final result = await repo.approveCheckIn(
        checkInId: request.id,
        merchantId: _selectedOwner!,
      );
      if (!mounted) return;
      final success =
          result.outcome == CheckInValidationOutcome.validated ||
          result.outcome == CheckInValidationOutcome.rewardUnlocked;
      setState(() {
        _processed = success;
        _message = switch (result.outcome) {
          CheckInValidationOutcome.validated ||
          CheckInValidationOutcome.rewardUnlocked =>
            !result.synced
                ? 'Demande enregistrée. La validation et les points restent à confirmer après synchronisation.'
                : result.outcome == CheckInValidationOutcome.rewardUnlocked
                ? 'Visite confirmée. Récompense débloquée.'
                : 'Visite confirmée.',
          CheckInValidationOutcome.alreadyValidated =>
            'Une visite a déjà été validée selon les règles de votre programme.',
          CheckInValidationOutcome.expired => 'Cette arrivée a expiré.',
          CheckInValidationOutcome.notPending =>
            'Cette arrivée est déjà traitée.',
          CheckInValidationOutcome.notFound => 'Arrivée introuvable.',
          CheckInValidationOutcome.unauthorized =>
            'Vous ne pouvez pas confirmer cette arrivée.',
          CheckInValidationOutcome.rejected => 'Cette demande a été refusée.',
        };
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Confirmation indisponible. Vérifiez votre connexion et réessayez.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged(false);
      }
    }
  }

  Widget _selection(
    LoyaltyRepository repo,
  ) => StreamBuilder<List<CheckInRequest>>(
    stream: _arrivals,
    builder: (context, snapshot) {
      final shop = repo.restaurantByIdOrNull(_selectedShop!);
      final requests =
          snapshot.data
              ?.where(
                (r) =>
                    r.customerId == _selected!.id &&
                    r.restaurantId == _selectedShop &&
                    r.isPending &&
                    !r.isExpired(DateTime.now()),
              )
              .toList() ??
          [];
      requests.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      final failed = snapshot.hasError || repo.checkInsLoadError != null;
      final loading =
          !failed && snapshot.connectionState == ConnectionState.waiting;
      _latest = failed || loading ? null : requests.firstOrNull;
      final available =
          _sameSession() &&
          shop?.ownerId == _selectedOwner &&
          shop?.active == true;
      final message = !available
          ? 'Cette visite ne peut pas être confirmée avec cette session ou ce commerce.'
          : failed
          ? 'Impossible de charger les arrivées. Réessayez la recherche.'
          : loading
          ? 'Chargement de l’arrivée…'
          : !snapshot.hasData
          ? 'Les arrivées sont indisponibles pour le moment.'
          : _latest == null
          ? 'Aucune arrivée valide pour ce client. Demandez-lui d’effectuer un check-in dans votre commerce avant de confirmer sa visite.'
          : !secureApproveCheckInEnabled
          ? 'La confirmation sécurisée est indisponible dans cette version.'
          : 'Une arrivée est en attente. Confirmez explicitement la visite pour poursuivre.';
      return LoyaloCard(
        key: const Key('visit-search-selection'),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _selected!.name,
              style: const TextStyle(
                color: LoyaloAuthColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (loading) const LinearProgressIndicator(),
            if (_message == null || !_processed)
              Text(
                message,
                style: const TextStyle(
                  color: LoyaloAuthColors.textSecondary,
                  height: 1.4,
                ),
              ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  key: const Key('visit-search-feedback'),
                  style: const TextStyle(
                    color: LoyaloAuthColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            if (available &&
                !failed &&
                !loading &&
                _latest != null &&
                secureApproveCheckInEnabled) ...[
              const SizedBox(height: 16),
              LoyaloAuthPrimaryButton(
                key: const Key('visit-search-approve'),
                label: 'Confirmer cette arrivée',
                loading: _busy,
                onPressed: _busy || _processed
                    ? null
                    : () => _confirm(_latest!),
              ),
            ],
            TextButton(
              key: const Key('visit-search-reset'),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _selected = null;
                      _arrivals = null;
                      _latest = null;
                      _message = null;
                    }),
              child: const Text('Choisir un autre client'),
            ),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final shopId = ref.watch(currentMerchantRestaurantIdProvider);
    final shop = shopId == null ? null : repo.restaurantByIdOrNull(shopId);
    final loading =
        _retrying ||
        repo.merchantClientsLoading ||
        (shop == null && repo.restaurantsLoading);
    var failed =
        _retryFailed ||
        repo.merchantClientsLoadError != null ||
        repo.restaurantsLoadError != null;
    var clients = const <DirectoryClient>[];
    if (shop != null && !loading && !failed) {
      try {
        clients = repo.searchClients(_query.text);
      } catch (_) {
        failed = true;
      }
    }
    final initial = _query.text.trim().isEmpty;
    Widget content;
    if (shopId == null) {
      content = const LoyaloClientSearchState(
        key: Key('visit-search-session'),
        title: 'Session indisponible',
        message: 'Reconnectez-vous à votre espace commerçant.',
        icon: Icons.lock_outline,
      );
    } else if (loading) {
      content = const LoyaloClientSearchState(
        key: Key('visit-search-loading'),
        title: 'Chargement des clients…',
        message: 'La recherche sera disponible dans un instant.',
        icon: Icons.people_outline,
        loading: true,
      );
    } else if (failed) {
      content = LoyaloClientSearchState(
        key: const Key('visit-search-error'),
        title: 'Recherche indisponible',
        message: 'Impossible de charger les clients. Réessayez.',
        icon: Icons.info_outline,
        actionLabel: 'Réessayer',
        onAction: _retry,
      );
    } else if (shop == null) {
      content = const LoyaloClientSearchState(
        key: Key('visit-search-unavailable'),
        title: 'Commerce indisponible',
        message: 'Le commerce doit être chargé pour rechercher un client.',
        icon: Icons.storefront_outlined,
      );
    } else if (_selected != null &&
        _selectedShop == shopId &&
        clients.any((c) => c.id == _selected!.id)) {
      content = _selection(repo);
    } else if (initial) {
      content = const LoyaloClientSearchState(
        key: Key('visit-search-initial'),
        title: 'Recherchez un client',
        message: 'Saisissez un nom ou un numéro de téléphone.',
        icon: Icons.person_search_outlined,
      );
    } else if (clients.isEmpty) {
      content = const LoyaloClientSearchState(
        key: Key('visit-search-empty'),
        title: 'Aucun client trouvé',
        message: 'Vérifiez le nom ou le numéro de téléphone saisi.',
        icon: Icons.person_search_outlined,
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${clients.length} résultat${clients.length > 1 ? 's' : ''}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final client in clients)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ClientSelectionCard(
                client: client,
                onTap: () => _select(client, shopId, repo),
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoyaloSearchField(
          key: const Key('visit-search-field'),
          controller: _query,
          focusNode: _focus,
          enabled: shopId != null && !_busy,
          onClear: _query.clear,
          onSubmitted: _focus.unfocus,
        ),
        const SizedBox(height: 16),
        if (initial || failed || loading || shop == null)
          LoyaloCard(
            color: Colors.white,
            padding: EdgeInsets.zero,
            child: content,
          )
        else
          content,
      ],
    );
  }
}

class _ClientSelectionCard extends StatelessWidget {
  const _ClientSelectionCard({required this.client, required this.onTap});
  final DirectoryClient client;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => LoyaloCard(
    padding: EdgeInsets.zero,
    color: Colors.white,
    child: InkWell(
      key: ValueKey('visit-search-client-${client.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.person_outline_rounded,
                color: LoyaloAuthColors.purple,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                client.name,
                style: const TextStyle(
                  color: LoyaloAuthColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const ExcludeSemantics(
              child: Icon(
                Icons.chevron_right,
                color: LoyaloAuthColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
