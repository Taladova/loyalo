import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/database/app_database.dart';
import '../core/network/network_monitor.dart';
import '../models/app_user.dart';
import '../services/loyalty_repository.dart';
import '../services/merchant_image_service.dart';
import '../services/notification_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final networkMonitorProvider = Provider<NetworkMonitor>(
  (ref) => ConnectivityNetworkMonitor(),
);

final loyaltyRepositoryProvider = ChangeNotifierProvider<LoyaltyRepository>(
  (ref) => LoyaltyRepository(
    database: ref.watch(appDatabaseProvider),
    networkMonitor: ref.watch(networkMonitorProvider),
  ),
);

/// Utilisateur client connecté (null si personne n'est connecté).
final currentUserProvider = StateProvider<AppUser?>((ref) => null);

/// Identifiant du restaurant pour la session commerçant en cours
/// (null si aucun commerçant n'est connecté).
final currentMerchantRestaurantIdProvider = StateProvider<String?>(
  (ref) => null,
);

final merchantImageServiceProvider = Provider<MerchantImageService>(
  (ref) => MerchantImageService(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
