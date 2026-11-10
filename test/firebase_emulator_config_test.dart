import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/core/firebase/firebase_emulator_config.dart';

void main() {
  test('Firebase Emulator is opt-in and uses the isolated demo project', () {
    expect(FirebaseEmulatorConfig.enabled, isFalse);
    expect(FirebaseEmulatorConfig.firebaseOptions.projectId, 'demo-loyalo-v2');
    expect(
      FirebaseEmulatorConfig.firebaseOptions.projectId,
      isNot('loyalo-app'),
    );
  });
}
