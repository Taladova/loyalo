import Flutter
import FirebaseCore
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureFirebaseEmulatorIfRequested()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureFirebaseEmulatorIfRequested() {
    guard FirebaseApp.app() == nil, usesFirebaseEmulators else { return }

    let options = FirebaseOptions(
      googleAppID: "1:1:ios:1",
      gcmSenderID: "1234567890"
    )
    options.apiKey = "AIzaSy000000000000000000000000000000000"
    options.projectID = "demo-loyalo-v2"
    options.bundleID = "com.loyalo.loyalo"
    options.storageBucket = "demo-loyalo-v2.appspot.com"
    FirebaseApp.configure(options: options)
  }

  private var usesFirebaseEmulators: Bool {
    guard let encodedDefines = Bundle.main.object(
      forInfoDictionaryKey: "LoyaloDartDefines"
    ) as? String else {
      return false
    }

    return encodedDefines.split(separator: ",").contains { encodedDefine in
      guard
        let data = Data(base64Encoded: String(encodedDefine)),
        let define = String(data: data, encoding: .utf8)
      else {
        return false
      }
      return define == "LOYALO_USE_FIREBASE_EMULATORS=true"
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
