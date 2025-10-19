// File: SahilStats/App/SahilStatsApp.swift (Corrected)

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import Network
import UserNotifications

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

        // Request notification permissions
        Task { @MainActor in
            _ = await NotificationManager.shared.requestAuthorization()
        }

        // Start auto-connection in background if user has trusted devices
        Task { @MainActor in
            MultipeerConnectivityManager.shared.startAutoConnectionIfNeeded()
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
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set the notification delegate
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Called when app is about to terminate
    func applicationWillTerminate(_ application: UIApplication) {
        forcePrint("🛑 App terminating - resetting roles and stopping connections")
        Task { @MainActor in
            // Clear device role
            await DeviceRoleManager.shared.clearDeviceRole()

            // Stop multipeer session
            MultipeerConnectivityManager.shared.stopSession()
        }
    }

    // Called when app enters background
    func applicationDidEnterBackground(_ application: UIApplication) {
        forcePrint("📱 App entered background - keeping connection alive")
        // Reset idle timer to allow screen to sleep in background
        UIApplication.shared.isIdleTimerDisabled = false
        debugPrint("🌙 Idle timer enabled (background) - screen can now sleep")
    }

    // Called when app returns to foreground
    func applicationWillEnterForeground(_ application: UIApplication) {
        forcePrint("📱 App returning to foreground - checking connection")
        // Ensure idle timer is enabled when returning to foreground
        // (specific views will disable it if needed, like recording)
        UIApplication.shared.isIdleTimerDisabled = false
        debugPrint("🌙 Idle timer enabled (foreground) - screen can now sleep")

        Task { @MainActor in
            // Restart auto-connection if needed
            MultipeerConnectivityManager.shared.startAutoConnectionIfNeeded()
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // This allows notifications to show even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification banner even when app is in foreground (like AirPods)
        completionHandler([.banner, .sound])
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        debugPrint("📱 Notification tapped: \(userInfo)")
        completionHandler()
    }
}
