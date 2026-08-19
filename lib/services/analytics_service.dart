import 'package:firebase_analytics/firebase_analytics.dart';

/// Fine couche au-dessus de Firebase Analytics : centralise les événements
/// métier qu'on veut suivre pendant le pilote (qui se connecte, qui valide
/// une visite, qui débloque une récompense...).
class AnalyticsService {
  static final FirebaseAnalytics instance = FirebaseAnalytics.instance;

  static FirebaseAnalyticsObserver get observer => FirebaseAnalyticsObserver(analytics: instance);

  static Future<void> logClientLogin() => instance.logLogin(loginMethod: 'client');

  static Future<void> logMerchantLogin() => instance.logLogin(loginMethod: 'merchant');

  static Future<void> logMerchantSignUp() => instance.logSignUp(signUpMethod: 'merchant');

  static Future<void> logVisitRegistered({required String restaurantId}) => instance.logEvent(
        name: 'visit_registered',
        parameters: {'restaurant_id': restaurantId},
      );

  static Future<void> logRewardUnlocked({required String restaurantId, required String rewardLabel}) =>
      instance.logEvent(
        name: 'reward_unlocked',
        parameters: {'restaurant_id': restaurantId, 'reward_label': rewardLabel},
      );

  static Future<void> logRewardCreated({required String restaurantId}) => instance.logEvent(
        name: 'reward_created',
        parameters: {'restaurant_id': restaurantId},
      );
}
