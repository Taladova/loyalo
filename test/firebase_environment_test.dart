import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/core/firebase/firebase_environment.dart';
import 'package:loyalo/firebase_options_pilot.dart';

void main() {
  const productionOptions = FirebaseOptions(
    apiKey: 'production-key',
    appId: 'production-app',
    messagingSenderId: 'production-sender',
    projectId: FirebaseEnvironmentConfig.productionProjectId,
  );
  const validPilotValues = {
    'apiKey': 'pilot-key',
    'appId': 'pilot-app',
    'messagingSenderId': 'pilot-sender',
    'projectId': FirebaseEnvironmentConfig.pilotProjectId,
    'storageBucket': 'loyalo-pilot.firebasestorage.app',
  };

  test('un environnement absent ne bascule jamais vers la production', () {
    expect(
      () => FirebaseEnvironmentConfig.resolve(
        environmentName: '',
        emulatorEnabled: false,
        productionOptions: productionOptions,
      ),
      throwsStateError,
    );
  });

  test('la production doit être sélectionnée explicitement', () {
    final config = FirebaseEnvironmentConfig.resolve(
      environmentName: 'production',
      emulatorEnabled: false,
      productionOptions: productionOptions,
    );

    expect(config.environment, LoyaloFirebaseEnvironment.production);
    expect(config.options.projectId, 'loyalo-app');
  });

  test('une configuration pilote manquante échoue sans fallback', () {
    expect(
      () => FirebaseEnvironmentConfig.resolve(
        environmentName: 'pilot',
        emulatorEnabled: false,
        pilotValues: const {'projectId': 'loyalo-pilot'},
      ),
      throwsStateError,
    );
  });

  test('les placeholders du fichier exemple sont refusés', () {
    expect(
      () => FirebaseEnvironmentConfig.resolve(
        environmentName: 'pilot',
        emulatorEnabled: false,
        pilotValues: const {
          'apiKey': 'REPLACE_AFTER_FIREBASE_PROJECT_CREATION',
          'appId': 'REPLACE_WITH_PLATFORM_APP_ID',
          'messagingSenderId': 'REPLACE_AFTER_FIREBASE_PROJECT_CREATION',
          'projectId': 'loyalo-pilot',
          'storageBucket': 'REPLACE_AFTER_FIREBASE_PROJECT_CREATION',
        },
      ),
      throwsStateError,
    );
  });

  test('une build pilote refuse le projectId de production', () {
    expect(
      () => FirebaseEnvironmentConfig.resolve(
        environmentName: 'pilot',
        emulatorEnabled: false,
        pilotValues: {
          ...validPilotValues,
          'projectId': FirebaseEnvironmentConfig.productionProjectId,
        },
      ),
      throwsStateError,
    );
  });

  test('une configuration pilote complète cible uniquement loyalo-pilot', () {
    final config = FirebaseEnvironmentConfig.resolve(
      environmentName: 'pilot',
      emulatorEnabled: false,
      pilotValues: validPilotValues,
    );

    expect(config.environment, LoyaloFirebaseEnvironment.pilot);
    expect(config.options.projectId, 'loyalo-pilot');
    expect(config.options.projectId, isNot('loyalo-app'));
  });

  test(
    'les options FlutterFire pilote natives sont isolées de la production',
    () {
      expect(PilotFirebaseOptions.android.projectId, 'loyalo-pilot');
      expect(
        PilotFirebaseOptions.android.appId,
        isNot(contains('1095968052802')),
      );
      expect(PilotFirebaseOptions.ios.projectId, 'loyalo-pilot');
      expect(PilotFirebaseOptions.ios.iosBundleId, 'com.loyalo.loyalo.pilot');
    },
  );

  test('la sélection pilote accepte les options FlutterFire vérifiées', () {
    final config = FirebaseEnvironmentConfig.resolve(
      environmentName: 'pilot',
      emulatorEnabled: false,
      pilotOptions: PilotFirebaseOptions.ios,
      pilotValues: const {'projectId': 'loyalo-pilot'},
    );

    expect(config.environment, LoyaloFirebaseEnvironment.pilot);
    expect(config.options.projectId, 'loyalo-pilot');
    expect(config.options.iosBundleId, 'com.loyalo.loyalo.pilot');
  });

  test('le mode emulator exige la connexion aux émulateurs', () {
    expect(
      () => FirebaseEnvironmentConfig.resolve(
        environmentName: 'emulator',
        emulatorEnabled: false,
      ),
      throwsStateError,
    );
  });

  test('le flag emulator historique reste explicitement compatible', () {
    final config = FirebaseEnvironmentConfig.resolve(
      environmentName: '',
      emulatorEnabled: true,
    );

    expect(config.environment, LoyaloFirebaseEnvironment.emulator);
    expect(config.options.projectId, 'demo-loyalo-v2');
  });

  test('un projectId initialisé différent arrête le démarrage', () {
    final config = FirebaseEnvironmentConfig.resolve(
      environmentName: 'pilot',
      emulatorEnabled: false,
      pilotValues: validPilotValues,
    );

    expect(
      () => config.ensureInitializedProject('loyalo-app'),
      throwsStateError,
    );
  });
}
