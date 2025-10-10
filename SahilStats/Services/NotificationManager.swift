// SahilStats/Services/NotificationManager.swift

import Foundation
import UserNotifications
import UIKit
import Combine


@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private override init() {
        super.init()
        checkAuthorizationStatus()
    }

    // MARK: - Permission Request

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await MainActor.run {
                self.isAuthorized = granted
            }
            print("📱 Notification authorization: \(granted ? "Granted" : "Denied")")
            return granted
        } catch {
            print("❌ Error requesting notification authorization: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Send Notifications

    /// Send a connection status notification (like AirPods)
    func sendConnectionNotification(deviceName: String, isConnected: Bool) {
        let content = UNMutableNotificationContent()
        content.title = deviceName
        content.body = isConnected ? "Connected" : "Disconnected"
        content.sound = .default

        // Add icon/image if available
        // You can add an app icon or device icon here

        let request = UNNotificationRequest(
            identifier: "connection-\(UUID().uuidString)",
            content: content,
            trigger: nil // Show immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error sending connection notification: \(error)")
            } else {
                print("✅ Connection notification sent: \(deviceName) - \(isConnected ? "Connected" : "Disconnected")")
            }
        }
    }

    /// Send a game start notification
    func sendGameStartNotification(teamName: String, opponent: String) {
        let content = UNMutableNotificationContent()
        content.title = "Game Started"
        content.body = "\(teamName) vs \(opponent)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "game-start-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error sending game start notification: \(error)")
            } else {
                print("✅ Game start notification sent")
            }
        }
    }

    /// Send a recording status notification
    func sendRecordingNotification(isRecording: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "Recording"
        content.body = isRecording ? "Recording Started" : "Recording Stopped"
        content.sound = isRecording ? .default : nil

        let request = UNNotificationRequest(
            identifier: "recording-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error sending recording notification: \(error)")
            } else {
                print("✅ Recording notification sent: \(isRecording ? "Started" : "Stopped")")
            }
        }
    }

    /// Send a custom notification with title and message
    func sendNotification(title: String, message: String, sound: Bool = true) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        if sound {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: "custom-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error sending notification: \(error)")
            } else {
                print("✅ Notification sent: \(title)")
            }
        }
    }

    // MARK: - Cancel Notifications

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func cancelNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
