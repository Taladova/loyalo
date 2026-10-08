import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import 'merchant_client_profile_screen.dart';

class ClientSearchScreen extends ConsumerStatefulWidget {
  const ClientSearchScreen({super.key});

  @override
  ConsumerState<ClientSearchScreen> createState() => _ClientSearchScreenState();
}

class _ClientSearchScreenState extends ConsumerState<ClientSearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final results = repo.searchClients(_query);

    return Scaffold(
      appBar: AppBar(title: const Text('Rechercher un client')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher par nom, téléphone ou email',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = results[i];
                return Material(
                  color: AppTheme.surfaceOf(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.lavender.withValues(
                        alpha: 0.5,
                      ),
                      child: Text(
                        c.name.isNotEmpty ? c.name[0] : '?',
                        style: const TextStyle(
                          color: AppColors.purple,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      c.email,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textGray,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            MerchantClientProfileScreen(clientId: c.id),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
