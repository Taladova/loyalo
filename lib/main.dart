import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase/firebase_emulator_config.dart';
import 'core/firebase/firebase_environment.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseEnvironment = FirebaseEnvironmentConfig.fromCompileTime();
  final firebaseApp = await Firebase.initializeApp(
    options: firebaseEnvironment.options,
  );
  firebaseEnvironment.ensureInitializedProject(firebaseApp.options.projectId);
  await FirebaseEmulatorConfig.connectIfEnabled();
  if (!firebaseEnvironment.usesEmulators) {
    await NotificationService().initializeAppHandlers();
  }

  // Si Crashlytics lui-même échoue à enregistrer une erreur (ex: plugin
  // natif pas encore lié après un ajout de dépendance), il ne faut surtout
  // pas laisser cette erreur remonter au même gestionnaire : ça créerait
  // une boucle d'erreurs infinie. D'où les try/catch silencieux ci-dessous.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (_) {}
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {}
    return true;
  };

  runApp(const ProviderScope(child: LoyaloApp()));
}
