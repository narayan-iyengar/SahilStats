// File: SahilStats/App/SahilStatsApp.swift (Corrected)

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import Network

@main
struct SahilStatsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthService()
    
    init() {
        FirebaseApp.configure()
        let settings = FirestoreSettings()
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
        UITabBar.appearance().itemPositioning = .centered
        _ = WifiNetworkMonitor.shared
        _ = YouTubeUploadManager.shared
        _ = LiveGameManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            RootNavigationView()
                .environmentObject(authService)
                .onAppear {
                    AppDelegate.orientationLock = .portrait
                    _ = FirebaseYouTubeAuthManager.shared
                }
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}
