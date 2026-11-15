import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/core/firebase/firebase_emulator_config.dart';

void main() {
  test('Firebase Emulator is opt-in and uses the isolated demo project', () {
    expect(FirebaseEmulatorConfig.enabled, isFalse);
    expect(FirebaseEmulatorConfig.firebaseOptions.projectId, 'demo-loyalo-v2');
    expect(
      FirebaseEmulatorConfig.firebaseOptions.apiKey,
      matches(RegExp(r'^A[\w-]{38}$')),
      reason: 'Le SDK Android valide ce format avant un appel Functions local.',
    );
    expect(
      FirebaseEmulatorConfig.firebaseOptions.projectId,
      isNot('loyalo-app'),
    );
  });
}
