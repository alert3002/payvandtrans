import UIKit
import Flutter
import YandexMapsMobile 

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ⬇️ ИН САТРРО ИЛОВА КУНЕД ⬇️
    YMKMapKit.setApiKey("d5e38efa-ec24-409f-9336-81be148be796")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}