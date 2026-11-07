import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !apiKey.isEmpty,
       !apiKey.hasPrefix("$(") {
      GMSServices.provideAPIKey(apiKey)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.devfest.mymap/external_launcher",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "openGoogleMaps",
            let args = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      let encodedQuery = (args["encodedQuery"] as? String) ?? ""
      let universalUrlString = (args["universalUrl"] as? String)
        ?? "https://www.google.com/maps/search/?api=1&query=\(encodedQuery)"

      if let appUrl = URL(string: "comgooglemaps://?q=\(encodedQuery)"),
         UIApplication.shared.canOpenURL(appUrl) {
        UIApplication.shared.open(appUrl, options: [:]) { success in
          result(success)
        }
        return
      }

      if let webUrl = URL(string: universalUrlString) {
        UIApplication.shared.open(webUrl, options: [:]) { success in
          result(success)
        }
        return
      }

      result(false)
    }
  }
}
