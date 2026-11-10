// Generated from the Firebase native configurations registered for
// loyalo-pilot. Keep this file isolated from firebase_options.dart, which is
// the production configuration.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

abstract final class PilotFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'L’environnement Firebase pilote est configuré uniquement pour '
          'Android et iOS.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDIsyUBKDy_80udaf0bkXO_WIRWGk2phKg',
    appId: '1:974504708310:android:b1a7caa308984db8bf2177',
    messagingSenderId: '974504708310',
    projectId: 'loyalo-pilot',
    storageBucket: 'loyalo-pilot.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDsch3zooSJEa9Ml0i6XQb2sjendf9AZKI',
    appId: '1:974504708310:ios:d956a6e851250a3dbf2177',
    messagingSenderId: '974504708310',
    projectId: 'loyalo-pilot',
    storageBucket: 'loyalo-pilot.firebasestorage.app',
    iosBundleId: 'com.loyalo.loyalo.pilot',
  );
}
