import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import '../../firebase_options_pilot.dart';
import 'firebase_emulator_config.dart';

enum LoyaloFirebaseEnvironment { production, pilot, emulator }

final class FirebaseEnvironmentConfig {
  FirebaseEnvironmentConfig._({
    required this.environment,
    required this.options,
  });

  static const productionProjectId = 'loyalo-app';
  static const pilotProjectId = 'loyalo-pilot';
  static const emulatorProjectId = FirebaseEmulatorConfig.projectId;

  final LoyaloFirebaseEnvironment environment;
  final FirebaseOptions options;

  bool get usesEmulators => environment == LoyaloFirebaseEnvironment.emulator;

  static FirebaseEnvironmentConfig fromCompileTime() {
    const environment = String.fromEnvironment('LOYALO_FIREBASE_ENV');
    const pilotValues = <String, String>{
      'apiKey': String.fromEnvironment('LOYALO_FIREBASE_API_KEY'),
      'appId': String.fromEnvironment('LOYALO_FIREBASE_APP_ID'),
      'messagingSenderId': String.fromEnvironment(
        'LOYALO_FIREBASE_MESSAGING_SENDER_ID',
      ),
      'projectId': String.fromEnvironment('LOYALO_FIREBASE_PROJECT_ID'),
      'storageBucket': String.fromEnvironment('LOYALO_FIREBASE_STORAGE_BUCKET'),
      'authDomain': String.fromEnvironment('LOYALO_FIREBASE_AUTH_DOMAIN'),
      'measurementId': String.fromEnvironment('LOYALO_FIREBASE_MEASUREMENT_ID'),
      'iosBundleId': String.fromEnvironment('LOYALO_FIREBASE_IOS_BUNDLE_ID'),
    };
    return resolve(
      environmentName: environment,
      emulatorEnabled: FirebaseEmulatorConfig.enabled,
      pilotValues: pilotValues,
      pilotOptions: environment.trim().toLowerCase() == 'pilot'
          ? PilotFirebaseOptions.currentPlatform
          : null,
    );
  }

  static FirebaseEnvironmentConfig resolve({
    required String environmentName,
    required bool emulatorEnabled,
    Map<String, String> pilotValues = const {},
    FirebaseOptions? productionOptions,
    FirebaseOptions? pilotOptions,
  }) {
    final normalized = environmentName.trim().toLowerCase();
    final effective = normalized.isEmpty && emulatorEnabled
        ? 'emulator'
        : normalized;

    if (effective.isEmpty) {
      throw StateError(
        'Environnement Firebase manquant. Définissez explicitement '
        'LOYALO_FIREBASE_ENV=production, pilot ou emulator.',
      );
    }

    switch (effective) {
      case 'production':
        if (emulatorEnabled) {
          throw StateError(
            'Configuration incohérente : la production ne peut pas utiliser '
            'LOYALO_USE_FIREBASE_EMULATORS=true.',
          );
        }
        final options =
            productionOptions ?? DefaultFirebaseOptions.currentPlatform;
        if (options.projectId != productionProjectId) {
          throw StateError(
            'Configuration production invalide : projectId attendu '
            '$productionProjectId, reçu ${options.projectId}.',
          );
        }
        return FirebaseEnvironmentConfig._(
          environment: LoyaloFirebaseEnvironment.production,
          options: options,
        );
      case 'pilot':
        if (emulatorEnabled) {
          throw StateError(
            'Configuration incohérente : le pilote ne peut pas utiliser les '
            'émulateurs Firebase.',
          );
        }
        return FirebaseEnvironmentConfig._(
          environment: LoyaloFirebaseEnvironment.pilot,
          options: _validatedPilotOptions(pilotValues, pilotOptions),
        );
      case 'emulator':
        if (!emulatorEnabled) {
          throw StateError(
            'Le mode emulator exige '
            'LOYALO_USE_FIREBASE_EMULATORS=true.',
          );
        }
        return FirebaseEnvironmentConfig._(
          environment: LoyaloFirebaseEnvironment.emulator,
          options: FirebaseEmulatorConfig.firebaseOptions,
        );
      default:
        throw StateError(
          'Environnement Firebase inconnu "$environmentName". Valeurs '
          'acceptées : production, pilot, emulator.',
        );
    }
  }

  static FirebaseOptions _pilotOptions(Map<String, String> values) {
    const requiredKeys = [
      'apiKey',
      'appId',
      'messagingSenderId',
      'projectId',
      'storageBucket',
    ];
    final missing = requiredKeys.where((key) {
      final value = (values[key] ?? '').trim();
      return value.isEmpty || value.startsWith('REPLACE_');
    }).toList();
    if (missing.isNotEmpty) {
      throw StateError(
        'Configuration Firebase pilote incomplète : ${missing.join(', ')}. '
        'Aucun fallback vers la production n’est autorisé.',
      );
    }

    final projectId = values['projectId']!.trim();
    if (projectId != pilotProjectId) {
      throw StateError(
        'Une build pilote doit cibler exclusivement $pilotProjectId, reçu '
        '$projectId.',
      );
    }

    String? optional(String key) {
      final value = values[key]?.trim() ?? '';
      return value.isEmpty ? null : value;
    }

    return FirebaseOptions(
      apiKey: values['apiKey']!.trim(),
      appId: values['appId']!.trim(),
      messagingSenderId: values['messagingSenderId']!.trim(),
      projectId: projectId,
      storageBucket: values['storageBucket']!.trim(),
      authDomain: optional('authDomain'),
      measurementId: optional('measurementId'),
      iosBundleId: optional('iosBundleId'),
    );
  }

  static FirebaseOptions _validatedPilotOptions(
    Map<String, String> values,
    FirebaseOptions? configuredOptions,
  ) {
    if (configuredOptions == null) return _pilotOptions(values);

    final requestedProjectId = (values['projectId'] ?? '').trim();
    if (requestedProjectId != pilotProjectId) {
      throw StateError(
        'LOYALO_FIREBASE_PROJECT_ID doit être $pilotProjectId pour une build '
        'pilote, reçu ${requestedProjectId.isEmpty ? "vide" : requestedProjectId}.',
      );
    }
    if (configuredOptions.projectId != pilotProjectId) {
      throw StateError(
        'Les FirebaseOptions pilote ciblent ${configuredOptions.projectId} au '
        'lieu de $pilotProjectId.',
      );
    }
    return configuredOptions;
  }

  void ensureInitializedProject(String actualProjectId) {
    if (actualProjectId != options.projectId) {
      throw StateError(
        'Firebase a initialisé le projet $actualProjectId alors que '
        '${options.projectId} était attendu. Arrêt pour éviter tout accès au '
        'mauvais environnement.',
      );
    }
    if (environment == LoyaloFirebaseEnvironment.pilot &&
        actualProjectId == productionProjectId) {
      throw StateError(
        'Une build pilote ne peut jamais utiliser le projet de production.',
      );
    }
  }
}
