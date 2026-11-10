import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../features/checkins/data/check_in_remote_data_source.dart';

abstract final class FirebaseEmulatorConfig {
  static const projectId = 'demo-loyalo-v2';

  static const enabled = bool.fromEnvironment(
    'LOYALO_USE_FIREBASE_EMULATORS',
    defaultValue: false,
  );

  static const _configuredHost = String.fromEnvironment(
    'LOYALO_FIREBASE_EMULATOR_HOST',
  );

  static String get host {
    if (_configuredHost.isNotEmpty) return _configuredHost;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return '127.0.0.1';
  }

  static const firebaseOptions = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:1234567890:ios:demo-loyalo-v2',
    messagingSenderId: '1234567890',
    projectId: projectId,
    authDomain: 'demo-loyalo-v2.localhost',
    storageBucket: 'demo-loyalo-v2.appspot.com',
    iosBundleId: 'com.loyalo.loyalo',
  );

  static Future<void> connectIfEnabled() async {
    if (!enabled) return;

    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instanceFor(
      region: approveCheckInFunctionRegion,
    ).useFunctionsEmulator(host, 5001);
  }
}
