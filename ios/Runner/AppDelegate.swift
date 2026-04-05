import Flutter
import UIKit
import GoogleMaps // 🔹 ADDED THIS

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 🔹 PLEASE REPLACE WITH YOUR API KEY
    GMSServices.provideAPIKey("AIzaSyAbuq1D2c5ZgL5jGjQSCp3tFWx2S7aBl60") 
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
