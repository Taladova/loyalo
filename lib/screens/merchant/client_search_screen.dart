import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/loyalty_repository.dart';
import '../../widgets/loyalo_auth_ui.dart';
import '../../widgets/loyalo_client_search_ui.dart';
import 'merchant_client_profile_screen.dart';

class ClientSearchScreen extends ConsumerStatefulWidget {
  const ClientSearchScreen({super.key});
  @override
  ConsumerState<ClientSearchScreen> createState() => _ClientSearchScreenState();
}

class _ClientSearchScreenState extends ConsumerState<ClientSearchScreen>
    with WidgetsBindingObserver {
  final _query = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _fieldKey = GlobalKey();
  String _lastQuery = '';
  bool _showDirectory = false;
  bool _retrying = false;
  bool _retryFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _query.addListener(_queryChanged);
    _focus.addListener(_focusChanged);
  }

  void _queryChanged() {
    if (_query.text == _lastQuery) return;
    _lastQuery = _query.text;
    setState(() => _showDirectory = false);
  }

  void _focusChanged() {
    setState(() {});
    _revealField();
  }

  @override
  void didChangeMetrics() => _revealField();

  void _revealField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _fieldKey.currentContext;
      if (!mounted || !_focus.hasFocus || context == null) return;
      Scrollable.ensureVisible(context, alignment: 0);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _query.removeListener(_queryChanged);
    _focus.removeListener(_focusChanged);
    _query.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _retry(LoyaltyRepository repo) async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retryFailed = false;
    });
    try {
      await repo.retryRestaurants();
    } catch (_) {
      if (mounted) setState(() => _retryFailed = true);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider);
    final restaurant = restaurantId == null
        ? null
        : repo.restaurantByIdOrNull(restaurantId);
    final loading =
        restaurantId != null &&
        (_retrying ||
            repo.merchantClientsLoading ||
            (restaurant == null && repo.restaurantsLoading));
    var failed =
        _retryFailed ||
        repo.merchantClientsLoadError != null ||
        repo.restaurantsLoadError != null;
    var localSearchFailed = false;
    var results = const <DirectoryClient>[];
    if (restaurant != null && !loading && !failed) {
      try {
        // Le filtrage et les critères restent ceux du cache existant.
        results = repo.searchClients(_query.text);
      } catch (_) {
        failed = true;
        localSearchFailed = true;
      }
    }
    final initial = _query.text.trim().isEmpty && !_showDirectory;
    final showResults =
        restaurant != null &&
        !loading &&
        !failed &&
        !initial &&
        results.isNotEmpty;
    final canPop = Navigator.of(context).canPop();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final scale = MediaQuery.textScalerOf(context);
    final fieldHeight = math.max(56.0, scale.scale(16) * 1.4 + 24);

    Widget state;
    if (restaurantId == null) {
      state = const LoyaloClientSearchState(
        key: Key('client-search-session'),
        title: 'Session indisponible',
        message:
            'Reconnectez-vous à votre espace commerçant pour rechercher un client.',
        icon: Icons.lock_outline_rounded,
      );
    } else if (loading) {
      state = const LoyaloClientSearchState(
        key: Key('client-search-loading'),
        title: 'Chargement des clients…',
        message: 'Vous pouvez préparer votre recherche pendant le chargement.',
        icon: Icons.people_outline_rounded,
        loading: true,
      );
    } else if (failed) {
      state = LoyaloClientSearchState(
        key: const Key('client-search-error'),
        title: 'Recherche indisponible',
        message:
            'Impossible de rechercher les clients pour le moment. Réessayez.',
        icon: Icons.info_outline_rounded,
        actionLabel: 'Réessayer',
        onAction: localSearchFailed
            ? () => setState(() {})
            : () => _retry(repo),
      );
    } else if (restaurant == null) {
      state = const LoyaloClientSearchState(
        key: Key('client-search-unavailable'),
        title: 'Commerce indisponible',
        message:
            'La recherche sera disponible lorsque votre commerce sera chargé.',
        icon: Icons.storefront_outlined,
      );
    } else if (initial) {
      state = LoyaloClientSearchState(
        key: const Key('client-search-initial'),
        title: 'Recherchez un client',
        message:
            'Saisissez un nom ou un numéro de téléphone pour retrouver un client.',
        icon: Icons.people_outline_rounded,
        actionLabel: 'Afficher les clients du commerce',
        onAction: results.isEmpty
            ? null
            : () {
                _focus.unfocus();
                setState(() => _showDirectory = true);
              },
      );
    } else {
      state = const LoyaloClientSearchState(
        key: Key('client-search-empty'),
        title: 'Aucun client trouvé',
        message:
            'Aucun client ne correspond à votre recherche. Vérifiez les informations saisies.',
        icon: Icons.person_search_outlined,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: LoyaloAuthColors.navy,
        resizeToAvoidBottomInset: true,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.2,
              colors: [
                Color(0xFF075467),
                LoyaloAuthColors.navy,
                Color(0xFF160F43),
              ],
              stops: [0, 0.55, 1],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomScrollView(
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: LoyaloClientSearchHeader(
                        onBack: canPop
                            ? () {
                                _focus.unfocus();
                                Navigator.of(context).maybePop();
                              }
                            : null,
                        showDescription:
                            !keyboard &&
                            !_focus.hasFocus &&
                            scale.scale(16) <= 23 &&
                            constraints.maxHeight >= 400,
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: LoyaloSearchBarDelegate(
                        height: fieldHeight + 20,
                        child: LoyaloSearchField(
                          key: _fieldKey,
                          controller: _query,
                          focusNode: _focus,
                          enabled: restaurantId != null,
                          onClear: () {
                            _query.clear();
                            _focus.requestFocus();
                          },
                          onSubmitted: _focus.unfocus,
                        ),
                      ),
                    ),
                    DecoratedSliver(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFF),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          if (showResults) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  22,
                                  20,
                                  14,
                                ),
                                child: Semantics(
                                  header: true,
                                  liveRegion: true,
                                  child: Text(
                                    _showDirectory
                                        ? 'Clients du commerce · ${results.length}'
                                        : '${results.length} résultat${results.length > 1 ? 's' : ''}',
                                    key: const Key(
                                      'client-search-results-count',
                                    ),
                                    style: const TextStyle(
                                      color: LoyaloAuthColors.textPrimary,
                                      fontSize: 18,
                                      height: 1.3,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              sliver: SliverList.builder(
                                itemCount: results.length,
                                itemBuilder: (context, index) {
                                  final client = results[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: LoyaloClientCard(
                                      key: ValueKey(
                                        'client-search-result-${client.id}',
                                      ),
                                      name: client.name,
                                      onTap: () {
                                        _focus.unfocus();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                MerchantClientProfileScreen(
                                                  clientId: client.id,
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: SizedBox.shrink(),
                            ),
                          ] else
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: state,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
