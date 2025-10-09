// File: SahilStats/App/SahilStatsApp.swift (Fixed for iPad)

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
        _ = LiveGameManager.shared // Initialize the new manager
        
        // Initialize unified connection manager
        Task { @MainActor in
            UnifiedConnectionManager.shared.initializeOnAppLaunch()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RootNavigationView()
                .environmentObject(authService)
                .onAppear {
                    AppDelegate.orientationLock = .portrait
                    _ = FirebaseYouTubeAuthManager.shared
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task { @MainActor in
                        UnifiedConnectionManager.shared.handleAppWillEnterForeground()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    Task { @MainActor in
                        UnifiedConnectionManager.shared.handleAppDidEnterBackground()
                    }
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
